import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import 'audio_voice_proctor.dart';
import 'behavior_event.dart';
import 'behavior_score_engine.dart';
import 'camera_face_proctor.dart';
import 'room_scanner.dart';

/// Orchestrates the **silent** camera + audio proctoring for one exam attempt.
///
/// Owns the [CameraFaceProctor], [AudioVoiceProctor] and the [BehaviorScoreEngine],
/// routes every detected [BehaviorEvent] into the engine, and pauses the camera
/// while the app is backgrounded (the OS suspends the camera anyway). It never
/// surfaces anything to the student — the accumulated score + timeline are read
/// at submit time and sent to the teacher/admin.
class BehaviorMonitor with WidgetsBindingObserver {
  BehaviorMonitor();

  final CameraFaceProctor _camera = CameraFaceProctor();
  final AudioVoiceProctor _audio = AudioVoiceProctor();
  final BehaviorScoreEngine _engine = BehaviorScoreEngine();

  bool _cameraOk = false;
  bool _audioOk = false;
  bool _observing = false;
  final List<String> _notes = [];
  RoomScanResult? _roomScan;

  /// Notified when the camera controller becomes available (for the preview).
  void Function(CameraController controller)? onCameraReady;

  CameraController? get cameraController => _camera.controller;
  bool get cameraActive => _cameraOk;
  bool get audioActive => _audioOk;

  /// Advisory camera+audio cheat score (0–100).
  int get cheatScore => _engine.cheatScore;
  int get eventCount => _engine.eventCount;

  /// Folds the pre-exam room-scan findings into the score + timeline.
  void ingestRoomScan(RoomScanResult result) {
    _roomScan = result;
    for (final e in result.toEvents()) {
      _engine.add(e);
    }
  }

  /// Starts whichever sensors the permissions allow. [withCamera]/[withAudio]
  /// reflect the granted permissions decided by the caller.
  Future<void> start({required bool withCamera, required bool withAudio}) async {
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }

    if (withCamera) {
      _camera.onEvent = _engine.add;
      _camera.onCameraReady = (c) => onCameraReady?.call(c);
      _camera.onError = (m) => _notes.add('camera: $m');
      _cameraOk = await _camera.start();
      if (!_cameraOk) _notes.add('camera unavailable');
    } else {
      _notes.add('camera permission denied');
    }

    if (withAudio) {
      _audio.onEvent = _engine.add;
      _audio.onError = (m) => _notes.add('audio: $m');
      _audioOk = await _audio.start();
      if (!_audioOk) _notes.add('audio unavailable');
    } else {
      _notes.add('microphone permission denied');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _camera.resume();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _camera.pause();
        break;
    }
  }

  /// Full camera+audio report merged into the submission's `proctorReport`.
  Map<String, dynamic> buildReport() {
    final report = _engine.buildReport();
    report['cameraActive'] = _cameraOk;
    report['audioActive'] = _audioOk;
    if (_roomScan != null) report['roomScan'] = _roomScan!.toJson();
    if (_notes.isNotEmpty) report['notes'] = List<String>.from(_notes);
    return report;
  }

  List<BehaviorEvent> get events => _engine.events;

  Future<void> stop() async {
    await _camera.stop();
    await _audio.stop();
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
  }

  Future<void> dispose() async {
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    await _camera.dispose();
    _audio.dispose();
  }
}
