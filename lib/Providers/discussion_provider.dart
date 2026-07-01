import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/log/app_logger.dart';
import '../models/api_models/discussion_model.dart';

/// Q&A threads + DM, over the shared authenticated [Dio] (mirrors ChatProvider).
class DiscussionProvider extends ChangeNotifier {
  final Dio _dio;
  DiscussionProvider(this._dio);

  final _log = const AppLog('DiscussionProvider');

  // ── Q&A list state (per assignment) ──
  List<Discussion>? threads;
  bool loadingThreads = false;
  Object? threadsError;
  String filter = 'all'; // all | mine | unanswered

  // ── Single thread state ──
  DiscussionThread? thread;
  bool loadingThread = false;
  Object? threadError;

  // ── DM state ──
  List<DmConversation>? conversations;
  bool loadingConversations = false;

  List<DmMessage>? dmMessages;
  bool loadingDm = false;

  Future<void> loadThreads(String assignmentId, {String? filter}) async {
    if (filter != null) this.filter = filter;
    loadingThreads = true;
    threadsError = null;
    notifyListeners();
    try {
      final res = await _dio.get(
        '/assignments/$assignmentId/discussions',
        queryParameters: {'filter': this.filter},
      );
      final list = (res.data['data'] as List?) ?? [];
      threads = list
          .map((e) => Discussion.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      threadsError = e;
      _log.w('loadThreads failed', e);
    } finally {
      loadingThreads = false;
      notifyListeners();
    }
  }

  Future<Discussion?> createThread(
    String assignmentId, {
    required String title,
    String? body,
    bool isPrivate = false,
  }) async {
    try {
      final res = await _dio.post('/assignments/$assignmentId/discussions', data: {
        'title': title,
        'body': body,
        'isPrivate': isPrivate,
      });
      await loadThreads(assignmentId);
      return Discussion.fromJson(Map<String, dynamic>.from(res.data));
    } catch (e) {
      _log.e('createThread failed', e);
      return null;
    }
  }

  Future<void> loadThread(String id) async {
    loadingThread = true;
    threadError = null;
    notifyListeners();
    try {
      final res = await _dio.get('/discussions/$id');
      thread = DiscussionThread.fromJson(Map<String, dynamic>.from(res.data));
    } catch (e) {
      threadError = e;
      _log.w('loadThread failed', e);
    } finally {
      loadingThread = false;
      notifyListeners();
    }
  }

  Future<bool> reply(
    String discussionId, {
    required String body,
    String? parentId,
    List<String> mentionedUserIds = const [],
  }) async {
    try {
      await _dio.post('/discussions/$discussionId/messages', data: {
        'body': body,
        'parentId': parentId,
        'mentionedUserIds': mentionedUserIds,
      });
      await loadThread(discussionId);
      return true;
    } catch (e) {
      _log.e('reply failed', e);
      return false;
    }
  }

  Future<void> markSolved(String discussionId) async {
    try {
      await _dio.post('/discussions/$discussionId/solve');
      await loadThread(discussionId);
    } catch (e) {
      _log.w('markSolved failed', e);
    }
  }

  Future<void> markBest(String messageId, String discussionId) async {
    try {
      await _dio.post('/discussions/messages/$messageId/best');
      await loadThread(discussionId);
    } catch (e) {
      _log.w('markBest failed', e);
    }
  }

  // ── DM ──
  Future<void> loadConversations() async {
    loadingConversations = true;
    notifyListeners();
    try {
      final res = await _dio.get('/dm');
      final list = (res.data['data'] as List?) ?? [];
      conversations = list
          .map((e) => DmConversation.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _log.w('loadConversations failed', e);
    } finally {
      loadingConversations = false;
      notifyListeners();
    }
  }

  Future<void> loadConversation(String peerId) async {
    loadingDm = true;
    notifyListeners();
    try {
      final res = await _dio.get('/dm/$peerId');
      final list = (res.data['data'] as List?) ?? [];
      dmMessages = list
          .map((e) => DmMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      // best-effort mark read
      _dio.post('/dm/$peerId/read').ignore();
    } catch (e) {
      _log.w('loadConversation failed', e);
    } finally {
      loadingDm = false;
      notifyListeners();
    }
  }

  Future<bool> sendDm(String peerId, String body, {String? assignmentId}) async {
    try {
      await _dio.post('/dm/$peerId', data: {
        'body': body,
        'assignmentId': assignmentId,
      });
      await loadConversation(peerId);
      return true;
    } catch (e) {
      _log.e('sendDm failed', e);
      return false;
    }
  }
}
