import 'dart:async';

import 'package:flutter/widgets.dart';

import '../api/api_service.dart';

/// 📈 Lightweight heartbeat that feeds learning-time / active-days analytics.
/// Posts `/activity/ping {kind:'APP'}` every 60s while the app is foregrounded.
/// Idempotent singleton — calling [start] repeatedly is safe.
class ActivityPinger with WidgetsBindingObserver {
  ActivityPinger._();
  static final ActivityPinger instance = ActivityPinger._();

  ApiService? _api;
  Timer? _timer;
  bool _foreground = true;
  bool _started = false;

  void start(ApiService api) {
    _api = api;
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _ping(); // immediate ping marks the session active
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_foreground) _ping();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }

  Future<void> _ping() async {
    try {
      await _api?.pingActivity({'kind': 'APP'});
    } catch (_) {
      /* best-effort; analytics must never break the app */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _ping();
  }
}
