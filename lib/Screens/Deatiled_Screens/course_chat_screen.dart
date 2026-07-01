import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../Providers/course_chat_provider.dart';
import '../../Widgets/state/async_view.dart';
import '../../Widgets/user_info_sheet.dart';
import '../../core/haptics.dart';
import '../../core/userorgrole_manager.dart';
import '../../models/api_models/enums.dart';

/// Course-scoped chat (in addition to per-program chat). Reachable as a tab on
/// the course detail screen. Teachers/admins can disable it.
class CourseChatScreen extends StatefulWidget {
  final String courseId;
  final String courseName;
  const CourseChatScreen({super.key, required this.courseId, required this.courseName});

  @override
  State<CourseChatScreen> createState() => _CourseChatScreenState();
}

class _CourseChatScreenState extends State<CourseChatScreen> {
  final _composer = TextEditingController();

  bool get _isModerator {
    final r = UserSessionManager.globalRole;
    return r == Role.TEACHER || r == Role.ORG_ADMIN || r == Role.STAFF;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CourseChatProvider>().open(widget.courseId);
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _composer.text;
    if (text.trim().isEmpty) return;
    final ok = await context.read<CourseChatProvider>().send(text);
    if (ok) {
      Haptics.light();
      _composer.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CourseChatProvider>();
    final me = UserSessionManager.userId;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.courseName} · Chat'),
        actions: [
          if (_isModerator)
            Switch(
              value: p.isEnabled,
              onChanged: (v) {
                Haptics.light();
                p.toggle(v);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (!p.isEnabled)
            Container(
              width: double.infinity,
              color: cs.errorContainer,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Text('Chat is disabled for this course',
                  style: TextStyle(color: cs.onErrorContainer, fontSize: 13)),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: p.refresh,
              child: AsyncView<List<dynamic>>(
                loading: p.loading,
                error: p.error,
                data: p.messages,
                isEmpty: (m) => m.isEmpty,
                onRetry: () => context.read<CourseChatProvider>().open(widget.courseId),
                emptyIcon: Icons.chat_bubble_outline,
                emptyTitle: 'No messages yet',
                emptyMessage: 'Start the conversation for ${widget.courseName}.',
                builder: (_) {
                  final msgs = p.messages!;
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) {
                      final m = msgs[i];
                      final mine = m.senderId == me;
                      return _Bubble(
                        mine: mine,
                        name: m.senderName ?? 'Someone',
                        avatar: m.senderAvatar,
                        content: m.isDeleted ? 'This message was deleted' : m.content,
                        at: m.createdAt,
                        onTapAuthor: mine
                            ? null
                            : () => showUserInfoSheet(context,
                                name: m.senderName ?? 'Someone',
                                userId: m.senderId,
                                avatar: m.senderAvatar),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          if (p.isEnabled || _isModerator)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(top: BorderSide(color: cs.outlineVariant)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _composer,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Message…',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: p.sending ? null : _send,
                      icon: p.sending
                          ? const SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send, size: 18),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final bool mine;
  final String name;
  final String? avatar;
  final String content;
  final DateTime at;
  final VoidCallback? onTapAuthor;
  const _Bubble({
    required this.mine,
    required this.name,
    this.avatar,
    required this.content,
    required this.at,
    this.onTapAuthor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
        decoration: BoxDecoration(
          color: mine ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              GestureDetector(
                onTap: onTapAuthor,
                child: Text(name,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary)),
              ),
            if (!mine) const SizedBox(height: 2),
            Text(content, style: TextStyle(color: mine ? cs.onPrimary : cs.onSurface)),
            const SizedBox(height: 3),
            Text(
              DateFormat('h:mm a').format(at),
              style: TextStyle(
                fontSize: 10,
                color: (mine ? cs.onPrimary : cs.onSurfaceVariant).withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
