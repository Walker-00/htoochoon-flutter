import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/organisation_provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/subscription_provider.dart';
import 'package:htoochoon_flutter/Screens/AdminScreens/classes_screen.dart';
import 'package:htoochoon_flutter/Screens/AdminScreens/courses_screen.dart';
import 'package:htoochoon_flutter/Screens/AdminScreens/dashboard_screen.dart';
// TODO(enrollment): re-enable when the enrollment flow is reintroduced.
// import 'package:htoochoon_flutter/Screens/AdminScreens/enrollment_tab.dart';
import 'package:htoochoon_flutter/Screens/AdminScreens/live_sessions_screen.dart';
import 'package:htoochoon_flutter/Screens/AdminScreens/members_screen.dart';
import 'package:htoochoon_flutter/Screens/AdminScreens/programs_screen.dart';
import 'package:htoochoon_flutter/Screens/AdminScreens/settings_screen.dart';
import 'package:htoochoon_flutter/core/userorgrole_manager.dart';
import 'package:provider/provider.dart';
// ── AdminShell ────────────────────────────────────────────────────────────────
//
// Changes vs original:
//  1. initState loads SubscriptionProvider for the org so every child screen
//     can call context.read<SubscriptionProvider>().canCreateCourse() etc.
//  2. DashboardScreen already calls DashboardProvider.loadDashboard() on its
//     own initState — no double-fetch needed.
//  3. The "Quit Organisation" button calls onQuitOrganisation which now also
//     triggers orgProv.leaveOrganisation() (wired in _OrganisationsCard).

class AdminShell extends StatefulWidget {
  final String organisationId;
  final VoidCallback onQuitOrganisation;

  const AdminShell({
    super.key,
    required this.organisationId,
    required this.onQuitOrganisation,
  });

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;
  final userId = UserSessionManager.userId;
  late final List<_NavItem> _navItems;

  @override
  void initState() {
    super.initState();

    _navItems = [
      _NavItem(
        label: 'Overview',
        icon: Icons.dashboard_rounded,
        screen: DashboardScreen(
          organisationId: widget.organisationId,
          isInShell: true,
        ),
      ),
      _NavItem(
        label: 'Members',
        icon: Icons.people_alt_rounded,
        screen: MembersScreen(
          organisationId: widget.organisationId,
          isInShell: true,
        ),
      ),
      _NavItem(
        label: 'Courses',
        icon: Icons.menu_book_rounded,
        screen: CoursesScreen(
          organisationId: widget.organisationId,
          accessedFrom: "Admin",
          isInShell: true,
        ),
      ),
      // _NavItem(
      //   label: 'Programs',
      //   icon: Icons.school_rounded,
      //   screen: ProgramsScreen(organisationId: widget.organisationId),
      // ),
      // _NavItem(
      //   label: 'Classes',
      //   icon: Icons.class_rounded,
      //   screen: const ClassesScreen(),
      // ),
      // _NavItem(
      //   label: 'Sessions',
      //   icon: Icons.videocam_rounded,
      //   screen: LiveSessionsScreen(organisationId: widget.organisationId),
      // ),
      // TODO(enrollment): Self-service enrollment / pending-approvals is hidden
      // for now. Students are added by an admin via email (Members). Re-enable
      // this nav item when the enrollment flow is reintroduced.
      // _NavItem(
      //   label: 'Enrollment',
      //   icon: Icons.inbox_sharp,
      //   screen: PendingApprovalsScreen(
      //     orgId: widget.organisationId,
      //     isInShell: true,
      //   ),
      // ),
      _NavItem(
        label: 'Settings',
        icon: Icons.settings_rounded,
        screen: SettingsScreen(
          organisationId: widget.organisationId,
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
    // Load subscription data once for the whole shell.
    // All child screens read from SubscriptionProvider via context.watch/read
    // — no need for each screen to fetch independently.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().loadForOrg(widget.organisationId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;
    return isWide
        ? _DesktopLayout(
            items: _navItems,
            selectedIndex: _selectedIndex,
            onSelect: (i) => setState(() => _selectedIndex = i),
            onQuit: widget.onQuitOrganisation,
          )
        : _MobileLayout(
            items: _navItems,
            selectedIndex: _selectedIndex,
            onSelect: (i) => setState(() => _selectedIndex = i),
          );
  }
}

// ─────────────────────────────────────────────────────
// DESKTOP LAYOUT  (unchanged except onQuit wiring)
// ─────────────────────────────────────────────────────
class _DesktopLayout extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onQuit;

  const _DesktopLayout({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Row(
        children: [
          Container(
            width: 240,
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                right: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5), width: 1),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.corporate_fare_rounded,
                            color: cs.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Consumer<OrganizationProvider>(
                            builder: (_, orgProv, __) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  orgProv.selected?.name ?? 'Admin Panel',
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Consumer<SubscriptionProvider>(
                                  builder: (_, subProv, __) {
                                    if (subProv.currentPlan == null) return const SizedBox.shrink();
                                    return Container(
                                      margin: const EdgeInsets.only(top: 3),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: cs.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        subProv.currentPlan!.planType.toUpperCase(),
                                        style: TextStyle(
                                          color: cs.primary,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _SidebarTile(
                        item: items[i],
                        selected: selectedIndex == i,
                        onTap: () => onSelect(i),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: onQuit,
                        icon: Icon(Icons.swap_horiz_rounded, size: 18, color: cs.onSurfaceVariant),
                        label: Text(
                          'Quit Organisation',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
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
// MOBILE LAYOUT  (unchanged)
// ─────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────
// MOBILE LAYOUT
// ─────────────────────────────────────────────────────
class _MobileLayout extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _MobileLayout({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Ensure selectedIndex is within bounds if items change dynamically
    final safeIndex = selectedIndex >= items.length ? 0 : selectedIndex;

    return Scaffold(
      body: items[safeIndex].screen,
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: onSelect,
        backgroundColor: cs.surface,
        indicatorColor: cs.primary.withValues(alpha: 0.12),
        destinations: items.map((item) {
          return NavigationDestination(
            icon: Icon(item.icon),
            label: item.label,
            selectedIcon: Icon(item.icon, color: cs.primary),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Sidebar tile (unchanged)
// ─────────────────────────────────────────────────────
class _SidebarTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? cs.primary.withValues(alpha: 0.1) : Colors.transparent,
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
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    color: selected ? cs.primary : cs.onSurface,
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
