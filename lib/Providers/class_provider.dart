import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/models/api_models/enrollment_model.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:htoochoon_flutter/models/auth/auth_model.dart';
import '../api/api_service.dart';
import '../models/api_models/class_model.dart';

class ClassProvider extends ChangeNotifier {
  final ApiService _apiService;

  ClassProvider(this._apiService);

  // ─────────────────────────────────────────────
  // Global State
  // ─────────────────────────────────────────────

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isFetchingMore = false;
  bool get isFetchingMore => _isFetchingMore;
  String? _activeStudentRequestClassId;
  String? _error;
  String? get error => _error;

  // ─────────────────────────────────────────────
  // Classes State
  // ─────────────────────────────────────────────

  List<ClassModel> _classes = [];
  List<ClassModel> get classes => _classes;

  ClassModel? _selectedClass;
  ClassModel? get selectedClass => _selectedClass;

  int _page = 1;
  final int _limit = 10;
  bool _hasMore = true;

  bool get hasMore => _hasMore;

  // ─────────────────────────────────────────────
  // Students State
  // ─────────────────────────────────────────────

  final Map<String, List<User>> _classStudents = {};
  final Map<String, bool> _studentLoading = {};
  final Map<String, bool> _studentHasMore = {};
  final Map<String, int> _studentPages = {};

  List<User> getStudents(String classId) {
    return _classStudents[classId] ?? [];
  }

  bool isStudentsLoading(String classId) {
    return _studentLoading[classId] ?? false;
  }

  bool hasMoreStudents(String classId) {
    return _studentHasMore[classId] ?? true;
  }

