import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Screens/AuthScreens/login_screen.dart';
import 'package:htoochoon_flutter/Screens/AuthScreens/otp_screen.dart';
import 'package:htoochoon_flutter/Screens/MainLayout/main_scaffold.dart';
import 'package:htoochoon_flutter/Screens/Onboarding/onboarding_screen.dart';
import 'package:htoochoon_flutter/core/token_manager.dart';
import 'package:htoochoon_flutter/core/userorgrole_manager.dart';
import 'package:htoochoon_flutter/Live-Session/core/services/socket_service.dart';
import 'package:htoochoon_flutter/Live-Session/core/services/push_service.dart';
import 'package:htoochoon_flutter/Live-Session/core/services/local_notification_service.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:htoochoon_flutter/models/auth/auth_model.dart';
import '../api/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuthStatus { unauthenticated, authenticated, needsOtp }

enum RegisterResult { success, error }

enum LoginResult { success, needsOtp, error }

class AuthProvider extends ChangeNotifier {
  final ApiService apiService;
  final Dio dio;
  AuthProvider(this.apiService, this.dio) {
    loadUserFromPrefs();
  }
  String? _otpEmail;
  String? get otpEmail => _otpEmail;

  /// Last human-readable auth error (login/register), for the UI to show.
  String? _authError;
  String? get authError => _authError;

