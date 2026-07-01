import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'behavior_event.dart';

/// Result of the pre-exam room scan.
class RoomScanResult {
  /// Most faces seen in a single frame during the scan. The student is *behind*
  /// the back camera, so any face seen points to another person in the room.
  final int peopleSeen;

  /// Suspicious object labels detected (best-effort — see notes).
  final List<String> objectLabels;

  /// Number of frames that actually ran detection (lets the teacher know the
  /// scan really happened).
  final int framesScanned;

  /// Total measured device rotation during the scan, in radians (gyroscope
  /// integral). Proves the student physically panned the phone around rather
  /// than holding it still through a countdown. 0 if no gyroscope.
  final double panRadians;

  /// Whether the device actually exposed a gyroscope. When false the pan check
  /// is skipped (the scan falls back to a timed sweep).
  final bool hadGyroscope;

  RoomScanResult({
    required this.peopleSeen,
    required this.objectLabels,
    required this.framesScanned,
    this.panRadians = 0,
    this.hadGyroscope = false,
  });

  bool get clean => peopleSeen == 0 && objectLabels.isEmpty;

  /// Pre-exam violations folded into the behaviour score.
  List<BehaviorEvent> toEvents() {
    final now = DateTime.now();
    final events = <BehaviorEvent>[];
    // Cap people events so a noisy detector can't dominate the score.
    final people = peopleSeen.clamp(0, 3);
    for (var i = 0; i < people; i++) {
      events.add(BehaviorEvent(type: BehaviorEventType.roomPerson, timestamp: now));
    }
    for (final _ in objectLabels.take(3)) {
      events.add(BehaviorEvent(type: BehaviorEventType.roomObject, timestamp: now));
    }
    return events;
  }

  Map<String, dynamic> toJson() => {
        'peopleSeen': peopleSeen,
        'objectLabels': objectLabels,
        'framesScanned': framesScanned,
        'panDegrees': (panRadians * 180 / math.pi).round(),
        'hadGyroscope': hadGyroscope,
        'clean': clean,
      };
}

/// Scans the student's surroundings with the **back camera** before the exam,
/// running ML Kit face detection (other people) and object detection
/// (best-effort objects). Front-camera behaviour monitoring is separate and
/// runs during the exam.
class RoomScanner {
  RoomScanner({
    this.throttle = const Duration(milliseconds: 400),
    this.requiredPanRadians = 4.0, // ≈ 230° of cumulative panning
  });

  final Duration throttle;

  /// Cumulative device rotation the student must perform for the scan to count
  /// as a real sweep. Integrated from the gyroscope.
  final double requiredPanRadians;

  /// Live UI update: (peopleNow, objectsNow).
  void Function(int people, int objects)? onUpdate;
  void Function(CameraController controller)? onCameraReady;
  void Function(String message)? onError;

  /// Live pan progress, 0..1 (how much of [requiredPanRadians] is done).
  void Function(double progress)? onPanProgress;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
  );
  final ObjectDetector _objectDetector = ObjectDetector(
    options: ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
    ),
  );

  // Suspicious generic labels the base model may emit. Coarse by design.
  static const _suspiciousKeywords = [
    'phone', 'mobile', 'laptop', 'computer', 'monitor', 'tablet',
    'book', 'paper', 'screen', 'tv', 'television', 'remote',
  ];

  CameraController? _controller;
  CameraDescription? _camera;
  bool _running = false;
  bool _processing = false;
  DateTime? _lastFrame;

  int _maxPeople = 0;
  final Set<String> _objects = {};
  int _frames = 0;

  // ── Gyroscope pan tracking ────────────────────────────────────────────────
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  double _panRadians = 0;
  DateTime? _lastGyro;
  bool _hadGyro = false;

  CameraController? get controller => _controller;

  /// 0..1 — how much of the required panning sweep is done. Always 1 when the
  /// device has no gyroscope (so the scan can still complete on a timed basis).
  double get panProgress {
    if (!_hadGyro) return 0;
    return (_panRadians / requiredPanRadians).clamp(0.0, 1.0);
  }

  bool get hadGyroscope => _hadGyro;

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  void _startGyro() {
    try {
      _gyroSub = gyroscopeEventStream(
        samplingPeriod: const Duration(milliseconds: 50),
      ).listen(
        (e) {
          _hadGyro = true;
          final now = DateTime.now();
          final dt = _lastGyro == null
              ? 0.0
              : now.difference(_lastGyro!).inMicroseconds / 1e6;
          _lastGyro = now;
          // Ignore absurd gaps (first sample, app resumed) so a single frame
          // can't spike the integral.
          if (dt <= 0 || dt > 0.5) return;
          // Magnitude of angular velocity (rad/s) × dt → angular path travelled.
          final mag = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
          // Deadzone: ignore tiny hand jitter so just holding still adds nothing.
          if (mag < 0.15) return;
          _panRadians += mag * dt;
          onPanProgress?.call(panProgress);
        },
        onError: (_) {
          // No gyroscope on this device — leave _hadGyro false so the scan
          // falls back to a timed sweep.
        },
        cancelOnError: false,
      );
    } catch (_) {
      // Sensor unavailable; pan check is skipped.
    }
  }

  Future<bool> start() async {
    if (_running) return true;
    _startGyro();
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        onError?.call('No camera available');
        return false;
      }
      _camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
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
      onError?.call('Room scan camera failed: $e');
      return false;
    }
  }

  void _onImage(CameraImage image) async {
    if (!_running || _processing) return;
    final now = DateTime.now();
    if (_lastFrame != null && now.difference(_lastFrame!) < throttle) return;
    _lastFrame = now;
    _processing = true;
    try {
      final input = _toInputImage(image);
      if (input == null) return;

      final faces = await _faceDetector.processImage(input);
      if (faces.length > _maxPeople) _maxPeople = faces.length;

      var objectsNow = 0;
      try {
        final objects = await _objectDetector.processImage(input);
        for (final o in objects) {
          for (final l in o.labels) {
            final text = l.text.toLowerCase();
            if (_suspiciousKeywords.any(text.contains)) {
              _objects.add(l.text);
              objectsNow++;
            }
          }
        }
      } catch (_) {
        // object detection is best-effort
      }

      _frames++;
      onUpdate?.call(faces.length, objectsNow);
    } catch (e) {
      if (kDebugMode) debugPrint('RoomScanner frame error: $e');
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
      // Back camera.
      final rotationCompensation =
          (camera.sensorOrientation - deviceRotation + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || image.planes.isEmpty) return null;
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

  RoomScanResult result() => RoomScanResult(
        peopleSeen: _maxPeople,
        objectLabels: _objects.toList(),
        framesScanned: _frames,
        panRadians: _panRadians,
        hadGyroscope: _hadGyro,
      );

  Future<void> stop() async {
    _running = false;
    await _gyroSub?.cancel();
    _gyroSub = null;
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
    await _faceDetector.close();
    await _objectDetector.close();
  }
}
