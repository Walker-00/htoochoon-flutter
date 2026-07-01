import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/api/api_service.dart';
import 'package:htoochoon_flutter/models/api_models/course_model.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:json_annotation/json_annotation.dart';

class CoursesProvider extends ChangeNotifier {
  final ApiService _api;
  VoidCallback? onLimitReached;
  void _handleLimitReached(String message) {
    onLimitReached?.call();
  }

  CoursesProvider(this._api);

  bool _isLoading = false;
  String? _error;
  List<CourseResponse> _courses = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<CourseResponse> get courses => _courses;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String? e) {
    _error = e;
    notifyListeners();
  }

  List<CourseResponse> searchAndFilterCourses(String query, CourseType type) {
    return _courses.where((course) {
      final matchesType = course.type == type;
      final matchesQuery =
          query.isEmpty ||
          course.name.toLowerCase().contains(query.toLowerCase()) ||
          (course.description?.toLowerCase().contains(query.toLowerCase()) ??
              false);
      return matchesType && matchesQuery;
    }).toList();
  }

  Future<void> fetchAllCourses() async {
    _setError(null);
    _setLoading(true);
    notifyListeners();
    try {
      final res = await _api.getCourses(null, null, null, 1, 10);
      _courses = res.data;
      logD("PRINTING COURESE FROM COURSE PROVIDER");
      _setError(null);
    } catch (e) {
      _error = e.toString();
      debugPrint("Error fetching all courses: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCoursesInOrg(
    String organizationId,
    CourseType? type,
  ) async {
    _setError(null);
    _setLoading(true);
    try {
      final res = await _api.getCourses(
        organizationId.toString(),
        type,

        '',
        1,
        10,
      );
      _courses = res.data;
      logD("PRINTING COURSES FROM COURSES PROVIDER ${courses.length}");
      _setError(null);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  String _extractError(dynamic e) {
    if (e is DioException) {
      final data = e.response?.data;

      if (data is Map<String, dynamic>) {
        if (data['message'] != null) {
          return data['message'].toString();
        }
      }

      return 'Request failed (${e.response?.statusCode ?? 'unknown'})';
    }

    return e.toString();
  }

  Future<bool> createCourse(CourseRequest request) async {
    _setError(null);
    _setLoading(true);

    try {
      // 1. Await the response in the try block
      final course = await _api.createCourse(request);

      // 2. SUCCESS LOGIC GOES HERE (Inside the try block)
      _courses.add(course);
      _setError(null); // Clear errors on success

      notifyListeners();
      return true;
    } on CheckedFromJsonException catch (e) {
      // This blocks catches the specific JSON mismatch error and prints the exact field
      logD('❌ JSON Parsing failed on key: ${e.className}.${e.key}');
      logD('❌ Broken Key: ${e.key}');
      logD('❌ Error details: ${e.message}');

      _error = "Data parsing error on field: ${e.key}";
      return false;
    } catch (e) {
      // This catches regular network errors (400, 404, 500, timeouts, etc.)
      logD("Failed to execute request: $e");
      final errorMessage = _extractError(e);
      _error = errorMessage;

      if (errorMessage.contains('limit reached')) {
        _handleLimitReached(errorMessage);
      }
      return false;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }
  // Future<bool> createProgram(ProgramRequest request) async {
  //   _error = null;
  //   _isLoading = true;
  //   notifyListeners();
  //
  //   try {
  //     final created = await _api.createProgram(request);
  //
  //     final full = await _api.getProgramById(created.id);
  //     _programs.add(full);
  //
  //     return true;
  //   } catch (e) {
  //     final errorMessage = _extractError(e);
  //
  //     _error = errorMessage;
  //
  //     // 👇 IMPORTANT: detect limit reached
  //     if (errorMessage.contains('limit reached')) {
  //       _handleLimitReached(errorMessage);
  //     }
  //
  //     return false;
  //   } finally {
  //     _isLoading = false;
  //     notifyListeners();
  //   }
  // }

  Future<bool> updateCourse(String id, CourseRequest request) async {
    _setError(null);
    _setLoading(true);
    try {
      final updated = await _api.updateCourse(id, request);
      final idx = _courses.indexWhere((c) => c.id == id);
      if (idx != -1) {
        _courses[idx] = updated;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteCourse(String id) async {
    _setError(null);
    _setLoading(true);
    try {
      await _api.deleteCourse(id);
      _courses.removeWhere((c) => c.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void clearError() => _setError(null);
}
