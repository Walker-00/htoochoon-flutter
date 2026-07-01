// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/foundation.dart';
//
// import '../../models/api_models/organization_model.dart';
// // ─── Breakpoints ─────────────────────────────────────────────────────────────
//
// class _Breakpoints {
//   static bool isMobile(BuildContext ctx) => MediaQuery.of(ctx).size.width < 600;
//   static bool isTablet(BuildContext ctx) =>
//       MediaQuery.of(ctx).size.width >= 600 &&
//       MediaQuery.of(ctx).size.width < 1024;
//   static bool isDesktop(BuildContext ctx) =>
//       MediaQuery.of(ctx).size.width >= 1024;
// }
//
// // ─── Main Screen ─────────────────────────────────────────────────────────────
//
// class SettingsScreen extends StatefulWidget {
//   const SettingsScreen({super.key});
//
//   @override
//   State<SettingsScreen> createState() => _SettingsScreenState();
// }
//
// class _SettingsScreenState extends State<SettingsScreen> {
//   // State
//   bool _darkMode = false;
//   String _language = 'English (US)';
//   bool _notifyMaterials = true;
//   bool _notifyInsights = true;
//
//   // Loaded data
//   User? _user;
//   List<OrganizationResponse> _orgs = [];
//   bool _loading = true;
//   String? _error;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }
//
//   Future<void> _loadData() async {
//     // Simulate network delay — replace with real ApiService calls:
//     //   final user = await apiService.fetchMe();
//     //   final orgs = await apiService.getOrganizations();
//     await Future.delayed(const Duration(milliseconds: 800));
//     setState(() {
//       _user = User(fullName: 'Alex Thompson', email: 'alex.t@htoochoon.edu');
//       _orgs = [
//         OrganizationResponse(
//           id: '1',
//           name: 'Global Design Academy',
//           activeStudents: 1240,
//           role: 'ADMIN',
//           iconType: 'graduation',
//         ),
//         OrganizationResponse(
//           id: '2',
//           name: 'Modern Code Labs',
//           activeStudents: 85,
//           role: 'INSTRUCTOR',
//           iconType: 'code',
//         ),
//       ];
//       _loading = false;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final isDesktop = _Breakpoints.isDesktop(context);
//     final isMobile = _Breakpoints.isMobile(context);
//
//     return Scaffold(
//       backgroundColor: _AppColors.surface,
//       body: Column(
//         children: [
//           _TopBar(isMobile: isMobile),
//           Expanded(
//             child: _loading
//                 ? const Center(
//                     child: CircularProgressIndicator(color: _AppColors.teal),
//                   )
//                 : _error != null
//                 ? Center(child: Text(_error!))
//                 : SingleChildScrollView(
//                     padding: EdgeInsets.symmetric(
//                       horizontal: isMobile ? 16 : 32,
//                       vertical: 24,
//                     ),
//                     child: isDesktop
//                         ? _DesktopLayout(
//                             user: _user!,
//                             orgs: _orgs,
//                             darkMode: _darkMode,
//                             language: _language,
//                             notifyMaterials: _notifyMaterials,
//                             notifyInsights: _notifyInsights,
//                             onDarkModeChanged: (v) =>
//                                 setState(() => _darkMode = v),
//                             onLanguageChanged: (v) =>
//                                 setState(() => _language = v ?? _language),
//                             onNotifyMaterialsChanged: (v) =>
//                                 setState(() => _notifyMaterials = v ?? false),
//                             onNotifyInsightsChanged: (v) =>
//                                 setState(() => _notifyInsights = v ?? false),
//                           )
//                         : _MobileLayout(
//                             user: _user!,
//                             orgs: _orgs,
//                             darkMode: _darkMode,
//                             language: _language,
//                             notifyMaterials: _notifyMaterials,
//                             notifyInsights: _notifyInsights,
//                             onDarkModeChanged: (v) =>
//                                 setState(() => _darkMode = v),
//                             onLanguageChanged: (v) =>
//                                 setState(() => _language = v ?? _language),
//                             onNotifyMaterialsChanged: (v) =>
//                                 setState(() => _notifyMaterials = v ?? false),
//                             onNotifyInsightsChanged: (v) =>
//                                 setState(() => _notifyInsights = v ?? false),
//                           ),
//                   ),
//           ),
//           _Footer(isMobile: isMobile),
//         ],
//       ),
//     );
//   }
// }
//
// // ─── Top Bar ─────────────────────────────────────────────────────────────────
//
// class _TopBar extends StatelessWidget {
//   final bool isMobile;
//   const _TopBar({required this.isMobile});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: Colors.white,
//       padding: EdgeInsets.symmetric(
//         horizontal: isMobile ? 16 : 32,
//         vertical: 12,
//       ),
//       child: Row(
//         children: [
//           const Text(
//             'Settings',
//             style: TextStyle(
//               fontSize: 22,
//               fontWeight: FontWeight.w700,
//               color: _AppColors.textPrimary,
//             ),
//           ),
//           const Spacer(),
//           if (!isMobile)
//             SizedBox(
//               width: 280,
//               child: TextField(
//                 decoration: InputDecoration(
//                   hintText: 'Search settings...',
//                   hintStyle: const TextStyle(
//                     color: _AppColors.textMuted,
//                     fontSize: 14,
//                   ),
//                   prefixIcon: const Icon(
//                     Icons.search,
//                     color: _AppColors.textMuted,
//                     size: 18,
//                   ),
//                   filled: true,
//                   fillColor: _AppColors.surface,
//                   contentPadding: const EdgeInsets.symmetric(vertical: 8),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(24),
//                     borderSide: BorderSide.none,
//                   ),
//                 ),
//               ),
//             ),
//           const SizedBox(width: 12),
//           const Icon(
//             Icons.help_outline,
//             color: _AppColors.textSecondary,
//             size: 22,
//           ),
//           const SizedBox(width: 12),
//           CircleAvatar(
//             radius: 18,
//             backgroundColor: _AppColors.teal,
//             child: const Text(
//               'AT',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 12,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ─── Desktop Layout ───────────────────────────────────────────────────────────
//
// class _DesktopLayout extends StatelessWidget {
//   final User user;
//   final List<OrganizationResponse> orgs;
//   final bool darkMode;
//   final String language;
//   final bool notifyMaterials;
//   final bool notifyInsights;
//   final ValueChanged<bool> onDarkModeChanged;
//   final ValueChanged<String?> onLanguageChanged;
//   final ValueChanged<bool?> onNotifyMaterialsChanged;
//   final ValueChanged<bool?> onNotifyInsightsChanged;
//
//   const _DesktopLayout({
//     required this.user,
//     required this.orgs,
//     required this.darkMode,
//     required this.language,
//     required this.notifyMaterials,
//     required this.notifyInsights,
//     required this.onDarkModeChanged,
//     required this.onLanguageChanged,
//     required this.onNotifyMaterialsChanged,
//     required this.onNotifyInsightsChanged,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         // Left column
//         Expanded(
//           flex: 3,
//           child: Column(
//             children: [
//               _ProfileCard(user: user),
//               const SizedBox(height: 20),
//               _OrganizationsCard(orgs: orgs),
//             ],
//           ),
//         ),
//         const SizedBox(width: 20),
//         // Right column
//         SizedBox(
//           width: 320,
//           child: Column(
//             children: [
//               _PreferencesCard(
//                 darkMode: darkMode,
//                 language: language,
//                 notifyMaterials: notifyMaterials,
//                 notifyInsights: notifyInsights,
//                 onDarkModeChanged: onDarkModeChanged,
//                 onLanguageChanged: onLanguageChanged,
//                 onNotifyMaterialsChanged: onNotifyMaterialsChanged,
//                 onNotifyInsightsChanged: onNotifyInsightsChanged,
//               ),
//               const SizedBox(height: 20),
//               const _SecurityCard(),
//               const SizedBox(height: 20),
//               const _AIInsightCard(),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// // ─── Mobile Layout ────────────────────────────────────────────────────────────
//
// class _MobileLayout extends StatelessWidget {
//   final User user;
//   final List<OrganizationResponse> orgs;
//   final bool darkMode;
//   final String language;
//   final bool notifyMaterials;
//   final bool notifyInsights;
//   final ValueChanged<bool> onDarkModeChanged;
//   final ValueChanged<String?> onLanguageChanged;
//   final ValueChanged<bool?> onNotifyMaterialsChanged;
//   final ValueChanged<bool?> onNotifyInsightsChanged;
//
//   const _MobileLayout({
//     required this.user,
//     required this.orgs,
//     required this.darkMode,
//     required this.language,
//     required this.notifyMaterials,
//     required this.notifyInsights,
//     required this.onDarkModeChanged,
//     required this.onLanguageChanged,
//     required this.onNotifyMaterialsChanged,
//     required this.onNotifyInsightsChanged,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         _ProfileCard(user: user),
//         const SizedBox(height: 16),
//         _PreferencesCard(
//           darkMode: darkMode,
//           language: language,
//           notifyMaterials: notifyMaterials,
//           notifyInsights: notifyInsights,
//           onDarkModeChanged: onDarkModeChanged,
//           onLanguageChanged: onLanguageChanged,
//           onNotifyMaterialsChanged: onNotifyMaterialsChanged,
//           onNotifyInsightsChanged: onNotifyInsightsChanged,
//         ),
//         const SizedBox(height: 16),
//         _OrganizationsCard(orgs: orgs),
//         const SizedBox(height: 16),
//         const _SecurityCard(),
//         const SizedBox(height: 16),
//         const _AIInsightCard(),
//         const SizedBox(height: 16),
//       ],
//     );
//   }
// }
//
// // ─── Profile Card ─────────────────────────────────────────────────────────────
//
// class _ProfileCard extends StatelessWidget {
//   final User user;
//   const _ProfileCard({required this.user});
//
//   @override
//   Widget build(BuildContext context) {
//     return _Card(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Profile Information',
//                       style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.w700,
//                         color: _AppColors.textPrimary,
//                       ),
//                     ),
//                     const SizedBox(height: 6),
//                     const Text(
//                       'Update your personal details and how others see you on the platform.',
//                       style: TextStyle(
//                         fontSize: 13,
//                         color: _AppColors.textSecondary,
//                         height: 1.5,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(width: 16),
//               ElevatedButton(
//                 onPressed: () {},
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: _AppColors.teal,
//                   foregroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 20,
//                     vertical: 14,
//                   ),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   elevation: 0,
//                 ),
//                 child: const Text(
//                   'Update\nProfile',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),
//           Container(
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: _AppColors.surface,
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Row(
//               children: [
//                 // Avatar
//                 Stack(
//                   children: [
//                     Container(
//                       width: 72,
//                       height: 72,
//                       decoration: BoxDecoration(
//                         color: _AppColors.avatarBg,
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: const Icon(
//                         Icons.person,
//                         color: Colors.white,
//                         size: 36,
//                       ),
//                     ),
//                     Positioned(
//                       bottom: 2,
//                       right: 2,
//                       child: Container(
//                         width: 22,
//                         height: 22,
//                         decoration: BoxDecoration(
//                           color: _AppColors.textSecondary,
//                           shape: BoxShape.circle,
//                           border: Border.all(color: Colors.white, width: 2),
//                         ),
//                         child: const Icon(
//                           Icons.camera_alt,
//                           size: 11,
//                           color: Colors.white,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(width: 16),
//                 Expanded(
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: _LabeledField(
//                           label: 'FULL NAME',
//                           value: user.fullName,
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: _LabeledField(
//                           label: 'EMAIL ADDRESS',
//                           value: user.email,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _LabeledField extends StatelessWidget {
//   final String label;
//   final String value;
//   const _LabeledField({required this.label, required this.value});
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 10,
//             fontWeight: FontWeight.w600,
//             color: _AppColors.textMuted,
//             letterSpacing: 0.8,
//           ),
//         ),
//         const SizedBox(height: 6),
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(8),
//             border: Border.all(color: _AppColors.border),
//           ),
//           child: Text(
//             value,
//             style: const TextStyle(
//               fontSize: 13,
//               color: _AppColors.textPrimary,
//               fontWeight: FontWeight.w500,
//             ),
//             overflow: TextOverflow.ellipsis,
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// // ─── Organizations Card ───────────────────────────────────────────────────────
//
// class _OrganizationsCard extends StatelessWidget {
//   final List<OrganizationResponse> orgs;
//   const _OrganizationsCard({required this.orgs});
//
//   @override
//   Widget build(BuildContext context) {
//     final isMobile = _Breakpoints.isMobile(context);
//
//     return _Card(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               const Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'My Organizations',
//                       style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.w700,
//                         color: _AppColors.textPrimary,
//                       ),
//                     ),
//                     SizedBox(height: 4),
//                     Text(
//                       'Manage your institutional roles and associations.',
//                       style: TextStyle(
//                         fontSize: 13,
//                         color: _AppColors.textSecondary,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(width: 12),
//               OutlinedButton.icon(
//                 onPressed: () {},
//                 icon: const Icon(Icons.add, size: 16),
//                 label: const Text(
//                   'Start your own Organization',
//                   style: TextStyle(fontSize: 12),
//                 ),
//                 style: OutlinedButton.styleFrom(
//                   foregroundColor: _AppColors.teal,
//                   side: const BorderSide(color: _AppColors.teal, width: 1.5),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 14,
//                     vertical: 12,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),
//           isMobile
//               ? Column(
//                   children: orgs
//                       .map(
//                         (o) => Padding(
//                           padding: const EdgeInsets.only(bottom: 12),
//                           child: _OrgTile(org: o),
//                         ),
//                       )
//                       .toList(),
//                 )
//               : Row(
//                   children: orgs
//                       .map(
//                         (o) => Expanded(
//                           child: Padding(
//                             padding: EdgeInsets.only(
//                               right: o == orgs.last ? 0 : 12,
//                             ),
//                             child: _OrgTile(org: o),
//                           ),
//                         ),
//                       )
//                       .toList(),
//                 ),
//         ],
//       ),
//     );
//   }
// }
//
// class _OrgTile extends StatelessWidget {
//   final OrganizationResponse org;
//   const _OrgTile({required this.org});
//
//   Color get _badgeColor =>
//       org.role == 'ADMIN' ? _AppColors.adminBadge : _AppColors.instructorBadge;
//
//   Color get _iconBg => org.iconType == 'graduation'
//       ? const Color(0xFFD0EBF0)
//       : const Color(0xFFD0F0E8);
//
//   Color get _iconColor => org.iconType == 'graduation'
//       ? _AppColors.teal
//       : _AppColors.instructorBadge;
//
//   IconData get _icon =>
//       org.iconType == 'graduation' ? Icons.school : Icons.code;
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border(
//           left: BorderSide(color: _badgeColor, width: 4),
//           top: BorderSide(color: _AppColors.border),
//           right: BorderSide(color: _AppColors.border),
//           bottom: BorderSide(color: _AppColors.border),
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Container(
//                 width: 42,
//                 height: 42,
//                 decoration: BoxDecoration(
//                   color: _iconBg,
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: Icon(_icon, color: _iconColor, size: 20),
//               ),
//               Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 10,
//                   vertical: 4,
//                 ),
//                 decoration: BoxDecoration(
//                   color: _badgeColor,
//                   borderRadius: BorderRadius.circular(6),
//                 ),
//                 child: Text(
//                   org.role,
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 11,
//                     fontWeight: FontWeight.w700,
//                     letterSpacing: 0.5,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Text(
//             org.name,
//             style: const TextStyle(
//               fontSize: 15,
//               fontWeight: FontWeight.w700,
//               color: _AppColors.textPrimary,
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             '${org.activeStudents.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} active students',
//             style: const TextStyle(
//               fontSize: 12,
//               color: _AppColors.textSecondary,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ─── Preferences Card ─────────────────────────────────────────────────────────
//
// class _PreferencesCard extends StatelessWidget {
//   final bool darkMode;
//   final String language;
//   final bool notifyMaterials;
//   final bool notifyInsights;
//   final ValueChanged<bool> onDarkModeChanged;
//   final ValueChanged<String?> onLanguageChanged;
//   final ValueChanged<bool?> onNotifyMaterialsChanged;
//   final ValueChanged<bool?> onNotifyInsightsChanged;
//
//   const _PreferencesCard({
//     required this.darkMode,
//     required this.language,
//     required this.notifyMaterials,
//     required this.notifyInsights,
//     required this.onDarkModeChanged,
//     required this.onLanguageChanged,
//     required this.onNotifyMaterialsChanged,
//     required this.onNotifyInsightsChanged,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return _Card(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               const Icon(Icons.tune, color: _AppColors.textPrimary, size: 20),
//               const SizedBox(width: 8),
//               const Text(
//                 'Preferences',
//                 style: TextStyle(
//                   fontSize: 17,
//                   fontWeight: FontWeight.w700,
//                   color: _AppColors.textPrimary,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           // Dark mode row
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
//             decoration: BoxDecoration(
//               color: _AppColors.surface,
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Row(
//               children: [
//                 const Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'Dark Mode',
//                         style: TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w600,
//                           color: _AppColors.textPrimary,
//                         ),
//                       ),
//                       SizedBox(height: 2),
//                       Text(
//                         'Switch to dark interface',
//                         style: TextStyle(
//                           fontSize: 12,
//                           color: _AppColors.textSecondary,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 Switch(
//                   value: darkMode,
//                   onChanged: onDarkModeChanged,
//                   activeColor: _AppColors.teal,
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 16),
//           // Language
//           const Text(
//             'Language',
//             style: TextStyle(
//               fontSize: 13,
//               fontWeight: FontWeight.w500,
//               color: _AppColors.textSecondary,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 12),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(10),
//               border: Border.all(color: _AppColors.border),
//             ),
//             child: DropdownButtonHideUnderline(
//               child: DropdownButton<String>(
//                 value: language,
//                 isExpanded: true,
//                 icon: const Icon(
//                   Icons.keyboard_arrow_down,
//                   color: _AppColors.textSecondary,
//                 ),
//                 style: const TextStyle(
//                   fontSize: 14,
//                   color: _AppColors.textPrimary,
//                 ),
//                 items: const [
//                   DropdownMenuItem(
//                     value: 'English (US)',
//                     child: Text('English (US)'),
//                   ),
//                   DropdownMenuItem(
//                     value: 'English (UK)',
//                     child: Text('English (UK)'),
//                   ),
//                   DropdownMenuItem(
//                     value: 'Nederlands',
//                     child: Text('Nederlands'),
//                   ),
//                   DropdownMenuItem(value: 'Deutsch', child: Text('Deutsch')),
//                 ],
//                 onChanged: onLanguageChanged,
//               ),
//             ),
//           ),
//           const SizedBox(height: 16),
//           // Notify me about
//           const Text(
//             'Notify me about',
//             style: TextStyle(
//               fontSize: 13,
//               fontWeight: FontWeight.w500,
//               color: _AppColors.textSecondary,
//             ),
//           ),
//           const SizedBox(height: 8),
//           _CheckboxRow(
//             label: 'New course materials',
//             value: notifyMaterials,
//             onChanged: onNotifyMaterialsChanged,
//           ),
//           const SizedBox(height: 6),
//           _CheckboxRow(
//             label: 'AI performance insights',
//             value: notifyInsights,
//             onChanged: onNotifyInsightsChanged,
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _CheckboxRow extends StatelessWidget {
//   final String label;
//   final bool value;
//   final ValueChanged<bool?> onChanged;
//
//   const _CheckboxRow({
//     required this.label,
//     required this.value,
//     required this.onChanged,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         SizedBox(
//           width: 22,
//           height: 22,
//           child: Checkbox(
//             value: value,
//             onChanged: onChanged,
//             activeColor: _AppColors.checkTeal,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(4),
//             ),
//           ),
//         ),
//         const SizedBox(width: 8),
//         Text(
//           label,
//           style: const TextStyle(fontSize: 14, color: _AppColors.textPrimary),
//         ),
//       ],
//     );
//   }
// }
//
// // ─── Security Card ────────────────────────────────────────────────────────────
//
// class _SecurityCard extends StatelessWidget {
//   const _SecurityCard();
//
//   @override
//   Widget build(BuildContext context) {
//     return _Card(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               const Icon(
//                 Icons.shield_outlined,
//                 color: _AppColors.textPrimary,
//                 size: 20,
//               ),
//               const SizedBox(width: 8),
//               const Text(
//                 'Security',
//                 style: TextStyle(
//                   fontSize: 17,
//                   fontWeight: FontWeight.w700,
//                   color: _AppColors.textPrimary,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 14),
//           // Change Password
//           InkWell(
//             onTap: () {},
//             borderRadius: BorderRadius.circular(10),
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(10),
//                 border: Border.all(color: _AppColors.border),
//               ),
//               child: const Row(
//                 children: [
//                   Icon(
//                     Icons.lock_outline,
//                     color: _AppColors.textSecondary,
//                     size: 18,
//                   ),
//                   SizedBox(width: 12),
//                   Expanded(
//                     child: Text(
//                       'Change Password',
//                       style: TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w500,
//                         color: _AppColors.textPrimary,
//                       ),
//                     ),
//                   ),
//                   Icon(
//                     Icons.chevron_right,
//                     color: _AppColors.textSecondary,
//                     size: 20,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           const SizedBox(height: 12),
//           // 2FA
//           Container(
//             padding: const EdgeInsets.all(14),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(10),
//               border: Border.all(color: _AppColors.border),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     const Text(
//                       '2FA Authentication',
//                       style: TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                         color: _AppColors.textPrimary,
//                       ),
//                     ),
//                     const SizedBox(width: 10),
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 10,
//                         vertical: 4,
//                       ),
//                       decoration: BoxDecoration(
//                         color: _AppColors.enabledBadge,
//                         borderRadius: BorderRadius.circular(6),
//                       ),
//                       child: const Text(
//                         'Enabled',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 11,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 6),
//                 const Text(
//                   'Two-factor authentication adds an extra layer of security to your account.',
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: _AppColors.textSecondary,
//                     height: 1.5,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ─── AI Insight Card ──────────────────────────────────────────────────────────
//
// class _AIInsightCard extends StatelessWidget {
//   const _AIInsightCard();
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: _AppColors.insightBg,
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Stack(
//         children: [
//           // Decorative large icon
//           Positioned(
//             right: -8,
//             bottom: -8,
//             child: Icon(
//               Icons.auto_awesome,
//               size: 64,
//               color: Colors.white.withValues(alpha: 0.08),
//             ),
//           ),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   const Icon(
//                     Icons.auto_awesome,
//                     color: Colors.white70,
//                     size: 16,
//                   ),
//                   const SizedBox(width: 8),
//                   Text(
//                     'AI SECURITY INSIGHT',
//                     style: TextStyle(
//                       color: Colors.white.withValues(alpha: 0.85),
//                       fontSize: 11,
//                       fontWeight: FontWeight.w700,
//                       letterSpacing: 1.2,
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 12),
//               const Text(
//                 'Your profile is 85% secure. Complete your bio and verification to reach 100%.',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 15,
//                   fontWeight: FontWeight.w500,
//                   height: 1.5,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ─── Shared Card wrapper ──────────────────────────────────────────────────────
//
// class _Card extends StatelessWidget {
//   final Widget child;
//   const _Card({required this.child});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(24),
//       decoration: BoxDecoration(
//         color: _AppColors.card,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: _AppColors.border),
//       ),
//       child: child,
//     );
//   }
// }
//
// // ─── Footer ───────────────────────────────────────────────────────────────────
//
// class _Footer extends StatelessWidget {
//   final bool isMobile;
//   const _Footer({required this.isMobile});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.symmetric(
//         horizontal: isMobile ? 16 : 32,
//         vertical: 16,
//       ),
//       decoration: const BoxDecoration(
//         border: Border(top: BorderSide(color: _AppColors.border)),
//       ),
//       child: isMobile
//           ? const Column(
//               children: [
//                 Text(
//                   '© 2024 HTOOCHOON LMS. ALL RIGHTS RESERVED.',
//                   style: TextStyle(
//                     fontSize: 10,
//                     color: _AppColors.textMuted,
//                     letterSpacing: 0.5,
//                   ),
//                 ),
//                 SizedBox(height: 8),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     _FooterLink(label: 'PRIVACY POLICY'),
//                     SizedBox(width: 16),
//                     _FooterLink(label: 'TERMS OF SERVICE'),
//                   ],
//                 ),
//               ],
//             )
//           : const Row(
//               children: [
//                 Text(
//                   '© 2024 HTOOCHOON LMS. ALL RIGHTS RESERVED.',
//                   style: TextStyle(
//                     fontSize: 11,
//                     color: _AppColors.textMuted,
//                     letterSpacing: 0.5,
//                   ),
//                 ),
//                 Spacer(),
//                 _FooterLink(label: 'PRIVACY POLICY'),
//                 SizedBox(width: 24),
//                 _FooterLink(label: 'TERMS OF SERVICE'),
//               ],
//             ),
//     );
//   }
// }
//
// class _FooterLink extends StatelessWidget {
//   final String label;
//   const _FooterLink({required this.label});
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: () {},
//       child: Text(
//         label,
//         style: const TextStyle(
//           fontSize: 11,
//           color: _AppColors.textMuted,
//           fontWeight: FontWeight.w600,
//           letterSpacing: 0.5,
//         ),
//       ),
//     );
//   }
// }
