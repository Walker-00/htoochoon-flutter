import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';
import 'package:htoochoon_flutter/Theme/peacock_logo.dart';
import 'package:htoochoon_flutter/Widgets/profile_menu.dart';
import 'package:htoochoon_flutter/Providers/notification_provider.dart';
import 'package:htoochoon_flutter/Notificaton/notification_center_screen.dart';
import 'package:htoochoon_flutter/Screens/Search/global_search_screen.dart';

class UserAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final IconData? leadIcon;
  final bool showSearchIcon;
  final VoidCallback onProfileTap;
  const UserAppBar({
    required this.onProfileTap,
    super.key,
    this.title = '',
    this.leadIcon,
    required this.showSearchIcon,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      scrolledUnderElevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      title: Row(
        children: [
          // 🦚 Peacock brand mark
          const PeacockLogo(size: 30),
          const SizedBox(width: AppTheme.spaceSm),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
          ),
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppTheme.getBorder(context)),
            ),
          ),
          icon: Icon(Icons.search,
              size: 20, color: AppTheme.getTextSecondary(context)),
        ),
        const SizedBox(width: AppTheme.spaceXs),
        Builder(builder: (context) {
          final unread = context.watch<NotificationProvider>().unreadCount;
          return IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationCenterScreen(),
              ),
            ),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppTheme.getBorder(context)),
              ),
            ),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: Icon(
                Icons.notifications_outlined,
                size: 20,
                color: AppTheme.getTextSecondary(context),
              ),
            ),
          );
        }),

        const SizedBox(width: AppTheme.spaceMd),

        ProfileMenu(onProfileTabTap: onProfileTap),

        const SizedBox(width: AppTheme.spaceLg),
      ],
    );
  }
}
