import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/log/app_logger.dart';

class SearchResults {
  final List<Map<String, dynamic>> courses;
  final List<Map<String, dynamic>> materials;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> assignments;
  final List<Map<String, dynamic>> messages;

  SearchResults({
    this.courses = const [],
    this.materials = const [],
    this.users = const [],
    this.assignments = const [],
    this.messages = const [],
  });

  bool get isEmpty =>
      courses.isEmpty &&
      materials.isEmpty &&
      users.isEmpty &&
      assignments.isEmpty &&
      messages.isEmpty;

  static List<Map<String, dynamic>> _l(dynamic v) =>
      ((v as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();

  factory SearchResults.fromJson(Map<String, dynamic> j) => SearchResults(
        courses: _l(j['courses']),
        materials: _l(j['materials']),
        users: _l(j['users']),
        assignments: _l(j['assignments']),
        messages: _l(j['messages']),
      );
}

/// Global search across courses/materials/people/assignments/messages.
/// Debounced by the UI; keeps a recent-search history in shared_preferences.
class SearchProvider extends ChangeNotifier {
  final Dio _dio;
  SearchProvider(this._dio);

  static const _kRecentKey = 'global_search_recent';
  final _log = const AppLog('SearchProvider');

  SearchResults? results;
  bool loading = false;
  Object? error;
  String query = '';
  String scope = 'all';
  List<String> recent = [];

  Timer? _debounce;

  Future<void> loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    recent = prefs.getStringList(_kRecentKey) ?? [];
    notifyListeners();
  }

  void onQueryChanged(String q) {
    query = q;
    _debounce?.cancel();
    if (q.trim().length < 2) {
      results = null;
      notifyListeners();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(q));
  }

  void setScope(String s) {
    scope = s;
    if (query.trim().length >= 2) _run(query);
    notifyListeners();
  }

  Future<void> _run(String q) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _dio.get('/search', queryParameters: {
        'q': q.trim(),
        'scope': scope,
        'limit': 20,
      });
      results = SearchResults.fromJson(Map<String, dynamic>.from(res.data));
      await _remember(q.trim());
    } catch (e) {
      error = e;
      _log.w('search failed', e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _remember(String q) async {
    if (q.isEmpty) return;
    recent.remove(q);
    recent.insert(0, q);
    if (recent.length > 8) recent = recent.sublist(0, 8);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentKey, recent);
  }

  Future<void> clearRecent() async {
    recent = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRecentKey);
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
