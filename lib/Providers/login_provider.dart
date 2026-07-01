// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../api/api_service.dart';
// import '../models/auth/auth_model.dart';
// import '../models/api_models/user_model.dart';
// import '../models/api_models/enums.dart';
//
// class LoginProvider extends ChangeNotifier {
//   final ApiService _apiService;
//
//   LoginProvider(this._apiService);
//
//   bool _isLoading = false;
//   String? _errorMessage;
//   UserResponse? _user;
//
//   bool get isLoading => _isLoading;
//   String? get errorMessage => _errorMessage;
//   UserResponse? get user => _user;
//   UserResponse? get userData => _user; // Alias for compatibility
//
//   /// Convert User (from auth auth_model) to UserResponse (from api_models)
//   UserResponse _userToResponse(User user) {
//     Role role;
//     try {
//       role = Role.values.firstWhere(
//         (e) => e.name.toUpperCase() == (user.role ?? '').toUpperCase(),
//         orElse: () => Role.ADMIN,
//       );
//     } catch (_) {
//       role = Role.ADMIN;
//     }
//     return UserResponse(
//       id: user.id,
//       email: user.email,
//       name: user.name,
//       role: role,
//       isActive: user.isActive,
//       isTwoFactorEnabled: user.isTwoFactorEnabled,
//       createdAt: user.createdAt,
//       updatedAt: user.updatedAt,
//     );
//   }
//
//   /// Login with email/password
//   Future<LoginResponse?> loginWithEmail(String email, String password) async {
//     _isLoading = true;
//     _errorMessage = null;
//     notifyListeners();
//     try {
//       final response = await _apiService.login(
//         LoginRequest(email: email, password: password),
//       );
//       _user = _userToResponse(response.data);
//       await _saveUserToPrefs(
//         _user!,
//         accessToken: response.access_token.access_token,
//       );
//       _isLoading = false;
//       notifyListeners();
//       return response;
//     } catch (e) {
//       _errorMessage = e.toString();
//       _isLoading = false;
//       notifyListeners();
//       debugPrint("Login Error: $e");
//       rethrow;
//     }
//   }
//
//   /// Register a new user
//   Future<RegisterResponse?> register(
//     String email,
//     String password,
//     String name,
//   ) async {
//     _isLoading = true;
//     _errorMessage = null;
//     notifyListeners();
//     try {
//       final response = await _apiService.register(
//         RegisterRequest(email: email, password: password, name: name),
//       );
//       _isLoading = false;
//       notifyListeners();
//       return response;
//     } catch (e) {
//       _errorMessage = e.toString();
//       _isLoading = false;
//       notifyListeners();
//       debugPrint("Register Error: $e");
//       rethrow;
//     }
//   }
//
//   /// Request OTP
//   Future<RequestOtpResponse?> requestOtp(String email, String action) async {
//     _isLoading = true;
//     _errorMessage = null;
//     notifyListeners();
//     try {
//       final response = await _apiService.requestOtp(
//         RequestOtpRequest(email: email, action: action),
//       );
//       _isLoading = false;
//       notifyListeners();
//       return response;
//     } catch (e) {
//       _errorMessage = e.toString();
//       _isLoading = false;
//       notifyListeners();
//       debugPrint("Request OTP Error: $e");
//       rethrow;
//     }
//   }
//
//   /// Verify OTP
//   Future<VerifyOtpResponse?> verifyOtp(
//     String email,
//     String action,
//     String otp,
//   ) async {
//     _isLoading = true;
//     _errorMessage = null;
//     notifyListeners();
//     try {
//       final response = await _apiService.verifyOtp(
//         VerifyOtpRequest(email: email, action: action, otp: otp),
//       );
//       _isLoading = false;
//       notifyListeners();
//       return response;
//     } catch (e) {
//       _errorMessage = e.toString();
//       _isLoading = false;
//       notifyListeners();
//       debugPrint("Verify OTP Error: $e");
//       rethrow;
//     }
//   }
//
//   /// Reset password
//   Future<ResetPasswordResponse?> resetPassword(
//     String email,
//     String action,
//     String otp,
//     String newPassword,
//   ) async {
//     _isLoading = true;
//     _errorMessage = null;
//     notifyListeners();
//     try {
//       final response = await _apiService.resetPassword(
//         ResetPasswordRequest(
//           email: email,
//           action: action,
//           otp: otp,
//           newPassword: newPassword,
//         ),
//       );
//       _isLoading = false;
//       notifyListeners();
//       return response;
//     } catch (e) {
//       _errorMessage = e.toString();
//       _isLoading = false;
//       notifyListeners();
//       debugPrint("Reset Password Error: $e");
//       rethrow;
//     }
//   }
//
//   /// Fetch current user profile
//   Future<UserResponse?> fetchMe() async {
//     _isLoading = true;
//     _errorMessage = null;
//     notifyListeners();
//     try {
//       final user = await _apiService.fetchMe();
//       _user = _userToResponse(user);
//       _isLoading = false;
//       notifyListeners();
//       return _user;
//     } catch (e) {
//       _errorMessage = e.toString();
//       _isLoading = false;
//       notifyListeners();
//       debugPrint("Fetch Me Error: $e");
//       return null;
//     }
//   }
//
//   /// Logout
//   Future<void> logout() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.clear();
//     _user = null;
//     notifyListeners();
//   }
//
//   /// Save user to shared preferences
//   Future<void> _saveUserToPrefs(UserResponse user, {String? accessToken}) async {
//     final prefs = await SharedPreferences.getInstance();
//     if (accessToken != null) {
//       await prefs.setString("access_token", accessToken);
//     }
//     await prefs.setString("id", user.id);
//     await prefs.setString("email", user.email);
//     await prefs.setString("name", user.name);
//     await prefs.setString("role", user.role.name);
//     await prefs.setBool("isActive", user.isActive);
//     await prefs.setBool("isTwoFactorEnabled", user.isTwoFactorEnabled);
//     await prefs.setString("createdAt", user.createdAt.toIso8601String());
//     await prefs.setString("updatedAt", user.updatedAt.toIso8601String());
//   }
//
//   /// Load user from shared preferences
//   Future<UserResponse?> loadUserFromPrefs() async {
//     final prefs = await SharedPreferences.getInstance();
//     final token = prefs.getString("access_token");
//     final id = prefs.getString("id");
//     if (token == null || id == null || id.isEmpty) return null;
//
//     final roleStr = prefs.getString("role") ?? 'ADMIN';
//     Role role;
//     try {
//       role = Role.values.firstWhere((e) => e.name.toUpperCase() == roleStr.toUpperCase(), orElse: () => Role.ADMIN);
//     } catch (_) {
//       role = Role.ADMIN;
//     }
//
//     _user = UserResponse(
//       id: id,
//       email: prefs.getString("email") ?? '',
//       name: prefs.getString("name") ?? '',
//       role: role,
//       isActive: prefs.getBool("isActive") ?? false,
//       isTwoFactorEnabled: prefs.getBool("isTwoFactorEnabled") ?? false,
//       createdAt: DateTime.tryParse(prefs.getString("createdAt") ?? '') ?? DateTime.now(),
//       updatedAt: DateTime.tryParse(prefs.getString("updatedAt") ?? '') ?? DateTime.now(),
//     );
//     notifyListeners();
//     return _user;
//   }
//
//   void clearError() {
//     _errorMessage = null;
//     notifyListeners();
//   }
// }
