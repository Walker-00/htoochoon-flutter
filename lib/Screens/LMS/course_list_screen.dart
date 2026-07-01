// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:htoochoon_flutter/Providers/structure_provider.dart';
// import 'package:htoochoon_flutter/Providers/org_provider.dart';
// import 'package:htoochoon_flutter/Screens/LMS/course_detail_screen.dart';
// import 'package:htoochoon_flutter/models/api_models/course_model.dart';
//
// class CourseListScreen extends StatefulWidget {
//   final String programId;
//   const CourseListScreen({super.key, required this.programId});
//
//   @override
//   State<CourseListScreen> createState() => _CourseListScreenState();
// }
//
// class _CourseListScreenState extends State<CourseListScreen> {
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       context.read<StructureProvider>().fetchCourses();
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Courses')),
//       body: Consumer<StructureProvider>(
//         builder: (context, provider, child) {
//           if (provider.isLoading) {
//             return const Center(child: CircularProgressIndicator());
//           }
//
//           if (provider.courses.isEmpty) {
//             return _buildEmptyState();
//           }
//
//           return ListView.builder(
//             padding: const EdgeInsets.all(16),
//             itemCount: provider.courses.length,
//             itemBuilder: (context, index) {
//               final course = provider.courses[index];
//               return _CourseCard(course: course);
//             },
//           );
//         },
//       ),
//       floatingActionButton: _buildAddButton(context),
//     );
//   }
//
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.library_books_outlined, size: 64, color: Colors.grey[400]),
//           const SizedBox(height: 16),
//           Text(
//             'No courses found',
//             style: TextStyle(fontSize: 18, color: Colors.grey[600]),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget? _buildAddButton(BuildContext context) {
//     final role = context.read<OrgProvider>().role;
//     if (role == 'owner' || role == 'admin') {
//       return FloatingActionButton(
//         onPressed: () {
//           // TODO: Navigate to create course form
//         },
//         child: const Icon(Icons.add),
//       );
//     }
//     return null;
//   }
// }
//
// class _CourseCard extends StatelessWidget {
//   final CourseResponse course;
//   const _CourseCard({required this.course});
//
//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       margin: const EdgeInsets.only(bottom: 16),
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: InkWell(
//         borderRadius: BorderRadius.circular(12),
//         onTap: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder:
//                   (_) =>
//                       CourseDetailScreen(courseId: course.id, courseName: course.name ?? 'Untitled'),
//             ),
//           );
//         },
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Expanded(
//                     child: Text(
//                       course.name ?? 'Untitled Course',
//                       style: const TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                   _StatusChip(status: course.type.name),
//                 ],
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 course.description ?? 'No description available',
//                 style: TextStyle(color: Colors.grey[600]),
//                 maxLines: 2,
//                 overflow: TextOverflow.ellipsis,
//               ),
//               const SizedBox(height: 12),
//               Row(
//                 children: [
//                   Icon(Icons.people_outline, size: 16, color: Colors.grey[500]),
//                   const SizedBox(width: 4),
//                   Text(
//                     'Students',
//                     style: TextStyle(color: Colors.grey[500], fontSize: 12),
//                   ),
//                   const SizedBox(width: 16),
//                   Icon(Icons.class_outlined, size: 16, color: Colors.grey[500]),
//                   const SizedBox(width: 4),
//                   Text(
//                     'Classes',
//                     style: TextStyle(color: Colors.grey[500], fontSize: 12),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// class _StatusChip extends StatelessWidget {
//   final String status;
//   const _StatusChip({required this.status});
//
//   @override
//   Widget build(BuildContext context) {
//     Color color;
//     switch (status.toLowerCase()) {
//       case 'active':
//       case 'published':
//         color = Colors.green;
//         break;
//       case 'archived':
//         color = Colors.grey;
//         break;
//       default:
//         color = Colors.orange;
//     }
//
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         color: color.withValues(alpha: 0.1),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: color.withValues(alpha: 0.5)),
//       ),
//       child: Text(
//         status.toUpperCase(),
//         style: TextStyle(
//           color: color,
//           fontSize: 10,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//     );
//   }
// }
