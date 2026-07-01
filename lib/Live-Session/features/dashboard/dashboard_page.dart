// import 'package:flutter/material.dart';
// import 'package:webrtc_videoconference/core/services/socket_service.dart';
// import 'package:webrtc_videoconference/features/meeting/meeting_page.dart';
// import 'package:webrtc_videoconference/models/user_model.dart';
// import 'package:webrtc_videoconference/models/class_model.dart';
// import 'package:webrtc_videoconference/models/live_session_model.dart';
//
// class DashboardPage extends StatelessWidget {
//   final UserModel user;
//
//   const DashboardPage({super.key, required this.user});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('🎓 LMS Meet'),
//         actions: [
//           CircleAvatar(
//             backgroundColor: Colors.blue[100],
//             child: Text(user.name[0], style: const TextStyle(color: Colors.blue)),
//           ),
//           const SizedBox(width: 16),
//         ],
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // 🎀 Welcome Header
//             Text(
//               'Mingalarpar, ${user.name}! ✨',
//               style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
//             ),
//             const Text('Ready for your next session?', style: TextStyle(color: Colors.grey)),
//             const SizedBox(height: 24),
//
//             // 🎀 Active/Live Now Section
//             _buildLiveBanner(context),
//             const SizedBox(height: 32),
//
//             // 🎀 Your Classes Grid
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text('Your Classes 📚', style: Theme.of(context).textTheme.titleLarge),
//                 TextButton(onPressed: () {}, child: const Text('View All')),
//               ],
//             ),
//             const SizedBox(height: 12),
//             _buildClassGrid(context),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildLiveBanner(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(colors: [Colors.blue[700]!, Colors.blue[400]!]),
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Badge(label: Text('LIVE NOW'), backgroundColor: Colors.red),
//           const SizedBox(height: 12),
//           const Text(
//             'Full-Stack WebRTC Class',
//             style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//           const Text('Hosted by: Dr. Mila', style: TextStyle(color: Colors.white70)),
//           const SizedBox(height: 16),
//           ElevatedButton(
//             onPressed: () {
//               // In a real app, you'd get this ID from your LiveSessionModel
//               const String activeRoomId = 'full-stack-webrtc-101';
//
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => MeetingPage(
//                     roomId: activeRoomId,
//                     userName: user.name,
//                     // ✅ FIX: Use .name or .toString().split('.').last
//                     role: user.role.name,
//                     socketService: SocketService(),
//                   ),
//                 ),
//               );
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.white,
//               foregroundColor: Colors.blue[700],
//             ),
//             child: const Text('Join Meeting 🚀'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildClassGrid(BuildContext context) {
//     // Mocking data for UI layout
//     final List<Map<String, dynamic>> mockClasses = [
//       {'name': 'Flutter Advanced', 'students': 24, 'color': Colors.purple},
//       {'name': 'VoIP & Asterisk', 'students': 12, 'color': Colors.orange},
//       {'name': 'NestJS Backend', 'students': 30, 'color': Colors.green},
//     ];
//
//     return GridView.builder(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: 2,
//         crossAxisSpacing: 12,
//         mainAxisSpacing: 12,
//         childAspectRatio: 1.1,
//       ),
//       itemCount: mockClasses.length,
//       itemBuilder: (context, index) {
//         final c = mockClasses[index];
//         return InkWell(
//           onTap: () {
//             // Navigation logic will go here
//           },
//           child: Card(
//             color: c['color'].withValues(alpha: 0.1),
//             elevation: 0,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(16),
//               side: BorderSide(color: c['color'].withValues(alpha: 0.3)),
//             ),
//             child: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.class_, color: c['color']),
//                   const SizedBox(height: 12),
//                   Text(c['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
//                   Text('${c['students']} Students', style: const TextStyle(color: Colors.grey, fontSize: 12)),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
