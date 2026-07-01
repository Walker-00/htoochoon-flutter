import 'dart:io';

import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/core/userorgrole_manager.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_service.dart';
import '../models/api_models/user_model.dart';
import '../models/api_models/enums.dart';

// import '../models/auth/auth_model.dart' show User;
//
// class UserProvider extends ChangeNotifier {
//   final ApiService _apiService;
//
//   UserProvider(this._apiService);
//
//   UserResponse? _userData;
//   bool _isLoading = false;
//   String? _error;
//
//   UserResponse? get userData => _userData;
//   bool get isLoading => _isLoading;
//   String? get error => _error;
//
//   /// Fetches the current user from the API
//   Future<UserResponse?> fetchMe() async {
//     _isLoading = true;
//     _error = null;
//     notifyListeners();
//     try {
//       final user = await _apiService.fetchMe();
//       _userData = _userToResponse(user);
//       await _cacheUserData(_userData!);
//       _isLoading = false;
//       notifyListeners();
//       return _userData;
//     } catch (e) {
//       _error = e.toString();
//       _isLoading = false;
//       notifyListeners();
//       debugPrint("Error fetching user: $e");
//       return null;
//     }
//   }
//
//   /// Convert User (auth_model) to UserResponse (api_models)
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
//   /// Fetch a specific user by ID
//   Future<UserResponse?> getUserById(String id) async {
//     _isLoading = true;
//     _error = null;
//     notifyListeners();
//     try {
//       final user = await _apiService.getUser(id);
//
//       UserSessionManager.setUser(user);
//       _isLoading = false;
//       notifyListeners();
//       return _userToResponse(user);
//     } catch (e) {
//       _error = e.toString();
//       _isLoading = false;
//       notifyListeners();
//       debugPrint("Error fetching user by ID: $e");
//       return null;
//     }
//   }
//
//   /// Update user profile
//   Future<bool> updateProfile({String? name, String? email}) async {
//     _isLoading = true;
//     _error = null;
//     notifyListeners();
//     try {
//       if (_userData == null) throw Exception("No user data available");
//
//       final updates = <String, dynamic>{};
//
//       if (name != null) updates['name'] = name;
//       if (email != null) updates['email'] = email;
//
//       if (updates.isNotEmpty) {
//         final updated = await _apiService.updateUser(_userData!.id, updates);
//         _userData = UserResponse(
//           id: updated.id,
//           email: updated.email,
//           name: updated.name,
//           role: roleFromString(updated.role),
//           isActive: updated.isActive,
//           isTwoFactorEnabled: updated.isTwoFactorEnabled,
//           createdAt: updated.createdAt,
//           updatedAt: updated.updatedAt,
//         );
//         await _cacheUserData(_userData!);
//       }
//
//       _isLoading = false;
//       notifyListeners();
//       return true;
//     } catch (e) {
//       _error = e.toString();
//       _isLoading = false;
//       notifyListeners();
//       debugPrint("Error updating profile: $e");
//       return false;
//     }
//   }
//
//   /// Update profile photo (requires backend endpoint for file upload)
//   Future<bool> updateProfilePhoto(File imageFile) async {
//     _isLoading = true;
//     _error = null;
//     notifyListeners();
//     try {
//       if (_userData == null) throw Exception("No user data available");
//
//       // TODO: Implement file upload to backend
//       // This would typically use a multipart form upload endpoint
//       // final response = await _apiService.uploadProfilePhoto(imageFile);
//       // _userData = _userData!.copyWith(photoUrl: response.photoUrl);
//
//       _isLoading = false;
//       notifyListeners();
//       return true;
//     } catch (e) {
//       _error = e.toString();
//       _isLoading = false;
//       notifyListeners();
//       debugPrint("Error updating profile photo: $e");
//       return false;
//     }
//   }
//
//   /// Caches critical user data to SharedPreferences
//   Future<void> _cacheUserData(UserResponse data) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('uid', data.id);
//     await prefs.setString('userName', data.name);
//     await prefs.setString('userEmail', data.email);
//     await prefs.setString('userRole', data.role.name);
//   }
//
//   /// Load user from shared preferences
//   Future<UserResponse?> loadUserFromPrefs() async {
//     final prefs = await SharedPreferences.getInstance();
//     final id = prefs.getString("uid");
//     if (id == null || id.isEmpty) return null;
//     // Reading from SharedPreferences
//     final roleString = prefs.getString("userRole");
//     final role = roleString != null
//         ? Role.values.firstWhere(
//             (r) => r.name == roleString,
//             orElse: () => Role.STUDENT, // default role
//           )
//         : Role.STUDENT;
//     _userData = UserResponse(
//       id: id,
//       email: prefs.getString("userEmail") ?? '',
//       name: prefs.getString("userName") ?? '',
//       role: role,
//       isActive: true,
//       isTwoFactorEnabled: false,
//       createdAt: DateTime.now(),
//       updatedAt: DateTime.now(),
//     );
//     notifyListeners();
//     return _userData;
//   }
//
//   /// Clear user data (on logout)
//   Future<void> clearUser() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.clear();
//     _userData = null;
//     notifyListeners();
//   }
//
//   void clearError() {
//     _error = null;
//     notifyListeners();
//   }
// }
