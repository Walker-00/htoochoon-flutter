import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/log/app_logger.dart';

/// One course-chat message (codegen-free).
class CourseChatMessage {
  final String id;
  final String senderId;
  final String content;
  final String? senderName;
  final String? senderAvatar;
  final bool isDeleted;
  final DateTime createdAt;

  CourseChatMessage({
    required this.id,
    required this.senderId,
    required this.content,
    this.senderName,
    this.senderAvatar,
    this.isDeleted = false,
    required this.createdAt,
  });

  factory CourseChatMessage.fromJson(Map<String, dynamic> j) => CourseChatMessage(
        id: '${j['id']}',
        senderId: '${j['senderId']}',
        content: (j['content'] as String?) ?? '',
        senderName: j['senderName'] as String?,
        senderAvatar: j['senderAvatar'] as String?,
        isDeleted: (j['isDeleted'] as bool?) ?? false,
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
      );
}

/// Per-course chat over the shared authenticated [Dio]. Mirrors ChatProvider but
/// scoped to a course room (backend `/courses/{id}/chat/...`).
class CourseChatProvider extends ChangeNotifier {
  final Dio _dio;
  CourseChatProvider(this._dio);

  final _log = const AppLog('CourseChatProvider');

  String? _courseId;
  List<CourseChatMessage>? messages;
  bool loading = false;
  Object? error;
  bool isEnabled = true;
  bool sending = false;

  Future<void> open(String courseId) async {
    _courseId = courseId;
    loading = true;
    error = null;
    notifyListeners();
    try {
      // Room state (lazily created server-side).
      final room = await _dio.get('/courses/$courseId/chat');
      isEnabled = (room.data['isEnabled'] as bool?) ?? true;
      await _fetch();
    } catch (e) {
      error = e;
      _log.w('open course chat failed', e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _fetch() async {
    final cid = _courseId;
    if (cid == null) return;
    final res = await _dio.get('/courses/$cid/chat/messages',
        queryParameters: {'limit': 80});
    final list = (res.data['data'] as List?) ?? [];
    messages = list
        .map((e) => CourseChatMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> refresh() async {
    try {
      await _fetch();
    } catch (e) {
      _log.w('refresh failed', e);
    }
    notifyListeners();
  }

  Future<bool> send(String content) async {
    final cid = _courseId;
    if (cid == null || content.trim().isEmpty || sending) return false;
    sending = true;
    notifyListeners();
    try {
      await _dio.post('/courses/$cid/chat/messages',
          data: {'content': content.trim(), 'type': 'TEXT'});
      await _fetch();
      return true;
    } catch (e) {
      _log.e('send failed', e);
      return false;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<void> toggle(bool enabled) async {
    final cid = _courseId;
    if (cid == null) return;
    try {
      await _dio.patch('/courses/$cid/chat', data: {'isEnabled': enabled});
      isEnabled = enabled;
      notifyListeners();
    } catch (e) {
      _log.w('toggle failed', e);
    }
  }
}
