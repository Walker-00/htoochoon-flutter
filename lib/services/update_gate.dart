import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Polls the backend version feed (`GET /app/version`) and, when the installed
/// build is below `minSupported`, shows a HARD non-dismissible update blocker.
///
/// Beta policy (per product decision): updates are mandatory — there is no
/// "later"/cancel, because the backend may ship breaking changes the old client
/// can't speak to.
class UpdateGate {
  static const _base = 'https://backend.htoochoon.com/';
  static bool _showing = false;

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _base,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  /// Call on app start and on resume. No-op on failure (never block the app for
  /// a transient network error — only a confirmed mismatch gates).
  static Future<void> check(BuildContext context) async {
    if (_showing) return;
    try {
      final res = await _dio.get('app/version');
      final data = res.data as Map<String, dynamic>;
      final minSupported = (data['minSupported'] ?? '0.0.0').toString();
      final downloadUrl = (data['downloadUrl'] ?? '').toString();
      final notes = (data['notes'] ?? '').toString();

      final info = await PackageInfo.fromPlatform();
      final current = info.version;

      if (_isBelow(current, minSupported)) {
        if (!context.mounted) return;
        _showing = true;
        await Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => UpdateRequiredScreen(
              downloadUrl: downloadUrl,
              notes: notes,
              currentVersion: current,
              requiredVersion: minSupported,
            ),
          ),
        );
        _showing = false;
      }
    } catch (_) {
      // Network/parse failure → don't gate.
    }
  }

  /// True when [current] < [min] using dotted numeric comparison.
  static bool _isBelow(String current, String min) {
    final c = _parts(current);
    final m = _parts(min);
    for (var i = 0; i < 3; i++) {
      if (c[i] < m[i]) return true;
      if (c[i] > m[i]) return false;
    }
    return false;
  }

  static List<int> _parts(String v) {
    final nums = v
        .split('+')
        .first
        .split('.')
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .toList();
    while (nums.length < 3) {
      nums.add(0);
    }
    return nums;
  }
}

class UpdateRequiredScreen extends StatelessWidget {
  final String downloadUrl;
  final String notes;
  final String currentVersion;
  final String requiredVersion;

  const UpdateRequiredScreen({
    super.key,
    required this.downloadUrl,
    required this.notes,
    required this.currentVersion,
    required this.requiredVersion,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // canPop: false blocks the system back button — no escape, by design.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.system_update, size: 72, color: cs.primary),
                  const SizedBox(height: 20),
                  Text(
                    'Update required',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    notes.isNotEmpty
                        ? notes
                        : 'Please update — this build may break against the latest server.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Installed $currentVersion · Required $requiredVersion+',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final uri = Uri.tryParse(downloadUrl);
                        if (uri != null) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.download),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Update now'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
