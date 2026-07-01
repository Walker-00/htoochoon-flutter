import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/models/api_models/assignment_model.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import '../api/api_service.dart';

import '../models/api_models/submission_model.dart';
// assignment_provider.dart

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'dart:convert';

class AssignmentProvider extends ChangeNotifier {
  final ApiService _apiService;
  AssignmentProvider(this._apiService);
  Assignment? _assignmentDetails;
  Assignment? get assignmentDetails => _assignmentDetails;
  Assignment? getAssignmentById(String id) {
    // Check detailed version first
    if (_assignmentDetails?.id == id) return _assignmentDetails;

    // Manual search in list
    for (final assignment in _assignments) {
      if (assignment.id == id) return assignment;
    }
    return null; // Not found
  }

  // ── Exam lockout ──────────────────────────────────────────────────────────
  /// True when a prior forced exit locked this exam pending teacher approval.
  /// Fail-open: a network hiccup must never trap a legitimate student out.
  Future<bool> isExamLocked(String assessmentId) async {
    try {
      final res = await _apiService.checkExamLock(assessmentId);
      return res is Map && res['locked'] == true;
    } catch (e) {
      debugPrint('isExamLocked error: $e');
      return false;
    }
  }

  /// Lock the exam for the current student after a kick-out / forced exit.
  Future<void> lockExamForcedExit(
    String assessmentId, {
    String reason = 'left the app during the exam',
    int cheatScore = 0,
    Map<String, dynamic>? proctorSummary,
  }) async {
    try {
      await _apiService.createExamLock({
        'assessmentId': assessmentId,
        'reason': reason,
        'cheatScore': cheatScore,
        'forcedExit': true,
        if (proctorSummary != null) 'proctorSummary': proctorSummary,
      });
    } catch (e) {
      debugPrint('lockExamForcedExit error: $e');
    }
  }

  /// Teacher/admin: locked/flagged attempts for a course.
  Future<List<dynamic>> listExamLocks(
    String courseId, {
    String status = 'LOCKED',
  }) async {
    try {
      final res = await _apiService.listExamLocks(courseId, status);
      return res is List ? res : const [];
    } catch (e) {
      debugPrint('listExamLocks error: $e');
      return const [];
    }
  }

  /// Teacher/admin: approve a retake (clears the lock + prior forced attempt).
  Future<bool> approveExamRetake(String lockId) async {
    try {
      await _apiService.approveExamLock(lockId);
      return true;
    } catch (e) {
      debugPrint('approveExamRetake error: $e');
      return false;
    }
  }

