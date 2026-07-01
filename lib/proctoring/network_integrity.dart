import 'dart:async';
import 'dart:io';

import 'behavior_event.dart';

/// Passive, cross-platform proxy / VPN DETECTION for a proctored exam.
///
/// Unlike [ExamNetworkGuard] (the Android-only `VpnService` that actively blocks
/// other apps' traffic), this never blocks anything — it only *detects* whether
/// the student is sitting behind a proxy or VPN-like tunnel, which is a common
/// way to reach answer sites or route around a school firewall. It works on
/// every native platform (Android / iOS / Windows / macOS / Linux) with pure
/// `dart:io`, so desktop and iOS finally get a network integrity signal too.
///
/// Two signals:
///  * PROXY — a system HTTP(S) proxy is configured (env vars / `HttpClient`
///    proxy resolution returns something other than DIRECT).
///  * VPN   — a VPN-style network interface is up (tun/utun/ppp/wg/ipsec/…).
///
/// Both are advisory and folded into the same 0–100 cheat score as every other
/// proctoring signal.
class NetworkSnapshot {
  final bool proxy;
  final bool vpn;
  final List<String> vpnInterfaces;
  final String? proxyValue;

  const NetworkSnapshot({
    required this.proxy,
    required this.vpn,
    required this.vpnInterfaces,
    required this.proxyValue,
  });

  bool get clean => !proxy && !vpn;
}

class NetworkIntegrity {
  // Interface-name fragments that indicate a VPN / tunnel. Matched case-
  // insensitively against the interface name on every platform.
  static const List<String> _vpnHints = [
    'tun', // OpenVPN / generic tunnel (Linux/Android)
    'tap', // OpenVPN bridged
    'utun', // macOS / iOS tunnel (also WireGuard, built-in VPN)
    'ppp', // PPTP / L2TP
    'ipsec', // IPSec / IKEv2
    'wg', // WireGuard (incl. wg-mullvad)
    'wireguard',
    'nordlynx', // NordVPN
    'nordvpn',
    'proton', // ProtonVPN
    'tailscale',
    'zt', // ZeroTier
    'gpd', // GlobalProtect
    'pan', // Palo Alto GlobalProtect (panvpn)
    'warp', // Cloudflare WARP
    'cloudflare',
    'mullvad',
    'expressvpn',
    'surfshark',
    'windscribe',
    'openvpn',
    'softether',
    'pia', // Private Internet Access
    'vpn',
  ];

  Timer? _poll;
  bool _started = false;

  bool _proxySeen = false;
  bool _vpnSeen = false;
  DateTime? _proxyFirst;
  DateTime? _vpnFirst;
  String? _proxyValue;
  final Set<String> _vpnInterfaces = {};

  // Network fingerprint: the public IP the student takes the exam from, and
  // whether it changes mid-exam (a strong sign of toggling a VPN / switching
  // networks). Informational/trackable — captured best-effort, never blocks.
  String? _firstPublicIp;
  String? _publicIp;
  bool _ipChanged = false;
  DateTime? _lastIpFetch;

  /// Fired whenever the clean/dirty state flips — drives the warning banner.
  void Function(bool clean)? onChange;

  bool get proxyDetected => _proxySeen;
  bool get vpnDetected => _vpnSeen;
  bool get clean => !_proxySeen && !_vpnSeen;

  /// One scan of the current network state. Safe to call anywhere; never throws.
  Future<NetworkSnapshot> check() async {
    // Env vars + Dart proxy resolution (cheap, sync) then system-level probe
    // (GNOME gsettings / macOS scutil / Windows registry) which catches GUI
    // proxies that never appear in environment variables.
    final proxyValue = _detectProxy() ?? await _detectSystemProxy();
    final vpnIfaces = await _detectVpnInterfaces();
    final toolVpn = await _detectVpnViaTools();
    final allVpn = <String>{...vpnIfaces, ...toolVpn}.toList();
    return NetworkSnapshot(
      proxy: proxyValue != null,
      vpn: allVpn.isNotEmpty,
      vpnInterfaces: allVpn,
      proxyValue: proxyValue,
    );
  }

  /// Begin periodic monitoring. Records the first time each signal is seen so a
  /// student enabling a VPN mid-exam is still caught. Re-checks every [interval].
  Future<void> start({
    Duration interval = const Duration(seconds: 10),
  }) async {
    if (_started) return;
    _started = true;
    await _tick();
    _poll = Timer.periodic(interval, (_) => _tick());
  }

  Future<void> _tick() async {
    final before = clean;
    final snap = await check();
    await _trackPublicIp();
    if (snap.proxy && !_proxySeen) {
      _proxySeen = true;
      _proxyFirst = DateTime.now();
      _proxyValue = snap.proxyValue;
    }
    if (snap.vpn) {
      if (!_vpnSeen) {
        _vpnSeen = true;
        _vpnFirst = DateTime.now();
      }
      _vpnInterfaces.addAll(snap.vpnInterfaces);
    }
    if (clean != before) onChange?.call(clean);
  }

  Future<void> stop() async {
    _poll?.cancel();
    _poll = null;
    _started = false;
  }

  /// Best-effort public-IP capture (throttled to once a minute). Records the
  /// first IP seen and flips [_ipChanged] if it ever differs — i.e. the student
  /// switched networks / toggled a VPN mid-exam. Never throws, never blocks.
  Future<void> _trackPublicIp() async {
    final now = DateTime.now();
    if (_lastIpFetch != null &&
        now.difference(_lastIpFetch!) < const Duration(seconds: 60)) {
      return;
    }
    _lastIpFetch = now;
    final ip = await _fetchPublicIp();
    if (ip == null || ip.isEmpty) return;
    _publicIp = ip;
    if (_firstPublicIp == null) {
      _firstPublicIp = ip;
    } else if (_firstPublicIp != ip) {
      _ipChanged = true;
    }
  }

