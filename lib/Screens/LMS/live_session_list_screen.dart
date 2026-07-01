// import 'package:flutter/material.dart';
// import 'package:htoochoon_flutter/Providers/auth_provider.dart';
// import 'package:htoochoon_flutter/Providers/login_provider.dart';
// import 'package:htoochoon_flutter/WEB_RTC/features/lobby/lobby_page.dart';
// import 'package:htoochoon_flutter/lms_demo/demo_services.dart';
// import 'package:htoochoon_flutter/lms_demo/models.dart';
// import 'package:provider/provider.dart';
//
// class LiveSessionListScreen extends StatelessWidget {
//   final String classId;
//   final String role;
//
//   const LiveSessionListScreen({
//     super.key,
//     required this.classId,
//     required this.role,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//
//     //TODO participant id from live session list screen
//     final participantId = authProvider.userId;
//     final services = context.watch<DemoServices>();
//
//     final session = services.getSessionForCourse(classId);
//     final isLive = session?.status == "live";
//
//     return Card(
//       elevation: isLive ? 3 : 1,
//       margin: const EdgeInsets.only(bottom: 14),
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//         side: isLive
//             ? const BorderSide(color: Colors.redAccent, width: 2)
//             : BorderSide.none,
//       ),
//       child: ListTile(
//         leading: Icon(Icons.videocam, color: isLive ? Colors.red : Colors.grey),
//         title: Text(
//           classId,
//           style: const TextStyle(fontWeight: FontWeight.bold),
//         ),
//         subtitle: Text(isLive ? "Live now" : "Waiting for teacher"),
//         trailing: _buildActionButton(
//           participantId.toString(),
//           context,
//           role,
//           classId,
//           isLive,
//           services,
//           session,
//         ),
//       ),
//     );
//   }
//
//   Widget _buildActionButton(
//     String participantId,
//     BuildContext context,
//     String role,
//     String course,
//     bool isLive,
//     DemoServices services,
//     DemoLiveSession? session,
//   ) {
//     if (role == "teacher") {
//       if (isLive) {
//         return Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextButton(
//               onPressed: () => services.endSession(classId),
//               child: const Text("End"),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => LobbyPage(
//                       roomId: session!.id,
//                       participantId: participantId,
//                     ),
//                   ),
//                 );
//               },
//               child: const Text("Rejoin"),
//             ),
//           ],
//         );
//       }
//
//       return ElevatedButton(
//         onPressed: () async {
//           final newSession = await services.startSession(classId);
//
//           logD("🎉 Join code for students: ${newSession?.joinCode}");
//           if (newSession == null) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text("Failed to start session")),
//             );
//             return;
//           }
//
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (_) => LobbyPage(
//                 roomId: newSession.id,
//                 participantId: participantId,
//               ),
//             ),
//           );
//         },
//         style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//         child: const Text("Start"),
//       );
//     }
//
//     /// student
//     if (isLive) {
//       return ElevatedButton(
//         onPressed: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (_) =>
//                   LobbyPage(roomId: session!.id, participantId: participantId),
//             ),
//           );
//         },
//         style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
//         child: const Text("Join"),
//       );
//     }
//
//     return const Text("Waiting...", style: TextStyle(color: Colors.grey));
//   }
// }