  // ─────────────────────────────────────────────
  // Fetch Classes
  // ─────────────────────────────────────────────
  Future<void> fetchTeacherIdClass(String? teacherId, String? orgId) async {
    try {
      _isLoading = true;
      _error = null;
      _page = 1;
      _hasMore = true;

      notifyListeners();

      final response = await _apiService.getClasses(
        orgId,
        _limit,
        _page,
        "",
        teacherId,
        "",
      );

      _classes = response.data;

      _hasMore = _page < response.meta.totalPages;
    } catch (e) {
      _error = e.toString();

      debugPrint("Error fetching classes: $e");
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  Future<void> fetchClasses(
    String? orgId,
    String? teacherId,
    String? courseId,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      _page = 1;
      _hasMore = true;

      notifyListeners();
      final response = await _apiService.getClasses(
        (orgId != null) ? orgId : null,
        _limit,
        _page,
        "",
        teacherId,
        courseId,
      );
      _classes = response.data;

      _hasMore = _page < response.meta.totalPages;
    } catch (e) {
      _error = e.toString();

      debugPrint("Error fetching classes: $e");
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // Fetch More Classes
  // ─────────────────────────────────────────────

  Future<void> fetchMoreClasses() async {
    try {
      if (_isFetchingMore || !_hasMore) return;

      _isFetchingMore = true;

      notifyListeners();

      _page++;

      final response = await _apiService.getClasses(
        null,
        _limit,
        _page,
        "",
        "",
        "",
      );

      _classes.addAll(response.data);

      _hasMore = _page < response.meta.totalPages;
    } catch (e) {
      _error = e.toString();

      debugPrint("Error fetching more classes: $e");
    } finally {
      _isFetchingMore = false;

      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // Get Class By ID
  // ─────────────────────────────────────────────

  Future<ClassModel?> getClassById(String id) async {
    try {
      _isLoading = true;
      _error = null;

      notifyListeners();

      final classModel = await _apiService.getClassById(id);

      _selectedClass = classModel;

      return classModel;
    } catch (e) {
      _error = e.toString();

      debugPrint("Error fetching class: $e");

      return null;
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // Create Class
  // ─────────────────────────────────────────────

  Future<ClassModel?> createClass(ClassRequest request) async {
    try {
      _isLoading = true;
      _error = null;

      notifyListeners();

      final newClass = await _apiService.createClass(request);

      _classes = [..._classes, newClass];

      return newClass;
    } catch (e) {
      _error = e.toString();

      debugPrint("Error creating class: $e");

      return null;
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // Update Class
  // ─────────────────────────────────────────────

  Future<bool> updateClass(String id, ClassRequest request) async {
    try {
      _isLoading = true;
      _error = null;

      notifyListeners();

      final updated = await _apiService.updateClass(id, request);

      _classes = [for (final c in _classes) c.id == id ? updated : c];

      if (_selectedClass?.id == id) {
        _selectedClass = updated;
      }

      return true;
    } catch (e) {
      _error = e.toString();

      debugPrint("Error updating class: $e");

      return false;
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // Delete Class
  // ─────────────────────────────────────────────

  Future<bool> deleteClass(String id) async {
    try {
      _isLoading = true;
      _error = null;

      notifyListeners();

      await _apiService.deleteClass(id);

      _classes.removeWhere((c) => c.id == id);
      notifyListeners();
      if (_selectedClass?.id == id) {
        _selectedClass = null;
      }

      return true;
    } catch (e) {
      _error = e.toString();

      debugPrint("Error deleting class: $e");

      return false;
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // Fetch Students
  // ─────────────────────────────────────────────

  Future<void> fetchStudents(
    String classId, {
    bool refresh = false,
    int limit = 20,
  }) async {
    try {
      if (_studentLoading[classId] == true) return;

      _studentLoading[classId] = true;

      // 🔥 track active request
      _activeStudentRequestClassId = classId;

      if (refresh) {
        _classStudents[classId] = [];
        _studentPages[classId] = 1;
        _studentHasMore[classId] = true;
        notifyListeners();
      }

      final page = _studentPages[classId] ?? 1;

      final response = await _apiService.getAllStudentsInAClass(
        classId,
        // page: page,
        // limit: limit,
      );

      logD("FETCHED MEMBERS ${response.data.length}");

      // ❗ ignore stale response
      if (_activeStudentRequestClassId != classId) return;

      final newStudents = response.data.map((e) {
        final s = e.students;

        return User(
          id: s.id,
          name: s.name,
          email: s.email,
          avatar: s.avatar,
          role: Role.STUDENT,
          isActive: true,
          createdAt: e.joinedAt,
        );
      }).toList();

      final existing = _classStudents[classId] ?? [];

      _classStudents[classId] = (refresh || page == 1)
          ? newStudents
          : [...existing, ...newStudents];

      _studentHasMore[classId] = page < response.meta.totalPages;

      if (_studentHasMore[classId] == true) {
        _studentPages[classId] = page + 1;
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
    } finally {
      _studentLoading[classId] = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // Add Student
  // ─────────────────────────────────────────────

  Future<bool> addStudentToClass(String classId, String userId) async {
    try {
      _isLoading = true;
      _error = null;

      notifyListeners();

      // 1. Add student to class
      await _apiService.addStudentToClass(
        classId,
        ClassStudentRequest(userId: userId),
      );

      // 2. Get class
      final classModel = await _apiService.getClassById(classId);

      // 3. Get course
      final course = await _apiService.getCourseById(
        classModel.courseId.toString(),
      );

      // 4. Conditional Enrollment Logic
      if (course.type == CourseType.SKILL) {
        logD("course type is skill ");
        // Check if user is already enrolled in this course
        final existingCourseEnrollments = await _apiService
            .getCourseEnrollmentsByUser(userId, null);

        // FIX: Cast to Enrollment? so returning null from orElse is legal
        final existingEnrollment = existingCourseEnrollments
            .cast<Enrollment?>()
            .firstWhere((e) => e?.courseId == course.id, orElse: () => null);

        if (existingEnrollment != null) {
          logD("skill course enrollment  exist");
          // Already enrolled -> Update status to ACTIVE
          await _apiService.updateCourseEnrollmentStatus(
            existingEnrollment.id.toString(),
            UpdateEnrollmentStatusRequest(status: EnrollmentStatus.ACTIVE),
          );
        } else {
          logD("skill course enrollment not exist");
          // Not enrolled -> Create brand new enrollment
          await _apiService.enrollCourse(
            CourseEnrollmentRequest(
              userId: userId,
              courseId: course.id,
              classId: classId,
              status: "ACTIVE",
            ),
          );
        }
      } else if (course.type == CourseType.ACADEMIC) {
        logD("course type is academic");
        if (course.programCourses.isEmpty) {
          throw Exception("ACADEMIC course has no linked program");
        }

        final programId = course.programCourses.first.programId;

        // Check if user is already enrolled in this program
        final existingProgramEnrollments = await _apiService
            .getProgramEnrollmentsByUser(userId, null);

        // FIX: Cast to Enrollment? so returning null from orElse is legal
        final existingEnrollment = existingProgramEnrollments
            .cast<Enrollment?>()
            .firstWhere((e) => e?.programId == programId, orElse: () => null);
        if (existingEnrollment != null) {
          logD("acedemic course enrollment not exist");
          // Already enrolled -> Update status to ACTIVE
          await _apiService.updateProgramEnrollmentStatus(
            existingEnrollment.id.toString(),
            UpdateEnrollmentStatusRequest(
              status: EnrollmentStatus.ACTIVE,
            ), // Match EnrollmentStatus type or string
          );
        } else {
          logD("acedemic course enrollment  exist");
          // Not enrolled -> Create brand new enrollment
          await _apiService.enrollProgram(
            ProgramEnrollmentRequest(
              userId: userId,
              programId: programId,
              status: EnrollmentStatus.ACTIVE,
            ),
          );
        }
      }

      // 5. Refresh UI
      await fetchStudents(classId, refresh: true);

      return true;
    } catch (e, stack) {
      _error = e.toString();

      debugPrint("Error adding student to class: $e");
      debugPrintStack(stackTrace: stack);

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  // Future<bool> addStudentToClass(String classId, String userId) async {
  //   try {
  //     _isLoading = true;
  //     _error = null;
  //
  //     notifyListeners();
  //
  //     // 1. Add student to class
  //     await _apiService.addStudentToClass(
  //       classId,
  //       ClassStudentRequest(userId: userId),
  //     );
  //
  //     // 2. Get class
  //     final classModel = await _apiService.getClassById(classId);
  //
  //     // 3. Get course
  //     final course = await _apiService.getCourseById(
  //       classModel.courseId.toString(),
  //     );
  //
  //     // 4. Enrollment logic
  //     if (course.type == CourseType.SKILL) {
  //       // Direct course enrollment
  //       await _apiService.enrollCourse(
  //         CourseEnrollmentRequest(
  //           userId: userId,
  //           courseId: course.id,
  //           classId: classId,
  //           status: "ACTIVE",
  //         ),
  //       );
  //     } else if (course.type == CourseType.ACADEMIC) {
  //       // Program enrollment
  //       if (course.programCourses.isEmpty) {
  //         throw Exception("ACADEMIC course has no linked program");
  //       }
  //
  //       final programId = course.programCourses.first.programId;
  //
  //       await _apiService.enrollProgram(
  //         ProgramEnrollmentRequest(
  //           userId: userId,
  //           programId: programId,
  //           status: EnrollmentStatus.ACTIVE,
  //         ),
  //       );
  //     }
  //
  //     // 5. Refresh UI
  //     await fetchStudents(classId, refresh: true);
  //
  //     return true;
  //   } catch (e, stack) {
  //     _error = e.toString();
  //
  //     debugPrint("Error adding student to class: $e");
  //     debugPrintStack(stackTrace: stack);
  //
  //     return false;
  //   } finally {
  //     _isLoading = false;
  //     notifyListeners();
  //   }
  // }
  //

  Future<bool> removeStudentFromClass(String classId, String userId) async {
    try {
      _isLoading = true;
      _error = null;

      notifyListeners();

      await _apiService.removeStudentFromClass(classId, userId);

      _classStudents[classId]?.removeWhere((student) => student.id == userId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();

      debugPrint("Error removing student from class: $e");

      return false;
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // Clear Student Cache
  // ─────────────────────────────────────────────

  void clearStudents(String classId) {
    _classStudents.remove(classId);
    _studentPages.remove(classId);
    _studentLoading.remove(classId);
    _studentHasMore.remove(classId);

    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // Clear Error
  // ─────────────────────────────────────────────

  void clearError() {
    _error = null;

    notifyListeners();
  }
}
