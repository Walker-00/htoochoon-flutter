import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/api/api_service.dart';
import 'package:htoochoon_flutter/models/api_models/live_session_model.dart';
import 'package:htoochoon_flutter/models/api_models/session_schedule_model.dart';
import 'package:flutter/foundation.dart';

import 'package:htoochoon_flutter/services/home_widget_service.dart';
import 'package:collection/collection.dart';
class LiveSessionProvider extends ChangeNotifier {
  final ApiService _api;
  final Dio _dio;

  LiveSessionProvider(this._api, this._dio);

  String _extractErr(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['message'] != null) {
        final m = d['message'];
        return m is List ? m.join(', ') : m.toString();
      }
      return e.message ?? 'Request failed';
    }
    return e.toString();
  }

  /// Create a recurring series (materialized occurrences server-side).
  Future<bool> createSeries(SeriesRequest req) async {
    _setLoading(true);
    try {
      await _dio.post('/live-sessions/series', data: req.toJson());
      return true;
    } catch (e) {
      _setError(_extractErr(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Edit-split update (SINGLE/FUTURE/ALL) via the pivot occurrence id.
  Future<bool> updateSession(String sessionId, EditScope scope,
      {String? topic, String? startTimeIso, int? durationMin, String? rrule}) async {
    try {
      await _dio.patch('/live-sessions/series/$sessionId', data: {
        'scope': scope.wire,
        if (topic != null) 'topic': topic,
        if (startTimeIso != null) 'startTime': startTimeIso,
        if (durationMin != null) 'durationMin': durationMin,
        if (rrule != null) 'rrule': rrule,
      });
      return true;
    } catch (e) {
      _setError(_extractErr(e));
      return false;
    }
  }

  /// Edit-split delete (SINGLE/FUTURE/ALL).
  Future<bool> deleteSessionScoped(String sessionId, EditScope scope) async {
    try {
      await _dio.delete('/live-sessions/series/$sessionId',
          queryParameters: {'scope': scope.wire});
      return true;
    } catch (e) {
      _setError(_extractErr(e));
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // STATE
  // ─────────────────────────────────────────────

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;
  List<LiveSession> _liveSessions = [];
  List<LiveSession> get liveSessions => _liveSessions;

  List<LiveSession> _upcomingSessions = [];
  List<LiveSession> get upcomingSessions => _upcomingSessions;

  List<LiveSession> _pastSessions = [];
  List<LiveSession> get pastSessions => _pastSessions;

  LiveSession? _currentSession;
  LiveSession? get currentSession => _currentSession;

  // ─────────────────────────────────────────────
  // MEETING STATE (used by socket/video SDK)
  // ─────────────────────────────────────────────

  String? _meetingCode;
  String? get meetingCode => _meetingCode;

  String? _accessToken;
  String? get accessToken => _accessToken;

  String? _refreshToken;
  String? get refreshToken => _refreshToken;

  String? _userName;
  String? get userName => _userName;

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────
  // Add this state
  // Add state
  List<LiveSession> _homeUpcomingSessions = [];
  List<LiveSession> get homeUpcomingSessions => _homeUpcomingSessions;

  bool _isLoadingHome = false;
  bool get isLoadingHome => _isLoadingHome;

  /// Fetches SCHEDULED + LIVE sessions across all classes the student is enrolled in
  Future<void> fetchStudentHomeSessions(String orgId) async {
    _isLoadingHome = true;
    notifyListeners();

    try {
      // 1. Get all classes this student is enrolled in
      final enrollments = await _api.getStudentCourses();

      if (enrollments.isEmpty) {
        _homeUpcomingSessions = [];
        notifyListeners();
        return;
      }

      // 2. Fetch LIVE + SCHEDULED sessions for each classId in parallel
      final futures = enrollments.map((enrollment) async {
        final results = await Future.wait([
          _api
              .getLiveSessions(
                null,
                enrollment.courseId,
                ['LIVE'],
                null,
                null,
                10,
                1,
              )
              .then((r) => r.data)
              .catchError((_) => <LiveSession>[]),

          _api
              .getLiveSessions(
                orgId,
                enrollment.courseId,
                ['SCHEDULED'],
                null,
                null,
                10,
                1,
              )
              .then((r) => r.data)
              .catchError((_) => <LiveSession>[]),
        ]);
        return [...results[0], ...results[1]];
      });

      final nested = await Future.wait(futures);

      // 3. Flatten, deduplicate by id, sort by startTime
      final merged = <String, LiveSession>{};
      for (final sessions in nested) {
        for (final s in sessions) {
          merged[s.id] = s;
        }
      }

      _homeUpcomingSessions = merged.values.toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      // Push the next upcoming session to the home-screen widget (no-op if no
      // widget installed / unsupported platform).
      final next = _homeUpcomingSessions
          .where((s) => s.startTime.isAfter(DateTime.now()))
          .firstOrNull;
      HomeWidgetService.instance.updateUpcoming(
        nextSessionTitle: next?.topic,
        nextSessionAt: next?.startTime,
      );

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoadingHome = false;
      notifyListeners();
    }
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String? e) {
    _error = e;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // FETCH SESSIONS (CLASSROOM DETAIL LOAD)
  // ─────────────────────────────────────────────

  // ─────────────────────────────────────────────
  // FETCH SESSIONS (TARGETED BY STATUS)
  // ─────────────────────────────────────────────

  Future<void> fetchSessionsByStatus({
    required String orgId,
    required String classId,
    required String targetStatus, // 'LIVE', 'SCHEDULED', or 'ENDED'
    int? page,
    int? limit,
  }) async {
    _setLoading(true);
    try {
      final result = await _api.getLiveSessions(
        orgId,
        classId,
        [targetStatus], // Send explicit status array to the backend
        null,
        null,
        limit,
        page,
      );

      final incomingData = result.data;

      switch (targetStatus) {
        case 'LIVE':
          _liveSessions = incomingData;
          break;
        case 'SCHEDULED':
          _upcomingSessions = incomingData;
          break;
        case 'ENDED':
          if (page != null && page > 1) {
            // Append next page results for past history list
            final existingIds = _pastSessions.map((s) => s.id).toSet();
            _pastSessions.addAll(
              incomingData.where((s) => !existingIds.contains(s.id)),
            );
          } else {
            _pastSessions = incomingData;
          }
          break;
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Handle local transformations cleanly when status mutations occur
  void _updateSession(LiveSession updated) {
    // If a session was ended, move it from live/upcoming buckets to past history
    final statusStr = updated.status.toString().toUpperCase();
    if (statusStr.contains('ENDED') || statusStr == 'ENDED') {
      _liveSessions.removeWhere((s) => s.id == updated.id);
      _upcomingSessions.removeWhere((s) => s.id == updated.id);
      if (!_pastSessions.any((s) => s.id == updated.id)) {
        _pastSessions.insert(0, updated);
      }
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // FETCH SINGLE SESSION DETAIL (FOR MEETING PAGE OVERLAY)
  // ─────────────────────────────────────────────
  Future<LiveSession?> fetchSessionDetail(String id) async {
    _setLoading(true);
    try {
      final session = await _api.getLiveSession(id);
      _currentSession = session;
      notifyListeners();
      return session;
    } catch (e) {
      logD("❌ Failed to load live-session detail: $e");
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }
  // ─────────────────────────────────────────────
  // CREATE SESSION (TEACHER)
  // ─────────────────────────────────────────────

  // ─────────────────────────────────────────────
  // CREATE SESSION (TEACHER)
  // ─────────────────────────────────────────────

  Future<LiveSession?> createSession(LiveSessionRequest request) async {
    _setLoading(true);

    try {
      final res = await _api.createLiveSession(request);

      _upcomingSessions.insert(0, res);

      _currentSession = res;

      notifyListeners();
      return res;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }
  // ─────────────────────────────────────────────
  // START SESSION (TEACHER)
  // ─────────────────────────────────────────────

  Future<void> startSession(String id) async {
    try {
      final res = await _api.startLiveSession(id);

      _updateSession(res);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // ─────────────────────────────────────────────
  // END SESSION (TEACHER)
  // ─────────────────────────────────────────────
  Future<void> endSession(String id) async {
    try {
      _setError(null); // Clear previous errors

      // 1. Await the API call (returns a single LiveSession object)
      final updatedSession = await _api.endLiveSession(id);

      // 2. Pass the updated object directly to your handler
      _updateSession(updatedSession);

      // 3. Notify UI of changes
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      debugPrint("endSession error: $e");
    }
  }

  // ─────────────────────────────────────────────
  // JOIN SESSION (STUDENT OR TEACHER)
  // ─────────────────────────────────────────────
  Future<bool> teacherJoinSession({
    required String sessionId,
    required String name,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      // 💡 The backend returns the joining credentials in the response payload
      final res = await _api.joinTeacherLiveSession(sessionId);

      // Assuming res contains data fields: meetingCode, token, refreshToken
      _meetingCode = res.meetingCode;
      _accessToken =
          res.accessToken; // Map 'token' to your provider state property
      _refreshToken = res.refreshToken;
      _userName = name;

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> studentJoinSession({
    required String sessionId,
    required String name,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      // 💡 The backend returns the joining credentials in the response payload
      final res = await _api.joinStudentLiveSession(sessionId);

      _meetingCode = res.meetingCode;
      _accessToken = res.accessToken;
      _refreshToken = res.refreshToken;
      _userName = name;

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      logD(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────
  // STATUS HELPERS (IMPORTANT FOR UI)
  // ─────────────────────────────────────────────

  // List<LiveSession> get scheduled =>
  //     _sessions.where((e) => e.status == LiveSessionStatus.scheduled).toList();
  //
  // List<LiveSession> get live =>
  //     _sessions.where((e) => e.status == LiveSessionStatus.live).toList();
  //
  // List<LiveSession> get ended =>
  //     _sessions.where((e) => e.status == LiveSessionStatus.ended).toList();

  // ─────────────────────────────────────────────
  // INTERNAL UPDATE
  // ─────────────────────────────────────────────

  // ─────────────────────────────────────────────
  // CLEAR MEETING (LEAVE ROOM)
  // ─────────────────────────────────────────────

  void clearMeeting() {
    _meetingCode = null;
    _accessToken = null;
    _refreshToken = null;
    _userName = null;

    notifyListeners();
  }
}
