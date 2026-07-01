// import 'package:flutter/material.dart';
// import 'package:htoochoon_flutter/Providers/class_provider.dart';
// import 'package:htoochoon_flutter/models/api_models/class_model.dart';
// import 'package:provider/provider.dart';
//
// class ClassesScreen extends StatefulWidget {
//   const ClassesScreen({super.key});
//
//   @override
//   State<ClassesScreen> createState() => _ClassesScreenState();
// }
//
// class _ClassesScreenState extends State<ClassesScreen> {
//   final ScrollController _scrollController = ScrollController();
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       context.read<ClassProvider>().fetchClasses();
//     });
//     _scrollController.addListener(_onScroll);
//   }
//
//   void _onScroll() {
//     final prov = context.read<ClassProvider>();
//
//     if (_scrollController.position.pixels >=
//         _scrollController.position.maxScrollExtent - 200) {
//       prov.fetchMoreClasses(); // ✅ trigger pagination
//     }
//   }
//
//   @override
//   void dispose() {
//     _scrollController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//
//     return Scaffold(
//       backgroundColor: cs.surface,
//       body: Consumer<ClassProvider>(
//         builder: (context, prov, child) => CustomScrollView(
//           controller: _scrollController,
//           slivers: [
//             SliverAppBar(
//               backgroundColor: cs.primary,
//               foregroundColor: cs.onPrimary,
//               pinned: true,
//               title: Text(
//                 'Classes',
//                 style: TextStyle(
//                   color: cs.onPrimary,
//                   fontWeight: FontWeight.w700,
//                 ),
//               ),
//               flexibleSpace: FlexibleSpaceBar(
//                 background: Container(
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [cs.primary, cs.tertiary],
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                     ),
//                   ),
//                 ),
//               ),
//               actions: [
//                 IconButton(
//                   icon: Icon(Icons.add_rounded, color: cs.onPrimary),
//                   onPressed: () => _showCreateDialog(context, prov),
//                 ),
//               ],
//             ),
//             if (prov.isFetchingMore)
//               const SliverToBoxAdapter(
//                 child: Padding(
//                   padding: EdgeInsets.all(16),
//                   child: Center(child: CircularProgressIndicator()),
//                 ),
//               ),
//             if (prov.isLoading)
//               const SliverToBoxAdapter(child: LinearProgressIndicator()),
//             if (prov.error != null)
//               SliverToBoxAdapter(
//                 child: _ErrorBanner(
//                   message: prov.error!,
//                   onDismiss: prov.clearError,
//                 ),
//               ),
//             if (prov.classes.isEmpty && !prov.isLoading)
//               const SliverFillRemaining(child: _EmptyState())
//             else
//               SliverPadding(
//                 padding: const EdgeInsets.all(16),
//                 sliver: SliverList(
//                   delegate: SliverChildBuilderDelegate((_, i) {
//                     final cls = prov.classes[i];
//                     return _ClassCard(
//                       classModel: cls,
//                       onDelete: () => prov.deleteClass(cls.id),
//                     );
//                   }, childCount: prov.classes.length),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Future<void> _showCreateDialog(
//     BuildContext context,
//     ClassProvider prov,
//   ) async {
//     final nameCtrl = TextEditingController();
//     final courseIdCtrl = TextEditingController();
//     final teacherIdCtrl = TextEditingController();
//     final maxStudentsCtrl = TextEditingController(text: '30');
//     DateTime startDate = DateTime.now();
//     DateTime endDate = DateTime.now().add(const Duration(days: 90));
//
//     await showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text('New Class'),
//         content: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               TextField(
//                 controller: nameCtrl,
//                 decoration: const InputDecoration(
//                   labelText: 'Class Name',
//                   border: OutlineInputBorder(),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               TextField(
//                 controller: courseIdCtrl,
//                 decoration: const InputDecoration(
//                   labelText: 'Course ID',
//                   border: OutlineInputBorder(),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               TextField(
//                 controller: teacherIdCtrl,
//                 decoration: const InputDecoration(
//                   labelText: 'Teacher ID',
//                   border: OutlineInputBorder(),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               TextField(
//                 controller: maxStudentsCtrl,
//                 keyboardType: TextInputType.number,
//                 decoration: const InputDecoration(
//                   labelText: 'Max Students',
//                   border: OutlineInputBorder(),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               if (nameCtrl.text.isEmpty) return;
//               Navigator.pop(ctx);
//               await prov.createClass(
//                 ClassRequest(
//                   name: nameCtrl.text,
//                   courseId: courseIdCtrl.text,
//                   startDate: startDate,
//                   endDate: endDate,
//                   maxStudents: int.tryParse(maxStudentsCtrl.text) ?? 30,
//                   teacherId: teacherIdCtrl.text,
//                 ),
//               );
//             },
//             child: const Text('Create'),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _ClassCard extends StatelessWidget {
//   final ClassModel classModel;
//   final VoidCallback onDelete;
//
//   const _ClassCard({required this.classModel, required this.onDelete});
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final now = DateTime.now();
//     final isActive =
//         now.isAfter(classModel.startDate) && now.isBefore(classModel.endDate);
//
//     return Container(
//       margin: const EdgeInsets.only(bottom: 10),
//       decoration: BoxDecoration(
//         color: cs.surfaceContainerHighest,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: isActive
//               ? cs.primary.withValues(alpha: 0.3)
//               : cs.outline.withValues(alpha: 0.1),
//         ),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(14),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Expanded(
//                   child: Text(
//                     classModel.name,
//                     style: const TextStyle(
//                       fontWeight: FontWeight.w700,
//                       fontSize: 15,
//                     ),
//                   ),
//                 ),
//                 if (isActive)
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 8,
//                       vertical: 3,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.green.withValues(alpha: 0.1),
//                       borderRadius: BorderRadius.circular(6),
//                     ),
//                     child: const Text(
//                       'ACTIVE',
//                       style: TextStyle(
//                         color: Colors.green,
//                         fontSize: 10,
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//                   ),
//                 PopupMenuButton<String>(
//                   icon: const Icon(Icons.more_vert_rounded, size: 18),
//                   onSelected: (v) {
//                     if (v == 'delete') onDelete();
//                   },
//                   itemBuilder: (_) => [
//                     const PopupMenuItem(value: 'delete', child: Text('Delete')),
//                   ],
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             Row(
//               children: [
//                 _InfoChip(
//                   icon: Icons.menu_book_rounded,
//                   label: classModel.course?.name ?? 'Unknown Course',
//                 ),
//                 const SizedBox(width: 8),
//                 _InfoChip(
//                   icon: Icons.person_rounded,
//                   label: classModel.teacher?.name ?? 'Unknown Teacher',
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             Row(
//               children: [
//                 Icon(
//                   Icons.calendar_today_rounded,
//                   size: 12,
//                   color: cs.onSurface.withValues(alpha: 0.5),
//                 ),
//                 const SizedBox(width: 4),
//                 Text(
//                   '${_fmt(classModel.startDate)} – ${_fmt(classModel.endDate)}',
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: cs.onSurface.withValues(alpha: 0.5),
//                   ),
//                 ),
//                 const Spacer(),
//                 Icon(
//                   Icons.people_rounded,
//                   size: 12,
//                   color: cs.onSurface.withValues(alpha: 0.5),
//                 ),
//                 const SizedBox(width: 4),
//                 Text(
//                   'Max ${classModel.maxStudents}',
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: cs.onSurface.withValues(alpha: 0.5),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
// }
//
// class _InfoChip extends StatelessWidget {
//   final IconData icon;
//   final String label;
//
//   const _InfoChip({required this.icon, required this.label});
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         color: cs.primary.withValues(alpha: 0.08),
//         borderRadius: BorderRadius.circular(6),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(icon, size: 12, color: cs.primary),
//           const SizedBox(width: 4),
//           Text(
//             label,
//             style: TextStyle(
//               fontSize: 11,
//               color: cs.primary,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _EmptyState extends StatelessWidget {
//   const _EmptyState();
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     return Center(
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(Icons.class_outlined, size: 56, color: cs.outline),
//           const SizedBox(height: 12),
//           const Text(
//             'No classes yet',
//             style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _ErrorBanner extends StatelessWidget {
//   final String message;
//   final VoidCallback onDismiss;
//
//   const _ErrorBanner({required this.message, required this.onDismiss});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.all(16),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.red.withValues(alpha: 0.1),
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
//       ),
//       child: Row(
//         children: [
//           const Icon(Icons.error_outline_rounded, color: Colors.red),
//           const SizedBox(width: 8),
//           Expanded(child: Text(message)),
//           IconButton(
//             icon: const Icon(Icons.close_rounded, size: 18),
//             onPressed: onDismiss,
//           ),
//         ],
//       ),
//     );
//   }
// }
