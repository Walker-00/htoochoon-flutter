// import 'package:flutter/material.dart';
// import 'package:htoochoon_flutter/Screens/LMS/OrgMainScreens/OrgWidgets/org_dashboard_widgets.dart';
//
// import 'package:htoochoon_flutter/Widgets/user_appbar.dart';
// import 'package:lottie/lottie.dart';
// import 'package:provider/provider.dart';
// import 'package:htoochoon_flutter/Providers/org_provider.dart';
//
// import 'package:htoochoon_flutter/Theme/themedata.dart';
// import 'package:htoochoon_flutter/models/api_models/organization_model.dart';
//
// class OrgContextLoader extends StatefulWidget {
//   OrgContextLoader({super.key});
//
//   @override
//   State<OrgContextLoader> createState() => _OrgContextLoaderState();
// }
//
// class _OrgContextLoaderState extends State<OrgContextLoader> {
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       context.read<OrgProvider>().loadOrganisations();
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Consumer<OrgProvider>(
//       builder: (context, orgProvider, _) {
//         if (orgProvider.organisations.isNotEmpty) {
//           return Scaffold(
//             backgroundColor: Theme.of(context).scaffoldBackgroundColor,
//             appBar: UserAppBar(
//               showSearchIcon: false,
//               title: "My Organizations",
//               leadIcon: Icons.business,
//             ),
//             body: ListView.builder(
//               padding: const EdgeInsets.all(AppTheme.spaceLg),
//               itemCount: orgProvider.organisations.length,
//               itemBuilder: (context, index) {
//                 final org = orgProvider.organisations[index];
//                 // final role = org. ?? 'student';
//
//                 return _OrganizationCard(
//                   org: org,
//                   role: 'gcgs',
//                   isLoading: orgProvider.isLoading,
//                   onTap: () {
//                     context.read<OrgProvider>().selectOrganisation(org.id);
//                   },
//                 );
//               },
//             ),
//           );
//         }
//
//         // Empty state
//         return Scaffold(
//           backgroundColor: Theme.of(context).scaffoldBackgroundColor,
//           appBar: AppBar(
//             elevation: 0,
//             backgroundColor: Theme.of(context).cardColor,
//             title: Text(
//               'My Organizations',
//               style: Theme.of(
//                 context,
//               ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
//             ),
//             actions: [
//               IconButton(
//                 onPressed: () => showCreateDialog(context,'Organization', orgProvider),
//                 icon: const Icon(Icons.add_circle_outline, size: 22),
//               ),
//               const SizedBox(width: AppTheme.spaceXs),
//             ],
//           ),
//           body: Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(AppTheme.spaceLg),
//                   decoration: BoxDecoration(
//                     color: Theme.of(
//                       context,
//                     ).colorScheme.primary.withValues(alpha: 0.1),
//                     borderRadius: BorderRadius.circular(AppTheme.radius2xl),
//                   ),
//                   child: Icon(
//                     Icons.business_center_outlined,
//                     size: 64,
//                     color: Theme.of(context).colorScheme.primary,
//                   ),
//                 ),
//                 const SizedBox(height: AppTheme.spaceLg),
//                 Text(
//                   'No Organizations Yet',
//                   style: Theme.of(context).textTheme.headlineSmall?.copyWith(
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//                 const SizedBox(height: AppTheme.spaceXs),
//                 Text(
//                   'Create or join an organization to get started',
//                   style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                     color: AppTheme.getTextSecondary(context),
//                   ),
//                 ),
//                 const SizedBox(height: AppTheme.spaceLg),
//                 ElevatedButton.icon(
//                   onPressed: () =>  showCreateDialog(context,'Organization', orgProvider),
//                   icon: const Icon(Icons.add, size: 20),
//                   label: const Text('Create Organization'),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
//
// class _OrganizationCard extends StatelessWidget {
//   final OrganizationResponse org;
//   final String role;
//   final bool isLoading;
//   final VoidCallback onTap;
//
//   const _OrganizationCard({
//     required this.org,
//     required this.role,
//     required this.isLoading,
//     required this.onTap,
//   });
//
//   Color _getRoleColor() {
//     switch (role.toLowerCase()) {
//       case 'owner':
//         return const Color(0xFF9333EA); // Purple
//       case 'admin':
//         return const Color(0xFFEA580C); // Deep Orange
//       case 'moderator':
//         return const Color(0xFF4F46E5); // Indigo
//       case 'teacher':
//         return const Color(0xFF3B82F6); // Blue
//       default:
//         return AppTheme.success; // Green
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final roleColor = _getRoleColor();
//
//     return Container(
//       margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
//       decoration: BoxDecoration(
//         color: Theme.of(context).cardColor,
//         borderRadius: AppTheme.borderRadiusXl,
//         border: Border.all(color: AppTheme.getBorder(context), width: 1),
//       ),
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           onTap: isLoading ? null : onTap,
//           borderRadius: AppTheme.borderRadiusXl,
//           child: Padding(
//             padding: const EdgeInsets.all(AppTheme.spaceMd),
//             child: Row(
//               children: [
//                 // Organization Icon
//                 Container(
//                   width: 56,
//                   height: 56,
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [roleColor.withValues(alpha: 0.7), roleColor],
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                     ),
//                     borderRadius: AppTheme.borderRadiusLg,
//                   ),
//                   child: const Icon(
//                     Icons.business_rounded,
//                     color: Colors.white,
//                     size: 28,
//                   ),
//                 ),
//                 const SizedBox(width: AppTheme.spaceMd),
//
//                 // Organization Info
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         org.name,
//                         style: Theme.of(context).textTheme.bodyLarge?.copyWith(
//                           fontWeight: FontWeight.w600,
//                         ),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                       const SizedBox(height: AppTheme.space2xs),
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: AppTheme.spaceXs,
//                           vertical: AppTheme.space2xs,
//                         ),
//                         decoration: BoxDecoration(
//                           color: roleColor.withValues(alpha: 0.1),
//                           borderRadius: AppTheme.borderRadiusSm,
//                         ),
//                         child: Text(
//                           role.toUpperCase(),
//                           style: Theme.of(context).textTheme.labelSmall
//                               ?.copyWith(
//                                 fontWeight: FontWeight.w700,
//                                 color: roleColor,
//                                 fontSize: 10,
//                               ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 // Arrow
//                 Icon(
//                   Icons.arrow_forward_ios_rounded,
//                   size: 16,
//                   color: AppTheme.getTextTertiary(context),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
