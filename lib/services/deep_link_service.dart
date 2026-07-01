import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Screens/Join/join_link_screen.dart';

/// Handles `…/join/<token>` deep links (cold start + while running) and routes
/// them to the [JoinLinkScreen]. Custom scheme `htoochoon://join/<token>` and
/// the `https://app.htoochoon.com/join/<token>` App Link both resolve here.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  GlobalKey<NavigatorState>? _navKey;
  bool _started = false;

  Future<void> init(GlobalKey<NavigatorState> navKey) async {
    if (_started) return;
    _started = true;
    _navKey = navKey;

    // Cold start: a link that launched the app.
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handle(initial);
    } catch (_) {}

    // Warm: links received while the app is running.
    _appLinks.uriLinkStream.listen(_handle, onError: (_) {});
  }

  void _handle(Uri uri) {
    final token = _tokenFrom(uri);
    if (token == null) return;
    // Defer to after the current frame so the navigator is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navKey?.currentState?.push(
        MaterialPageRoute(builder: (_) => JoinLinkScreen(token: token)),
      );
    });
  }

  /// Extracts the token from `.../join/<token>`.
  String? _tokenFrom(Uri uri) {
    final segs = uri.pathSegments;
    final i = segs.indexOf('join');
    if (i >= 0 && i + 1 < segs.length) return segs[i + 1];
    // Custom scheme `htoochoon://join/<token>` puts `join` in the host.
    if (uri.host == 'join' && segs.isNotEmpty) return segs.first;
    return null;
  }
}
