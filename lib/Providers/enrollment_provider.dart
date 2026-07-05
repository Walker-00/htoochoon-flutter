import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/api/api_service.dart';
import 'package:htoochoon_flutter/models/api_models/enrollment_model.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';

/// Central state for program & course enrollments.
///
/// Backs both the student-facing "my learning" views (the *my\*Enrollments*
/// lists, populated from `/enrollment/{courses,programs}/user/{userId}`) and
/// the admin/teacher review views (the *\*SpecificEnrollments* and
/// `programEnrollments` lists, populated from the paginated
/// `/enrollment/{courses,programs}` and `/enrollment/{courses,programs}/{id}`
/// routes).
class EnrollmentProvider extends ChangeNotifier {
  final ApiService _api;
  EnrollmentProvider(this._api);

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  String? _error;

  // Current user's enrollments (student "My Learning" / Home).
  List<Enrollment> _myCourseEnrollments = [];
  List<Enrollment> _myProgramEnrollments = [];

  // Enrollments for a specific course / program (detail screens, paginated).
  List<Enrollment> _courseSpecificEnrollments = [];
  List<Enrollment> _programSpecificEnrollments = [];

  // Org-wide pending/approval list (enrollment_tab).
  List<Enrollment> _programEnrollments = [];

  // Programs/orgs the current user has an OPEN (PENDING) access request for.
  // Loaded from /access-requests/mine so the "Enrollment requested" state
  // survives rebuilds and app restarts (was previously a lost local bool).
  final Set<String> _pendingReqProgramIds = {};
  final Set<String> _pendingReqOrgIds = {};

  // ── Getters ───────────────────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  bool get isFetchingMore => _isFetchingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  List<Enrollment> get myCourseEnrollments => _myCourseEnrollments;
  List<Enrollment> get myProgramEnrollments => _myProgramEnrollments;

  /// Alias used by Home — the current user's course enrollments.
  List<Enrollment> get courseEnrollments => _myCourseEnrollments;

  List<Enrollment> get courseSpecificEnrollments => _courseSpecificEnrollments;
  List<Enrollment> get programSpecificEnrollments =>
      _programSpecificEnrollments;
  List<Enrollment> get programEnrollments => _programEnrollments;

  /// True if the user has an open access request tagged with [programId].
  bool hasPendingProgramRequest(String programId) =>
      _pendingReqProgramIds.contains(programId);

  /// True if the user has an open org-join access request (no specific program).
  bool hasPendingOrgRequest(String orgId) =>
      _pendingReqOrgIds.contains(orgId);

