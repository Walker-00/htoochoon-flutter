import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:htoochoon_flutter/Live-Session/core/services/screen_service.dart';
import 'package:htoochoon_flutter/Live-Session/core/services/device_storage.dart';

enum RecordingState { idle, recording, paused, saving }

/// Pausable local screen recording for a live session.
///
/// Android: true `start → pause → resume → stop` via the native
/// `htoochoon/recording` channel (MediaRecorder.pause()/resume(), API 24+).
/// Other platforms: capture via [ScreenService]; pause is best-effort and
/// reported through [pauseSupported] so the UI can hide the control.
///
/// On stop the temp file is moved into `<Video>/HtooChoon/` + the app Library
/// via [DeviceStorage]. A crash/fallback marker is written to prefs on start so
/// an orphaned recording can be recovered on the next launch.
class RecordingService {
  static const _channel = MethodChannel('htoochoon/recording');
  static const _prefsKey = 'pending_recording';

  final ScreenService _screen;
  RecordingService([ScreenService? screen]) : _screen = screen ?? ScreenService();

  final ValueNotifier<RecordingState> state =
      ValueNotifier(RecordingState.idle);

  String _org = '';
  String _program = '';
  DateTime _startedAt = DateTime.now();
  bool _nativePause = false;

  bool get pauseSupported => _nativePause;
  bool get isActive =>
      state.value == RecordingState.recording ||
      state.value == RecordingState.paused;

  Future<bool> _nativeAvailable() async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('isSupported');
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> start({
    required String org,
    required String program,
    bool includeMic = true,
  }) async {
    if (isActive) return true;
    _org = org;
    _program = program;
    _startedAt = DateTime.now();

    bool started;
    if (await _nativeAvailable()) {
      try {
        started = (await _channel.invokeMethod<bool>('start', {
              'includeMic': includeMic,
            })) ??
            false;
        _nativePause = started;
      } on PlatformException catch (e) {
        debugPrint('native record start failed: $e');
        started = false;
      }
      if (!started) {
        // Native handshake failed — fall back to the plugin recorder.
        started = await _screen.startRecording(includeMic: includeMic);
        _nativePause = false;
      }
    } else {
      started = await _screen.startRecording(includeMic: includeMic);
      _nativePause = false;
    }

    if (started) {
      state.value = RecordingState.recording;
      await _markPending();
    }
    return started;
  }

  Future<void> pause() async {
    if (state.value != RecordingState.recording) return;
    if (_nativePause) {
      try {
        await _channel.invokeMethod('pause');
      } on PlatformException catch (e) {
        debugPrint('pause failed: $e');
        return;
      }
    }
    // Without native pause we keep capturing (best-effort) but flip the UI flag
    // so the user sees a paused state; the segment stays continuous.
    state.value = RecordingState.paused;
  }

  Future<void> resume() async {
    if (state.value != RecordingState.paused) return;
    if (_nativePause) {
      try {
        await _channel.invokeMethod('resume');
      } on PlatformException catch (e) {
        debugPrint('resume failed: $e');
        return;
      }
    }
    state.value = RecordingState.recording;
  }

  /// Stops, saves to device + Library, returns the saved file path (or null).
  Future<String?> stop() async {
    if (!isActive) return null;
    state.value = RecordingState.saving;

    String? tempPath;
    if (_nativePause) {
      try {
        tempPath = await _channel.invokeMethod<String>('stop');
      } on PlatformException catch (e) {
        debugPrint('native stop failed: $e');
      }
    } else {
      tempPath = await _screen.stopAndGetFilePath();
    }

    String? saved;
    if (tempPath != null && tempPath.isNotEmpty) {
      saved = await _saveTemp(tempPath);
    }
    await _clearPending();
    state.value = RecordingState.idle;
    return saved;
  }

  Future<String> _saveTemp(String tempPath) async {
    final name = DeviceStorage.recordingName(
      org: _org.isEmpty ? 'Org' : _org,
      program: _program.isEmpty ? 'Session' : _program,
      date: _startedAt,
    );
    return DeviceStorage.saveRecording(File(tempPath), name);
  }

  // ── Fallback / crash recovery ──────────────────────────────────────────
  Future<void> _markPending() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefsKey, '$_org|$_program|${_startedAt.toIso8601String()}');
  }

  Future<void> _clearPending() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_prefsKey);
  }

  /// Called on app launch: if a recording was interrupted, try to recover the
  /// native temp file into the Library. Returns the saved path if recovered.
  Future<String?> recoverOrphan() async {
    final p = await SharedPreferences.getInstance();
    final marker = p.getString(_prefsKey);
    if (marker == null) return null;
    final parts = marker.split('|');
    _org = parts.isNotEmpty ? parts[0] : 'Org';
    _program = parts.length > 1 ? parts[1] : 'Session';
    _startedAt = parts.length > 2
        ? DateTime.tryParse(parts[2]) ?? DateTime.now()
        : DateTime.now();

    String? tempPath;
    if (Platform.isAndroid) {
      try {
        tempPath = await _channel.invokeMethod<String>('recover');
      } on PlatformException catch (_) {
      } on MissingPluginException catch (_) {}
    }
    await _clearPending();
    if (tempPath != null && tempPath.isNotEmpty && await File(tempPath).exists()) {
      return _saveTemp(tempPath);
    }
    return null;
  }
}
