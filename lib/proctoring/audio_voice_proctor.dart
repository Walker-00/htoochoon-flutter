import 'dart:async';

import 'package:noise_meter/noise_meter.dart';

import 'behavior_event.dart';

/// Microphone voice-activity proctor.
///
/// Continuously tracks the ambient noise floor with an exponential moving
/// average and flags **sustained** speech above that floor as a
/// VOICE_DETECTED event (with duration). A short single noise (a cough, a
/// door) is ignored. The floor keeps adapting during quiet stretches, so the
/// detector works in any room and follows slow changes (a fan, traffic).
///
/// Rewritten after the original (a fixed-baseline + hard `db <= 0` guard) was
/// reported as "not detecting" on real devices: it threw away every reading
/// whose `meanDecibel` was non-positive (common on quiet Android mics) and
/// never re-adapted, so a bad initial calibration disabled it for the whole
/// exam. It also never restarted the stream after a transient mic error.
///
/// Silent: emits events to the report only; never warns the student.
class AudioVoiceProctor {
  AudioVoiceProctor({
    this.marginDb = 12.0,
    this.minSpeech = const Duration(milliseconds: 700),
    this.silenceGap = const Duration(milliseconds: 900),
    this.warmupSamples = 8,
  });

  /// Speech must exceed (adaptive floor + [marginDb]).
  final double marginDb;

  /// Loudness must hold this long before it counts as speech.
  final Duration minSpeech;

  /// Quiet must hold this long before a speech segment is considered ended.
  final Duration silenceGap;

  /// Readings collected before the floor is considered usable. Detection holds
  /// off until then so the very first loud frame can't false-fire.
  final int warmupSamples;

  void Function(BehaviorEvent event)? onEvent;
  void Function(String message)? onError;

  /// Live monitor hook (level, floor, threshold, speaking) — used by debug /
  /// verification UIs to confirm the mic is actually producing readings.
  void Function(double db, double floor, double threshold, bool speaking)?
      onLevel;

  NoiseMeter? _meter;
  StreamSubscription<NoiseReading>? _sub;
  bool _running = false;
  int _samples = 0;
  int _restartAttempts = 0;

  // Adaptive ambient floor (EMA). Null until the first valid reading.
  double? _floor;

  DateTime? _aboveSince;
  DateTime? _belowSince;
  bool _speaking = false;
  DateTime? _speechStart;

  bool get isRunning => _running;

  Future<bool> start() async {
    if (_running) return true;
    final ok = _listen();
    _running = ok;
    return ok;
  }

  bool _listen() {
    try {
      _meter = NoiseMeter();
      _sub = _meter!.noise.listen(
        _onReading,
        onError: _onStreamError,
        cancelOnError: false,
      );
      return true;
    } catch (e) {
      onError?.call('Audio start failed: $e');
      return false;
    }
  }

  void _onStreamError(Object e) {
    onError?.call('Audio error: $e');
    // Transient mic glitches (focus loss, another app grabbing the mic) kill
    // the stream. Try to bring it back a few times instead of going silent for
    // the rest of the exam.
    if (!_running || _restartAttempts >= 5) return;
    _restartAttempts++;
    _sub?.cancel();
    _sub = null;
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_running && _sub == null) _listen();
    });
  }

  void _onReading(NoiseReading reading) {
    if (!_running) return;
    _restartAttempts = 0; // healthy stream
    final db = reading.meanDecibel;
    // Only discard genuinely broken samples — NOT merely non-positive ones,
    // which are valid on quiet mics and were wrongly dropped before.
    if (db.isNaN || db.isInfinite) return;
    final now = DateTime.now();
    _samples++;

    // Seed / adapt the ambient floor.
    if (_floor == null) {
      _floor = db;
    } else if (!_speaking && db < _floor! + marginDb) {
      // Adapt only while quiet so speech doesn't drag the floor up. Fast pull
      // downward (room got quieter), slow drift upward.
      final alpha = db < _floor! ? 0.2 : 0.05;
      _floor = _floor! + alpha * (db - _floor!);
    }

    final threshold = _floor! + marginDb;
    onLevel?.call(db, _floor!, threshold, _speaking);

    // Hold off detection until the floor has settled.
    if (_samples < warmupSamples) return;

    if (db >= threshold) {
      _belowSince = null;
      if (!_speaking) {
        _aboveSince ??= now;
        if (now.difference(_aboveSince!) >= minSpeech) {
          _speaking = true;
          _speechStart = _aboveSince;
        }
      }
    } else {
      _aboveSince = null;
      if (_speaking) {
        _belowSince ??= now;
        if (now.difference(_belowSince!) >= silenceGap) {
          _finalizeSpeech(_belowSince!);
        }
      }
    }
  }

  void _finalizeSpeech(DateTime end) {
    final start = _speechStart;
    _speaking = false;
    _belowSince = null;
    _aboveSince = null;
    _speechStart = null;
    if (start == null) return;
    final duration = end.difference(start);
    if (duration <= Duration.zero) return;
    onEvent?.call(BehaviorEvent(
      type: BehaviorEventType.voiceDetected,
      timestamp: start,
      durationSeconds: duration.inSeconds,
    ));
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    if (_speaking) _finalizeSpeech(DateTime.now());
    await _sub?.cancel();
    _sub = null;
    _meter = null;
  }

  void dispose() {
    stop();
  }
}
