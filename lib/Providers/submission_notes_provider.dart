import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/log/app_logger.dart';

/// A note / private comment on a submission.
class SubmissionNote {
  final String id;
  final String body;
  final bool isTeacherOnly;
  final String? parentId;
  final DateTime createdAt;
  final String authorId;
  final String? authorName;
  final String? authorAvatar;

  SubmissionNote({
    required this.id,
    required this.body,
    required this.isTeacherOnly,
    this.parentId,
    required this.createdAt,
    required this.authorId,
    this.authorName,
    this.authorAvatar,
  });

  factory SubmissionNote.fromJson(Map<String, dynamic> j) => SubmissionNote(
        id: '${j['id']}',
        body: (j['body'] as String?) ?? '',
        isTeacherOnly: (j['isTeacherOnly'] as bool?) ?? false,
        parentId: j['parentId'] == null ? null : '${j['parentId']}',
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
        authorId: '${j['authorId']}',
        authorName: j['authorName'] as String?,
        authorAvatar: j['authorAvatar'] as String?,
      );
}

/// Submission notes + return-status, over the shared authenticated [Dio].
class SubmissionNotesProvider extends ChangeNotifier {
  final Dio _dio;
  SubmissionNotesProvider(this._dio);

  final _log = const AppLog('SubmissionNotesProvider');

  List<SubmissionNote>? notes;
  bool loading = false;
  Object? error;
  bool posting = false;

  Future<void> load(String submissionId) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _dio.get('/submissions/$submissionId/notes');
      final list = (res.data['data'] as List?) ?? [];
      notes = list
          .map((e) => SubmissionNote.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      error = e;
      _log.w('load notes failed', e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> add(
    String submissionId, {
    required String body,
    bool isTeacherOnly = false,
    String? parentId,
  }) async {
    if (body.trim().isEmpty || posting) return false;
    posting = true;
    notifyListeners();
    try {
      await _dio.post('/submissions/$submissionId/notes', data: {
        'body': body.trim(),
        'isTeacherOnly': isTeacherOnly,
        'parentId': parentId,
      });
      await load(submissionId);
      return true;
    } catch (e) {
      _log.e('add note failed', e);
      return false;
    } finally {
      posting = false;
      notifyListeners();
    }
  }

  /// Teacher: mark a submission Returned.
  Future<bool> returnSubmission(String submissionId) async {
    try {
      await _dio.patch('/submissions/$submissionId/return');
      return true;
    } catch (e) {
      _log.e('return failed', e);
      return false;
    }
  }

  /// Teacher: set an explicit review status.
  Future<bool> setStatus(String submissionId, String status) async {
    try {
      await _dio.patch('/submissions/$submissionId/review-status',
          data: {'status': status});
      return true;
    } catch (e) {
      _log.e('setStatus failed', e);
      return false;
    }
  }

  /// Teacher: return multiple submissions.
  Future<int> bulkReturn(List<String> ids) async {
    try {
      final res = await _dio.post('/submissions/bulk-return', data: {'ids': ids});
      return (res.data['returned'] as num?)?.toInt() ?? 0;
    } catch (e) {
      _log.e('bulkReturn failed', e);
      return 0;
    }
  }
}
