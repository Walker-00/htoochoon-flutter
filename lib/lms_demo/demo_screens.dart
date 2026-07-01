// import 'package:flutter/material.dart';
// import 'package:htoochoon_flutter/Providers/auth_provider.dart';
// import 'package:htoochoon_flutter/Screens/LMS/class_detail_screen.dart';
// import 'package:htoochoon_flutter/Screens/LMS/course_detail_screen.dart';
// import 'package:provider/provider.dart';
// import 'package:htoochoon_flutter/Providers/user_provider.dart';
// import '../WEB_RTC/features/lobby/lobby_page.dart';
// import 'demo_services.dart';
// import 'models.dart';
//
// class DemoOrganizationListScreen extends StatelessWidget {
//   const DemoOrganizationListScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final services = context.watch<DemoServices>();
//     final orgs = services.getOrganizations();
//     final participantId = "student_${DateTime.now().millisecondsSinceEpoch}";
//     return Scaffold(
//       appBar: AppBar(title: const Text('Organizations'), elevation: 0),
//       body: ListView.builder(
//         padding: const EdgeInsets.all(16),
//         itemCount: orgs.length,
//         itemBuilder: (context, index) {
//           final org = orgs[index];
//           return Card(
//             elevation: 2,
//             margin: const EdgeInsets.only(bottom: 12),
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: ListTile(
//               contentPadding: const EdgeInsets.all(16),
//               leading: CircleAvatar(
//                 backgroundColor: Theme.of(
//                   context,
//                 ).primaryColor.withValues(alpha: 0.1),
//                 child: Icon(
//                   Icons.business,
//                   color: Theme.of(context).primaryColor,
//                 ),
//               ),
//               title: Text(
//                 org.name,
//                 style: const TextStyle(
//                   fontWeight: FontWeight.bold,
//                   fontSize: 18,
//                 ),
//               ),
//               trailing: const Icon(Icons.arrow_forward_ios, size: 16),
//               onTap: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => DemoClassListScreen(org: org),
//                   ),
//                 );
//               },
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
//
// class DemoClassListScreen extends StatelessWidget {
//   final DemoOrganization org;
//   const DemoClassListScreen({super.key, required this.org});
//
//   @override
//   Widget build(BuildContext context) {
//     final authProvider = Provider.of<AuthProvider>(context, listen: false);
//
//     //TODO participant id from demo class list screen
//     // final participantId = authProvider.userId;
//     final participantId = 'TDCIS';
//     final services = context.watch<DemoServices>();
//     final classes = services.getClassesForOrg(org.id);
//
//     return Scaffold(
//       appBar: AppBar(title: Text('${org.name} Classes'), elevation: 0),
//       body: classes.isEmpty
//           ? const Center(child: Text('No classes found'))
//           : ListView.builder(
//               padding: const EdgeInsets.all(16),
//               itemCount: classes.length,
//               itemBuilder: (context, index) {
//                 final cls = classes[index];
//                 return Card(
//                   elevation: 2,
//                   margin: const EdgeInsets.only(bottom: 12),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: ListTile(
//                     contentPadding: const EdgeInsets.all(16),
//                     leading: CircleAvatar(
//                       backgroundColor: Colors.orange.withValues(alpha: 0.1),
//                       child: const Icon(Icons.class_, color: Colors.orange),
//                     ),
//                     title: Text(
//                       cls.name,
//                       style: const TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),
//                     trailing: const Icon(Icons.arrow_forward_ios, size: 16),
//                     onTap: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (_) => DemoCourseListScreen(
//                             cls: cls,
//                             participantId: participantId.toString(),
//                           ),
//
//                           // DemoCourseListScreen(cls: cls),
//                         ),
//                       );
//                     },
//                   ),
//                 );
//               },
//             ),
//     );
//   }
// }
//
// class DemoCourseListScreen extends StatelessWidget {
//   final DemoClassroom cls;
//   final String participantId;
//   const DemoCourseListScreen({
//     super.key,
//     required this.cls,
//     required this.participantId,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final services = context.watch<DemoServices>();
//     final userProvider = context.watch<UserProvider>();
//     final role = userProvider.userData?['role'] ?? 'teacher';
//
//     final courses = services.getCoursesForClass(cls.id);
//
//     return Scaffold(
//       appBar: AppBar(title: Text('${cls.name} Courses'), elevation: 0),
//       body: courses.isEmpty
//           ? const Center(child: Text('No courses found'))
//           : GridView.builder(
//               padding: const EdgeInsets.all(16),
//               itemCount: courses.length,
//               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 3,
//                 crossAxisSpacing: 16,
//                 mainAxisSpacing: 16,
//                 childAspectRatio: 1.2,
//               ),
//               itemBuilder: (context, index) {
//                 final course = courses[index];
//                 final session = services.getSessionForCourse(course.id);
//                 final isLive = session?.status == 'live';
//
//                 return _buildCourseCard(
//                   () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (context) => ClassDetailScreen(
//                           role: 'teacher',
//                           classId: course.id,
//                           className: course.title,
//                         ),
//                       ),
//                     );
//                   },
//                   context,
//                   course,
//                   isLive,
//                   role,
//                   services,
//                   session,
//                   participantId,
//                 );
//               },
//             ),
//     );
//   }
// }
//
// Widget _buildActionButtons(
//   BuildContext context,
//   String role,
//   DemoCourse course,
//   bool isLive,
//   DemoServices services,
//   DemoLiveSession? session,
//   String participantId,
// ) {
//   if (role == 'student') {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.end,
//       children: [
//         if (isLive) ...[
//           TextButton(
//             onPressed: () => services.endSession(course.id),
//             style: TextButton.styleFrom(foregroundColor: Colors.grey),
//             child: const Text('End Session'),
//           ),
//           const SizedBox(width: 8),
//           ElevatedButton.icon(
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (_) => LobbyPage(
//                     roomId: session!.id,
//                     participantId: participantId,
//                   ),
//                 ),
//               );
//             },
//             icon: const Icon(Icons.videocam),
//             label: const Text('Re-join Class'),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.redAccent,
//               foregroundColor: Colors.white,
//             ),
//           ),
//         ] else
//           ElevatedButton.icon(
//             onPressed: () {
//               services.startSession(course.id);
//
//               // logD("🎉 Join code from demo screen: ${session!.joinCode.toString()} ");
//               final newSession = services.getSessionForCourse(course.id);
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (_) => LobbyPage(
//                     roomId: newSession!.id,
//                     participantId: participantId,
//                   ),
//                 ),
//               );
//             },
//             icon: const Icon(Icons.play_arrow),
//             label: const Text('Start Live Session'),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.green,
//               foregroundColor: Colors.white,
//             ),
//           ),
//       ],
//     );
//   } else {
//     // Student view
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.end,
//       children: [
//         if (isLive)
//           ElevatedButton.icon(
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (_) => LobbyPage(
//                     roomId: session!.id,
//                     participantId: participantId,
//                   ),
//                 ),
//               );
//             },
//             icon: const Icon(Icons.exit_to_app),
//             label: const Text('Join Live Session'),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.redAccent,
//               foregroundColor: Colors.white,
//             ),
//           )
//         else
//           const Text(
//             'Waiting for teacher to start...',
//             style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
//           ),
//       ],
//     );
//   }
// }
//
// Widget _buildCourseCard(
//   VoidCallback ontap,
//   BuildContext context,
//   DemoCourse course,
//   bool isLive,
//   String role,
//   DemoServices services,
//   DemoLiveSession? session,
//   String participantId,
// ) {
//   final colors = [
//     Colors.blue,
//     Colors.green,
//     Colors.deepPurple,
//     Colors.orange,
//     Colors.teal,
//   ];
//
//   final color = colors[course.id.hashCode % colors.length];
//
//   return Container(
//     margin: const EdgeInsets.only(bottom: 20),
//     child: Card(
//       elevation: 3,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       clipBehavior: Clip.antiAlias,
//       child: GestureDetector(
//         onTap: ontap,
//
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             /// HEADER (like Google Classroom)
//             Container(
//               height: 110,
//               color: color,
//               padding: const EdgeInsets.all(16),
//               child: Stack(
//                 children: [
//                   Positioned(
//                     left: 0,
//                     top: 0,
//                     right: 0,
//                     child: Text(
//                       course.title,
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//
//                   Positioned(
//                     bottom: 0,
//                     left: 0,
//                     child: Text(
//                       course.teacherName,
//                       style: const TextStyle(
//                         color: Colors.white70,
//                         fontSize: 14,
//                       ),
//                     ),
//                   ),
//
//                   if (isLive)
//                     Positioned(
//                       right: 0,
//                       top: 0,
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 10,
//                           vertical: 4,
//                         ),
//                         decoration: BoxDecoration(
//                           color: Colors.red,
//                           borderRadius: BorderRadius.circular(20),
//                         ),
//                         child: const Text(
//                           "LIVE",
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 12,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//
//             /// BODY
//             Padding(
//               padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
//               child: Column(
//                 children: [
//                   _buildActionButtons(
//                     context,
//                     role,
//                     course,
//                     isLive,
//                     services,
//                     session,
//                     participantId,
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     ),
//   );
// }