  Future<String?> _fetchPublicIp() async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final req = await client
          .getUrl(Uri.parse('https://api.ipify.org'))
          .timeout(const Duration(seconds: 4));
      final res = await req.close().timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return null;
      final body = await res
          .transform(const SystemEncoding().decoder)
          .join()
          .timeout(const Duration(seconds: 4));
      final ip = body.trim();
      // crude sanity: looks like an IPv4/IPv6, not an error page
      if (ip.isEmpty || ip.length > 64 || ip.contains('<')) return null;
      return ip;
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  String? _detectProxy() {
    // 1. Environment proxy variables (covers Linux/macOS/Windows shells + CI).
    const keys = [
      'HTTP_PROXY',
      'http_proxy',
      'HTTPS_PROXY',
      'https_proxy',
      'ALL_PROXY',
      'all_proxy',
    ];
    for (final k in keys) {
      final v = Platform.environment[k];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    // 2. Dart's own proxy resolution (reads platform proxy settings on desktop).
    try {
      final resolved = HttpClient.findProxyFromEnvironment(
        Uri.parse('https://example.com'),
      );
      if (resolved.isNotEmpty && !resolved.toUpperCase().contains('DIRECT')) {
        return resolved;
      }
    } catch (_) {}
    return null;
  }

  /// Desktop system proxy that is NOT exposed through environment variables
  /// (GNOME "Network Proxy" set in Settings, macOS System Settings, Windows
  /// Internet Options). Best-effort: spawns a tiny OS query, never throws, and
  /// is a no-op on platforms without the binary (mobile → caught + null).
  Future<String?> _detectSystemProxy() async {
    try {
      if (Platform.isLinux) {
        final r = await Process.run(
          'gsettings',
          ['get', 'org.gnome.system.proxy', 'mode'],
        );
        final mode = (r.stdout as String).trim().replaceAll("'", '');
        if (mode == 'manual' || mode == 'auto') return 'gnome:$mode';
      } else if (Platform.isMacOS) {
        final r = await Process.run('scutil', ['--proxy']);
        final out = r.stdout as String;
        if (RegExp(r'(HTTP|HTTPS|SOCKS)Enable\s*:\s*1').hasMatch(out)) {
          return 'macos:system-proxy';
        }
      } else if (Platform.isWindows) {
        final r = await Process.run('reg', [
          'query',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
          '/v',
          'ProxyEnable',
        ]);
        final out = r.stdout as String;
        if (RegExp(r'ProxyEnable\s+REG_DWORD\s+0x1').hasMatch(out)) {
          return 'windows:system-proxy';
        }
      }
    } catch (_) {}
    return null;
  }

  /// VPN connections that have no kernel interface name match (e.g. a Network
  /// Manager VPN profile on Linux). Best-effort via `nmcli`; no-op elsewhere.
  Future<Set<String>> _detectVpnViaTools() async {
    final hits = <String>{};
    try {
      if (Platform.isLinux) {
        final r = await Process.run(
          'nmcli',
          ['-t', '-f', 'NAME,TYPE', 'connection', 'show', '--active'],
        );
        for (final line in (r.stdout as String).split('\n')) {
          if (line.trim().isEmpty) continue;
          final parts = line.split(':');
          if (parts.length < 2) continue;
          final type = parts[1].toLowerCase();
          if (type.contains('vpn') ||
              type.contains('wireguard') ||
              type.contains('tun')) {
            hits.add('nmcli:${parts[0]}');
          }
        }
      }
    } catch (_) {}
    return hits;
  }

  Future<List<String>> _detectVpnInterfaces() async {
    try {
      final ifaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: true,
      );
      final hits = <String>[];
      for (final i in ifaces) {
        final name = i.name.toLowerCase();
        if (_vpnHints.any((h) => name.contains(h))) {
          hits.add(i.name);
        }
      }
      return hits;
    } catch (_) {
      return const [];
    }
  }

  Map<String, dynamic> report() => {
        'proxyDetected': _proxySeen,
        'vpnDetected': _vpnSeen,
        'proxyValue': _proxyValue,
        'vpnInterfaces': _vpnInterfaces.toList(),
        'proxyFirstSeen': _proxyFirst?.toUtc().toIso8601String(),
        'vpnFirstSeen': _vpnFirst?.toUtc().toIso8601String(),
        // Network fingerprint (trackable: which network the exam was taken on).
        'publicIp': _publicIp,
        'firstPublicIp': _firstPublicIp,
        'ipChanged': _ipChanged,
      };

  /// Detections as scored behaviour events (one per signal, duration = how long
  /// it was present from first-seen to now).
  List<BehaviorEvent> toEvents() {
    final now = DateTime.now();
    final events = <BehaviorEvent>[];
    if (_proxySeen && _proxyFirst != null) {
      events.add(BehaviorEvent(
        type: BehaviorEventType.proxyDetected,
        timestamp: _proxyFirst!,
        durationSeconds: now.difference(_proxyFirst!).inSeconds,
      ));
    }
    if (_vpnSeen && _vpnFirst != null) {
      events.add(BehaviorEvent(
        type: BehaviorEventType.vpnDetected,
        timestamp: _vpnFirst!,
        durationSeconds: now.difference(_vpnFirst!).inSeconds,
      ));
    }
    return events;
  }
}
