import 'package:dio/dio.dart';
import 'package:htoochoon_flutter/core/token_manager.dart';

class AuthService {
  final Dio dio;
  final TokenManager tokenManager;

  AuthService(this.dio, this.tokenManager);

  Future<String?> refreshAccessToken(String userId) async {
    try {
      final refreshToken = await tokenManager.getRefreshToken();

      final response = await dio.post(
        "/auth/refresh",
        data: {"userId": userId, "refresh_token": refreshToken},
      );

      final newAccessToken = response.data["access_token"];
      await tokenManager.setToken(newAccessToken);
      final newRefreshToken = response.data["refresh_token"];
      await tokenManager.setToken(newRefreshToken);
      return newAccessToken;
    } catch (e) {
      await tokenManager.clearToken();
      return null;
    }
  }
}
