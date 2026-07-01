import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:htoochoon_flutter/Providers/notification_provider.dart';

/// Per-user notification preferences: how chatty group chat should be, and
/// whether background push is delivered to this account at all.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<NotificationProvider>().loadPreferences());
  }

  static const _chatOptions = <String, ({String title, String subtitle})>{
    'ALL': (title: 'All messages', subtitle: 'Notify me about every chat message'),
    'MENTIONS': (
      title: 'Only when mentioned',
      subtitle: 'Notify me only when someone @-mentions me',
    ),
    'NONE': (title: 'Off', subtitle: 'Never notify me about chat'),
  };

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<NotificationProvider>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Notification settings')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text('CHAT',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 1)),
          ),
          for (final entry in _chatOptions.entries)
            RadioListTile<String>(
              value: entry.key,
              groupValue: prov.chatNotify,
              onChanged: (v) {
                if (v != null) {
                  context
                      .read<NotificationProvider>()
                      .updatePreferences(chatNotify: v);
                }
              },
              title: Text(entry.value.title),
              subtitle: Text(entry.value.subtitle),
            ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('PUSH',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 1)),
          ),
          SwitchListTile(
            value: prov.pushEnabled,
            onChanged: (v) => context
                .read<NotificationProvider>()
                .updatePreferences(pushEnabled: v),
            title: const Text('Background push notifications'),
            subtitle: const Text(
                'Receive notifications when the app is closed or in the background'),
          ),
        ],
      ),
    );
  }
}
