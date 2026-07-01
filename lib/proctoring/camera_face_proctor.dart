import 'dart:async';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'behavior_event.dart';

/// Front-camera face / behaviour proctor built on ML Kit face detection.
///
/// Runs the front camera as a throttled image stream (~3 fps), detects faces,
/// and classifies the student's behaviour each frame into a single "condition":
/// MULTIPLE_PERSON / FACE_MISSING / FACE_LEFT / LOOKING_DOWN / LOOKING_LEFT /
/// LOOKING_RIGHT / normal. It tracks how long each condition persists and how
/// far the head angle deviates, then emits a finalized [BehaviorEvent] (with
/// duration + worst angle) when the condition ends — so the score engine can
/// weight by duration and angle.
///
/// This is adapted from `exam-guardian`'s FaceDetectionService but rewritten to
/// be a clean state machine (the reference fired one violation per frame, which
/// floods the score and loses duration). It is **silent** — it never warns the
/// student; events flow to the teacher/admin via the submission report.
class CameraFaceProctor {
  CameraFaceProctor({
    this.headTurnThresholdDeg = 25.0,
    this.headDownThresholdDeg = 18.0,
    this.throttle = const Duration(milliseconds: 333),
    this.minEventGrace = const Duration(milliseconds: 1500),
    this.faceMissingGrace = const Duration(seconds: 2),
  });

  /// |headEulerAngleY| beyond this ⇒ looking left/right.
  final double headTurnThresholdDeg;

  /// headEulerAngleX below -threshold ⇒ looking down.
  final double headDownThresholdDeg;

  final Duration throttle;

  /// Conditions shorter than this are treated as transient and dropped (avoids
  /// flagging a quick natural glance).
  final Duration minEventGrace;

  /// Face-missing needs a slightly longer grace (a blink of detection loss is
  /// common).
  final Duration faceMissingGrace;

