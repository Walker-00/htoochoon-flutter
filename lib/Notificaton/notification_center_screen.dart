import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:htoochoon_flutter/Providers/notification_provider.dart';
import 'package:htoochoon_flutter/models/api_models/notification_model.dart';
import 'package:htoochoon_flutter/Notificaton/notification_settings_screen.dart';
import 'package:htoochoon_flutter/Theme/skeletons.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});
  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<NotificationProvider>().refresh());
  }

  IconData _icon(String type) => switch (type) {
        'SESSION_LIVE' => Icons.sensors,
        'SESSION_SCHEDULED' => Icons.event_available_outlined,
        'NEW_MESSAGE' => Icons.chat_bubble_outline,
        'SUBMISSION_GRADED' => Icons.grading_outlined,
        'MATERIAL_NEW' => Icons.folder_open_outlined,
        _ => Icons.notifications_outlined,
      };

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<NotificationProvider>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (prov.unreadCount > 0)
            TextButton(
              onPressed: () => context.read<NotificationProvider>().markAllRead(),
              child: const Text('Mark all read'),
            ),
          IconButton(
            tooltip: 'Notification settings',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<NotificationProvider>().refresh(),
        child: prov.loading && prov.items.isEmpty
            ? const SkeletonList(count: 7)
            : prov.items.isEmpty
            ? ListView(children: [
                const SizedBox(height: 120),
                Icon(Icons.notifications_off_outlined,
                    size: 48, color: cs.onSurfaceVariant),
                const SizedBox(height: 12),
                Center(
                    child: Text('No notifications yet',
                        style: TextStyle(color: cs.onSurfaceVariant))),
              ])
            : ListView.separated(
                itemCount: prov.items.length + (prov.hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  if (i >= prov.items.length) {
                    context.read<NotificationProvider>().loadMore();
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final AppNotification n = prov.items[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: n.isRead
                          ? cs.surfaceContainerHighest
                          : cs.primaryContainer,
                      child: Icon(_icon(n.type),
                          color: n.isRead ? cs.onSurfaceVariant : cs.primary,
                          size: 20),
                    ),
                    title: Text(n.title,
                        style: TextStyle(
                            fontWeight:
                                n.isRead ? FontWeight.w500 : FontWeight.w700)),
                    subtitle: Text(n.body,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Text(_ago(n.createdAt),
                        style:
                            TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    onTap: () => context.read<NotificationProvider>().markRead(n),
                  );
                },
              ),
      ),
    );
  }
}