  // ── Helpers ─────────────────────────────────────────────────────────────────
  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String? e) {
    _error = e;
    notifyListeners();
  }

  void clearError() => _setError(null);

  String _extractError(dynamic e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data['message'] != null) {
        return data['message'].toString();
      }
      return 'Request failed (${e.response?.statusCode ?? 'unknown'})';
    }
    return e.toString();
  }

  // ── Current user's enrollments ───────────────────────────────────────────────
  Future<void> fetchCurrentUserEnrollments(String userId) async {
    _setError(null);
    _setLoading(true);
    try {
      final courses = await _api.getCourseEnrollmentsByUser(userId, null);
      final programs = await _api.getProgramEnrollmentsByUser(userId, null);
      _myCourseEnrollments = courses;
      _myProgramEnrollments = programs;
      _setError(null);
    } catch (e) {
      _setError(_extractError(e));
      debugPrint("Error fetching current user enrollments: $e");
    } finally {
      _setLoading(false);
    }
  }

  // ── Current user's OPEN access requests ──────────────────────────────────────
  /// Populates [_pendingReqProgramIds] / [_pendingReqOrgIds] from
  /// /access-requests/mine so enroll buttons can render the "requested" state
  /// after a rebuild or restart. Best-effort — failure just leaves the sets as-is.
  Future<void> fetchMyAccessRequests() async {
    try {
      final res = await _api.myAccessRequests();
      final list = (res as List?) ?? const [];
      _pendingReqProgramIds.clear();
      _pendingReqOrgIds.clear();
      for (final raw in list) {
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);
        final status = (m['status']?.toString() ?? '').toUpperCase();
        if (status != 'PENDING') continue;
        final pid = m['programId']?.toString();
        final oid = m['organizationId']?.toString();
        if (pid != null && pid.isNotEmpty) {
          _pendingReqProgramIds.add(pid);
        } else if (oid != null && oid.isNotEmpty) {
          _pendingReqOrgIds.add(oid);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching my access requests: $e");
    }
  }

  /// Optimistically mark a just-sent access request so the UI flips to the
  /// "requested" state immediately, before the next /mine refresh.
  void markRequested({String? programId, String? orgId}) {
    if (programId != null && programId.isNotEmpty) {
      _pendingReqProgramIds.add(programId);
    } else if (orgId != null && orgId.isNotEmpty) {
      _pendingReqOrgIds.add(orgId);
    }
    notifyListeners();
  }

  // ── Org-wide program enrollments (e.g. pending approvals) ──────────────────────
  Future<void> fetchProgramEnrollments({
    required EnrollmentStatus status,
    required String organizationId,
    String search = '',
    int page = 1,
    int limit = 100,
  }) async {
    _setError(null);
    _setLoading(true);
    try {
      final res = await _api.getAllProgramEnrollments(
        page,
        limit,
        organizationId,
        status.name,
        search,
      );
      _programEnrollments = res.data;
      _setError(null);
    } catch (e) {
      _setError(_extractError(e));
      debugPrint("Error fetching program enrollments: $e");
    } finally {
      _setLoading(false);
    }
  }

  // ── Enrollments for a specific program ──────────────────────────────────────
  Future<void> fetchEnrollmentsByProgramId({
    required String programId,
    String? organizationId,
    String? status,
    int? page,
    int? limit,
  }) async {
    _setError(null);
    _setLoading(true);
    try {
      final res = await _api.getProgramEnrollmentsByProgramId(
        programId,
        page ?? 1,
        limit ?? 100,
        organizationId,
        null,
        status,
      );
      _programSpecificEnrollments = res.data;
      _setError(null);
    } catch (e) {
      _setError(_extractError(e));
      debugPrint("Error fetching enrollments by program id: $e");
    } finally {
      _setLoading(false);
    }
  }

  /// Used by program_detail to load every enrollment for a program.
  /// [userIds] is accepted for call-site compatibility; the server route is
  /// keyed by program id so we fetch the full program enrollment list.
  Future<void> fetchAllProgramEnrollments(
    List<String> userIds,
    String programId, {
    String? organizationId,
  }) async {
    await fetchEnrollmentsByProgramId(
      programId: programId,
      organizationId: organizationId,
    );
  }

  // ── Enrollments for a specific course (paginated) ───────────────────────────
  Future<void> fetchEnrollmentsByCourseId({
    required String courseId,
    int page = 1,
    int limit = 20,
    String? organizationId,
    String? status,
    bool loadMore = false,
  }) async {
    _setError(null);
    if (loadMore) {
      _isFetchingMore = true;
      notifyListeners();
    } else {
      _hasMore = true;
      _setLoading(true);
    }
    try {
      final res = await _api.getCourseEnrollmentsByCourseId(
        courseId,
        page,
        limit,
        organizationId,
        null,
        status,
      );
      if (loadMore) {
        _courseSpecificEnrollments = [
          ..._courseSpecificEnrollments,
          ...res.data,
        ];
      } else {
        _courseSpecificEnrollments = res.data;
      }
      _hasMore = res.meta.page < res.meta.totalPages;
      _setError(null);
    } catch (e) {
      _setError(_extractError(e));
      debugPrint("Error fetching enrollments by course id: $e");
    } finally {
      _isFetchingMore = false;
      _setLoading(false);
    }
  }

  /// Used by course_detail to load every enrollment for a course.
  Future<void> fetchAllCourseEnrollments(
    List<String> userIds,
    String courseId, {
    String? organizationId,
  }) async {
    await fetchEnrollmentsByCourseId(
      courseId: courseId,
      organizationId: organizationId,
      limit: 100,
    );
  }

  // ── Mutations ────────────────────────────────────────────────────────────────
  Future<Enrollment?> enrollCourse(CourseEnrollmentRequest request) async {
    _setError(null);
    _setLoading(true);
    try {
      final created = await _api.enrollCourse(request);
      _myCourseEnrollments = [..._myCourseEnrollments, created];
      _setError(null);
      return created;
    } catch (e) {
      _setError(_extractError(e));
      debugPrint("Error enrolling in course: $e");
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<Enrollment?> enrollProgram(ProgramEnrollmentRequest request) async {
    _setError(null);
    _setLoading(true);
    try {
      final created = await _api.enrollProgram(request);
      _myProgramEnrollments = [..._myProgramEnrollments, created];
      _setError(null);
      return created;
    } catch (e) {
      _setError(_extractError(e));
      debugPrint("Error enrolling in program: $e");
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<Enrollment?> updateCourseEnrollmentStatus(
    String enrollmentId,
    UpdateEnrollmentStatusRequest request,
  ) async {
    _setError(null);
    try {
      final updated =
          await _api.updateCourseEnrollmentStatus(enrollmentId, request);
      _replaceInList(_courseSpecificEnrollments, updated);
      _replaceInList(_myCourseEnrollments, updated);
      notifyListeners();
      return updated;
    } catch (e) {
      _setError(_extractError(e));
      debugPrint("Error updating course enrollment status: $e");
      return null;
    }
  }

  Future<Enrollment?> updateProgramEnrollmentStatus(
    String enrollmentId,
    UpdateEnrollmentStatusRequest request,
  ) async {
    _setError(null);
    try {
      final updated =
          await _api.updateProgramEnrollmentStatus(enrollmentId, request);
      _replaceInList(_programSpecificEnrollments, updated);
      _replaceInList(_programEnrollments, updated);
      _replaceInList(_myProgramEnrollments, updated);
      notifyListeners();
      return updated;
    } catch (e) {
      _setError(_extractError(e));
      debugPrint("Error updating program enrollment status: $e");
      return null;
    }
  }

  /// Convenience wrapper used by the admin enrollment UI: approves a pending
  /// program enrollment by setting its status to ACTIVE. Returns `true` on
  /// success so callers can branch without inspecting the returned model.
  Future<bool> acceptProgramEnrollment(String enrollmentId) async {
    final updated = await updateProgramEnrollmentStatus(
      enrollmentId,
      UpdateEnrollmentStatusRequest(status: EnrollmentStatus.ACTIVE),
    );
    return updated != null;
  }

  void _replaceInList(List<Enrollment> list, Enrollment updated) {
    final idx = list.indexWhere((e) => e.id == updated.id);
    if (idx != -1) list[idx] = updated;
  }
}
