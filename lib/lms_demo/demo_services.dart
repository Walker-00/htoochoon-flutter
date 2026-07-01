import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';
import 'package:flutter/foundation.dart';

class DemoServices extends ChangeNotifier {
  final Dio dio;
  DemoLiveSession? _currentSession;

  DemoServices(this.dio);

  /// Base URL (CHANGE if needed)
  final String baseUrl = kIsWeb
      ? "http://192.168.100.157:3000"
      // "http://172.16.22.216:3000"
      : "http://192.168.100.157:3000";
  // : "http://10.0.2.2:3000";

  /// Current session
  DemoLiveSession? getSessionForCourse(String courseId) {
    if (_currentSession != null &&
        _currentSession!.courseId == courseId &&
        _currentSession!.status == "live") {
      return _currentSession;
    }
    return null;
  }

  /// Demo org structure (UI only)
  final List<DemoOrganization> organizations = [
    DemoOrganization(id: 'org1', name: 'Demo Academy'),
    DemoOrganization(id: 'org2', name: 'Tech Institute'),
  ];

  final List<DemoClassroom> classrooms = [
    DemoClassroom(id: 'cls1', name: 'Grade 10 A', orgId: 'org1'),
    DemoClassroom(id: 'cls2', name: 'Grade 10 B', orgId: 'org1'),
    DemoClassroom(id: 'cls3', name: 'Web Dev Basics', orgId: 'org2'),
  ];

  final List<DemoCourse> courses = [
    DemoCourse(
      id: 'crs1',
      title: 'Mathematics',
      classId: 'cls1',
      teacherName: 'Mr. Smith',
    ),
    DemoCourse(
      id: 'crs2',
      title: 'Physics',
      classId: 'cls1',
      teacherName: 'Mrs. Davis',
    ),
    DemoCourse(
      id: 'crs3',
      title: 'Chemistry',
      classId: 'cls2',
      teacherName: 'Dr. John',
    ),
    DemoCourse(
      id: 'crs4',
      title: 'Flutter Crash Course',
      classId: 'cls3',
      teacherName: 'Alice Dev',
    ),
  ];

  /// Org helpers
  List<DemoOrganization> getOrganizations() => organizations;

  List<DemoClassroom> getClassesForOrg(String orgId) {
    return classrooms.where((c) => c.orgId == orgId).toList();
  }

  List<DemoCourse> getCoursesForClass(String classId) {
    return courses.where((c) => c.classId == classId).toList();
  }

  // =========================
  // 🚀 BACKEND SESSION LOGIC
  // =========================

  /// Start session (teacher)
  Future<DemoLiveSession?> startSession(String courseId) async {
    try {
      final res = await dio.post("$baseUrl/create-session");

      final roomId = res.data["roomId"];
      final code = res.data["code"];

      final session = DemoLiveSession(
        id: roomId,
        courseId: courseId,
        teacherId: "teacher_demo",
        startTime: DateTime.now(),
        status: "live",
        joinCode: code,
      );

      _currentSession = session; // ✅ store locally
      notifyListeners();

      return session;
    } catch (e) {
      logD("❌ startSession error: $e");
      return null;
    }
  }

  /// Join by code (student)
  Future<DemoLiveSession?> findLiveSessionByCode(String code) async {
    try {
      final res = await dio.get("$baseUrl/session/$code");

      final roomId = res.data["roomId"];

      final session = DemoLiveSession(
        id: roomId,
        courseId: "",
        teacherId: "",
        startTime: DateTime.now(),
        status: "live",
        joinCode: code,
      );

      return session;
    } catch (e) {
      logD("❌ joinSession error: $e");
      return null;
    }
  }

  /// End session (optional, local only)
  void endSession(String joinCode) {
    // Backend not implemented yet
    notifyListeners();
  }

  /// Get live sessions (not supported without backend list API)
  List<DemoLiveSession> getLiveSessions() {
    return [];
  }
}
