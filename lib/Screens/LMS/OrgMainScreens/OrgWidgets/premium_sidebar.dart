// import 'package:flutter/material.dart';
// import 'package:htoochoon_flutter/Provider/organisation_provider.dart';
// import 'package:htoochoon_flutter/Providers/login_provider.dart';
// import 'package:htoochoon_flutter/Providers/org_provider.dart';
// import 'package:htoochoon_flutter/Providers/theme_provider.dart';
//
// import 'package:htoochoon_flutter/Theme/themedata.dart';
// import 'package:provider/provider.dart';
//
// /// Premium Sidebar Navigation
// /// Features:
// /// - Smooth transitions
// /// - Icon-first design
// /// - Clear visual hierarchy
// /// - Contextual user profile
// // premium_sidebar.dart
// // Refactored to match screenshot:
// //  - Org name + subtitle at top (no gradient icon box)
// //  - Nav items: icon + label, selected = primary color text/icon + right-side accent bar
// //  - No background fill on selected item (just color + accent border)
// //  - Section labels (MAIN, PEOPLE) only in extended mode
// //  - Footer: theme toggle, settings, user profile, exit org
// //  - Full AppTheme token usage, dark/light safe
// // premium_sidebar.dart
// // Refactored to match screenshot:
// //  - Org name + subtitle at top (no gradient icon box)
// //  - Nav items: icon + label, selected = primary color text/icon + right-side accent bar
// //  - No background fill on selected item (just color + accent border)
// //  - Section labels (MAIN, PEOPLE) only in extended mode
// //  - Footer: theme toggle, settings, user profile, exit org
// //  - Full AppTheme token usage, dark/light safe
//
// class PremiumSidebar extends StatelessWidget {
//   final int selectedIndex;
//   final ValueChanged<int> onDestinationSelected;
//   final bool isExtended;
//   final String? orgImageUrl;
//   final String orgName;
//
//   const PremiumSidebar({
//     super.key,
//     required this.selectedIndex,
//     required this.onDestinationSelected,
//     this.orgImageUrl,
//     required this.orgName,
//     required this.isExtended,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: isExtended ? 260 : 68,
//       decoration: BoxDecoration(
//         color: Theme.of(context).colorScheme.surface,
//         border: Border(
//           right: BorderSide(color: AppTheme.getBorder(context), width: 1),
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _buildHeader(context),
//
//           const SizedBox(height: AppTheme.spaceSm),
//
//           // ── Nav Items ──────────────────────────────────────────────────
//           Expanded(
//             child: SingleChildScrollView(
//               padding: EdgeInsets.symmetric(
//                 horizontal: isExtended ? AppTheme.spaceMd : AppTheme.spaceXs,
//                 vertical: AppTheme.spaceXs,
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   if (isExtended) _SectionLabel(label: 'MAIN'),
//
//                   _NavItem(
//                     icon: Icons.home_outlined,
//                     selectedIcon: Icons.home_rounded,
//                     label: 'Dashboard',
//                     isSelected: selectedIndex == 0,
//                     isExtended: isExtended,
//                     onTap: () => onDestinationSelected(0),
//                   ),
//                   _NavItem(
//                     icon: Icons.layers_outlined,
//                     selectedIcon: Icons.layers_rounded,
//                     label: 'Programs',
//                     isSelected: selectedIndex == 1,
//                     isExtended: isExtended,
//                     onTap: () => onDestinationSelected(1),
//                   ),
//
//                   if (isExtended) ...[
//                     const SizedBox(height: AppTheme.spaceMd),
//                     _SectionLabel(label: 'PEOPLE'),
//                   ] else
//                     const SizedBox(height: AppTheme.spaceSm),
//
//                   _NavItem(
//                     icon: Icons.people_outline_rounded,
//                     selectedIcon: Icons.people_rounded,
//                     label: 'All Members',
//                     isSelected: selectedIndex == 2,
//                     isExtended: isExtended,
//                     onTap: () => onDestinationSelected(2),
//                   ),
//                   _NavItem(
//                     icon: Icons.school_outlined,
//                     selectedIcon: Icons.school_rounded,
//                     label: 'Teachers',
//                     isSelected: selectedIndex == 3,
//                     isExtended: isExtended,
//                     onTap: () => onDestinationSelected(3),
//                   ),
//                   _NavItem(
//                     icon: Icons.person_outline_rounded,
//                     selectedIcon: Icons.person_rounded,
//                     label: 'Students',
//                     isSelected: selectedIndex == 4,
//                     isExtended: isExtended,
//                     onTap: () => onDestinationSelected(4),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//
//           Divider(height: 1, color: AppTheme.getBorder(context)),
//
//           _buildFooter(context),
//         ],
//       ),
//     );
//   }
//
//   // ── Header ───────────────────────────────────────────────────────────────
//
//   Widget _buildHeader(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.fromLTRB(
//         isExtended ? AppTheme.spaceLg : AppTheme.spaceMd,
//         AppTheme.spaceLg,
//         AppTheme.spaceMd,
//         AppTheme.spaceMd,
//       ),
//       decoration: BoxDecoration(
//         border: Border(
//           bottom: BorderSide(color: AppTheme.getBorder(context), width: 1),
//         ),
//       ),
//       child: isExtended
//           ? Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Org logo + name row
//                 Row(
//                   children: [
//                     _OrgAvatar(
//                       orgImageUrl: orgImageUrl,
//                       orgName: orgName,
//                       size: 36,
//                     ),
//                     const SizedBox(width: AppTheme.spaceSm),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             orgName,
//                             style: Theme.of(context).textTheme.titleMedium
//                                 ?.copyWith(
//                                   fontWeight: FontWeight.w700,
//                                   color: Theme.of(
//                                     context,
//                                   ).colorScheme.onSurface,
//                                 ),
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                           Text(
//                             'Modern LMS',
//                             style: Theme.of(context).textTheme.bodySmall
//                                 ?.copyWith(
//                                   color: AppTheme.getTextSecondary(context),
//                                   fontSize: 12,
//                                 ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             )
//           : Center(
//               child: _OrgAvatar(
//                 orgImageUrl: orgImageUrl,
//                 orgName: orgName,
//                 size: 32,
//               ),
//             ),
//     );
//   }
//
//   // ── Footer ───────────────────────────────────────────────────────────────
//
//   Widget _buildFooter(BuildContext context) {
//     final themeProvider = Provider.of<ThemeProvider>(context);
//     final orgProvider = Provider.of<OrganizationProvider>(context, listen: false);
//
//     return Padding(
//       padding: const EdgeInsets.all(AppTheme.spaceMd),
//       child: Column(
//         children: [
//           // Theme toggle
//           _FooterButton(
//             icon: themeProvider.isDarkMode
//                 ? Icons.dark_mode_rounded
//                 : Icons.light_mode_rounded,
//             label: themeProvider.isDarkMode ? 'Dark Mode' : 'Light Mode',
//             isExtended: isExtended,
//             onTap: themeProvider.toggleTheme,
//             trailing: isExtended
//                 ? Transform.scale(
//                     scale: 0.8,
//                     child: Switch(
//                       value: themeProvider.isDarkMode,
//                       onChanged: (_) => themeProvider.toggleTheme(),
//                       activeColor: Theme.of(context).colorScheme.primary,
//                     ),
//                   )
//                 : null,
//           ),
//
//           const SizedBox(height: AppTheme.space2xs),
//
//           _FooterButton(
//             icon: Icons.settings_outlined,
//             label: 'Settings',
//             isExtended: isExtended,
//             onTap: () {},
//           ),
//
//           const SizedBox(height: AppTheme.spaceSm),
//
//           _UserProfileCard(isExtended: isExtended),
//
//           const SizedBox(height: AppTheme.spaceSm),
//
//           _FooterButton(
//             icon: Icons.logout_rounded,
//             label: 'Exit Organization',
//             isExtended: isExtended,
//             onTap: orgProvider.leaveOrganisation,
//             color: AppTheme.warning,
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ── Org Avatar ───────────────────────────────────────────────────────────────
//
// class _OrgAvatar extends StatelessWidget {
//   final String? orgImageUrl;
//   final String orgName;
//   final double size;
//
//   const _OrgAvatar({
//     required this.orgImageUrl,
//     required this.orgName,
//     required this.size,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final primary = Theme.of(context).colorScheme.primary;
//     final initials = orgName.isNotEmpty
//         ? orgName
//               .trim()
//               .split(' ')
//               .take(2)
//               .map((w) => w[0].toUpperCase())
//               .join()
//         : '?';
//
//     return Container(
//       width: size,
//       height: size,
//       decoration: BoxDecoration(
//         color: primary.withValues(alpha: 0.12),
//         borderRadius: AppTheme.borderRadiusMd,
//         border: Border.all(color: primary.withValues(alpha: 0.25), width: 1),
//       ),
//       child: orgImageUrl != null
//           ? ClipRRect(
//               borderRadius: AppTheme.borderRadiusMd,
//               child: Image.asset(orgImageUrl!, fit: BoxFit.cover),
//             )
//           : Center(
//               child: Text(
//                 initials,
//                 style: TextStyle(
//                   color: primary,
//                   fontWeight: FontWeight.w700,
//                   fontSize: size * 0.35,
//                 ),
//               ),
//             ),
//     );
//   }
// }
//
// // ── Section Label ─────────────────────────────────────────────────────────────
//
// class _SectionLabel extends StatelessWidget {
//   final String label;
//
//   const _SectionLabel({required this.label});
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(
//         AppTheme.spaceSm,
//         AppTheme.spaceXs,
//         AppTheme.spaceSm,
//         AppTheme.space2xs,
//       ),
//       child: Text(
//         label,
//         style: Theme.of(context).textTheme.labelSmall?.copyWith(
//           color: AppTheme.getTextTertiary(context),
//           letterSpacing: 1.4,
//           fontWeight: FontWeight.w600,
//           fontSize: 10,
//         ),
//       ),
//     );
//   }
// }
//
// // ── Nav Item — right-accent selected style (matches screenshot) ──────────────
//
// class _NavItem extends StatefulWidget {
//   final IconData icon;
//   final IconData selectedIcon;
//   final String label;
//   final bool isSelected;
//   final bool isExtended;
//   final VoidCallback onTap;
//
//   const _NavItem({
//     required this.icon,
//     required this.selectedIcon,
//     required this.label,
//     required this.isSelected,
//     required this.isExtended,
//     required this.onTap,
//   });
//
//   @override
//   State<_NavItem> createState() => _NavItemState();
// }
//
// class _NavItemState extends State<_NavItem> {
//   bool _isHovered = false;
//
//   @override
//   Widget build(BuildContext context) {
//     final primary = Theme.of(context).colorScheme.primary;
//     final iconColor = widget.isSelected
//         ? primary
//         : _isHovered
//         ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75)
//         : AppTheme.getTextSecondary(context);
//
//     return MouseRegion(
//       onEnter: (_) => setState(() => _isHovered = true),
//       onExit: (_) => setState(() => _isHovered = false),
//       cursor: SystemMouseCursors.click,
//       child: GestureDetector(
//         onTap: widget.onTap,
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 180),
//           margin: const EdgeInsets.symmetric(vertical: 1),
//           decoration: BoxDecoration(
//             color: widget.isSelected
//                 ? primary.withValues(alpha: 0.07)
//                 : _isHovered
//                 ? AppTheme.getSurfaceVariant(context)
//                 : Colors.transparent,
//             borderRadius: AppTheme.borderRadiusMd,
//             // Right-side accent bar (visible in screenshot on selected item)
//             border: widget.isSelected
//                 ? Border(right: BorderSide(color: primary, width: 3))
//                 : null,
//           ),
//           padding: EdgeInsets.symmetric(
//             horizontal: widget.isExtended ? AppTheme.spaceMd : AppTheme.spaceSm,
//             vertical: AppTheme.spaceSm,
//           ),
//           child: Row(
//             mainAxisAlignment: widget.isExtended
//                 ? MainAxisAlignment.start
//                 : MainAxisAlignment.center,
//             children: [
//               Icon(
//                 widget.isSelected ? widget.selectedIcon : widget.icon,
//                 color: iconColor,
//                 size: 22,
//               ),
//               if (widget.isExtended) ...[
//                 const SizedBox(width: AppTheme.spaceSm),
//                 Expanded(
//                   child: Text(
//                     widget.label,
//                     style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                       color: widget.isSelected
//                           ? primary
//                           : AppTheme.getTextSecondary(context),
//                       fontWeight: widget.isSelected
//                           ? FontWeight.w600
//                           : FontWeight.w500,
//                     ),
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // ── Footer Button ────────────────────────────────────────────────────────────
//
// class _FooterButton extends StatefulWidget {
//   final IconData icon;
//   final String label;
//   final bool isExtended;
//   final VoidCallback onTap;
//   final Color? color;
//   final Widget? trailing;
//
//   const _FooterButton({
//     required this.icon,
//     required this.label,
//     required this.isExtended,
//     required this.onTap,
//     this.color,
//     this.trailing,
//   });
//
//   @override
//   State<_FooterButton> createState() => _FooterButtonState();
// }
//
// class _FooterButtonState extends State<_FooterButton> {
//   bool _isHovered = false;
//
//   @override
//   Widget build(BuildContext context) {
//     final color = widget.color ?? AppTheme.getTextSecondary(context);
//
//     return MouseRegion(
//       onEnter: (_) => setState(() => _isHovered = true),
//       onExit: (_) => setState(() => _isHovered = false),
//       cursor: SystemMouseCursors.click,
//       child: GestureDetector(
//         onTap: widget.onTap,
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 180),
//           padding: EdgeInsets.symmetric(
//             horizontal: widget.isExtended ? AppTheme.spaceMd : AppTheme.spaceSm,
//             vertical: AppTheme.spaceSm,
//           ),
//           decoration: BoxDecoration(
//             color: _isHovered
//                 ? AppTheme.getSurfaceVariant(context)
//                 : Colors.transparent,
//             borderRadius: AppTheme.borderRadiusMd,
//           ),
//           child: Row(
//             mainAxisAlignment: widget.isExtended
//                 ? MainAxisAlignment.start
//                 : MainAxisAlignment.center,
//             children: [
//               Icon(widget.icon, color: color, size: 20),
//               if (widget.isExtended) ...[
//                 const SizedBox(width: AppTheme.spaceSm),
//                 Expanded(
//                   child: Text(
//                     widget.label,
//                     style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                       color: color,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ),
//                 if (widget.trailing != null) widget.trailing!,
//               ],
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // ── User Profile Card ─────────────────────────────────────────────────────────
//
// class _UserProfileCard extends StatefulWidget {
//   final bool isExtended;
//
//   const _UserProfileCard({required this.isExtended});
//
//   @override
//   State<_UserProfileCard> createState() => _UserProfileCardState();
// }
//
// class _UserProfileCardState extends State<_UserProfileCard> {
//   bool _isHovered = false;
//
//   @override
//   Widget build(BuildContext context) {
//     return MouseRegion(
//       onEnter: (_) => setState(() => _isHovered = true),
//       onExit: (_) => setState(() => _isHovered = false),
//       cursor: SystemMouseCursors.click,
//       child: GestureDetector(
//         onTap: () {},
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 180),
//           padding: EdgeInsets.all(
//             widget.isExtended ? AppTheme.spaceSm : AppTheme.spaceXs,
//           ),
//           decoration: BoxDecoration(
//             color: _isHovered
//                 ? AppTheme.getSurfaceVariant(context)
//                 : AppTheme.getSurfaceVariant(context).withValues(alpha: 0.6),
//             borderRadius: AppTheme.borderRadiusMd,
//             border: Border.all(color: AppTheme.getBorder(context), width: 1),
//           ),
//           child: Row(
//             mainAxisAlignment: widget.isExtended
//                 ? MainAxisAlignment.start
//                 : MainAxisAlignment.center,
//             children: [
//               // Avatar
//               Container(
//                 width: 34,
//                 height: 34,
//                 decoration: BoxDecoration(
//                   gradient: const LinearGradient(
//                     colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                   ),
//                   borderRadius: BorderRadius.circular(AppTheme.radiusMd),
//                 ),
//                 child: const Center(
//                   child: Text(
//                     'AD',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 12,
//                       fontWeight: FontWeight.w700,
//                     ),
//                   ),
//                 ),
//               ),
//               if (widget.isExtended) ...[
//                 const SizedBox(width: AppTheme.spaceSm),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'Admin User',
//                         style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                           fontWeight: FontWeight.w600,
//                         ),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                       Text(
//                         'View profile',
//                         style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                           color: Theme.of(context).colorScheme.primary,
//                           fontSize: 11,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 Icon(
//                   Icons.chevron_right_rounded,
//                   size: 16,
//                   color: AppTheme.getTextTertiary(context),
//                 ),
//               ],
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
