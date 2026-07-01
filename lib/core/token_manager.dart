// lib/core/token_manager.dart
//
// Centralized token storage for the whole app.
//
// This is the single source of truth for the access token, refresh token and
// current user id. It is intentionally backed by SharedPreferences using the
// SAME keys that AuthProvider already reads/writes ("access_token",
// "refresh_token", "user_id") so that the Dio interceptor (main.dart),
// AuthProvider, the legacy AuthService and the Live-Session SocketService all
// observe a consistent token state instead of each keeping their own copy.
//
// It is a singleton: calling `TokenManager()` anywhere returns the same
// instance, so transient flags such as `isRefreshing` / pending token are
// shared across the request interceptor and the rest of the app.

import 'package:shared_preferences/shared_preferences.dart';

class TokenManager {
  // ── Singleton ──────────────────────────────────────────────────────────
  TokenManager._internal();
  static final TokenManager _instance = TokenManager._internal();
  factory TokenManager() => _instance;

  // ── Storage keys (kept in sync with AuthProvider) ───────────────────────
  static const String _kAccessToken = 'access_token';
  static const String _kRefreshToken = 'refresh_token';
  static const String _kUserId = 'user_id';

  SharedPreferences? _prefs;

  // In-memory cache so synchronous-ish callers don't always hit disk.
  String? _accessToken;
  String? _refreshToken;
  String? _userId;

  // Refresh coordination flags (shared via the singleton).
  bool _isRefreshing = false;
  String? _pendingToken;

  bool get isRefreshing => _isRefreshing;
  void setRefreshing(bool value) => _isRefreshing = value;

  String? get pendingToken => _pendingToken;
  void setPendingToken(String? token) => _pendingToken = token;

  String? get userId => _userId;

  /// Must be awaited once at startup (see main.dart) before tokens are read.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _accessToken = _prefs?.getString(_kAccessToken);
    _refreshToken = _prefs?.getString(_kRefreshToken);
    _userId = _prefs?.getString(_kUserId);
  }

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  // ── Access token ─────────────────────────────────────────────────────────
  Future<String?> getToken() async {
    if (_accessToken != null && _accessToken!.isNotEmpty) return _accessToken;
    final prefs = await _ensurePrefs();
    _accessToken = prefs.getString(_kAccessToken);
    return _accessToken;
  }

  Future<void> setToken(String? token) async {
    _accessToken = token;
    final prefs = await _ensurePrefs();
    if (token == null || token.isEmpty) {
      await prefs.remove(_kAccessToken);
    } else {
      await prefs.setString(_kAccessToken, token);
    }
  }

  // ── Refresh token ─────────────────────────────────────────────────────────
  Future<String?> getRefreshToken() async {
    if (_refreshToken != null && _refreshToken!.isNotEmpty) return _refreshToken;
    final prefs = await _ensurePrefs();
    _refreshToken = prefs.getString(_kRefreshToken);
    return _refreshToken;
  }

  Future<void> setRefreshToken(String? token) async {
    _refreshToken = token;
    final prefs = await _ensurePrefs();
    if (token == null || token.isEmpty) {
      await prefs.remove(_kRefreshToken);
    } else {
      await prefs.setString(_kRefreshToken, token);
    }
  }

  // ── User id ────────────────────────────────────────────────────────────────
  Future<String?> getUserId() async {
    if (_userId != null && _userId!.isNotEmpty) return _userId;
    final prefs = await _ensurePrefs();
    _userId = prefs.getString(_kUserId);
    return _userId;
  }

  Future<void> setUserId(String? userId) async {
    _userId = userId;
    final prefs = await _ensurePrefs();
    if (userId == null || userId.isEmpty) {
      await prefs.remove(_kUserId);
    } else {
      await prefs.setString(_kUserId, userId);
    }
  }

  /// Clears all auth-related state (used on logout / unrecoverable 401).
  Future<void> clearToken() async {
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    _pendingToken = null;
    _isRefreshing = false;
    final prefs = await _ensurePrefs();
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
    await prefs.remove(_kUserId);
  }
}
