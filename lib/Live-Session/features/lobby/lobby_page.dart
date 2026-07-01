// import 'package:flutter/material.dart';
// import '../../core/services/socket_service.dart';
// import '../meeting/meeting_page.dart';
//
// class LobbyPage extends StatefulWidget {
//   const LobbyPage({super.key});
//
//   @override
//   State<LobbyPage> createState() => _LobbyPageState();
// }
//
// class _LobbyPageState extends State<LobbyPage> {
//   final SocketService _socket = SocketService();
//   final _nameCtrl = TextEditingController();
//   final _codeCtrl = TextEditingController();
//
//   // New Controllers for Tokens
//   final _accessCtrl = TextEditingController();
//   final _refreshCtrl = TextEditingController();
//
//   bool _isConnected = false;
//   String _role = 'student';
//
//   void _connectSocket() {
//     // Pass tokens to the socket service during connection
//     _socket.connect(
//       accessToken: _accessCtrl.text.trim(),
//       refreshToken: _refreshCtrl.text.trim(),
//     );
//
//     _socket.onConnected = () => setState(() => _isConnected = true);
//     _socket.onDisconnected = () => setState(() => _isConnected = false);
//   }
//
//   void _joinMeeting() {
//     if (_codeCtrl.text.isEmpty || _nameCtrl.text.isEmpty) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('💌 Enter name & code~')));
//       return;
//     }
//
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => MeetingPage(
//
//           isLocal: false,
//           roomId: _codeCtrl.text.trim(),
//           role: _role,
//           userName: _nameCtrl.text.trim(),
//           socketService: _socket,
//           // // Pass tokens to MeetingPage
//           accessToken: _accessCtrl.text.trim(),
//           refreshToken: _refreshCtrl.text.trim(),
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('🌸 Kawaii Meet Lobby')),
//       body: SingleChildScrollView(
//         // Added for better UX with more inputs
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             TextField(
//               controller: _nameCtrl,
//               decoration: const InputDecoration(labelText: 'Your Name ✏️'),
//             ),
//             TextField(
//               controller: _codeCtrl,
//               decoration: const InputDecoration(labelText: 'Meeting Code 🔑'),
//             ),
//             TextField(
//               controller: _accessCtrl,
//               decoration: const InputDecoration(labelText: 'Access Token 🎟️'),
//             ),
//             TextField(
//               controller: _refreshCtrl,
//               decoration: const InputDecoration(labelText: 'Refresh Token 🔄'),
//             ),
//
//             const SizedBox(height: 12),
//             DropdownButtonFormField(
//               value: _role,
//               items: const [
//                 DropdownMenuItem(
//                   value: 'student',
//                   child: Text('👩‍🎓 Student'),
//                 ),
//                 DropdownMenuItem(
//                   value: 'teacher',
//                   child: Text('👨‍🏫 Teacher'),
//                 ),
//               ],
//               onChanged: (v) => setState(() => _role = v!),
//             ),
//             const SizedBox(height: 24),
//             ElevatedButton(
//               onPressed: _connectSocket,
//               child: const Text('1. Connect Socket 🔌'),
//             ),
//             const SizedBox(height: 10),
//             ElevatedButton(
//               onPressed: _joinMeeting,
//               child: const Text('2. Join Meeting ✨'),
//             ),
//             const SizedBox(height: 12),
//             Text(_isConnected ? 'Connected 💖' : 'Disconnected 💔'),
//           ],
//         ),
//       ),
//     );
//   }
// }
