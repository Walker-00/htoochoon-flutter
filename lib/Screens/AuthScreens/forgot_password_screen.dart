import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:htoochoon_flutter/Providers/auth_provider.dart';
import 'package:htoochoon_flutter/models/auth/auth_model.dart';

/// Single-screen forgot-password flow.
///
/// Step 1: enter email -> request a RESET_PASSWORD OTP.
/// Step 2: reveal OTP + new-password fields -> reset the password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const String _action = 'RESET_PASSWORD';

  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _codeSent = false;
  bool _sending = false;
  bool _resetting = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) {
      _emailCtrl.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  bool _looksLikeEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!_looksLikeEmail(email)) {
      _snack('Please enter a valid email address.', error: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await context.read<AuthProvider>().requestOtp(
        RequestOtpRequest(email: email, action: _action),
      );
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _sending = false;
      });
      _snack('We sent a reset code to $email.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      final msg = e.toString().toLowerCase();
      _snack(
        msg.contains('not found') || msg.contains('404')
            ? 'No account found for that email.'
            : 'Could not send the code. Please try again.',
        error: true,
      );
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    final otp = _otpCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (otp.isEmpty) {
      _snack('Enter the code we sent you.', error: true);
      return;
    }
    if (password.length < 6) {
      _snack('New password must be at least 6 characters.', error: true);
      return;
    }

    setState(() => _resetting = true);
    try {
      await context.read<AuthProvider>().resetPassword(
        ResetPasswordRequest(
          email: email,
          action: _action,
          otp: otp,
          newPassword: password,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Password reset — please sign in.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _resetting = false);
      final msg = e.toString().toLowerCase();
      _snack(
        msg.contains('otp') ||
                msg.contains('code') ||
                msg.contains('invalid') ||
                msg.contains('expired') ||
                msg.contains('400')
            ? 'That code is invalid or has expired.'
            : 'Could not reset your password. Please try again.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _codeSent ? 'Enter your code' : 'Reset your password',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _codeSent
                    ? 'We emailed you a 6-digit code. Enter it below with your new password.'
                    : 'Enter your account email and we\'ll send you a code to reset your password.',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _emailCtrl,
                enabled: !_codeSent && !_sending,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.mail_outline, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),

              if (_codeSent) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _otpCtrl,
                  enabled: !_resetting,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  decoration: InputDecoration(
                    labelText: 'Reset code',
                    prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordCtrl,
                  enabled: !_resetting,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              if (!_codeSent)
                _PrimaryButton(
                  label: 'Send code',
                  loading: _sending,
                  onPressed: _sending ? null : _sendCode,
                )
              else ...[
                _PrimaryButton(
                  label: 'Reset password',
                  loading: _resetting,
                  onPressed: _resetting ? null : _resetPassword,
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: (_sending || _resetting) ? null : _sendCode,
                  child: Text(
                    _sending ? 'Sending…' : 'Resend code',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: onPressed,
      child: loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.onPrimary,
              ),
            )
          : Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}
