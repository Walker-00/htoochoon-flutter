import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/auth_provider.dart';
import 'package:htoochoon_flutter/Screens/AuthScreens/login_screen.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';
import 'package:htoochoon_flutter/core/userorgrole_manager.dart';
import 'package:provider/provider.dart';

class ProfileMenu extends StatelessWidget {
  // 🎯 Add a clean callback hook to notify MainScaffold to change tabs
  final VoidCallback onProfileTabTap;

  const ProfileMenu({super.key, required this.onProfileTabTap});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = UserSessionManager.user;

    final ImageProvider avatarImage =
        (user?.absoluteAvatarUrl != null && user!.absoluteAvatarUrl!.isNotEmpty)
        ? NetworkImage(user.absoluteAvatarUrl!)
        : const NetworkImage("https://i.pravatar.cc/150?img=12");

    return Material(
      type: MaterialType.transparency,
      child: PopupMenuButton<int>(
        tooltip: "",
        offset: const Offset(0, 45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: Theme.of(context).cardColor,
        // ✅ Rule everything cleanly inside onSelected
        onSelected: (value) {
          if (value == 1 || value == 2) {
            // 🚀 Switch directly to index 3 (Profile/Settings view) in MainScaffold
            onProfileTabTap();
          } else if (value == 3) {
            authProvider.logout();
            Future.microtask(() {
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const PremiumLoginScreen(),
                  ),
                  (route) => false,
                );
              }
            });
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 0,
            enabled: false,
            child: _ProfileHeader(),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 1,
            child: _MenuItemRow(icon: Icons.person_outline, label: "Profile"),
          ),
          const PopupMenuItem(
            value: 2,
            child: _MenuItemRow(
              icon: Icons.settings_outlined,
              label: "Settings",
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 3,
            child: _MenuItemRow(
              icon: Icons.logout,
              label: "Logout",
              isDanger: true,
            ),
          ),
        ],
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppTheme.getBorder(context)),
            ),
            child: CircleAvatar(radius: 18, backgroundImage: avatarImage),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    final user = UserSessionManager.user;

    // Build the dynamic image provider matching our new model setup
    final ImageProvider avatarImage =
        (user?.absoluteAvatarUrl != null && user!.absoluteAvatarUrl!.isNotEmpty)
        ? NetworkImage(user.absoluteAvatarUrl!)
        : const NetworkImage("https://i.pravatar.cc/150?img=12");

    return Consumer<AuthProvider>(
      builder: (context, authProv, child) => Row(
        children: [
          CircleAvatar(radius: 20, backgroundImage: avatarImage),
          const SizedBox(width: 12),
          if (authProv.user != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    authProv.user!.name.toString(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    authProv.user!.email.toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            )
          else
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

// 💡 CHANGED: Simplified to a layout Row widget.
// PopupMenuItem already handles its own tap animations and feedback cleanly.
class _MenuItemRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDanger;

  const _MenuItemRow({
    required this.icon,
    required this.label,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? Colors.red : AppTheme.getTextTertiary(context);

    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
