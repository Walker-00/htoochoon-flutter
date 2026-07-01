import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'package:htoochoon_flutter/core/haptics.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Notificaton/announcements_widget.dart';
import 'package:htoochoon_flutter/Notificaton/noti&emails.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/organisation_provider.dart';

import 'package:htoochoon_flutter/Providers/auth_provider.dart';
import 'package:htoochoon_flutter/Providers/org_provider.dart';
import 'package:htoochoon_flutter/Providers/theme_provider.dart';
import 'package:htoochoon_flutter/Providers/login_provider.dart';
import 'package:htoochoon_flutter/Screens/Classes/classes_tab.dart';
import 'package:htoochoon_flutter/Screens/Courses/courses_tab.dart';
import 'package:htoochoon_flutter/Screens/Home/home_tab.dart';
import 'package:htoochoon_flutter/Screens/LMS/OrgMainScreens/org_context_loader.dart';
import 'package:htoochoon_flutter/Screens/LMS/OrgMainScreens/org_dashboard_wrapper.dart';
import 'package:htoochoon_flutter/Screens/Notification/notification.dart';

import 'package:htoochoon_flutter/Screens/Profile/profile_tab.dart'; // Implemented

import 'package:htoochoon_flutter/lms_demo/demo_constants.dart';
import 'package:htoochoon_flutter/lms_demo/demo_screens.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'package:htoochoon_flutter/Theme/themedata.dart';
import 'package:htoochoon_flutter/Live-Session/core/services/local_notification_service.dart';
import 'package:htoochoon_flutter/Live-Session/core/services/push_service.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  void _changeTab(int index) {
    if (index != _selectedIndex) Haptics.light();
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Widget> get _pages => [
    HomeTab(onProfileTap: () => _changeTab(3)),
    MyLearningTab(organisationId: "", onProfileTap: () => _changeTab(3)),
    CoursesTab(onProfileTap: () => _changeTab(3)),
    // OrgContextLoader(),
    // SettingsScreen(),
    // NotiAndEmails()
    // ProfileTab(),
    SettingsScreen(onProfileTap: () => _changeTab(3)),
    // NotificationsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();

      // Wait for SharedPreferences to finish loading
      if (!auth.initialized) {
        await Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 30));
          return !auth.initialized;
        });
      }

      try {
        if (auth.user == null) {
          logD("loadMe tryingggg");
          await auth.loadMe();
          logD(
            "loadMe ok cuz user was null ${auth.user!.absoluteAvatarUrl.toString()}",
          );
        }
      } catch (e) {
        logD("loadMe failed: $e");
      }

      // Ask for OS notification permission once we reach the authenticated
      // shell. This used to live only inside loadMe(), which the normal login
      // path skips (login sets auth.user directly) — so the system prompt never
      // appeared and heads-up notifications were silently dropped. Calling it
      // here covers every entry (fresh login, register, restored session); the
      // OS only ever prompts once, so repeated calls are safe.
      await LocalNotificationService.instance.requestPermission();
      // Register this device for background/terminated push now that we're
      // authenticated (idempotent upsert on the backend).
      await PushService.instance.registerToken();

      if (mounted) {
        context.read<OrganizationProvider>().loadOrganisations();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final isDesktop = width > 900;
    final isMobile = width < 700;

    final themeProvider = Provider.of<ThemeProvider>(context);
    // final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final orgProvider = context.watch<OrganizationProvider>();
    final authProvider = context.watch<AuthProvider>();
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (orgProvider.justSwitched) {
    //     // // Reset the switched flag
    //     // orgProvider.clearJustSwitched();
    //     //
    //     // Navigator.of(context).pushAndRemoveUntil(
    //     //   MaterialPageRoute(
    //     //     builder: (_) => PremiumDashboardWrapper(
    //     //       currentOrgID: orgProvider.currentOrgId,
    //     //       currentOrgName: orgProvider.currentOrgName ?? "Htoo Choon",
    //     //     ),
    //     //   ),
    //     //   (route) => false,
    //     // );
    //   }
    // });

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,

          // 📱 Mobile Drawer (optional)
          drawer: isMobile
              ? Drawer(
                  child: ListView(
                    children: [
                      const DrawerHeader(child: Text("Menu")),
                      _drawerItem(Icons.home, "Home", 0),
                      _drawerItem(Icons.class_, "Classes", 1),
                      _drawerItem(Icons.school, "Explore", 2),
                      // _drawerItem(Icons.business, "Organizations", 3),
                      _drawerItem(Icons.person, "Profile", 3),
                      _drawerItem(Icons.notifications, "Notifications", 4),
                    ],
                  ),
                )
              : null,

          body: Row(
            children: [
              // 🖥 Desktop Sidebar
              if (!isMobile)
                _PremiumNavigationRail(
                  isExtended: isDesktop,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    _changeTab(index);
                  },
                  themeProvider: themeProvider,
                  authProvider: authProvider,
                ),

              Expanded(
                child: IndexedStack(index: _selectedIndex, children: _pages),
              ),
            ],
          ),

          // 📱 Bottom Navigation for Mobile
          bottomNavigationBar: isMobile
              ? NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    _changeTab(index);
                  },
                  height: 64,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.auto_stories_outlined),
                      selectedIcon: Icon(Icons.auto_stories),
                      label: 'My learning',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.explore_outlined),
                      selectedIcon: Icon(Icons.explore),
                      label: 'Explore',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: 'Profile',
                    ),
                  ],
                )
              : null,
        ),

        // Loading overlay
        // GlobalOrgSwitchOverlay(loadingText: "Switching organization…"),
      ],
    );
  }

  Widget _drawerItem(IconData icon, String label, int index) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.inversePrimary),
      title: Text(
        label,
        style: TextStyle(color: Theme.of(context).colorScheme.inversePrimary),
      ),
      selected: _selectedIndex == index,
      onTap: () {
        Navigator.pop(context);
        _changeTab(index);
      },
    );
  }
}

