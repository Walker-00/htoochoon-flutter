import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/models/api_models/assignment_model.dart';
import '../api/api_service.dart';
import '../models/api_models/attendance_model.dart';
import '../models/api_models/submission_model.dart';

class ProgressProvider extends ChangeNotifier {
  final ApiService _apiService;

  ProgressProvider(this._apiService);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Map<String, double> _classProgress = {};
  double getProgress(String classId) => _classProgress[classId] ?? 0.0;

  List<Attendance> _attendanceRecords = [];
  List<Attendance> get attendanceRecords => _attendanceRecords;

  List<Submission> _studentSubmissions = [];
  List<Submission> get studentSubmissions => _studentSubmissions;

  /// Calculate and fetch class progress based on attendance
  Future<void> fetchClassProgress(String classId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final attendance = await _apiService.getAttendanceByCourse(classId, null);
      _attendanceRecords = attendance;

      // Calculate progress based on attendance
      if (attendance.isNotEmpty) {
        final presentCount = attendance
            .where((a) => a.status == AttendanceStatus.present)
            .length;
        _classProgress[classId] = presentCount / attendance.length;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint("Error fetching class progress: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch student progress (submissions) for a class
  // Future<void> fetchStudentProgress(
  //   String classId,
  //   String type,
  //   String itemId,
  // ) async {
  //   _isLoading = true;
  //   _error = null;
  //   notifyListeners();
  //   try {
  //     _studentSubmissions = await _apiService.getClassSubmissions(
  //       classId,
  //       // type,
  //       // itemId,
  //     );
  //   } catch (e) {
  //     _error = e.toString();
  //     debugPrint("Error fetching student progress: $e");
  //   } finally {
  //     _isLoading = false;
  //     notifyListeners();
  //   }
  // }

  /// Fetch student's attendance
  Future<List<Attendance>> fetchStudentAttendance(String studentId) async {
    try {
      return await _apiService.getAttendanceByStudent(studentId, studentId);
    } catch (e) {
      _error = e.toString();
      debugPrint("Error fetching student attendance: $e");
      return [];
    }
  }

  /// Fetch student's submissions
  Future<List<Submission>> fetchStudentSubmissions(String studentId) async {
    try {
      return await _apiService.getStudentSubmissions(studentId);
    } catch (e) {
      _error = e.toString();
      debugPrint("Error fetching student submissions: $e");
      return [];
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
