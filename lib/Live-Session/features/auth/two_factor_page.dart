import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart'; // v9.3.0
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/services/socket_service.dart';
import '../../models/user_model.dart';
import 'package:htoochoon_flutter/core/token_manager.dart';

class TwoFactorPage extends StatefulWidget {
  final String email;
  final Function(UserModel) onVerified;

  const TwoFactorPage({
    super.key,
    required this.email,
    required this.onVerified,
  });

  @override
  State<TwoFactorPage> createState() => _TwoFactorPageState();
}

class _TwoFactorPageState extends State<TwoFactorPage> {
  // New Controller for v9
  final PinInputController _pinController = PinInputController();
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://backend.htoochoon.com'));
  final _storage = const FlutterSecureStorage();

  bool _loading = false;
  String? _errorMessage;

  void _verifyCode() async {
    final code = _pinController.text;
    if (code.length != 6) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response = await _dio.post('/auth/2fa/verify-login', data: {
        'email': widget.email,
        'code': code,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        // Persist to the SAME store the REST interceptor + socket handshake read
        // (TokenManager → SharedPreferences). Writing to FlutterSecureStorage
        // here left the socket unauthenticated. Keep the secure-storage write too
        // for any legacy reader, but TokenManager is the source of truth.
        await _storage.write(key: 'access_token', value: data['accessToken']);
        await _storage.write(key: 'refresh_token', value: data['refreshToken']);
        await TokenManager().setToken(data['accessToken'] as String?);
        await TokenManager().setRefreshToken(data['refreshToken'] as String?);

        // Shared singleton socket — reconnects with the fresh JWT.
        await SocketService().initSocket();

        widget.onVerified(UserModel.fromJson(data['user']));
      }
    } on DioException catch (e) {
      // Trigger the new shake error animation in v9!
      _pinController.triggerError();
      setState(() {
        _errorMessage = e.response?.data['message'] ?? 'Invalid code~ 💦';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification 🔐')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Enter 6-digit code', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 32),

            // ✅ New v9 Widget
            MaterialPinField(
              length: 6,
              pinController: _pinController,
              onCompleted: (pin) => _verifyCode(),
              onChanged: (value) => setState(() => _errorMessage = null),
              theme: MaterialPinTheme(
                shape: MaterialPinShape.outlined,
                cellSize: const Size(48, 56),
                borderRadius: BorderRadius.circular(12),
                focusedBorderColor: Theme.of(context).colorScheme.primary,
                errorColor: Colors.red,
              ),
            ),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ),

            const SizedBox(height: 40),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _verifyCode,
              child: const Text('Verify ✨'),
            ),
          ],
        ),
      ),
    );
  }
}