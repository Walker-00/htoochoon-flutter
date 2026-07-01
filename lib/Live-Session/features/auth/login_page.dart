// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import '../../core/services/socket_service.dart';
// import '../../models/user_model.dart';
// import '../dashboard/dashboard_page.dart';
// import 'two_factor_page.dart';
//
// class LoginPage extends StatefulWidget {
//   const LoginPage({super.key});
//
//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }
//
// class _LoginPageState extends State<LoginPage> {
//   final SocketService _socket = SocketService();
//   final _formKey = GlobalKey<FormState>();
//   final _emailCtrl = TextEditingController();
//   final _passwordCtrl = TextEditingController();
//
//   bool _loading = false;
//   bool _obscurePassword = true;
//   String? _errorMessage;
//
//   @override
//   void initState() {
//     super.initState();
//   }
//
//   final Dio _dio = Dio(BaseOptions(baseUrl: 'https://backend.htoochoon.com'));
//   final _storage = const FlutterSecureStorage();
//
//   void _handleLogin() async {
//     if (!_formKey.currentState!.validate()) return;
//
//     setState(() {
//       _loading = true;
//       _errorMessage = null;
//     });
//
//     try {
//       // 1. Authenticate via HTTP Dio
//       final response = await _dio.post('/auth/login', data: {
//         'email': _emailCtrl.text.trim(),
//         'password': _passwordCtrl.text,
//       });
//
//       if (response.statusCode == 201 || response.statusCode == 200) {
//         final responseBody = response.data; // This is the full JSON you shared
//
//         // 1. Store Tokens (Note the snake_case keys from your JSON)
//         await _storage.write(key: 'access_token', value: responseBody['access_token']);
//         await _storage.write(key: 'refresh_token', value: responseBody['refresh_token']);
//
//         // 2. Parse the User
//         // IMPORTANT: We pass the WHOLE responseBody because your
//         // UserModel.fromJson logic now handles the ['data'] nesting.
//         final user = UserModel.fromJson(responseBody);
//
//         // 3. Handle 2FA or Navigate
//         if (user.isTwoFactorEnabled) {
//           _navigateTo2FA(user);
//         } else {
//           await _socket.initSocket();
//           _navigateToDashboard(user);
//         }
//       }
//     } on DioException catch (e) {
//       setState(() {
//         _loading = false;
//         _errorMessage = e.response?.data['message'] ?? 'Login failed~ 💦';
//       });
//     } catch (e) {
//       debugPrint(e.toString());
//       setState(() {
//         _loading = false;
//         _errorMessage = 'An unexpected error occurred';
//       });
//     } finally {
//       if (mounted) setState(() => _loading = false);
//     }
//   }
//
//   void _navigateTo2FA(UserModel user) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => TwoFactorPage(
//           email: user.email,
//           onVerified: (verifiedUser) async {
//             await _socket.initSocket(); // Init socket after 2FA success
//             _navigateToDashboard(verifiedUser);
//           },
//         ),
//       ),
//     );
//   }
//
//   void _navigateToDashboard(UserModel user) {
//     // Store user in shared prefs or provider here~
//     Navigator.pushAndRemoveUntil(
//       context,
//       MaterialPageRoute(builder: (_) => DashboardPage(user: user)),
//           (route) => false,
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Theme.of(context).colorScheme.surface,
//       body: SafeArea(
//         child: Center(
//           child: SingleChildScrollView(
//             padding: EdgeInsets.all(24),
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   // 🎀 Cute Logo/Header
//                   Icon(Icons.school, size: 64, color: Theme.of(context).colorScheme.primary),
//                   SizedBox(height: 16),
//                   Text(
//                     '🎓 LMS Meet',
//                     style: Theme.of(context).textTheme.headlineMedium?.copyWith(
//                       fontWeight: FontWeight.bold,
//                       color: Theme.of(context).colorScheme.primary,
//                     ),
//                   ),
//                   SizedBox(height: 8),
//                   Text(
//                     'Sign in to continue your learning journey~ ✧',
//                     textAlign: TextAlign.center,
//                     style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                       color: Colors.grey[600],
//                     ),
//                   ),
//                   SizedBox(height: 32),
//
//                   // 🎀 Email Field
//                   TextFormField(
//                     controller: _emailCtrl,
//                     keyboardType: TextInputType.emailAddress,
//                     decoration: InputDecoration(
//                       labelText: 'Email Address 📧',
//                       prefixIcon: Icon(Icons.email_outlined),
//                     ),
//                     validator: (v) => v!.isEmpty || !v.contains('@')
//                         ? 'Please enter a valid email' : null,
//                   ),
//                   SizedBox(height: 16),
//
//                   // 🎀 Password Field
//                   TextFormField(
//                     controller: _passwordCtrl,
//                     obscureText: _obscurePassword,
//                     decoration: InputDecoration(
//                       labelText: 'Password 🔑',
//                       prefixIcon: Icon(Icons.lock_outline),
//                       suffixIcon: IconButton(
//                         icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
//                         onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
//                       ),
//                     ),
//                     validator: (v) => v!.length < 6 ? 'Password must be 6+ characters' : null,
//                   ),
//                   Align(
//                     alignment: Alignment.centerRight,
//                     child: TextButton(
//                       onPressed: () {
//                         // TODO: Navigate to forgot password
//                       },
//                       child: Text('Forgot password?'),
//                     ),
//                   ),
//
//                   // 🎀 Error Message
//                   if (_errorMessage != null)
//                     Padding(
//                       padding: EdgeInsets.symmetric(vertical: 8),
//                       child: Text(
//                         _errorMessage!,
//                         style: TextStyle(color: Colors.red, fontSize: 14),
//                         textAlign: TextAlign.center,
//                       ),
//                     ),
//
//                   SizedBox(height: 24),
//
//                   // 🎀 Login Button
//                   _loading
//                       ? CircularProgressIndicator()
//                       : SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton.icon(
//                       onPressed: _handleLogin,
//                       icon: Icon(Icons.login),
//                       label: Text('Sign In ✨'),
//                       style: ElevatedButton.styleFrom(
//                         padding: EdgeInsets.symmetric(vertical: 16),
//                       ),
//                     ),
//                   ),
//
//                   SizedBox(height: 24),
//
//                   // 🎀 Divider
//                   Row(
//                     children: [
//                       Expanded(child: Divider()),
//                       Padding(
//                         padding: EdgeInsets.symmetric(horizontal: 16),
//                         child: Text('or', style: TextStyle(color: Colors.grey)),
//                       ),
//                       Expanded(child: Divider()),
//                     ],
//                   ),
//
//                   SizedBox(height: 24),
//
//                   // 🎀 Google Sign In (Optional)
//                   OutlinedButton.icon(
//                     onPressed: () {
//                       // TODO: Implement Google OAuth flow
//                       _socket.socket.emit('auth:google:init');
//                     },
//                     icon: Image.asset('assets/google_logo.png', width: 24, height: 24),
//                     label: Text('Continue with Google'),
//                   ),
//
//                   SizedBox(height: 32),
//
//                   // 🎀 Register Link
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text("Don't have an account?"),
//                       TextButton(
//                         onPressed: () {
//                           // TODO: Navigate to register page
//                         },
//                         child: Text('Sign Up'),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _emailCtrl.dispose();
//     _passwordCtrl.dispose();
//     _socket.dispose();
//     super.dispose();
//   }
// }
