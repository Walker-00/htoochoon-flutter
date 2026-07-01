// import 'package:flutter/material.dart';
// import 'package:htoochoon_flutter/Providers/auth_provider.dart';
// import 'package:provider/provider.dart';
//
// class UserDetailScreen extends StatefulWidget {
//
//   String userId;
//    UserDetailScreen({super.key, required this.userId })
//
//
//
//
//
//   @override
//   State<UserDetailScreen> createState() => _UserDetailScreenState();
// }
//
// class _UserDetailScreenState extends State<UserDetailScreen> {
//   @override
//   Widget build(BuildContext context) {
//     @override
//     void initState() {
//       super.initState();
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         context.read<AuthProvider>().loadUserById(widget.userId);
//       });
//     }
//
//     return Consumer<AuthProvider>(
//       builder: (context, authProv, child) => Scaffold(
//         body: SafeArea(child: Column(children: [
//
//
//         ])),
//       ),
//     );
//   }
// }
