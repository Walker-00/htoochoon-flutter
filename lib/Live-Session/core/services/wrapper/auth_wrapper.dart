// import "dart:async";
//
// import "package:flutter/cupertino.dart";
// import "package:flutter/material.dart";
// import "package:flutter_secure_storage/flutter_secure_storage.dart";
// import "package:webrtc_videoconference/features/auth/login_page.dart";
// import "package:webrtc_videoconference/features/dashboard/dashboard_page.dart";
// class AuthWrapper extends StatefulWidget {
//   const AuthWrapper({super.key});
//
//   @override
//   State<AuthWrapper> createState() => _AuthWrapperState();
// }
//
// class _AuthWrapperState extends State<AuthWrapper> {
//   final _storage = const FlutterSecureStorage();
//   bool? _isLoggedIn;
//
//   @override
//   void initState() {
//     super.initState();
//     _checkAuth();
//   }
//
//   Future<void> _checkAuth() async {
//     String? token = await _storage.read(key: 'access_token');
//     setState(() => _isLoggedIn = token != null);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_isLoggedIn == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
//
//     return _isLoggedIn! ? const DashboardPage(user: user) : const LoginPage();
//   }
// }
