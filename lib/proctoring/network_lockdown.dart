import 'dart:io';

/// DESKTOP active network BLOCK for an EXTREME-safety exam.
///
/// Flutter (and any sandboxed app) cannot intercept other apps' packets without
/// a system VPN / packet driver. The portable, no-driver way to actually stop a
/// student reaching answer sites from the browser is the OS **hosts file**:
/// point known cheat/answer/AI/distraction domains at 127.0.0.1 for the duration
/// of the exam, then remove them. Editing the hosts file needs admin/root, so we
/// run a single elevated command per apply/restore:
///   * Linux   — `pkexec sh <script>`            (PolicyKit GUI prompt)
///   * macOS   — `osascript ... with administrator privileges`  (auth prompt)
///   * Windows — `Start-Process -Verb RunAs`      (UAC prompt)
///
/// Crash-safe: the injected lines are wrapped in unique sentinel markers, so
/// restore just strips everything between them — idempotent even if the app
/// died mid-exam (see [sweepStale], called at launch).
///
/// Best-effort by design: if the student denies the elevation prompt we DON'T
/// trap them — we record `blocked:false` in the report (detection still runs via
/// NetworkIntegrity) and let the exam proceed. Android blocking is handled
/// separately by ExamNetworkGuard (VpnService); this class is desktop-only.
class NetworkLockdown {
  /// Domains forced to 127.0.0.1 during an EXTREME exam. Bare + www variants are
  /// emitted for each. Kept deliberately conservative (well-known answer/AI/chat
  /// sites) so we don't break the exam app itself.
  static const List<String> denylist = [
    'chat.openai.com',
    'chatgpt.com',
    'openai.com',
    'gemini.google.com',
    'bard.google.com',
    'claude.ai',
    'anthropic.com',
    'copilot.microsoft.com',
    'bing.com',
    'perplexity.ai',
    'poe.com',
    'quizlet.com',
    'chegg.com',
    'coursehero.com',
    'brainly.com',
    'symbolab.com',
    'wolframalpha.com',
    'mathway.com',
    'socratic.org',
    'reddit.com',
    'discord.com',
    'telegram.org',
    'web.whatsapp.com',
    'messenger.com',
  ];

  static const String _begin = '# >>> HTOOCHOON-EXAM-LOCK (auto, do not edit) >>>';
  static const String _end = '# <<< HTOOCHOON-EXAM-LOCK <<<';

  bool _applied = false;
  bool _blocked = false;
  String? _error;
  DateTime? _appliedAt;
  DateTime? _restoredAt;

  bool get applied => _applied;
  bool get blocked => _blocked;

  static bool get _isDesktop =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  static String get _hostsPath => Platform.isWindows
      ? '${Platform.environment['SystemRoot'] ?? r'C:\Windows'}\\System32\\drivers\\etc\\hosts'
      : '/etc/hosts';

  /// Apply the block. Returns true only if the hosts file was actually edited.
  Future<bool> apply() async {
    if (!_isDesktop) return false;
    try {
      final ok = await _run(block: true);
      _applied = true;
      _blocked = ok;
      _appliedAt = DateTime.now();
      return ok;
    } catch (e) {
      _error = '$e';
      _blocked = false;
      return false;
    }
  }

  /// Remove the block. Safe to call even if [apply] failed or never ran.
  Future<void> restore() async {
    if (!_isDesktop) return;
    try {
      await _run(block: false);
    } catch (e) {
      _error = '$e';
    } finally {
      _blocked = false;
      _restoredAt = DateTime.now();
    }
  }

  Map<String, dynamic> report() => {
        'supported': _isDesktop,
        'attempted': _applied,
        'blocked': _blocked,
        'blockedHostCount': _applied && _blocked ? denylist.length : 0,
        // Exactly which domains were forced to 127.0.0.1, and the window they
        // were blocked for. (We can't see which the student *tried* to reach —
        // that needs packet capture — only what was blocked + when.)
        'blockedHosts': _applied && _blocked ? denylist : const <String>[],
        'appliedAt': _appliedAt?.toUtc().toIso8601String(),
        'restoredAt': _restoredAt?.toUtc().toIso8601String(),
        'error': _error,
      };

  // ── internals ─────────────────────────────────────────────────────────────

  Future<bool> _run({required bool block}) async {
    if (Platform.isWindows) return _runWindows(block: block);
    return _runUnix(block: block);
  }

