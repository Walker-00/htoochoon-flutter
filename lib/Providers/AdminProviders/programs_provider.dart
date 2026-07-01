import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/api/api_service.dart';
import 'package:htoochoon_flutter/models/api_models/program_model.dart';

///THESE PROGRAMS ARE FOR IN ORG AND ALL (NOT FILTERED FOR ENROLLED BY USRER)
class ProgramsProvider extends ChangeNotifier {
  final ApiService _api;
  VoidCallback? onLimitReached;
  void _handleLimitReached(String message) {
    onLimitReached?.call();
  }

  ProgramsProvider(this._api);

  bool _isLoading = false;
  String? _error;
  List<ProgramResponse> _programs = [];
  List<ProgramResponse> _allPrograms = [];
  List<ProgramResponse> _programsInOrg = [];
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<ProgramResponse> get programs => _programs;

  List<ProgramResponse> get programsInOrg => _programsInOrg;
  List<ProgramResponse> get allPrograms => _allPrograms;
  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String? e) {
    _error = e;
    notifyListeners();
  }

  List<ProgramResponse> searchPrograms(String query) {
    return _allPrograms.where((program) {
      return query.isEmpty ||
          program.name.toLowerCase().contains(query.toLowerCase()) ||
          (program.description?.toLowerCase().contains(query.toLowerCase()) ??
              false);
    }).toList();
  }

  Future<void> fetchAllPrograms() async {
    _setError(null);
    _setLoading(true);

    notifyListeners();
    try {
      _allPrograms = await _api.getPrograms(null, null);
      _setError(null);
    } catch (e) {
      _error = e.toString();
      debugPrint("Error fetching all programs: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchProgramsInOrgId(String organisationId) async {
    _setError(null);
    _setLoading(true);

    try {
      final rawList = await _api.getPrograms(null, organisationId);
      logD('🔍 Fetching programs for org: $organisationId');
      // logD('📡 Response: ${rawList.data}');
      _programs = rawList;
      _setError(null);
    } catch (e, stack) {
      debugPrint("FULL ERROR: $e");
      debugPrint("STACK: $stack");
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

  Future<bool> createProgram(ProgramRequest request) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      final created = await _api.createProgram(request);

      final full = await _api.getProgramById(created.id);
      _programs.add(full);

      return true;
    } catch (e) {
      final errorMessage = _extractError(e);

      _error = errorMessage;

      if (errorMessage.contains('limit reached')) {
        _handleLimitReached(errorMessage);
      }

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProgram(String id, ProgramRequest request) async {
    _setError(null);
    _setLoading(true);
    try {
      final updated = await _api.updateProgram(id, request);
      final idx = _programs.indexWhere((p) => p.id == id);
      if (idx != -1) {
        _programs[idx] = updated;
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

  Future<bool> deleteProgram(String id) async {
    _setLoading(true);
    _setError(null);
    try {
      await _api.deleteProgram(id);
      _programs.removeWhere((p) => p.id == id);
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
