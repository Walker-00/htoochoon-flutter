import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/'));
  final _storage = const FlutterSecureStorage();

  AuthService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        String? token = await _storage.read(key: 'access_token');
        options.headers['Authorization'] = 'Bearer $token';
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          // Token expired, try to refresh
          String? refreshToken = await _storage.read(key: 'refresh_token');
          if (refreshToken != null) {
            try {
              final res = await _dio.post('/auth/refresh', data: {'refresh': refreshToken});
              final newAccess = res.data['access_token'];
              await _storage.write(key: 'access_token', value: newAccess);

              // Retry the original request
              e.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
              final retryRes = await _dio.fetch(e.requestOptions);
              return handler.resolve(retryRes);
            } catch (err) {
              await logout();
            }
          }
        }
        return handler.next(e);
      },
    ));
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    await _storage.write(key: 'access_token', value: response.data['accessToken']);
    await _storage.write(key: 'refresh_token', value: response.data['refreshToken']);
    return response.data;
  }

  Future<void> logout() async {
    await _storage.deleteAll();

  }
}