/// Premium Navigation Rail with theme integration

class _PremiumNavigationRail extends StatelessWidget {
  final bool isExtended;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final ThemeProvider themeProvider;
  final AuthProvider authProvider;

  const _PremiumNavigationRail({
    required this.isExtended,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.themeProvider,
    required this.authProvider,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: isExtended ? 220 : 64,
      decoration: BoxDecoration(
        color: isDark ? cs.surface : cs.surface,
        border: Border(
          right: BorderSide(
            color: AppTheme.getBorder(context),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context, isExtended),

          const SizedBox(height: 8),

          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                navigationRailTheme: NavigationRailThemeData(
                  selectedIconTheme: IconThemeData(
                    color: cs.primary,
                    size: 22,
                  ),
                  unselectedIconTheme: IconThemeData(
                    color: cs.onSurfaceVariant,
                    size: 21,
                  ),
                  selectedLabelTextStyle: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  unselectedLabelTextStyle: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 13,
                  ),
                  indicatorColor: cs.primary.withValues(alpha: 0.1),
                  useIndicator: true,
                ),
              ),
                  child: NavigationRail(
                    extended: isExtended,
                    minExtendedWidth: 220,
                    backgroundColor: Colors.transparent,
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onDestinationSelected,
                    labelType: isExtended
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,

                    groupAlignment: -0.9,

                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: Text('Home'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.class_outlined),
                        selectedIcon: Icon(Icons.class_),
                        label: Text('My learning'),
                      ),

                      NavigationRailDestination(
                        icon: Icon(Icons.library_books_outlined),
                        selectedIcon: Icon(Icons.library_books),
                        label: Text('Courses'),
                      ),
                      // NavigationRailDestination(
                      //   icon: Icon(Icons.business_outlined),
                      //   selectedIcon: Icon(Icons.business),
                      //   label: Text('Org'),
                      // ),
                      NavigationRailDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person),
                        label: Text('Profile'),
                      ),
                      // NavigationRailDestination(
                      //   icon: Icon(Icons.notifications_outlined),
                      //   selectedIcon: Icon(Icons.notifications),
                      //   label: Text('Notifications'),
                      // ),
                    ],
                  ),
                ),
              ),

              Divider(height: 1, color: AppTheme.getBorder(context)),

              _buildFooter(context, isExtended),
            ],
          ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isExtended) {
    return Padding(
      padding: EdgeInsets.all(isExtended ? 16 : 10),
      child: Row(
        mainAxisAlignment: isExtended
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/logos/main_logo.jpeg',
              height: 40,
            ),
          ),
          if (isExtended) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "HTOO CHOON",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    "Learning Platform",
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isExtended) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          SizedBox(height: 10),

          _FooterButton(
            icon: themeProvider.isDarkMode
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined,
            label: "Theme",
            isExtended: isExtended,
            onTap: () => themeProvider.toggleTheme(),
          ),
          SizedBox(height: 10),
          // _FooterButton(
          //   icon: Icons.settings,
          //   label: "Profile",
          //   isExtended: isExtended,
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (context) => SettingsScreen()),
          //     );
          //   },
          // ),
          // SizedBox(height: 10),
          // _FooterButton(
          //   icon: Icons.settings,
          //   label: "Settings",
          //   isExtended: isExtended,
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (context) => SettingsScreen()),
          //     );
          //   },
          // ),
          const SizedBox(height: 6),

          // _FooterButton(
          //   icon: Icons.logout_rounded,
          //   label: "Logout",
          //   isExtended: isExtended,
          //   color: Colors.orange,
          //   onTap: () => loginProvider.logout(context),
          // ),
        ],
      ),
    );
  }
}

class _FooterButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isExtended;
  final VoidCallback onTap;
  final Color? color;

  const _FooterButton({
    required this.icon,
    required this.label,
    required this.isExtended,
    required this.onTap,
    this.color,
  });

  @override
  State<_FooterButton> createState() => _FooterButtonState();
}

class _FooterButtonState extends State<_FooterButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppTheme.getTextSecondary(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: AppTheme.borderRadiusMd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: widget.isExtended
                  ? AppTheme.spaceMd
                  : AppTheme.spaceXs,
              vertical: AppTheme.spaceSm,
            ),
            decoration: BoxDecoration(
              color: _isHovered
                  ? AppTheme.getSurfaceVariant(context)
                  : Colors.transparent,
              borderRadius: AppTheme.borderRadiusMd,
            ),
            child: Row(
              mainAxisAlignment: widget.isExtended
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: color, size: 20),
                if (widget.isExtended) ...[
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// HERE!!! Global loading overlay for organization operations
class GlobalOrgSwitchOverlay extends StatelessWidget {
  final String loadingText;

  const GlobalOrgSwitchOverlay({super.key, required this.loadingText});

  @override
  Widget build(BuildContext context) {
    return Consumer<OrganizationProvider>(
      builder: (_, provider, __) {
        if (!provider.isLoading) return const SizedBox.shrink();

        return Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.6),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 120,
                    width: 120,
                    child: Lottie.asset(
                      'assets/lottie/networking.json',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  Text(
                    loadingText,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Widget _categoryLabel(BuildContext context, String title, bool isExtended) {
  if (!isExtended) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
    child: Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
