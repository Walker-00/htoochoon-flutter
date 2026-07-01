// import 'package:flutter/material.dart';
// import 'package:htoochoon_flutter/Providers/AdminProviders/live_sessions_provider.dart';
// import 'package:htoochoon_flutter/models/api_models/enums.dart';
// import 'package:htoochoon_flutter/models/api_models/live_session_model.dart';
// import 'package:provider/provider.dart';
//
// class LiveSessionsScreen extends StatefulWidget {
//   final String organisationId;
//
//   const LiveSessionsScreen({super.key, required this.organisationId});
//
//   @override
//   State<LiveSessionsScreen> createState() => _LiveSessionsScreenState();
// }
//
// class _LiveSessionsScreenState extends State<LiveSessionsScreen> {
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       final prov = context.read<LiveSessionsProvider>();
//       prov.fetchSessions();
//       prov.fetchUpcomingSessions(orgId: widget.organisationId);
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//
//     return Scaffold(
//       backgroundColor: cs.surface,
//       body: Consumer<LiveSessionsProvider>(
//         builder: (_, prov, __) => CustomScrollView(
//           slivers: [
//             SliverAppBar(
//               backgroundColor: cs.primary,
//               foregroundColor: cs.onPrimary,
//               pinned: true,
//               expandedHeight: 120,
//               flexibleSpace: FlexibleSpaceBar(
//                 title: Text(
//                   'Live Sessions',
//                   style: TextStyle(
//                     color: cs.onPrimary,
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
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
//             if (prov.isLoading)
//               const SliverToBoxAdapter(child: LinearProgressIndicator()),
//
//             // ── Live now ──────────────────────────────
//             SliverToBoxAdapter(
//               child: Padding(
//                 padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
//                 child: Text(
//                   'Live Now',
//                   style: Theme.of(context).textTheme.titleMedium?.copyWith(
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//               ),
//             ),
//
//             SliverPadding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               sliver: SliverList(
//                 delegate: SliverChildBuilderDelegate((_, i) {
//                   final live = prov.sessions
//                       .where((s) => s.status == LiveSessionStatus.LIVE)
//                       .toList();
//                   if (live.isEmpty) {
//                     return Padding(
//                       padding: const EdgeInsets.only(bottom: 16),
//                       child: _EmptyCard(
//                         icon: Icons.videocam_off_rounded,
//                         message: 'No active sessions',
//                       ),
//                     );
//                   }
//                   return _SessionTile(
//                     session: live[i],
//                     onEnd: () => prov.endSession(live[i].id),
//                     onDelete: () => prov.deleteSession(live[i].id),
//                   );
//                 }, childCount: 1),
//               ),
//             ),
//
//             // ── Upcoming ──────────────────────────────
//             SliverToBoxAdapter(
//               child: Padding(
//                 padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
//                 child: Text(
//                   'Upcoming',
//                   style: Theme.of(context).textTheme.titleMedium?.copyWith(
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//               ),
//             ),
//
//             if (prov.upcomingSessions.isEmpty)
//               SliverToBoxAdapter(
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 16),
//                   child: _EmptyCard(
//                     icon: Icons.event_available_rounded,
//                     message: 'No upcoming sessions',
//                   ),
//                 ),
//               )
//             else
//               SliverPadding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16),
//                 sliver: SliverList(
//                   delegate: SliverChildBuilderDelegate((_, i) {
//                     final s = prov.upcomingSessions[i];
//                     return _SessionTile(
//                       session: s,
//                       onStart: s.status == LiveSessionStatus.SCHEDULED
//                           ? () => prov.startSession(s.id)
//                           : null,
//                       onDelete: () => prov.deleteSession(s.id),
//                     );
//                   }, childCount: prov.upcomingSessions.length),
//                 ),
//               ),
//
//             const SliverToBoxAdapter(child: SizedBox(height: 32)),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Future<void> _showCreateDialog(
//     BuildContext context,
//     LiveSessionsProvider prov,
//   ) async {
//     final topicCtrl = TextEditingController();
//     final classIdCtrl = TextEditingController();
//     final hostIdCtrl = TextEditingController();
//
//     await showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text('Schedule Live Session'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: topicCtrl,
//               decoration: const InputDecoration(
//                 labelText: 'Topic',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 12),
//             TextField(
//               controller: classIdCtrl,
//               decoration: const InputDecoration(
//                 labelText: 'Class ID',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 12),
//             TextField(
//               controller: hostIdCtrl,
//               decoration: const InputDecoration(
//                 labelText: 'Host ID',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               if (topicCtrl.text.isEmpty) return;
//               Navigator.pop(ctx);
//               await prov.createSession(
//                 LiveSessionRequest(
//                   topic: topicCtrl.text,
//                   classId: classIdCtrl.text,
//                   startTime: DateTime.now().add(const Duration(hours: 1)),
//                   hostId: hostIdCtrl.text,
//                   status: LiveSessionStatus.SCHEDULED,
//                 ),
//               );
//             },
//             child: const Text('Schedule'),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _SessionTile extends StatelessWidget {
//   final LiveSession session;
//   final VoidCallback? onStart;
//   final VoidCallback? onEnd;
//   final VoidCallback onDelete;
//
//   const _SessionTile({
//     required this.session,
//     this.onStart,
//     this.onEnd,
//     required this.onDelete,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final isLive = session.status == LiveSessionStatus.LIVE;
//
//     return Container(
//       margin: const EdgeInsets.only(bottom: 10),
//       decoration: BoxDecoration(
//         color: cs.surfaceContainerHighest,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: isLive
//               ? Colors.green.withValues(alpha: 0.4)
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
//                 Container(
//                   width: 36,
//                   height: 36,
//                   decoration: BoxDecoration(
//                     color: isLive
//                         ? Colors.green.withValues(alpha: 0.12)
//                         : cs.primary.withValues(alpha: 0.1),
//                     shape: BoxShape.circle,
//                   ),
//                   child: Icon(
//                     Icons.videocam_rounded,
//                     color: isLive ? Colors.green : cs.primary,
//                     size: 18,
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         session.topic,
//                         style: const TextStyle(
//                           fontWeight: FontWeight.w700,
//                           fontSize: 14,
//                         ),
//                       ),
//                       Text(
//                         session.sessionClass.name,
//                         style: TextStyle(
//                           fontSize: 12,
//                           color: cs.onSurface.withValues(alpha: 0.55),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 _StatusBadge(status: session.status),
//               ],
//             ),
//             const SizedBox(height: 10),
//             Row(
//               children: [
//                 Icon(
//                   Icons.schedule_rounded,
//                   size: 12,
//                   color: cs.onSurface.withValues(alpha: 0.5),
//                 ),
//                 const SizedBox(width: 4),
//                 Text(
//                   _formatDateTime(session.startTime),
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: cs.onSurface.withValues(alpha: 0.5),
//                   ),
//                 ),
//                 const Spacer(),
//                 // Action buttons
//                 if (onStart != null)
//                   _ActionBtn(
//                     label: 'Start',
//                     color: Colors.green,
//                     onTap: onStart!,
//                   ),
//                 if (onEnd != null) ...[
//                   const SizedBox(width: 8),
//                   _ActionBtn(label: 'End', color: Colors.red, onTap: onEnd!),
//                 ],
//                 const SizedBox(width: 8),
//                 GestureDetector(
//                   onTap: onDelete,
//                   child: Icon(
//                     Icons.delete_outline_rounded,
//                     size: 18,
//                     color: cs.onSurface.withValues(alpha: 0.4),
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
//   String _formatDateTime(DateTime d) =>
//       '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
// }
//
// class _StatusBadge extends StatelessWidget {
//   final LiveSessionStatus status;
//
//   const _StatusBadge({required this.status});
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final (color, label) = switch (status) {
//       LiveSessionStatus.LIVE => (Colors.green, 'LIVE'),
//       LiveSessionStatus.SCHEDULED => (cs.primary, 'SCHEDULED'),
//       LiveSessionStatus.ENDED => (cs.outline, 'ENDED'),
//     };
//
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//       decoration: BoxDecoration(
//         color: color.withValues(alpha: 0.1),
//         borderRadius: BorderRadius.circular(6),
//       ),
//       child: Text(
//         label,
//         style: TextStyle(
//           color: color,
//           fontSize: 10,
//           fontWeight: FontWeight.w700,
//         ),
//       ),
//     );
//   }
// }
//
// class _ActionBtn extends StatelessWidget {
//   final String label;
//   final Color color;
//   final VoidCallback onTap;
//
//   const _ActionBtn({
//     required this.label,
//     required this.color,
//     required this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
//         decoration: BoxDecoration(
//           color: color.withValues(alpha: 0.1),
//           borderRadius: BorderRadius.circular(6),
//         ),
//         child: Text(
//           label,
//           style: TextStyle(
//             color: color,
//             fontSize: 12,
//             fontWeight: FontWeight.w700,
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// class _EmptyCard extends StatelessWidget {
//   final IconData icon;
//   final String message;
//
//   const _EmptyCard({required this.icon, required this.message});
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.symmetric(vertical: 24),
//       decoration: BoxDecoration(
//         color: cs.surfaceContainerHighest,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         children: [
//           Icon(icon, size: 32, color: cs.outline),
//           const SizedBox(height: 8),
//           Text(message, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
//         ],
//       ),
//     );
//   }
// }