  Future<Submission?> submitAssignmentRaw(Map<String, dynamic> payload) async {
    _setLoading(true);
    _error = null;
    try {
      // ⚠️ Pass the MAP directly. Do not use jsonEncode!
      final submission = await _apiService.submitWorkRaw(payload);

      _submissions = [..._submissions, submission];
      notifyListeners();
      return submission;
    } catch (e) {
      _error = e.toString();
      debugPrint('submitAssignment error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ✅ FIXED: Fetch assignment details with questions
  Future<Assignment?> fetchAssignmentDetail(String assignmentId) async {
    _setLoading(true);
    _error = null;

    try {
      final detail = await _apiService.getAssignmentDetails(assignmentId);

      // Store detailed assignment
      _assignmentDetails = detail;

      // Replace lightweight list item with full detail
      final idx = _assignments.indexWhere((a) => a.id == assignmentId);

      if (idx != -1) {
        _assignments = List.from(_assignments)..[idx] = detail;
      } else {
        _assignments = [..._assignments, detail];
      }

      notifyListeners();

      return detail;
    } catch (e) {
      _error = e.toString();
      debugPrint('fetchAssignmentDetail error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ── State ──────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  String? _error;
  List<Assignment> _assignments = [];
  List<Submission> _submissions = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Assignment> get assignments => _assignments;
  List<Submission> get submissions => _submissions;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET /assignments/class/{classId}
  // Returns list without questions — call fetchAssignmentDetail for full data
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> fetchAssignments(
    String classId, {
    bool? publishedOnly,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      _assignments = await _apiService.getAssignmentsByCourse(
        classId,
        publishedOnly: publishedOnly,
      );
    } catch (e) {
      _error = e.toString();
      debugPrint('fetchAssignments error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Returns all submissions for a given student (raw list, no filter).
  Future<List<Submission>> fetchStudentSubmissionsRaw({
    required String studentId,
  }) async {
    final result = await _apiService.getStudentSubmissions(studentId);
    return result;
  }

  /// Fetches a single submission by ID (full object with answers).
  /// Uses the student submissions endpoint and picks by ID, OR add a
  /// dedicated GET /submissions/{id} endpoint if your API supports it.
  // Future<Submission?> fetchSubmissionById(
  //   String submissionId,
  //   String classId,
  // ) async {
  //   final all = await _apiService.getCourseSubmissions(classId);
  //   final matches = all.where((s) => s.id == submissionId);
  //   return matches.isEmpty ? null : matches.first;
  // }

  // ─────────────────────────────────────────────────────────────────────────
  // GET /assignments/{id}/details
  // Returns full assignment with questions + options + attachments
  // Updates the matching item in _assignments list in-place
  // ─────────────────────────────────────────────────────────────────────────
  // Future<Assignment?> fetchAssignmentDetail(String assignmentId) async {
  //   _setLoading(true);
  //   _error = null;
  //   try {
  //     final detail = await _apiService.getAssignmentDetails(assignmentId);
  //
  //     final idx = _assignments.indexWhere((a) => a.id == assignmentId);
  //     if (idx != -1) {
  //       _assignments = List.from(_assignments)..[idx] = detail;
  //     } else {
  //       _assignments = [..._assignments, detail];
  //     }
  //     notifyListeners();
  //     return detail;
  //   } catch (e) {
  //     _error = e.toString();
  //     debugPrint('fetchAssignmentDetail error: $e');
  //     return null;
  //   } finally {
  //     _setLoading(false);
  //   }
  // }

  // ─────────────────────────────────────────────────────────────────────────
  // POST /assignments  (multipart)
  //
  // questionsJson — pre-encoded JSON string of List<QuestionRequest>
  //   '[{"order":1,"type":"MULTIPLE_CHOICE","text":"...","points":5,
  //      "files":[0,1],"options":[{"label":"A","text":"3"},
  //                                {"label":"B","text":"4","isCorrect":true}]},
  //     {"order":2,...,"files":[2],...}]'
  //
  // attachments — flat List<MultipartFile> across ALL questions in order.
  //   Q1 has "files":[0,1] → attachments[0], attachments[1]
  //   Q2 has "files":[2]   → attachments[2]
  //   EVERY index in any question's "files" array MUST exist here.
  //   Pass null (or omit) only when NO question has any files at all.
  //
  // type — pass type.name ("ASSIGNMENT" or "TEST"), NOT the enum itself,
  //   because retrofit serializes enums as "AssignmentType.ASSIGNMENT".
  //   The api_service.dart @Part(name:"type") param should be String.
  // ─────────────────────────────────────────────────────────────────────────
  Future<Assignment?> createAssignment({
    required String title,
    required String content,
    required String classId,
    required AssignmentType type,
    int? dueDurationMinutes,
    required int duration,
    bool showContentPreview = true,
    required String questionsJson,
    List<MultipartFile>? attachments,
    String? safetyLevel,
    String? safetyScope,
    String? safetyMeasure,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final created = await _apiService.createAssignment(
        title,
        content,
        classId, // carries the courseId
        type.name, // ← sends "ASSIGNMENT" or "TEST", not "AssignmentType.TEST"
        duration,
        showContentPreview,
        questionsJson, // ← already a JSON string
        dueDurationMinutes, // optional relative deadline
        attachments, // ← flat MultipartFile list, null if no files
        safetyLevel,
        safetyScope,
        safetyMeasure,
      );

      // Reconcile from the server (source of truth) so the list reflects the
      // canonical list-shape (e.g. `_count`) rather than the create response
      // shape (with `questions`). Falls back to optimistic append if the
      // refetch fails so the UI still updates.
      try {
        _assignments = await _apiService.getAssignmentsByCourse(classId);
      } catch (_) {
        _assignments = [..._assignments, created];
      }
      notifyListeners();
      return created;
    } catch (e) {
      _error = e.toString();
      debugPrint('createAssignment error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PATCH /assignments/{id}
  // ─────────────────────────────────────────────────────────────────────────
  Future<Assignment?> updateAssignment(
    String id,
    Map<String, dynamic> body,
  ) async {
    _setLoading(true);
    _error = null;
    try {
      final updated = await _apiService.updateAssignment(id, body);
      _assignments = [for (final a in _assignments) a.id == id ? updated : a];
      notifyListeners();
      return updated;
    } catch (e) {
      _error = e.toString();
      debugPrint('updateAssignment error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DELETE /assignments/{id}
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> deleteAssignment(String id) async {
    _setLoading(true);
    _error = null;
    try {
      await _apiService.deleteAssignment(id);
      _assignments = _assignments.where((a) => a.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('deleteAssignment error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POST /submissions
  // ─────────────────────────────────────────────────────────────────────────
  Future<Submission?> submitAssignment(SubmissionRequest request) async {
    _setLoading(true);
    _error = null;
    try {
      final submission = await _apiService.submitWork(request);
      _submissions = [..._submissions, submission];
      notifyListeners();
      return submission;
    } catch (e) {
      _error = e.toString();
      debugPrint('submitAssignment error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET /submissions/class/{classId}/{type}/{itemId}
  // type = "assignment" | "test"
  // Stores results in _submissions for the current screen
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> fetchSubmissions({
    required String classId,
    required String type, // "assignment" or "test"
    required String itemId,
    num page = 1,
    num limit = 10,
    String search = '',
  }) async {
    _setLoading(true);
    _error = null;
    try {
      _submissions.clear();
      notifyListeners();
      _submissions = await _apiService.getCourseSubmissions(
        classId,
        itemId,
        type,
        page,
        limit,
        search,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('fetchSubmissions error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET /submissions/student/{studentId}
  // Returns list without storing — caller owns the result
  // ─────────────────────────────────────────────────────────────────────────
  // assignment_provider.dart
  Future<List<Submission>> fetchStudentSubmissions({
    required String studentId,
    required String classId,
    required String itemId,
    required String type, // "assignment" | "test"
    String? assessmentId,

    num page = 1,
    num limit = 10,
    String search = '',
  }) async {
    _setLoading(true);
    _error = null;

    try {
      // Fetch submissions for this assignment/test
      final all = await _apiService.getCourseSubmissions(
        classId,
        itemId,
        type,
        page,
        limit,
        search,
      );

      // Filter by student
      final studentSubs = all.where((s) => s.studentId == studentId).toList();

      // Optional additional filter
      if (assessmentId != null) {
        return studentSubs
            .where((s) => s.assessmentId == assessmentId)
            .toList();
      }

      return studentSubs;
    } catch (e) {
      _error = e.toString();
      debugPrint('fetchStudentSubmissions error: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PATCH /submissions/{id}/grade
  // Updates submission in _submissions list in-place
  // ─────────────────────────────────────────────────────────────────────────
  Future<Submission?> gradeSubmission({
    required String submissionId,
    // int score,
    // SubmissionStatus status,
    required GradeRequest request,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final updated = await _apiService.gradeSubmission(submissionId, request);
      _submissions = [
        for (final s in _submissions) s.id == submissionId ? updated : s,
      ];
      notifyListeners();
      return updated;
    } catch (e) {
      _error = e.toString();
      debugPrint('gradeSubmission error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PATCH /submissions/{id}/revoke  &  /restore  (teacher/admin)
  // ─────────────────────────────────────────────────────────────────────────
  Future<Submission?> revokeSubmission({
    required String submissionId,
    required String reason,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final updated =
          await _apiService.revokeSubmission(submissionId, {'reason': reason});
      _submissions = [
        for (final s in _submissions) s.id == submissionId ? updated : s,
      ];
      notifyListeners();
      return updated;
    } catch (e) {
      _error = e.toString();
      debugPrint('revokeSubmission error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<Submission?> restoreSubmission({required String submissionId}) async {
    _setLoading(true);
    _error = null;
    try {
      final updated = await _apiService.restoreSubmission(submissionId);
      _submissions = [
        for (final s in _submissions) s.id == submissionId ? updated : s,
      ];
      notifyListeners();
      return updated;
    } catch (e) {
      _error = e.toString();
      debugPrint('restoreSubmission error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // GET /teacher/classes/{classId}/students/{studentId}/analytics
  Future<Map<String, dynamic>?> fetchStudentAnalytics({
    required String classId,
    required String studentId,
  }) async {
    try {
      final res = await _apiService.getStudentAnalytics(classId, studentId);
      if (res is Map) return res.cast<String, dynamic>();
      return null;
    } catch (e) {
      debugPrint('fetchStudentAnalytics error: $e');
      return null;
    }
  }

  void clear() {
    _assignments = [];
    _submissions = [];
    notifyListeners();
  }
}
