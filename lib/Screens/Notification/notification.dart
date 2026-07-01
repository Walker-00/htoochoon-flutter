import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';

enum _NotifType {
  orgInvite,
  comment,
  announcement,
  badge,
  liveReminder,
  progressMilestone,
  newMaterial,
  graded,
}

class _Notif {
  final String id;
  final _NotifType type;
  final String title;
  final String body;
  final String time;
  final String? avatarInitials;
  final Color? avatarColor;
  final bool isRead;
  final bool isInvite; // shows Accept / Decline
  final String? orgName;

  const _Notif({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.avatarInitials,
    this.avatarColor,
    this.isRead = false,
    this.isInvite = false,
    this.orgName,
  });

  _Notif copyWith({bool? isRead}) => _Notif(
    id: id,
    type: type,
    title: title,
    body: body,
    time: time,
    avatarInitials: avatarInitials,
    avatarColor: avatarColor,
    isRead: isRead ?? this.isRead,
    isInvite: isInvite,
    orgName: orgName,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// ENTRY — NotificationsScreen
// ═══════════════════════════════════════════════════════════════════════════════

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _filterIndex = 0; // 0=All 1=Invites 2=Activity 3=Unread
  final Set<String> _dismissed = {};
  final Set<String> _accepted = {};
  final Set<String> _declined = {};

  static const List<String> _filters = ['All', 'Invites', 'Activity', 'Unread'];

  // ── Seed data ───────────────────────────────────────────────────────────────
  late final List<_Notif> _all = [
    _Notif(
      id: 'n1',
      type: _NotifType.orgInvite,
      title: 'Blabla Academy invited you',
      body: 'You\'ve been invited to join Blabla Academy as a Teacher.',
      time: '2 min ago',
      avatarInitials: 'BA',
      avatarColor: const Color(0xFF0D9488),
      isInvite: true,
      orgName: 'Blabla Academy',
    ),
    _Notif(
      id: 'n2',
      type: _NotifType.orgInvite,
      title: 'Global Design Academy invited you',
      body: 'Global Design Academy wants you to join as an Instructor.',
      time: '1 hr ago',
      avatarInitials: 'GD',
      avatarColor: const Color(0xFF7C3AED),
      isInvite: true,
      orgName: 'Global Design Academy',
    ),
    _Notif(
      id: 'n3',
      type: _NotifType.comment,
      title: '2 students commented on your material',
      body:
          'Sara K. and James R. left comments on "Intro to UX Research" · Harvard Organisation',
      time: '15 min ago',
      avatarInitials: 'SK',
      avatarColor: const Color(0xFF2563EB),
    ),
    _Notif(
      id: 'n4',
      type: _NotifType.liveReminder,
      title: 'Live class starting soon',
      body: '"Python Basics (Batch A)" with Dr. Smith begins in 30 minutes.',
      time: '28 min ago',
      avatarInitials: 'PS',
      avatarColor: const Color(0xFFD97706),
    ),
    _Notif(
      id: 'n5',
      type: _NotifType.graded,
      title: 'Your assignment was graded',
      body:
          'Prof. Johnson graded your "Week 3 Submission" — you scored 87/100.',
      time: '2 hrs ago',
      avatarInitials: 'PJ',
      avatarColor: const Color(0xFF059669),
      isRead: true,
    ),
    _Notif(
      id: 'n6',
      type: _NotifType.progressMilestone,
      title: 'Milestone reached 🎉',
      body: 'You\'ve completed 50% of "Web Development Bootcamp". Keep it up!',
      time: '3 hrs ago',
      avatarInitials: '50',
      avatarColor: const Color(0xFF0D9488),
      isRead: true,
    ),
    _Notif(
      id: 'n7',
      type: _NotifType.newMaterial,
      title: 'New material uploaded',
      body:
          'Dr. Smith added "Chapter 7: Recursion" to Python Basics (Batch A).',
      time: 'Yesterday',
      avatarInitials: 'DS',
      avatarColor: const Color(0xFF1D4ED8),
      isRead: true,
    ),
    _Notif(
      id: 'n8',
      type: _NotifType.announcement,
      title: 'Announcement from Harvard Organisation',
      body:
          'Mid-term exams are scheduled for April 14–18. Check your timetable.',
      time: 'Yesterday',
      avatarInitials: 'HO',
      avatarColor: const Color(0xFF9333EA),
      isRead: true,
    ),
    _Notif(
      id: 'n9',
      type: _NotifType.badge,
      title: 'You earned a new badge',
      body: '"7-Day Streak" badge awarded — you\'ve logged in 7 days in a row.',
      time: '2 days ago',
      avatarInitials: '🏅',
      avatarColor: const Color(0xFFF59E0B),
      isRead: true,
    ),
    _Notif(
      id: 'n10',
      type: _NotifType.comment,
      title: 'Reply on your comment',
      body:
          'Dr. Smith replied to your question in "Quantum Mechanics — Week 2 Q&A".',
      time: '2 days ago',
      avatarInitials: 'DS',
      avatarColor: const Color(0xFF1D4ED8),
      isRead: true,
    ),
  ];

  // ── Computed list ────────────────────────────────────────────────────────────
  List<_Notif> get _visible {
    final active = _all.where((n) => !_dismissed.contains(n.id)).toList();
    return switch (_filterIndex) {
      1 => active.where((n) => n.isInvite).toList(),
      2 => active.where((n) => !n.isInvite).toList(),
      3 => active.where((n) => !n.isRead).toList(),
      _ => active,
    };
  }

  int get _unreadCount =>
      _all.where((n) => !n.isRead && !_dismissed.contains(n.id)).length;

  void _markAllRead() => setState(() {
    for (final n in _all) {
      final idx = _all.indexOf(n);
      _all[idx] = n.copyWith(isRead: true);
    }
  });

  void _dismiss(String id) => setState(() => _dismissed.add(id));
  void _accept(String id) => setState(() {
    _accepted.add(id);
    _dismissed.add(id);
    // Show a brief snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Invitation accepted!'),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusMd),
      ),
    );
  });

  void _decline(String id) => setState(() {
    _declined.add(id);
    _dismissed.add(id);
  });

  // ── Icon per type ────────────────────────────────────────────────────────────
  IconData _typeIcon(_NotifType t) => switch (t) {
    _NotifType.orgInvite => Icons.group_add_rounded,
    _NotifType.comment => Icons.chat_bubble_outline_rounded,
    _NotifType.announcement => Icons.campaign_rounded,
    _NotifType.badge => Icons.workspace_premium_rounded,
    _NotifType.liveReminder => Icons.live_tv_rounded,
    _NotifType.progressMilestone => Icons.emoji_events_rounded,
    _NotifType.newMaterial => Icons.library_books_rounded,
    _NotifType.graded => Icons.grade_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final notifs = _visible;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── AppBar ────────────────────────────────────────────────────
          _NotifAppBar(
            unreadCount: _unreadCount,
            onMarkAllRead: _unreadCount > 0 ? _markAllRead : null,
          ),

          // ── Filter chips ──────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.getBorder(context),
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceLg,
              vertical: AppTheme.spaceSm,
            ),
            child: Row(
              children: List.generate(_filters.length, (i) {
                final sel = _filterIndex == i;
                // Show badge count on Unread tab
                final isUnread = i == 3;
                return Padding(
                  padding: const EdgeInsets.only(right: AppTheme.spaceXs),
                  child: GestureDetector(
                    onTap: () => setState(() => _filterIndex = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMd,
                        vertical: AppTheme.spaceXs,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? colorScheme.primary
                            : AppTheme.getSurfaceVariant(context),
                        borderRadius: AppTheme.borderRadiusXl,
                        border: Border.all(
                          color: sel
                              ? colorScheme.primary
                              : AppTheme.getBorder(context),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _filters[i],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: sel
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: sel
                                  ? colorScheme.onPrimary
                                  : AppTheme.getTextSecondary(context),
                            ),
                          ),
                          if (isUnread && _unreadCount > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: sel
                                    ? colorScheme.onPrimary.withValues(alpha: 0.25)
                                    : colorScheme.primary,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '$_unreadCount',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: sel
                                      ? colorScheme.onPrimary
                                      : colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: notifs.isEmpty
                ? _EmptyState(filterIndex: _filterIndex)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceLg,
                      vertical: AppTheme.spaceMd,
                    ),
                    itemCount: notifs.length,
                    itemBuilder: (context, idx) {
                      final n = notifs[idx];
                      return n.isInvite
                          ? _InviteCard(
                              notif: n,
                              icon: _typeIcon(n.type),
                              onAccept: () => _accept(n.id),
                              onDecline: () => _decline(n.id),
                            )
                          : _ActivityTile(
                              notif: n,
                              icon: _typeIcon(n.type),
                              onDismiss: () => _dismiss(n.id),
                            );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// APP BAR
// ═══════════════════════════════════════════════════════════════════════════════

class _NotifAppBar extends StatelessWidget {
  final int unreadCount;
  final VoidCallback? onMarkAllRead;

  const _NotifAppBar({required this.unreadCount, this.onMarkAllRead});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceLg,
        vertical: AppTheme.spaceMd,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.getBorder(context), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Back button (if pushed as route)
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.getTextSecondary(context),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: AppTheme.spaceSm),

          // Title + badge
          Row(
            children: [
              Text(
                'Notifications',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: AppTheme.spaceXs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$unreadCount',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const Spacer(),

          // Mark all read
          if (onMarkAllRead != null)
            TextButton.icon(
              onPressed: onMarkAllRead,
              icon: Icon(
                Icons.done_all_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: Text(
                'Mark all read',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INVITE CARD  (FB-friend-request style — prominent Accept / Decline)
// ═══════════════════════════════════════════════════════════════════════════════

class _InviteCard extends StatelessWidget {
  final _Notif notif;
  final IconData icon;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InviteCard({
    required this.notif,
    required this.icon,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                _Avatar(
                  initials: notif.avatarInitials ?? '?',
                  color: notif.avatarColor ?? colorScheme.primary,
                  size: 48,
                  icon: icon,
                ),
                const SizedBox(width: AppTheme.spaceMd),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Unread dot + title
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(
                              right: AppTheme.spaceXs,
                              top: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              notif.title,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space2xs),
                      Text(
                        notif.body,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.getTextSecondary(context),
                        ),
                      ),
                      const SizedBox(height: AppTheme.space2xs),
                      Text(
                        notif.time,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.getTextTertiary(context),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spaceMd),

            // Accept / Decline buttons
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Accept',
                    icon: Icons.check_rounded,
                    isPrimary: true,
                    onTap: onAccept,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: _ActionButton(
                    label: 'Decline',
                    icon: Icons.close_rounded,
                    isPrimary: false,
                    onTap: onDecline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTIVITY TILE  (swipe-to-dismiss + read indicator)
// ═══════════════════════════════════════════════════════════════════════════════

class _ActivityTile extends StatefulWidget {
  final _Notif notif;
  final IconData icon;
  final VoidCallback onDismiss;

  const _ActivityTile({
    required this.notif,
    required this.icon,
    required this.onDismiss,
  });

  @override
  State<_ActivityTile> createState() => _ActivityTileState();
}

class _ActivityTileState extends State<_ActivityTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUnread = !widget.notif.isRead;

    return Dismissible(
      key: Key(widget.notif.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onDismiss(),
      background: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.spaceLg),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.15),
          borderRadius: AppTheme.borderRadiusLg,
          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
        ),
        child: Icon(Icons.delete_outline_rounded, color: AppTheme.warning),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
          decoration: BoxDecoration(
            color: isUnread
                ? colorScheme.primary.withValues(alpha: _hovered ? 0.07 : 0.04)
                : _hovered
                ? AppTheme.getSurfaceVariant(context)
                : Theme.of(context).cardColor,
            borderRadius: AppTheme.borderRadiusLg,
            border: Border.all(
              color: isUnread
                  ? colorScheme.primary.withValues(alpha: 0.2)
                  : AppTheme.getBorder(context),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with type icon badge
                _AvatarWithBadge(
                  initials: widget.notif.avatarInitials ?? '?',
                  color: widget.notif.avatarColor ?? colorScheme.primary,
                  badgeIcon: widget.icon,
                ),
                const SizedBox(width: AppTheme.spaceMd),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isUnread)
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(
                                right: AppTheme.spaceXs,
                                top: 5,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              widget.notif.title,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: isUnread
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceXs),
                          Text(
                            widget.notif.time,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppTheme.getTextTertiary(context),
                                  fontSize: 11,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space2xs),
                      Text(
                        widget.notif.body,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.getTextSecondary(context),
                        ),
                      ),
                    ],
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

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

/// Circular avatar used on invite cards
class _Avatar extends StatelessWidget {
  final String initials;
  final Color color;
  final double size;
  final IconData icon;

  const _Avatar({
    required this.initials,
    required this.color,
    required this.size,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Center(
        child: Text(
          initials.length > 2 ? initials.substring(0, 2) : initials,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.3,
          ),
        ),
      ),
    );
  }
}

/// Avatar with a small type-icon badge in the bottom-right corner
class _AvatarWithBadge extends StatelessWidget {
  final String initials;
  final Color color;
  final IconData badgeIcon;

  const _AvatarWithBadge({
    required this.initials,
    required this.color,
    required this.badgeIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _Avatar(initials: initials, color: color, size: 44, icon: badgeIcon),
        Positioned(
          bottom: -2,
          right: -4,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.getBorder(context), width: 1),
            ),
            child: Icon(badgeIcon, size: 11, color: color),
          ),
        ),
      ],
    );
  }
}

/// Accept / Decline button
class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spaceSm,
            horizontal: AppTheme.spaceMd,
          ),
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? (_hovered
                      ? colorScheme.primary.withValues(alpha: 0.85)
                      : colorScheme.primary)
                : (_hovered
                      ? AppTheme.getSurfaceVariant(context)
                      : Theme.of(context).cardColor),
            borderRadius: AppTheme.borderRadiusMd,
            border: Border.all(
              color: widget.isPrimary
                  ? colorScheme.primary
                  : AppTheme.getBorder(context),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 15,
                color: widget.isPrimary
                    ? colorScheme.onPrimary
                    : AppTheme.getTextSecondary(context),
              ),
              const SizedBox(width: AppTheme.space2xs),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.isPrimary
                      ? colorScheme.onPrimary
                      : AppTheme.getTextSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state per filter
class _EmptyState extends StatelessWidget {
  final int filterIndex;

  const _EmptyState({required this.filterIndex});

  @override
  Widget build(BuildContext context) {
    final messages = [
      (
        'notifications_none',
        'You\'re all caught up!',
        'No new notifications right now.',
      ),
      (
        'group_off',
        'No pending invitations',
        'Organisation invites will show up here.',
      ),
      (
        'timeline',
        'No activity yet',
        'Comments, grades, and updates will appear here.',
      ),
      (
        'mark_email_read',
        'Nothing unread',
        'All notifications have been read.',
      ),
    ];

    final (iconName, title, sub) = messages[filterIndex.clamp(0, 3)];
    final icons = [
      Icons.notifications_none_rounded,
      Icons.group_off_rounded,
      Icons.timeline_rounded,
      Icons.mark_email_read_rounded,
    ];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icons[filterIndex.clamp(0, 3)],
            size: 56,
            color: AppTheme.getTextTertiary(context),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          Text(
            sub,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}
