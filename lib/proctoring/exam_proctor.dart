import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'violation.dart';

/// Lightweight, dependency-free anti-cheat orchestrator for exam taking.
///
/// Adapted (slimmed) from `exam-guardian`'s `ExamMonitor`, keeping only the
/// pieces that work without camera / ML / network entitlements. It watches the
/// app lifecycle and applies the product's exact policy:
///
///  * Normal in-app behaviour → never interrupts the student; only a cheat
///    score accumulates.
///  * Leaving the exam environment (backgrounding, app-switch, split-view, an
///    overlay app — all surface as `inactive`/`paused`/`hidden`):
///      - a SHORT absence → record + warn (snackbar) + bump score, keep going;
///      - a LONG single absence (≥ [forceExitAfter], even the first time) →
///        force-exit the exam (the screen submits whatever exists and reports
///        "active cheating detected").
///
/// The cheat score is advisory (0–100, higher = more likely cheating). It is
/// reported to the teacher/admin and NEVER changes the grade.
class ExamProctor with WidgetsBindingObserver {
  ExamProctor({
    this.warnGrace = const Duration(seconds: 2),
    this.forceExitAfter = const Duration(seconds: 15),
    this.flagThreshold = 40,
  });

  /// Absences shorter than this are treated as transient blips (e.g. iOS
  /// `inactive` when the notification shade is pulled) and ignored.
  final Duration warnGrace;

  /// A single continuous absence reaching this duration force-exits the exam,
  /// even on the first occurrence.
  final Duration forceExitAfter;

  /// At/above this cheat score the submission is marked `flagged`.
  final int flagThreshold;

  /// Fired for each recorded (non-trivial) away event. Use it to warn the
  /// student. Never fired for a force-exit (that uses [onForceExit]).
  void Function(Violation violation)? onWarn;

  /// Fired once when a long absence forces the exam to end.
  VoidCallback? onForceExit;

  final List<Violation> _violations = [];
  int _totalAwaySeconds = 0;
  bool _forcedExit = false;
  bool _ended = false;

  bool _monitoring = false;
  bool _hasFocus = true;
  DateTime? _lostAt;
  Timer? _forceTimer;

  // ── Public read API ────────────────────────────────────────────────────────
  List<Violation> get violations => List.unmodifiable(_violations);
  int get violationCount => _violations.length;
  bool get forcedExit => _forcedExit;
  int get totalAwaySeconds => _totalAwaySeconds;

  /// Advisory cheat score, 0–100 (higher = more likely cheating).
  int get cheatScore {
    if (_forcedExit) return 100;
    final raw = _violations.fold<double>(
      0,
      (sum, v) => sum + 8 + math.min(v.durationSeconds, 20),
    );
    return raw.clamp(0, 100).round();
  }

  bool get flagged => _forcedExit || cheatScore >= flagThreshold;

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  void start() {
    if (_monitoring) return;
    _monitoring = true;
    _hasFocus = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void stop() {
    if (!_monitoring) return;
    _monitoring = false;
    _forceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  void dispose() => stop();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_monitoring || _ended) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _onFocusLost();
        break;
      case AppLifecycleState.resumed:
      case AppLifecycleState.detached:
        _onFocusRegained();
        break;
    }
  }

  void _onFocusLost() {
    if (!_hasFocus) return; // already counting this absence
    _hasFocus = false;
    _lostAt = DateTime.now();
    // If they stay away this long, end the exam — even if they never return.
    _forceTimer?.cancel();
    _forceTimer = Timer(forceExitAfter, _triggerForceExit);
  }

  void _onFocusRegained() {
    if (_hasFocus) return;
    _hasFocus = true;
    _forceTimer?.cancel();

    final away = _lostAt == null
        ? 0
        : DateTime.now().difference(_lostAt!).inSeconds;
    _lostAt = null;

    // Ignore ultra-brief blips.
    if (away < warnGrace.inSeconds) return;

    _totalAwaySeconds += away;
    final v = Violation(
      type: ViolationType.appSwitch,
      description: 'Left the exam for ${away}s',
      timestamp: DateTime.now(),
      severity: ViolationSeverity.high.value,
      severityLevel: ViolationSeverity.high,
      durationSeconds: away,
      tags: ['app_switch', 'duration:${away}s'],
    );
    _violations.add(v);
    onWarn?.call(v);
  }

  void _triggerForceExit() {
    if (_ended) return;
    _ended = true;
    _forcedExit = true;
    final away = _lostAt == null
        ? forceExitAfter.inSeconds
        : DateTime.now().difference(_lostAt!).inSeconds;
    _totalAwaySeconds += away;
    _violations.add(Violation(
      type: ViolationType.appSwitch,
      description: 'Left the exam for ${away}s — exam ended',
      timestamp: DateTime.now(),
      severity: ViolationSeverity.critical.value,
      severityLevel: ViolationSeverity.critical,
      durationSeconds: away,
      tags: ['forced_exit', 'duration:${away}s'],
    ));
    stop();
    onForceExit?.call();
  }

  /// The full timeline + summary, stored verbatim on the submission as Json and
  /// shown to the teacher/admin.
  Map<String, dynamic> buildReport() => {
        'cheatScore': cheatScore,
        'violationCount': violationCount,
        'flagged': flagged,
        'forcedExit': _forcedExit,
        'totalAwaySeconds': _totalAwaySeconds,
        'violations': _violations.map((v) => v.toJson()).toList(),
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
      };
}