  /// Emitted when a condition ends and qualifies as a real event.
  void Function(BehaviorEvent event)? onEvent;
  void Function(String message)? onError;
  void Function(CameraController controller)? onCameraReady;

  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableClassification: false,
      enableTracking: false,
    ),
  );

  CameraController? _controller;
  CameraDescription? _camera;
  bool _starting = false;
  bool _running = false;
  bool _processing = false;
  bool _paused = false;
  DateTime? _lastFrame;

  // Smoothing (exponential moving average) to filter micro-shaking.
  double? _smoothY;
  double? _smoothX;
  static const double _alpha = 0.4;

  // Current condition state machine.
  BehaviorEventType? _condition;
  DateTime? _conditionStart;
  double _conditionMaxAngle = 0;

  CameraController? get controller => _controller;
  bool get isRunning => _running;

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  Future<bool> start() async {
    if (_running || _starting) return _running;
    _starting = true;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        onError?.call('No camera available');
        return false;
      }
      _camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        _camera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await _controller!.initialize();
      onCameraReady?.call(_controller!);

      await _controller!.startImageStream(_onImage);
      _running = true;
      return true;
    } catch (e) {
      onError?.call('Camera start failed: $e');
      return false;
    } finally {
      _starting = false;
    }
  }

  void pause() => _paused = true;
  void resume() => _paused = false;

  void _onImage(CameraImage image) async {
    if (!_running || _paused || _processing) return;
    final now = DateTime.now();
    if (_lastFrame != null && now.difference(_lastFrame!) < throttle) return;
    _lastFrame = now;
    _processing = true;
    try {
      final input = _toInputImage(image);
      if (input == null) return;
      final faces = await _detector.processImage(input);
      _evaluate(faces, image);
    } catch (e) {
      // Per-frame errors are non-fatal; keep the stream alive.
      if (kDebugMode) debugPrint('CameraFaceProctor frame error: $e');
    } finally {
      _processing = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final camera = _camera;
    final controller = _controller;
    if (camera == null || controller == null) return null;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    } else {
      final deviceRotation =
          _orientations[controller.value.deviceOrientation] ?? 0;
      int rotationCompensation;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation =
            (camera.sensorOrientation + deviceRotation) % 360;
      } else {
        rotationCompensation =
            (camera.sensorOrientation - deviceRotation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    // We requested single-plane nv21 (Android) / bgra8888 (iOS).
    if (image.planes.isEmpty) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _evaluate(List<Face> faces, CameraImage image) {
    BehaviorEventType? condition;
    double angle = 0;

    if (faces.length > 1) {
      condition = BehaviorEventType.multiplePerson;
    } else if (faces.isEmpty) {
      condition = BehaviorEventType.faceMissing;
    } else {
      final face = faces.first;

      // EMA-smooth the head angles.
      final y = face.headEulerAngleY;
      final x = face.headEulerAngleX;
      if (y != null) {
        _smoothY = _smoothY == null ? y : _alpha * y + (1 - _alpha) * _smoothY!;
      }
      if (x != null) {
        _smoothX = _smoothX == null ? x : _alpha * x + (1 - _alpha) * _smoothX!;
      }
      final sy = _smoothY ?? 0;
      final sx = _smoothX ?? 0;

      // Face drifting out of frame horizontally ⇒ FACE_LEFT (best-effort).
      final outOfFrame = _isNearHorizontalEdge(face.boundingBox.center.dx,
          Size(image.width.toDouble(), image.height.toDouble()));

      if (outOfFrame) {
        condition = BehaviorEventType.faceLeft;
      } else if (sx < -headDownThresholdDeg) {
        condition = BehaviorEventType.lookingDown;
        angle = sx.abs();
      } else if (sy.abs() > headTurnThresholdDeg) {
        condition =
            sy < 0 ? BehaviorEventType.lookingLeft : BehaviorEventType.lookingRight;
        angle = sy.abs();
      } else {
        condition = null; // looking at screen — normal
      }
    }

    _transition(condition, angle);
  }

  bool _isNearHorizontalEdge(double centerX, Size imageSize) {
    final w = imageSize.width;
    if (w <= 0) return false;
    final ratio = centerX / w;
    return ratio < 0.12 || ratio > 0.88;
  }

  /// Drives the condition state machine, finalizing the previous condition when
  /// it changes.
  void _transition(BehaviorEventType? next, double angle) {
    final now = DateTime.now();

    if (_condition == next) {
      // Same condition continues — track the worst angle.
      if (angle > _conditionMaxAngle) _conditionMaxAngle = angle;
      return;
    }

    // Condition changed — finalize the one that just ended.
    _finalizeCurrent(now);

    _condition = next;
    _conditionStart = next == null ? null : now;
    _conditionMaxAngle = angle;
  }

  void _finalizeCurrent(DateTime end) {
    final cond = _condition;
    final start = _conditionStart;
    if (cond == null || start == null) return;

    final duration = end.difference(start);
    final grace = cond == BehaviorEventType.faceMissing
        ? faceMissingGrace
        : minEventGrace;
    if (duration < grace) return; // transient — ignore

    onEvent?.call(BehaviorEvent(
      type: cond,
      timestamp: start,
      durationSeconds: duration.inSeconds,
      angle: _conditionMaxAngle,
    ));
  }

  Future<void> stop() async {
    if (!_running && _controller == null) return;
    _running = false;
    // Finalize any in-progress condition before tearing down.
    _finalizeCurrent(DateTime.now());
    _condition = null;
    _conditionStart = null;

    try {
      if (_controller != null) {
        if (_controller!.value.isStreamingImages) {
          await _controller!.stopImageStream();
        }
        await _controller!.dispose();
      }
    } catch (_) {}
    _controller = null;
  }

  Future<void> dispose() async {
    await stop();
    // ML Kit has no desktop implementation; closing the detector hits a method
    // channel that can throw MissingPluginException off-device. Never fatal.
    try {
      await _detector.close();
    } catch (_) {}
  }
}
