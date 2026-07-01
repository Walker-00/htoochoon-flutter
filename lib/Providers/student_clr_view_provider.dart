import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../models/api_models/class_model.dart';
import '../models/api_models/course_model.dart';
import '../models/api_models/live_session_model.dart';
import '../models/api_models/assignment_model.dart';
import '../models/api_models/submission_model.dart';
import '../models/api_models/attendance_model.dart';
import '../models/api_models/user_model.dart';
import '../models/api_models/organization_model.dart';
import '../models/api_models/enums.dart';

class StudentClassroomProvider extends ChangeNotifier {
  final ApiService _apiService;

  StudentClassroomProvider(this._apiService);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  List<ClassModel> _enrolledClasses = [];
  List<ClassModel> get enrolledClasses => _enrolledClasses;

  List<LiveSession> _upcomingSessions = [];
  List<LiveSession> get upcomingSessions => _upcomingSessions;

  List<Assignment> _assignments = [];
  List<Assignment> get assignments => _assignments;

  // List<TestModel> _tests = [];
  // List<TestModel> get tests => _tests;

  List<Submission> _mySubmissions = [];
  List<Submission> get mySubmissions => _mySubmissions;

  List<Attendance> _myAttendance = [];
  List<Attendance> get myAttendance => _myAttendance;
  //
  // /// Fetch student's enrolled classes
  // Future<void> fetchEnrolledClasses(String studentId) async {
  //   _isLoading = true;
  //   _error = null;
  //   notifyListeners();
  //   try {
  //     // Get all classes and filter by student enrollment
  //     // In a real backend, you'd have a dedicated endpoint like /students/{id}/classes
  //     _enrolledClasses = await _apiService.getClasses();
  //   } catch (e) {
  //     _error = e.toString();
  //     debugPrint("Error fetching enrolled classes: $e");
  //   } finally {
  //     _isLoading = false;
  //     notifyListeners();
  //   }
  // }

  /// Fetch upcoming live sessions for a class
  // Future<void> fetchUpcomingSessions({
  //   String? classId,
  //   String? status,
  //
  //   int? limit,
  //   int? page,
  // }) async {
  //   _isLoading = true;
  //   _error = null;
  //   notifyListeners();
  //   try {
  //     _upcomingSessions = await _apiService.getUpcomingLiveSessions(
  //       null,
  //       classId,
  //       status,
  //       null,
  //       null,
  //       limit,
  //       page,
  //     );
  //   } catch (e) {
  //     _error = e.toString();
  //     debugPrint("Error fetching upcoming sessions: $e");
  //   } finally {
  //     _isLoading = false;
  //     notifyListeners();
  //   }
  // }

  /// Fetch assignments for a class
  Future<void> fetchAssignments(String classId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _assignments = await _apiService.getAssignmentsByCourse(classId);
    } catch (e) {
      _error = e.toString();
      debugPrint("Error fetching assignments: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch student's submissions
  Future<void> fetchMySubmissions(String studentId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _mySubmissions = await _apiService.getStudentSubmissions(studentId);
    } catch (e) {
      _error = e.toString();
      debugPrint("Error fetching submissions: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch student's attendance
  Future<void> fetchMyAttendance(String studentId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _myAttendance = await _apiService.getAttendanceByStudent(
        studentId,
        studentId,
      );
    } catch (e) {
      _error = e.toString();
      debugPrint("Error fetching attendance: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Submit an assignment/test
  Future<Submission?> submitWork(SubmissionRequest request) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final submission = await _apiService.submitWork(request);
      _mySubmissions = [..._mySubmissions, submission];
      notifyListeners();
      return submission;
    } catch (e) {
      _error = e.toString();
      debugPrint("Error submitting work: $e");
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get course details for a class
  Future<CourseResponse?> getCourseForClass(String courseId) async {
    try {
      return await _apiService.getCourseById(courseId);
    } catch (e) {
      _error = e.toString();
      debugPrint("Error fetching course: $e");
      return null;
    }
  }

  /// Get teacher info
  Future<UserResponse?> getTeacherInfo(String teacherId) async {
    try {
      final user = await _apiService.getUser(teacherId);
      return UserResponse(
        id: user.id,
        email: user.email,
        name: user.name,
        role: _parseRole(user.role.toString()),
        isActive: user.isActive,
        isTwoFactorEnabled: user.isTwoFactorEnabled ?? false,
        createdAt: user.createdAt ?? DateTime.now(),
        updatedAt: user.updatedAt ?? DateTime.now(),
      );
    } catch (e) {
      _error = e.toString();
      debugPrint("Error fetching teacher info: $e");
      return null;
    }
  }

  /// Parse string role to Role enum
  Role _parseRole(String? roleStr) {
    try {
      return Role.values.firstWhere(
        (e) => e.name.toUpperCase() == (roleStr ?? '').toUpperCase(),
        orElse: () => Role.ORG_ADMIN,
      );
    } catch (_) {
      return Role.ORG_ADMIN;
    }
  }

  /// Get student's organizations
  Future<List<OrganizationResponse>> getStudentOrganizations() async {
    try {
      return await _apiService.getOrganizations();
    } catch (e) {
      _error = e.toString();
      debugPrint("Error fetching organizations: $e");
      return [];
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
