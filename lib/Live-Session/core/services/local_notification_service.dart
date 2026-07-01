import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:htoochoon_flutter/services/notification_router.dart';

/// System-tray / heads-up notifications via flutter_local_notifications.
///
/// Scope: in-app + local delivery (foreground/background). Terminated-state
/// push (FCM) is intentionally NOT here — it's a deferred premium feature.
/// Used by NotificationProvider when a `notification:new` socket event arrives,
/// and for the post-login OS permission prompt.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _inited = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'htoochoon_default',
    'Notifications',
    description: 'General app notifications',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_inited) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/launcher_icon');
      const darwin = DarwinInitializationSettings(
        // Defer the iOS prompt to requestPermission() (post-login), not init.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: android,
          iOS: darwin,
          macOS: darwin,
        ),
        onDidReceiveNotificationResponse: _onTap,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
      _inited = true;
    } catch (e) {
      debugPrint('LocalNotificationService.init failed: $e');
    }
  }

  /// Notification tapped → decode the JSON payload and deep-link.
  static void _onTap(NotificationResponse resp) {
    final raw = resp.payload;
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        NotificationRouter.instance.route(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      debugPrint('LocalNotificationService._onTap decode failed: $e');
    }
  }

  /// Request OS notification permission (Android 13+ POST_NOTIFICATIONS / iOS).
  /// Safe to call repeatedly; the OS only prompts once.
  Future<bool> requestPermission() async {
    if (!_inited) await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return (await android.requestNotificationsPermission()) ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return (await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            )) ??
            false;
      }
    } catch (e) {
      debugPrint('LocalNotificationService.requestPermission failed: $e');
    }
    return false;
  }

  Future<void> show(String title, String body,
      {Map<String, dynamic>? payload}) async {
    if (!_inited) await init();
    try {
      final id =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) & 0x7fffffff;
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'htoochoon_default',
          'Notifications',
          channelDescription: 'General app notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );
      await _plugin.show(
        id: id,
        title: title.isEmpty ? 'Notification' : title,
        body: body.isEmpty ? null : body,
        notificationDetails: details,
        payload: payload == null ? null : jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('LocalNotificationService.show failed: $e');
    }
  }
}
