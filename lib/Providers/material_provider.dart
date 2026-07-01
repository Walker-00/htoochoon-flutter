import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/api_models/material_model.dart';

/// Course materials provider.
///
/// Uses the shared authenticated [Dio] directly (same instance that carries the
/// Bearer-token interceptor in main.dart) instead of the Retrofit ApiService —
/// this avoids regenerating api_service.g.dart for the three new endpoints.
class MaterialProvider extends ChangeNotifier {
  final Dio _dio;
  MaterialProvider(this._dio);

  // Per-class state so multiple class screens don't clobber each other.
  final Map<String, List<CourseMaterial>> _byClass = {};
  final Set<String> _loading = {};
  final Map<String, String?> _errors = {};
  bool _uploading = false;

  List<CourseMaterial> materials(String classId) => _byClass[classId] ?? const [];
  bool isLoading(String classId) => _loading.contains(classId);
  String? error(String classId) => _errors[classId];
  bool get isUploading => _uploading;

  Future<void> fetchMaterials(String classId, {bool refresh = false}) async {
    if (_loading.contains(classId)) return;
    if (!refresh && _byClass.containsKey(classId)) return;

    _loading.add(classId);
    _errors[classId] = null;
    notifyListeners();

    try {
      // Content now hangs off the course (the Class layer was removed); the
      // `classId` argument carries the courseId.
      final res = await _dio.get('/courses/$classId/materials');
      final list = (res.data as List)
          .map((e) => CourseMaterial.fromJson(e as Map<String, dynamic>))
          .toList();
      _byClass[classId] = list;
    } on DioException catch (e) {
      _errors[classId] = _msg(e);
      debugPrint('fetchMaterials error: ${e.message}');
    } catch (e) {
      _errors[classId] = 'Could not load materials';
      debugPrint('fetchMaterials error: $e');
    } finally {
      _loading.remove(classId);
      notifyListeners();
    }
  }

  /// Uploads a picked file. Returns the created material, or null on failure
  /// (with [error] populated for that class).
  Future<CourseMaterial?> uploadMaterial({
    required String classId,
    required PlatformFile file,
    String? title,
  }) async {
    _uploading = true;
    _errors[classId] = null;
    notifyListeners();

    try {
      final multipart = file.bytes != null
          ? MultipartFile.fromBytes(file.bytes!, filename: file.name)
          : await MultipartFile.fromFile(file.path!, filename: file.name);

      final form = FormData.fromMap({
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        'file': multipart,
      });

      final res = await _dio.post(
        '/courses/$classId/materials',
        data: form,
        // Override the default JSON content-type — Dio sets the multipart
        // boundary itself when given a FormData body.
        options: Options(contentType: 'multipart/form-data'),
      );

      final created =
          CourseMaterial.fromJson(res.data as Map<String, dynamic>);
      _byClass.putIfAbsent(classId, () => []).insert(0, created);
      return created;
    } on DioException catch (e) {
      _errors[classId] = _msg(e);
      debugPrint('uploadMaterial error: ${e.message}');
      return null;
    } catch (e) {
      _errors[classId] = 'Upload failed';
      debugPrint('uploadMaterial error: $e');
      return null;
    } finally {
      _uploading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteMaterial(String classId, String materialId) async {
    try {
      await _dio.delete('/materials/$materialId');
      _byClass[classId]?.removeWhere((m) => m.id == materialId);
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _errors[classId] = _msg(e);
      notifyListeners();
      return false;
    }
  }

  String _msg(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      return m is List ? m.join(', ') : m.toString();
    }
    return e.message ?? 'Request failed';
  }
}
