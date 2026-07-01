import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Live-Session/core/services/socket_service.dart';
import '../Live-Session/core/services/local_notification_service.dart';
import '../models/api_models/notification_model.dart';

/// Drives the notification badge + center. Offline-first (SharedPreferences),
/// REST-backed, with realtime 'notification:new' over the shared socket.
class NotificationProvider extends ChangeNotifier {
  final Dio _dio;
  NotificationProvider(this._dio);

  SocketService? _socket;
  Function(dynamic)? _pushHandler;
  bool _loadedOnce = false;

  final List<AppNotification> _items = [];
  int _unread = 0;
  bool _loading = false;
  String? _cursor;
  bool _hasMore = false;

  List<AppNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _unread;
  bool get loading => _loading;
  bool get hasMore => _hasMore;

  static const _cacheKey = 'notif_cache_v1';
  static const _unreadKey = 'notif_unread_v1';

  // ── Preferences ──
  String _chatNotify = 'MENTIONS'; // ALL | MENTIONS | NONE
  bool _pushEnabled = true;
  bool _prefsLoaded = false;
  String get chatNotify => _chatNotify;
  bool get pushEnabled => _pushEnabled;
  bool get prefsLoaded => _prefsLoaded;

  Future<void> loadPreferences() async {
    try {
      final res = await _dio.get('/notifications/preferences');
      final m = res.data as Map<String, dynamic>;
      _chatNotify = (m['chatNotify'] as String?) ?? 'MENTIONS';
      _pushEnabled = (m['pushEnabled'] as bool?) ?? true;
      _prefsLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('notif loadPreferences: $e');
    }
  }

  Future<void> updatePreferences({String? chatNotify, bool? pushEnabled}) async {
    // Optimistic update so the toggle feels instant.
    final prevChat = _chatNotify;
    final prevPush = _pushEnabled;
    if (chatNotify != null) _chatNotify = chatNotify;
    if (pushEnabled != null) _pushEnabled = pushEnabled;
    notifyListeners();
    try {
      await _dio.patch('/notifications/preferences', data: {
        if (chatNotify != null) 'chatNotify': chatNotify,
        if (pushEnabled != null) 'pushEnabled': pushEnabled,
      });
    } catch (e) {
      debugPrint('notif updatePreferences: $e');
      _chatNotify = prevChat;
      _pushEnabled = prevPush;
      notifyListeners();
    }
  }

  /// Called by the ProxyProvider whenever the socket is (re)available.
  void bindSocket(SocketService socket) {
    _socket = socket;
    _pushHandler ??= (data) {
      if (data is! Map) return;
      final n = AppNotification.fromJson(Map<String, dynamic>.from(data));
      _items.insert(0, n);
      _unread += 1;
      notifyListeners();
      _persist();
      // Surface a system heads-up so it's visible even off the bell/center.
      LocalNotificationService.instance.show(n.title, n.body, payload: n.data);
    };
    // Re-attach safely (the underlying socket may have reconnected).
    socket.off('notification:new', _pushHandler);
    socket.on('notification:new', _pushHandler!);

    if (!_loadedOnce) {
      _loadedOnce = true;
      _loadFromCache();
      refresh();
    }
  }

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    _unread = prefs.getInt(_unreadKey) ?? 0;
    final raw = prefs.getString(_cacheKey);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _items
          ..clear()
          ..addAll(list);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_unreadKey, _unread);
    await prefs.setString(
        _cacheKey, jsonEncode(_items.take(50).map((e) => e.toJson()).toList()));
  }

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _dio.get('/notifications', queryParameters: {'limit': 20});
      final data = res.data as Map<String, dynamic>;
      final list = (data['data'] as List? ?? [])
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _items
        ..clear()
        ..addAll(list);
      _cursor = data['nextCursor'] as String?;
      _hasMore = _cursor != null;
      final c = await _dio.get('/notifications/unread-count');
      _unread = ((c.data as Map)['count'] as int?) ?? 0;
      await _persist();
    } catch (e) {
      debugPrint('notif refresh: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _loading || _cursor == null) return;
    try {
      final res = await _dio.get('/notifications',
          queryParameters: {'limit': 20, 'cursor': _cursor});
      final data = res.data as Map<String, dynamic>;
      _items.addAll((data['data'] as List? ?? [])
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e))));
      _cursor = data['nextCursor'] as String?;
      _hasMore = _cursor != null;
      notifyListeners();
    } catch (e) {
      debugPrint('notif loadMore: $e');
    }
  }

  Future<void> markRead(AppNotification n) async {
    if (n.isRead) return;
    n.isRead = true;
    if (_unread > 0) _unread -= 1;
    notifyListeners();
    _persist();
    try {
      await _dio.patch('/notifications/${n.id}/read');
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    for (final n in _items) {
      n.isRead = true;
    }
    _unread = 0;
    notifyListeners();
    _persist();
    try {
      await _dio.patch('/notifications/read-all');
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_socket != null && _pushHandler != null) {
      _socket!.off('notification:new', _pushHandler);
    }
    super.dispose();
  }
}
