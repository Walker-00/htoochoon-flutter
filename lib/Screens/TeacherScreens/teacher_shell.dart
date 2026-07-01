import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/organisation_provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/subscription_provider.dart';
// TODO(enrollment): re-enable when the enrollment flow is reintroduced.
// import 'package:htoochoon_flutter/Screens/AdminScreens/enrollment_tab.dart';
import 'package:htoochoon_flutter/Screens/AdminScreens/live_sessions_screen.dart';
import 'package:htoochoon_flutter/Screens/AdminScreens/members_screen.dart';
import 'package:htoochoon_flutter/Screens/AdminScreens/settings_screen.dart';
import 'package:htoochoon_flutter/Screens/TeacherScreens/profile_detail_screen.dart';
import 'package:htoochoon_flutter/core/userorgrole_manager.dart';

import 'package:provider/provider.dart';
import 'package:htoochoon_flutter/Providers/auth_provider.dart';

// Import teacher screens (create these files)
import 'teacher_dashboard_screen.dart';
import 'teacher_programs_screen.dart';
import 'teacher_classes_screen.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';

// Navigate into classroom detail — adjust import to your actual screen path
// import 'package:htoochoon_flutter/Screens/ClassroomScreen/classroom_screen.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';

class TeacherShell extends StatefulWidget {
  final String organisationId;
  final VoidCallback onQuitOrganisation;

  const TeacherShell({
    super.key,
    required this.organisationId,
    required this.onQuitOrganisation,
  });

  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  int _selectedIndex = 0;
  late final List<_NavItem> _navItems;
  final userId = UserSessionManager.userId;
  @override
  void initState() {
    super.initState();
    //
    // final authProv = context.read<AuthProvider>();

    final teacherId = UserSessionManager.userId ?? '';
    _navItems = [
      _NavItem(
        label: 'Dashboard',
        icon: Icons.dashboard_rounded,
        screen: TeacherDashboardScreen(
          organisationId: widget.organisationId,
          teacherId: teacherId,
          isInShell: true,
        ),
      ),
      _NavItem(
        label: 'My Programs',
        icon: Icons.school_rounded,
        screen: TeacherProgramsScreen(
          organisationId: widget.organisationId,
          isInShell: true,
        ),
      ),
      _NavItem(
        label: 'My Classes',
        icon: Icons.class_rounded,
        screen: TeacherClassesScreen(
          teacherId: teacherId,
          organisationId: widget.organisationId,
          isInShell: true,
        ),
      ),
      // _NavItem(
      //   label: 'Members',
      //   icon: Icons.people,
      //   screen: MembersScreen(organisationId: widget.organisationId),
      // ),
      // TODO(enrollment): Self-service enrollment / pending-approvals is hidden
      // for now. Students are added by an org admin via email. Re-enable this
      // nav item (and the admin one in admin_shell.dart) when the enrollment
      // flow is reintroduced.
      // _NavItem(
      //   label: 'Enrollment',
      //   icon: Icons.inbox_sharp,
      //   screen: PendingApprovalsScreen(
      //     orgId: widget.organisationId,
      //     isInShell: true,
      //   ),
      // ),
      // _NavItem(
      //   label: 'Sessions',
      //   icon: Icons.videocam_rounded,
      //   screen: LiveSessionsScreen(organisationId: widget.organisationId),
      // ),
      _NavItem(
        label: 'Settings',
        icon: Icons.settings_rounded,
        screen: TeacherProfileScreen(
          onQuitOrganisation: widget.onQuitOrganisation,
          isInShell: true,
        ),
      ),
    ];

    Future.microtask(() {
      context.read<OrganizationProvider>().selectOrganisation(
        widget.organisationId,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().loadForOrg(widget.organisationId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;
    return isWide
        ? _TeacherDesktopLayout(
            items: _navItems,
            selectedIndex: _selectedIndex,
            onSelect: (i) => setState(() => _selectedIndex = i),
            onQuit: widget.onQuitOrganisation,
          )
        : _TeacherMobileLayout(
            items: _navItems,
            selectedIndex: _selectedIndex,
            onSelect: (i) => setState(() => _selectedIndex = i),
          );
  }
}

// ─────────────────────────────────────────────────────
// DESKTOP LAYOUT
// ─────────────────────────────────────────────────────
class _TeacherDesktopLayout extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onQuit;

  const _TeacherDesktopLayout({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Use a teal/green accent to visually distinguish teacher shell from admin
    const teacherColor = Color(0xFF0F7B6C);
    const teacherColorLight = Color(0xFF13A896);

    return Scaffold(
      backgroundColor: cs.surface,
      body: Row(
        children: [
          Container(
            width: 240,
            decoration: BoxDecoration(
              color: teacherColor,
              boxShadow: [
                BoxShadow(
                  color: teacherColor.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(4, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 28),
                  // Header: org name + teacher badge
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Consumer<OrganizationProvider>(
                            builder: (_, orgProv, __) => Text(
                              orgProv.selected?.name ?? 'Teacher Panel',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Teacher role badge
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'TEACHER',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Teacher name from AuthProvider
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                    child: Consumer<AuthProvider>(
                      builder: (_, authProv, __) {
                        final name = authProv.user?.name ?? '';
                        if (name.isEmpty) return const SizedBox.shrink();
                        return Row(
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Nav items
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _SidebarTile(
                        item: items[i],
                        selected: selectedIndex == i,
                        onTap: () => onSelect(i),
                        selectedColor: teacherColorLight,
                      ),
                    ),
                  ),
                  // Quit button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onQuit,
                        icon: Icon(
                          Icons.swap_horiz_rounded,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        label: Text(
                          'Quit Organisation',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: items[selectedIndex].screen),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// MOBILE LAYOUT
// ─────────────────────────────────────────────────────
class _TeacherMobileLayout extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _TeacherMobileLayout({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: items[selectedIndex].screen,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelect,
        backgroundColor: cs.surface,
        indicatorColor: const Color(0xFF0F7B6C).withValues(alpha: 0.15),
        destinations: items.map((item) {
          return NavigationDestination(
            icon: Icon(item.icon),
            label: item.label,
            selectedIcon: Icon(item.icon, color: const Color(0xFF0F7B6C)),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Sidebar tile
// ─────────────────────────────────────────────────────
class _SidebarTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;

  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final Widget screen;

  _NavItem({required this.label, required this.icon, required this.screen});
}
