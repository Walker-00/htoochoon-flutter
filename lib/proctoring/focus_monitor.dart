import 'dart:async';
import 'package:flutter/widgets.dart';
import 'violation.dart';

/// Lightweight, dependency-free focus/app-switch monitor for exam proctoring.
/// Adapted from exam-guardian's FocusMonitor (the AppLifecycleState core), minus
/// its desktop process-scanning + singleton. The original add/removeObserver used
/// two different instances (observer never detached); here the class IS the
/// observer, so teardown is clean. Records a [Violation] when focus is lost
/// beyond [gracePeriod] (grace absorbs transient inactive blips, e.g. iOS).
class ProctorFocusMonitor with WidgetsBindingObserver {
  ProctorFocusMonitor({this.gracePeriod = const Duration(seconds: 2)});
  final Duration gracePeriod;

  Function(Violation)? onViolation;

  bool _monitoring = false;
  bool _hasFocus = true;
  Timer? _graceTimer;
  DateTime? _lostAt;

  void startMonitoring() {
    if (_monitoring) return;
    _monitoring = true;
    _hasFocus = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void stopMonitoring() {
    if (!_monitoring) return;
    _monitoring = false;
    _graceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _handleFocusLoss();
        break;
      case AppLifecycleState.resumed:
      case AppLifecycleState.detached:
        _resetGrace();
        break;
    }
  }

  void _handleFocusLoss() {
    if (!_monitoring || !_hasFocus) return;
    _hasFocus = false;
    _lostAt = DateTime.now();
    _graceTimer?.cancel();
    _graceTimer = Timer(gracePeriod, () {
      if (!_hasFocus) _record();
    });
  }

  void _resetGrace() {
    _hasFocus = true;
    _graceTimer?.cancel();
    _lostAt = null;
  }

  void _record() {
    final secs =
        _lostAt == null ? 0 : DateTime.now().difference(_lostAt!).inSeconds;
    onViolation?.call(Violation(
      type: ViolationType.focusLoss,
      description: 'Left the exam app for ${secs}s',
      timestamp: _lostAt ?? DateTime.now(),
      severity: ViolationSeverity.medium.value,
      severityLevel: ViolationSeverity.medium,
      durationSeconds: secs,
      tags: ['focus_loss', 'duration:${secs}s'],
    ));
  }

  void dispose() => stopMonitoring();
}
