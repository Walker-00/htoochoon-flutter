import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Notificaton/announcements_widget.dart';
import 'package:htoochoon_flutter/Notificaton/invitations_tab.dart';
import 'package:htoochoon_flutter/Providers/invitation_provider.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';
import 'package:provider/provider.dart';

class NotiAndEmails extends StatefulWidget {
  NotiAndEmails({super.key});

  @override
  State<NotiAndEmails> createState() => _NotiAndEmailsState();
}

class _NotiAndEmailsState extends State<NotiAndEmails>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      context.read<InvitationProvider>().init(vsync: this, email: user.email!);
    });
  }

  @override
  void dispose() {
    // InvitationProvider disposes its own tabController
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvitationProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Notifications',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: provider.tabController,
          labelStyle: Theme.of(context).textTheme.labelLarge,
          tabs: const [
            Tab(text: 'Invitations'),
            Tab(text: 'Announcements'),
          ],
        ),
      ),
      body: TabBarView(
        controller: provider.tabController,
        children: const [InvitationsTab(), AnnouncementsTab()],
      ),
    );
  }
}

class InvitationsTab extends StatelessWidget {
  const InvitationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvitationProvider>();
    final invites = provider.invitations;

    if (invites.isEmpty) {
      logD("invitation count: ${invites.length}");
      return const Center(child: Text('No invitations'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      itemCount: invites.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spaceMd),
      itemBuilder: (context, index) {
        return InvitationCard(inviteData: provider.invitations[index]);
      },
    );
  }
}

class InvitationCard extends StatefulWidget {
  final Map<String, dynamic> inviteData;

  const InvitationCard({super.key, required this.inviteData});
  @override
  State<InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends State<InvitationCard> {
  bool _isAccepted = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.inviteData;

    final user = FirebaseAuth.instance.currentUser!;
    final orgName = data['organizationName'] as String? ?? 'Organization';
    final role = data['role'] as String? ?? 'member';
    final invitedBy = data['invitedBy'] as String?;
    final status =
        (data['status'] as String?)?.trim().toLowerCase() ?? 'pending';
    final isAccepted = status == 'accepted';
    final isRejected = status == 'rejected';

    final isFinal = isAccepted || isRejected;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Header ----
          Row(
            children: [
              Icon(
                Icons.mail_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Text(
                  orgName,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spaceSm),

          Text('Invited as $role'),
          Text('Invited by $invitedBy'),

          const SizedBox(height: AppTheme.spaceMd),

          // ---- Status badge or buttons ----
          if (isFinal)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: isAccepted
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isAccepted ? Icons.check_circle : Icons.cancel,
                    color: isAccepted ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isAccepted ? 'Accepted' : 'Declined',
                    style: TextStyle(
                      color: isAccepted ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        context.read<InvitationProvider>().inviteIsLoading
                        ? null
                        : () async {
                            await context
                                .read<InvitationProvider>()
                                .rejectInvitation(
                                  inviteId: data['id'] ?? '',
                                  orgId: data['orgId'],
                                );
                          },
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        context.read<InvitationProvider>().inviteIsLoading
                        ? null
                        : () async {
                            try {
                              await context
                                  .read<InvitationProvider>()
                                  .acceptInvitation(
                                    orgId: data['orgId'],
                                    inviteId: data['id'] ?? '',
                                    userId: user.uid,
                                    email: user.email!,
                                  );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Failed to accept invitation. Please try again.',
                                  ),
                                ),
                              );
                            }
                          },
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Announcements Tab - Show system and organization announcements
class AnnouncementsTab extends StatelessWidget {
  const AnnouncementsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvitationProvider>();

    if (provider.announcements.isEmpty) {
      return const Center(child: Text('No announcements'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      itemCount: provider.announcements.length,
      itemBuilder: (context, index) {
        final data = provider.announcements[index];
        return _AnnouncementCard(
          title: data['title'] ?? '',
          message: data['message'] ?? '',
          type: AnnouncementType.info,
          date: data['date'] ?? '',
        );
      },
    );
  }
}

enum AnnouncementType { system, info, important }

class _AnnouncementCard extends StatelessWidget {
  final String title;
  final String message;
  final AnnouncementType type;
  final String date;

  const _AnnouncementCard({
    required this.title,
    required this.message,
    required this.type,
    required this.date,
  });

  Color _getTypeColor(BuildContext context) {
    switch (type) {
      case AnnouncementType.system:
        return AppTheme.info;
      case AnnouncementType.info:
        return AppTheme.success;
      case AnnouncementType.important:
        return AppTheme.warning;
    }
  }

  IconData _getTypeIcon() {
    switch (type) {
      case AnnouncementType.system:
        return Icons.settings;
      case AnnouncementType.info:
        return Icons.info_outline;
      case AnnouncementType.important:
        return Icons.priority_high;
    }
  }

  String _getTypeLabel() {
    switch (type) {
      case AnnouncementType.system:
        return 'SYSTEM';
      case AnnouncementType.info:
        return 'INFO';
      case AnnouncementType.important:
        return 'IMPORTANT';
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor(context);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.getBorder(context), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceXs),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: AppTheme.borderRadiusMd,
                ),
                child: Icon(_getTypeIcon(), color: typeColor, size: 20),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceXs,
                  vertical: AppTheme.space2xs,
                ),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: AppTheme.borderRadiusSm,
                ),
                child: Text(
                  _getTypeLabel(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: typeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                date,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getTextTertiary(context),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTheme.space2xs),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}
