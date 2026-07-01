import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../Providers/discussion_provider.dart';
import '../../Widgets/state/async_view.dart';
import '../../Widgets/user_info_sheet.dart';
import '../../core/haptics.dart';
import '../../core/userorgrole_manager.dart';
import '../../models/api_models/discussion_model.dart';
import '../../models/api_models/enums.dart';

/// A single Q&A thread: question + threaded replies (2 visible levels). The
/// author can mark Solved; teachers/admins/staff can mark a Best Answer.
class DiscussionThreadScreen extends StatefulWidget {
  final String discussionId;
  const DiscussionThreadScreen({super.key, required this.discussionId});

  @override
  State<DiscussionThreadScreen> createState() => _DiscussionThreadScreenState();
}

class _DiscussionThreadScreenState extends State<DiscussionThreadScreen> {
  final _composer = TextEditingController();
  String? _replyToId;
  String? _replyToName;
  bool _sending = false;

  bool get _isModerator {
    final r = UserSessionManager.globalRole;
    return r == Role.TEACHER || r == Role.ORG_ADMIN || r == Role.STAFF;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiscussionProvider>().loadThread(widget.discussionId);
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _composer.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    Haptics.medium();
    final ok = await context.read<DiscussionProvider>().reply(
          widget.discussionId,
          body: body,
          parentId: _replyToId,
        );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (ok) {
        _composer.clear();
        _replyToId = null;
        _replyToName = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DiscussionProvider>();
    final thread = p.thread;
    final mine = thread?.discussion.authorId == UserSessionManager.userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Question'),
        actions: [
          if (thread != null && (mine) && !thread.discussion.isSolved)
            TextButton.icon(
              onPressed: () {
                Haptics.success();
                context.read<DiscussionProvider>().markSolved(widget.discussionId);
              },
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Solve'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: AsyncView<DiscussionThread>(
              loading: p.loadingThread,
              error: p.threadError,
              data: thread,
              onRetry: () =>
                  context.read<DiscussionProvider>().loadThread(widget.discussionId),
              skeleton: SkeletonKind.detail,
              builder: (t) => _body(t),
            ),
          ),
          _composerBar(),
        ],
      ),
    );
  }

  Widget _body(DiscussionThread t) {
    final cs = Theme.of(context).colorScheme;
    // Group replies: top-level (parentId == null) + their children.
    final top = t.messages.where((m) => m.parentId == null).toList();
    final childrenOf = <String, List<DiscussionMessage>>{};
    for (final m in t.messages.where((m) => m.parentId != null)) {
      childrenOf.putIfAbsent(m.parentId!, () => []).add(m);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      children: [
        // Question card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (t.discussion.isSolved)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.check_circle, size: 18, color: cs.primary),
                    ),
                  Expanded(
                    child: Text(t.discussion.title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                  ),
                ],
              ),
              if ((t.discussion.body ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(t.discussion.body!),
              ],
              const SizedBox(height: 10),
              _AuthorLine(
                name: t.discussion.authorName ?? 'Someone',
                avatar: t.discussion.authorAvatar,
                at: t.discussion.createdAt,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('${t.messages.length} ${t.messages.length == 1 ? 'reply' : 'replies'}',
            style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (final m in top) ...[
          _ReplyTile(
            m: m,
            canMarkBest: _isModerator && !m.isBestAnswer,
            onMarkBest: () {
              Haptics.success();
              context.read<DiscussionProvider>().markBest(m.id, widget.discussionId);
            },
            onReply: () => setState(() {
              _replyToId = m.id;
              _replyToName = m.authorName;
            }),
          ),
          for (final c in (childrenOf[m.id] ?? []))
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: _ReplyTile(m: c, canMarkBest: false, onMarkBest: () {}, onReply: () {}),
            ),
        ],
      ],
    );
  }

  Widget _composerBar() {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyToName != null)
              Row(
                children: [
                  Icon(Icons.reply, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('Replying to $_replyToName',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() {
                      _replyToId = null;
                      _replyToName = null;
                    }),
                  ),
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _composer,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Write a reply…',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorLine extends StatelessWidget {
  final String name;
  final String? avatar;
  final DateTime at;
  const _AuthorLine({required this.name, this.avatar, required this.at});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => showUserInfoSheet(context, name: name, avatar: avatar),
      child: Row(
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: cs.primaryContainer,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 6),
          Text(name, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text(DateFormat('MMM d, h:mm a').format(at),
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  final DiscussionMessage m;
  final bool canMarkBest;
  final VoidCallback onMarkBest;
  final VoidCallback onReply;
  const _ReplyTile({
    required this.m,
    required this.canMarkBest,
    required this.onMarkBest,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: m.isBestAnswer ? cs.primaryContainer.withValues(alpha: 0.4) : cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: m.isBestAnswer ? cs.primary : cs.outlineVariant,
          width: m.isBestAnswer ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m.isBestAnswer)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.verified, size: 15, color: cs.primary),
                  const SizedBox(width: 4),
                  Text('Best answer',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary)),
                ],
              ),
            ),
          Text(m.body),
          const SizedBox(height: 8),
          Row(
            children: [
              _AuthorLine(name: m.authorName ?? 'Someone', avatar: m.authorAvatar, at: m.createdAt),
              const Spacer(),
              TextButton(
                onPressed: onReply,
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: const Text('Reply'),
              ),
              if (canMarkBest)
                TextButton(
                  onPressed: onMarkBest,
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('Best'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