  /// Turn any thrown error into a clear, actionable message for the user.
  /// Prefers the backend's `message`; falls back to status-code / network
  /// specific copy so the user knows what went wrong and what to do.
  String _friendlyError(Object e, {required bool isRegister}) {
    if (e is DioException) {
      // Backend-supplied message wins — filters now return meaningful text.
      final data = e.response?.data;
      String? backendMsg;
      if (data is Map && data["message"] != null) {
        final m = data["message"];
        backendMsg = m is List ? m.join(" • ") : m.toString();
      } else if (data is String && data.trim().isNotEmpty) {
        backendMsg = data.trim();
      }
      if (backendMsg != null && backendMsg.isNotEmpty) return backendMsg;

      // No body — infer from status / connection state.
      final code = e.response?.statusCode;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return "The server took too long to respond. Check your connection and try again.";
        case DioExceptionType.connectionError:
          return "Can't reach the server. Check your internet connection and try again.";
        default:
          break;
      }
      if (code == 401) {
        return "Incorrect email or password. Please check and try again.";
      }
      if (code == 409) {
        return "An account with this email already exists. Try logging in instead.";
      }
      if (code == 429) {
        return "Too many attempts. Please wait a moment and try again.";
      }
      if (code != null && code >= 500) {
        return "Something went wrong on our end. Please try again in a moment — if it keeps happening, contact support.";
      }
      return isRegister
          ? "Couldn't create your account. Please check your details and try again."
          : "Couldn't sign you in. Please check your details and try again.";
    }
    return isRegister
        ? "Couldn't create your account. Please try again."
        : "Couldn't sign you in. Please try again.";
  }
  AuthStatus _status = AuthStatus.unauthenticated;
  AuthStatus get status => _status;
  bool _isLoading = false;
  String? _accessToken;
  String? _refreshToken;
  User? _user;

  String? _userId;
  bool get isLoading => _isLoading;
  String? get accessToken => _accessToken;
  User? get user => _user;
  bool _initialized = false;
  bool get initialized => _initialized;
  String? get userId => _userId;
  Role? getRoleInOrg(String orgId) {
    final membership = user?.memberships?.firstWhere(
      (m) => m.organization.id == orgId,
    );
    return membership?.role;
  }

  /// =========================
  /// LOAD USER FROM STORAGE
  /// =========================
  Future<void> loadUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    _accessToken = prefs.getString("access_token");

    final userString = prefs.getString("user");

    if (userString != null) {
      try {
        final json = jsonDecode(userString);
        _user = User.fromJson(json);
        UserSessionManager.setUser(_user!);
      } catch (e) {
        debugPrint("Failed to parse cached user: $e");
        _user = null;
      }
    }

    _status = (_accessToken != null && _accessToken!.isNotEmpty)
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;

    _initialized = true;
    notifyListeners();
  }

  Future<User> loadMe() async {
    try {
      _isLoading = true;
      // 💡 Remove notifyListeners() from here to stop premature navigation resets

      final user = await apiService.getMe();
      _user = user;
      _userId = user.id;
      UserSessionManager.setUser(user);

      await saveUserToPrefs(user, accessToken: _accessToken);

      // Ask for OS notification permission once we're authenticated (the OS
      // only prompts once ever). Fire-and-forget — never blocks the load.
      LocalNotificationService.instance.requestPermission();
      return user;
    } catch (e) {
      debugPrint("Register Error: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners(); // ✅ Keep this to inform UI blocks that data is ready
    }
  }

  Future<User?> loadUserById(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = await apiService.getUser(userId);
      // _user = user;
      return user;
    } catch (e) {
      logD(e);
    }
  }

  // Future<void> saveUserToPrefs(User user, {String? accessToken}) async {
  //   final prefs = await SharedPreferences.getInstance();
  //
  //   if (accessToken != null) {
  //     await prefs.setString("access_token", accessToken);
  //   }
  //
  //   final dataMap = {
  //     "id": user.id.toString(),
  //     "email": user.email ?? '',
  //     "googleId": user.googleId ?? '',
  //     "name": user.name ?? '',
  //     "role": user.role ?? '',
  //     "isActive": user.isActive ?? false,
  //     "isTwoFactorEnabled": user.isTwoFactorEnabled ?? false,
  //     "twoFactorSecret": user.twoFactorSecret ?? '',
  //     "createdAt": user.createdAt?.toIso8601String() ?? '',
  //     "updatedAt": user.updatedAt?.toIso8601String() ?? '',
  //   };
  //
  //   for (final entry in dataMap.entries) {
  //     final key = entry.key;
  //     final value = entry.value;
  //
  //     if (value is String) {
  //       await prefs.setString(key, value);
  //     } else if (value is bool) {
  //       await prefs.setBool(key, value);
  //     } else {
  //       logD("Skipping unsupported type for key: $key");
  //     }
  //   }
  // }
  Future<void> saveUserToPrefs(User user, {String? accessToken}) async {
    final prefs = await SharedPreferences.getInstance();

    if (accessToken != null) {
      await prefs.setString("access_token", accessToken);
    }

    await prefs.setString("user", jsonEncode(user.toJson()));
  }

  /// =========================
  /// REGISTER
  /// =========================
  Future<RegisterResult> register(
    RegisterRequest request,
    BuildContext context,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      _authError = null;
      final response = await apiService.register(request);
      _otpEmail = request.email;
      _status = AuthStatus.needsOtp;

      return RegisterResult.success;
    } catch (e) {
      debugPrint("Register Error: $e");
      _authError = _friendlyError(e, isRegister: true);
      return RegisterResult.error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// =========================
  /// REQUEST OTP
  /// =========================
  Future<RequestOtpResponse?> requestOtp(RequestOtpRequest request) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await apiService.requestOtp(request);
      _isLoading = false;
      notifyListeners();
      logD("OTP requested successfully");
      return response;
    } catch (e) {
      debugPrint("Request OTP Error: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Request OTP without changing loading state (for internal use)
  Future<RequestOtpResponse?> requestOtpSilent(
    RequestOtpRequest request,
  ) async {
    try {
      final response = await apiService.requestOtp(request);
      return response;
    } catch (e) {
      debugPrint("Request OTP Silent Error: $e");
      rethrow;
    }
  }

  /// =========================
  /// VERIFY OTP
  /// =========================
  Future<bool> verifyOtp(VerifyOtpRequest request, BuildContext context) async {
    try {
      logD("login provider: verify beginning trying");
      _isLoading = true;
      notifyListeners();
      logD("login provider: trying to send apiservice.verifyrq");
      final response = await apiService.verifyOtp(request);
      logD("login provider: verify ok");
      _status = AuthStatus.authenticated;

      return true;
    } catch (e) {
      debugPrint("Verify OTP Error: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// =========================
  /// LOGIN
  /// =========================
  // Future<LoginStatus> login(LoginRequest request, BuildContext context) async {
  //   _isLoading = true;
  //   notifyListeners();
  //
  //   try {
  //     logD("Auth_provider: login called");
  //
  //     // 1. Call API
  //     final loginResponse = await apiService.login(request);
  //
  //     // 2. Save user & token
  //     _accessToken = loginResponse.access_token.toString();
  //     _user = loginResponse.data;
  //
  //     await saveUserToPrefs(_user!, accessToken: _accessToken);
  //
  //     logD("Login success");
  //
  //     return LoginStatus.success;
  //   } on DioException catch (e) {
  //     final data = e.response?.data;
  //
  //     String message = '';
  //
  //     if (data is Map && data['message'] != null) {
  //       message = data['message'].toString();
  //     } else if (data is String) {
  //       message = data;
  //     } else {
  //       message = e.message ?? 'Login failed';
  //     }
  //
  //     logD("Login error message: $message");
  //
  //     final normalized = message.toLowerCase().trim();
  //
  //     // 3. OTP CASE (Email not verified)
  //     if (normalized.contains('email not verified') ||
  //         normalized.contains('user is not active')) {
  //       logD("OTP flow triggered");
  //
  //       try {
  //         await requestOtpSilent(
  //           RequestOtpRequest(email: request.email, action: "VERIFY_EMAIL"),
  //         );
  //
  //         logD("OTP requested successfully");
  //       } catch (otpError) {
  //         logD("OTP request failed: $otpError");
  //         // continue anyway
  //       }
  //
  //       return LoginStatus.otpRequired;
  //     }
  //
  //     // 4. OTHER FAILURES
  //     return LoginStatus.failed;
  //   } catch (e) {
  //     logD("Unexpected login error: $e");
  //     return LoginStatus.failed;
  //   } finally {
  //     _isLoading = false;
  //     notifyListeners();
  //   }
  // }
  String? _memoryToken;
  String? get memoryToken => _memoryToken;
  // Future<void> testLogin(LoginRequest request) async {
  //   logD("testing login");
  //   try {
  //     final response = await apiService.login(request);
  //
  //     logD("✅ STATUS CODE: ${response.data}");
  //     logD("🔥 RAW LOGIN RESPONSE: ${response.data}");
  //
  //     if (response.data is Map<String, dynamic>) {
  //       logD("🔑 ACCESS TOKEN: ${response.access_token}");
  //       logD("👤 USER: ${response.access_token}");
  //     }
  //   } on DioException catch (e) {
  //     logD("❌ LOGIN FAILED");
  //
  //     logD("STATUS: ${e.response?.statusCode}");
  //     logD("ERROR DATA: ${e.response?.data}");
  //     logD("ERROR MESSAGE: ${e.message}");
  //
  //     if (e.response?.data is Map) {
  //       logD("PARSED ERROR: ${e.response?.data['message']}");
  //     }
  //   } catch (e) {
  //     logD("💥 UNKNOWN ERROR: $e");
  //   }
  // }

  Future<LoginResult> login(LoginRequest request) async {
    try {
      _isLoading = true;
      notifyListeners();

      final loginResponse = await apiService.login(request);

      logD("✅ LOGIN RESPONSE: ${loginResponse.toJson()}");
      logD("✅ ACCESS TOKEN:  ${loginResponse.access_token}");
      logD("✅ USER:          ${loginResponse.data}");

      _memoryToken = _accessToken;

      _accessToken = loginResponse.access_token;
      _refreshToken = loginResponse.refresh_token;
      await TokenManager().setUserId(userId);
      await TokenManager().setToken(_accessToken);
      await TokenManager().setRefreshToken(_refreshToken);
      // Re-init the shared socket so it (re)connects authenticated as this user.
      await SocketService().initSocket();

      _user = loginResponse.data;
      _userId = loginResponse.data.id;

      _status = AuthStatus.authenticated;
      final userInfo = await apiService.getUser(
        loginResponse.data.id.toString(),
      );
      _user = userInfo;
      _userId = userInfo.id;
      UserSessionManager.setUser(userInfo);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("user_id", userInfo.id);
      await saveUserToPrefs(userInfo, accessToken: _accessToken);
      _status = AuthStatus.authenticated;
      _isLoading = false;
      notifyListeners();

      logD("printing access token from auth provider: ${_accessToken}");

      logD("Auth Provider: login result is sucess");
      return LoginResult.success;
    } catch (e) {
      _authError = _friendlyError(e, isRegister: false);
      if (e is DioException) {
        final data = e.response?.data;

        String? message;
        if (data is Map) {
          message = data["message"];
          logD("message${message}");
        } else if (data is String) {
          message = data;
          logD("message${message}");
        }

        if (e is DioException) {
          final data = e.response?.data;

          logD("DIO DATA: $data");

          String? message;

          if (data is Map) {
            message = data["message"]?.toString();
          } else if (data is String) {
            message = data;
          }

          logD("Parsed message: $message");

          if (message != null) {
            final normalized = message.trim().toLowerCase();

            if (normalized.contains("not verified") ||
                normalized.contains("not active")) {
              try {
                await requestOtpSilent(
                  RequestOtpRequest(
                    email: request.email,
                    action: "VERIFY_EMAIL",
                  ),
                );

                _otpEmail = request.email;
                _status = AuthStatus.needsOtp;
                _authError = null; // not an error — routing to verification

                _isLoading = false;
                notifyListeners();

                return LoginResult.needsOtp;
              } catch (e) {
                logD("ERROR TYPE: ${e.runtimeType}");

                if (e is DioException) {
                  logD("STATUS: ${e.response?.statusCode}");
                  logD("HEADERS: ${e.response?.headers}");
                  logD("RAW RESPONSE: ${e.response}");
                  logD("DATA: ${e.response?.data}");
                } else {
                  logD("UNKNOWN ERROR: $e");
                }

                _isLoading = false;
                notifyListeners();
                return LoginResult.error;
              }
            }
          }
        }
      }

      _isLoading = false;
      notifyListeners();

      return LoginResult.error;
    }
  }

  /// =========================
  /// RESET PASSWORD
  /// =========================
  Future<ResetPasswordResponse?> resetPassword(
    ResetPasswordRequest request,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await apiService.resetPassword(request);

      return response;
    } catch (e) {
      debugPrint("Reset Password Error: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// =========================
  /// CHANGE PASSWORD
  /// =========================
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final id = _userId ?? _user?.id;
    if (id == null) {
      throw Exception('Not authenticated');
    }
    try {
      _isLoading = true;
      notifyListeners();

      await apiService.changePassword(id, {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
    } catch (e) {
      debugPrint("Change Password Error: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// =========================
  /// LOGOUT
  /// =========================
  Future<void> logout() async {
    // Drop this device's push token server-side while the auth header is still
    // valid, so push doesn't follow the next account that logs in here.
    await PushService.instance.unregisterToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("access_token");
    await prefs.remove("refresh_token");
    await prefs.remove("user");
    await prefs.remove("user_id");
    UserSessionManager.clear();
    await TokenManager().clearToken(); // clears access + refresh + userId
    SocketService().dispose();         // disconnect + drop listeners/callbacks
    _accessToken = null;
    _user = null;
    _userId = null;

    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// =========================
  /// UPDATE USER
  /// =========================
  /// Uploads profile picture and syncs internal user model data fields cleanly
  Future<bool> uploadProfilePicture(String userId, XFile pickedFile) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Prepare multi-part package binary
      final multipartFile = await MultipartFile.fromFile(
        pickedFile.path,
        filename: pickedFile.name,
      );

      // 2. Dispatch network update task
      final response = await apiService.uploadUserProfile(
        userId,
        multipartFile,
      );

      debugPrint("Server feedback message: ${response.message}");

      // 3. CRITICAL STEP: Fetch the profile to get the new avatar layout fields
      await loadMe();
      logD("Load you called from auth provider");

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Retrofit network stream profile upload error: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateUser(String id, Map<String, dynamic> updates) async {
    try {
      _isLoading = true;
      notifyListeners();

      final updatedUser = await apiService.updateUser(id, updates);
      _user = updatedUser;
      await saveUserToPrefs(updatedUser);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint("Update User Error: $e");
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}
