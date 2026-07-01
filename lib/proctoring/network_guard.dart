import 'dart:async';

import 'package:flutter/services.dart';

import 'behavior_event.dart';

/// One destination host the student's device tried to reach during the exam,
/// recovered from the VPN tunnel (DNS query name / TLS SNI). Because the guard
/// blocks all other apps, every hit here is a real attempt that was stopped.
class DomainHit {
  final String domain;
  final DateTime first;
  DateTime last;
  int count;
  DomainHit(this.domain, this.first)
      : last = first,
        count = 1;

  Map<String, dynamic> toJson() => {
        'domain': domain,
        'first': first.toUtc().toIso8601String(),
        'last': last.toUtc().toIso8601String(),
        'count': count,
      };
}

/// One window during which the network guard was OFF mid-exam.
class NetworkDowntime {
  final DateTime from;
  DateTime? to;
  NetworkDowntime(this.from);

  int get seconds => (to ?? DateTime.now()).difference(from).inSeconds;

  Map<String, dynamic> toJson() => {
        'from': from.toUtc().toIso8601String(),
        'to': to?.toUtc().toIso8601String(),
        'seconds': seconds,
      };
}

/// Flutter side of the local exam network guard (Android `VpnService`).
///
/// On [start] it asks the OS for VPN consent then launches the guard, which
/// blocks every other app's internet for the duration of the exam (this app is
/// excluded, so the exam keeps working). It listens for the guard going down —
/// e.g. the student turning the VPN off to browse for answers — records the
/// downtime, and exposes it for the submission report. A periodic poll
/// re-checks the real state in case an event is missed.
///
/// Android-only; on other platforms it reports "unsupported" and the exam
/// continues with the rest of the integrity checks.
class ExamNetworkGuard {
  static const MethodChannel _method = MethodChannel('exam_guard/vpn');
  static const EventChannel _events = EventChannel('exam_guard/vpn_state');

  bool _supported = false;
  bool _started = false;
  bool _connected = false;
  bool _everConnected = false;
  StreamSubscription? _sub;
  Timer? _poll;
  final List<NetworkDowntime> _downtimes = [];

  // Real attempted-host log (domain → hit), recovered from packet inspection.
  // Capped so a noisy device can't blow up the report.
  final Map<String, DomainHit> _hits = {};
  static const int _maxHits = 200;
  // Well-known answer/AI/chat hosts — flagged louder in the report.
  static const List<String> _suspicious = [
    'openai.com', 'chatgpt.com', 'gemini.google.com', 'bard.google.com',
    'claude.ai', 'anthropic.com', 'copilot.microsoft.com', 'perplexity.ai',
    'poe.com', 'quizlet.com', 'chegg.com', 'coursehero.com', 'brainly.com',
    'symbolab.com', 'wolframalpha.com', 'mathway.com', 'socratic.org',
  ];

  void _recordHit(String domain) {
    final d = domain.trim().toLowerCase();
    if (d.isEmpty || !d.contains('.')) return;
    final existing = _hits[d];
    if (existing != null) {
      existing.last = DateTime.now();
      existing.count++;
      return;
    }
    if (_hits.length >= _maxHits) return;
    _hits[d] = DomainHit(d, DateTime.now());
  }

  static bool _isSuspicious(String domain) =>
      _suspicious.any((s) => domain == s || domain.endsWith('.$s'));

  /// Called whenever the connected state changes (true = protected).
  void Function(bool connected)? onStateChange;

  bool get supported => _supported;
  bool get started => _started;
  bool get isConnected => _connected;

  /// True when the guard is supposed to be running but currently isn't —
  /// drives the student-facing warning banner.
  bool get currentlyDown => _started && _everConnected && !_connected;

  int get disconnectCount =>
      _downtimes.where((d) => d.to != null || currentlyDown).length;
  int get totalDownSeconds => _downtimes.fold(0, (s, d) => s + d.seconds);

  Future<bool> _isSupported() async {
    try {
      _supported = await _method.invokeMethod<bool>('isSupported') ?? false;
    } catch (_) {
      _supported = false;
    }
    return _supported;
  }

  /// Prepares (OS consent dialog) and starts the guard. Returns true if it was
  /// launched. Safe to call even where unsupported.
  Future<bool> start() async {
    if (!await _isSupported()) {
      _started = false;
      return false;
    }
    bool granted;
    try {
      granted = await _method.invokeMethod<bool>('prepare') ?? false;
    } catch (_) {
      granted = false;
    }
    if (!granted) {
      _started = false;
      return false;
    }

    _listen();
    try {
      await _method.invokeMethod('start');
    } catch (_) {}
    _started = true;
    _startPolling();
    return true;
  }

  void _listen() {
    _sub ??= _events.receiveBroadcastStream().listen((event) {
      final s = '$event';
      if (s.startsWith('hit:')) {
        _recordHit(s.substring(4));
        return;
      }
      switch (s) {
        case 'connected':
          _setConnected(true);
          break;
        case 'revoked':
        case 'stopped':
        case 'error':
          _setConnected(false);
          break;
      }
    }, onError: (_) {});
  }

  void _setConnected(bool connected) {
    if (connected == _connected) return;
    _connected = connected;
    if (connected) {
      _everConnected = true;
      // close any open downtime
      if (_downtimes.isNotEmpty && _downtimes.last.to == null) {
        _downtimes.last.to = DateTime.now();
      }
    } else if (_everConnected) {
      // went down after having been up — start a downtime window
      if (_downtimes.isEmpty || _downtimes.last.to != null) {
        _downtimes.add(NetworkDowntime(DateTime.now()));
      }
    }
    onStateChange?.call(connected);
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!_started) return;
      try {
        final active = await _method.invokeMethod<bool>('isActive') ?? false;
        _setConnected(active);
      } catch (_) {}
    });
  }

  Future<void> stop() async {
    _poll?.cancel();
    _poll = null;
    if (_downtimes.isNotEmpty && _downtimes.last.to == null) {
      _downtimes.last.to = DateTime.now();
    }
    _started = false;
    try {
      await _method.invokeMethod('stop');
    } catch (_) {}
    await _sub?.cancel();
    _sub = null;
  }

  /// Real attempted hosts, newest-first, with the suspicious ones marked.
  List<Map<String, dynamic>> attemptedDomains() {
    final list = _hits.values.toList()
      ..sort((a, b) => b.last.compareTo(a.last));
    return list
        .map((h) => {...h.toJson(), 'suspicious': _isSuspicious(h.domain)})
        .toList();
  }

  int get suspiciousHitCount =>
      _hits.keys.where(_isSuspicious).length;

  Map<String, dynamic> downtimeReport() => {
        'supported': _supported,
        'started': _started,
        'everConnected': _everConnected,
        'disconnectCount': _downtimes.length,
        'totalDownSeconds': totalDownSeconds,
        'currentlyDown': currentlyDown,
        'intervals': _downtimes.map((d) => d.toJson()).toList(),
        // REAL packet-derived attempt log (not a static guess).
        'attemptedDomains': attemptedDomains(),
        'attemptedCount': _hits.length,
        'suspiciousCount': suspiciousHitCount,
      };

  /// Downtime windows as scored behaviour events (high weight).
  List<BehaviorEvent> toEvents() => _downtimes
      .map((d) => BehaviorEvent(
            type: BehaviorEventType.networkGuardOff,
            timestamp: d.from,
            durationSeconds: d.seconds,
          ))
      .toList();
}