  /// Linux + macOS: a tiny sh script (strip old block, optionally append new),
  /// run with the platform's GUI elevation agent.
  Future<bool> _runUnix({required bool block}) async {
    final h = _hostsPath;
    final sb = StringBuffer()
      ..writeln('#!/bin/sh')
      ..writeln('set -e')
      // strip any previous block (idempotent)
      ..writeln("sed -i.htoobak '/>>> HTOOCHOON-EXAM-LOCK/,/<<< HTOOCHOON-EXAM-LOCK/d' \"$h\" 2>/dev/null || "
          "sed -i '' '/>>> HTOOCHOON-EXAM-LOCK/,/<<< HTOOCHOON-EXAM-LOCK/d' \"$h\" 2>/dev/null || true");
    if (block) {
      sb.writeln('{');
      sb.writeln("echo '$_begin'");
      for (final d in denylist) {
        sb.writeln("echo '127.0.0.1 $d'");
        sb.writeln("echo '127.0.0.1 www.$d'");
        sb.writeln("echo '::1 $d'");
      }
      sb.writeln("echo '$_end'");
      sb.writeln('} >> "$h"');
    }
    // flush DNS cache (best-effort, per-OS)
    if (Platform.isMacOS) {
      sb.writeln('dscacheutil -flushcache 2>/dev/null || true');
      sb.writeln('killall -HUP mDNSResponder 2>/dev/null || true');
    } else {
      sb.writeln('resolvectl flush-caches 2>/dev/null || '
          'systemd-resolve --flush-caches 2>/dev/null || true');
    }

    final script = File(
      '${Directory.systemTemp.path}/htoochoon_netlock_${DateTime.now().millisecondsSinceEpoch}.sh',
    );
    await script.writeAsString(sb.toString());

    try {
      ProcessResult res;
      if (Platform.isMacOS) {
        // osascript handles the admin auth dialog itself.
        final inner = 'sh ${script.path}';
        res = await Process.run('osascript', [
          '-e',
          'do shell script "${inner.replaceAll('"', '\\"')}" with administrator privileges',
        ]).timeout(const Duration(seconds: 90));
      } else {
        // Linux: PolicyKit GUI prompt; fall back to plain sh if already root.
        res = await Process.run('pkexec', ['sh', script.path])
            .timeout(const Duration(seconds: 90));
        if (res.exitCode != 0) {
          res = await Process.run('sh', [script.path])
              .timeout(const Duration(seconds: 10));
        }
      }
      return res.exitCode == 0;
    } finally {
      try {
        if (script.existsSync()) script.deleteSync();
      } catch (_) {}
    }
  }

  /// Windows: a PowerShell script run elevated through a UAC prompt.
  Future<bool> _runWindows({required bool block}) async {
    final h = _hostsPath.replaceAll('\\', '\\\\');
    final lines = <String>[
      '\$h = "$h"',
      '\$src = @()',
      'if (Test-Path -LiteralPath \$h) { \$src = Get-Content -LiteralPath \$h -ErrorAction SilentlyContinue }',
      '\$kept = @()',
      '\$skip = \$false',
      'foreach (\$l in \$src) {',
      "  if (\$l -match 'HTOOCHOON-EXAM-LOCK') {",
      "    if (\$l -match '>>>') { \$skip = \$true; continue }",
      "    elseif (\$l -match '<<<') { \$skip = \$false; continue }",
      '  }',
      '  if (-not \$skip) { \$kept += \$l }',
      '}',
    ];
    if (block) {
      lines.add("\$kept += '$_begin'");
      for (final d in denylist) {
        lines.add("\$kept += '127.0.0.1 $d'");
        lines.add("\$kept += '127.0.0.1 www.$d'");
      }
      lines.add("\$kept += '$_end'");
    }
    lines.add('Set-Content -LiteralPath \$h -Value \$kept -Encoding ASCII');
    lines.add('ipconfig /flushdns | Out-Null');

    final script = File(
      '${Directory.systemTemp.path}\\htoochoon_netlock_${DateTime.now().millisecondsSinceEpoch}.ps1',
    );
    await script.writeAsString(lines.join('\r\n'));

    try {
      // Launch an elevated (UAC) PowerShell that runs the script, and wait.
      final res = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        "Start-Process powershell -Verb RunAs -WindowStyle Hidden -Wait "
            "-ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','${script.path}'",
      ]).timeout(const Duration(seconds: 90));
      return res.exitCode == 0;
    } finally {
      try {
        if (script.existsSync()) script.deleteSync();
      } catch (_) {}
    }
  }

  /// Launch-time cleanup: if a previous exam crashed and left the block in the
  /// hosts file, strip it. Reads the file unprivileged first (no prompt) and
  /// only elevates when a stale block is actually present.
  static Future<void> sweepStale() async {
    if (!_isDesktop) return;
    try {
      final f = File(_hostsPath);
      if (!f.existsSync()) return;
      final content = await f.readAsString();
      if (content.contains('HTOOCHOON-EXAM-LOCK')) {
        await NetworkLockdown().restore();
      }
    } catch (_) {
      // best-effort; never block app startup
    }
  }
}
