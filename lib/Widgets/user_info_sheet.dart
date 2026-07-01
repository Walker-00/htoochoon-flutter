import 'package:flutter/material.dart';

import '../Screens/Discussion/dm_thread_screen.dart';

const String _kMediaBase = 'https://backend.htoochoon.com';

/// Bottom sheet showing a user's quick info, opened by tapping an @mention in
/// chat (or any avatar/name). Dismiss by tapping outside or dragging down.
///
/// [avatar] may be a full URL or a backend-relative path; both resolve.
/// When [userId] is provided, a "Message" button opens a 1:1 DM thread.
Future<void> showUserInfoSheet(
  BuildContext context, {
  required String name,
  String? userId,
  String? avatar,
  String? role,
  String? bio,
}) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _UserInfoCard(
      name: name,
      userId: userId,
      avatar: avatar,
      role: role,
      bio: bio,
    ),
  );
}

class _UserInfoCard extends StatelessWidget {
  final String name;
  final String? userId;
  final String? avatar;
  final String? role;
  final String? bio;
  const _UserInfoCard({
    required this.name,
    this.userId,
    this.avatar,
    this.role,
    this.bio,
  });

  String? get _avatarUrl {
    final a = avatar;
    if (a == null || a.isEmpty) return null;
    return a.startsWith('http') ? a : '$_kMediaBase$a';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = _avatarUrl;
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: cs.primaryContainer,
              backgroundImage: url != null ? NetworkImage(url) : null,
              child: url == null
                  ? Text(
                      initials.toUpperCase(),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimaryContainer,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            if (role != null && role!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  role!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: cs.onSecondaryContainer,
                  ),
                ),
              ),
            ],
            if (bio != null && bio!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                bio!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (userId != null && userId!.isNotEmpty) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DmThreadScreen(
                        peerId: userId!,
                        peerName: name,
                        peerAvatar: avatar,
                      ),
                    ));
                  },
                  icon: const Icon(Icons.send_outlined, size: 18),
                  label: const Text('Message'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
