import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../models/api_models/program_model.dart';
import '../models/api_models/course_model.dart';
import '../models/api_models/class_model.dart';

class StructureProvider extends ChangeNotifier {
  final ApiService _apiService;

  StructureProvider(this._apiService);
  ProgramResponse? _programDetail;
  ProgramResponse? get programDetail => _programDetail;
  CourseResponse? _courseDetail;
  CourseResponse? get courseDetail => _courseDetail;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  List<ClassModel> _classes = [];

  List<ClassModel> get classes => _classes;

  // /// Fetch all classes
  // Future<void> fetchClasses() async {
  //   _isLoading = true;
  //   _error = null;
  //   notifyListeners();
  //   try {
  //     _classes = await _apiService.getClasses();
  //   } catch (e) {
  //     _error = e.toString();
  //     debugPrint("Error fetching classes: $e");
  //   } finally {
  //     _isLoading = false;
  //     notifyListeners();
  //   }
  // }

  /// Create a class
  Future<ClassModel?> createClass(ClassRequest request) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final classModel = await _apiService.createClass(request);
      _classes = [..._classes, classModel];
      notifyListeners();
      return classModel;
    } catch (e) {
      _error = e.toString();
      debugPrint("Error creating class: $e");
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> getCourseDetailById(String courseId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _courseDetail = await _apiService.getCourseById(courseId);
    } catch (e) {
      _error = e.toString();
      debugPrint("Error fetching program detail: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // /// Get courses for a specific program
  Future<void> getProgramDetailById(String programId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _programDetail = await _apiService.getProgramById(programId);
    } catch (e) {
      _error = e.toString();
      debugPrint("Error fetching program detail: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a course to a program
  Future<bool> addCourseToProgram(
    String programId,
    ProgramCourseRequest request,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _apiService.createProgramCourse(programId, request);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint("Error adding course to program: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Remove a course from a program
  Future<bool> removeCourseFromProgram(
    String programId,
    String courseId,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _apiService.deleteProgramCourse(programId, courseId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint("Error removing course from program: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear all cached structure data (useful when switching orgs)
  void clearStructureData() {
    _classes = [];
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
