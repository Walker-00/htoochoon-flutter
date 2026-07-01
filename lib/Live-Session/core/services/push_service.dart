import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:htoochoon_flutter/utils/platform_support.dart';
import 'package:htoochoon_flutter/services/notification_router.dart';
import 'local_notification_service.dart';

/// Background/terminated FCM handler. Must be a top-level (or static) function
/// so it can run in its own isolate. With a `notification` payload Android shows
/// the tray notification automatically, so this only needs to not crash.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Intentionally minimal — the OS renders `notification`-type messages itself.
  debugPrint('📩 BG push: ${message.messageId}');
}

/// Wires Firebase Cloud Messaging into the app:
///  - foreground messages → a local heads-up (FCM doesn't show those itself),
///  - registers/refreshes the device token with the backend,
///  - unregisters on logout.
///
/// Pairs with the in-app WS 'notification:new' path: WS handles the running app,
/// FCM handles background/terminated. Both ultimately surface the same events.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  Dio? _dio;
  String? _token;
  bool _listenersReady = false;

  /// Give the service the authenticated Dio (its interceptor adds the bearer).
  void attachDio(Dio dio) => _dio = dio;

  /// Foreground + token-refresh listeners. Call once after Firebase.initializeApp.
  Future<void> initListeners() async {
    if (!PlatformSupport.supportsPushMessaging) return; // no FCM on desktop
    if (_listenersReady) return;
    _listenersReady = true;
    try {
      // FCM permission (Android 13+/iOS). Mirrors the local-notif prompt; the OS
      // only asks once, so calling alongside it is safe.
      await FirebaseMessaging.instance.requestPermission();

      // App in foreground: FCM does NOT display automatically → show locally.
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n == null) return;
        LocalNotificationService.instance.show(
          n.title ?? 'Notification',
          n.body ?? '',
          payload: m.data,
        );
      });

      // Re-register whenever FCM rotates the token.
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        _token = t;
        _postToken(t);
      });

      // Tapped a tray notification that opened/foregrounded the app → deep link.
      FirebaseMessaging.instance.getInitialMessage().then((m) {
        if (m != null) NotificationRouter.instance.route(m.data);
      });
      FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => NotificationRouter.instance.route(m.data),
      );
    } catch (e) {
      debugPrint('PushService.initListeners failed: $e');
    }
  }

  /// Fetch the current FCM token and register it with the backend. Safe to call
  /// repeatedly (the endpoint upserts). Requires an authenticated Dio.
  Future<void> registerToken() async {
    if (!PlatformSupport.supportsPushMessaging) return;
    try {
      final t = await FirebaseMessaging.instance.getToken();
      if (t == null) return;
      _token = t;
      await _postToken(t);
    } catch (e) {
      debugPrint('PushService.registerToken failed: $e');
    }
  }

  Future<void> _postToken(String token) async {
    final dio = _dio;
    if (dio == null) return;
    try {
      await dio.post('/notifications/devices', data: {
        'token': token,
        'platform': _platform(),
      });
    } catch (e) {
      debugPrint('PushService register POST failed: $e');
    }
  }

  /// Drop this device's token server-side (call on logout, before clearing auth).
  Future<void> unregisterToken() async {
    if (!PlatformSupport.supportsPushMessaging) return;
    final dio = _dio;
    final token = _token ?? await _safeToken();
    if (dio == null || token == null) return;
    try {
      await dio.delete('/notifications/devices', data: {'token': token});
    } catch (e) {
      debugPrint('PushService unregister failed: $e');
    }
  }

  Future<String?> _safeToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  String _platform() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
    } catch (_) {}
    return 'unknown';
  }
}
