import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../Providers/discussion_provider.dart';
import '../../Widgets/state/async_view.dart';
import '../../core/haptics.dart';
import '../../core/nav/page_routes.dart';
import 'discussion_thread_screen.dart';

/// Per-assignment Q&A list ("I want to ask a question about this assignment").
/// FAB opens a composer; filter chips switch All / Mine / Unanswered.
class DiscussionListScreen extends StatefulWidget {
  final String assignmentId;
  final String assignmentTitle;
  const DiscussionListScreen({
    super.key,
    required this.assignmentId,
    required this.assignmentTitle,
  });

  @override
  State<DiscussionListScreen> createState() => _DiscussionListScreenState();
}

class _DiscussionListScreenState extends State<DiscussionListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiscussionProvider>().loadThreads(widget.assignmentId);
    });
  }

  Future<void> _refresh() =>
      context.read<DiscussionProvider>().loadThreads(widget.assignmentId);

  void _setFilter(String f) {
    Haptics.light();
    context.read<DiscussionProvider>().loadThreads(widget.assignmentId, filter: f);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DiscussionProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Q&A'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                _FilterChip(label: 'All', value: 'all', current: p.filter, onTap: _setFilter),
                const SizedBox(width: 8),
                _FilterChip(label: 'My questions', value: 'mine', current: p.filter, onTap: _setFilter),
                const SizedBox(width: 8),
                _FilterChip(label: 'Unanswered', value: 'unanswered', current: p.filter, onTap: _setFilter),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openComposer,
        icon: const Icon(Icons.help_outline),
        label: const Text('Ask a question'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: AsyncView<List<dynamic>>(
          loading: p.loadingThreads,
          error: p.threadsError,
          data: p.threads,
          isEmpty: (t) => t.isEmpty,
          onRetry: _refresh,
          emptyIcon: Icons.forum_outlined,
          emptyTitle: 'No questions yet',
          emptyMessage: 'Be the first to ask about "${widget.assignmentTitle}".',
          emptyActionLabel: 'Ask a question',
          onEmptyAction: _openComposer,
          builder: (threads) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: threads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final d = p.threads![i];
              return _ThreadCard(
                title: d.title,
                author: d.authorName ?? 'Someone',
                replies: d.replyCount,
                solved: d.isSolved,
                isPrivate: d.isPrivate,
                createdAt: d.createdAt,
                onTap: () {
                  Haptics.light();
                  Navigator.push(
                    context,
                    slideUpRoute(DiscussionThreadScreen(discussionId: d.id)),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _openComposer() {
    Haptics.medium();
    final titleC = TextEditingController();
    final bodyC = TextEditingController();
    bool isPrivate = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 4,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ask a question',
                  style: Theme.of(sheetCtx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: titleC,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Question',
                  hintText: 'e.g. How do I submit part 2?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyC,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: isPrivate,
                onChanged: (v) => setSheet(() => isPrivate = v),
                title: const Text('Private'),
                subtitle: const Text('Only you and the teacher can see this'),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final title = titleC.text.trim();
                    if (title.isEmpty) return;
                    final nav = Navigator.of(sheetCtx);
                    final created = await context
                        .read<DiscussionProvider>()
                        .createThread(
                          widget.assignmentId,
                          title: title,
                          body: bodyC.text.trim().isEmpty ? null : bodyC.text.trim(),
                          isPrivate: isPrivate,
                        );
                    if (!mounted) return;
                    nav.pop();
                    if (created != null) {
                      Navigator.push(
                        context,
                        slideUpRoute(DiscussionThreadScreen(discussionId: created.id)),
                      );
                    }
                  },
                  child: const Text('Post question'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final void Function(String) onTap;
  const _FilterChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(value),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  final String title;
  final String author;
  final int replies;
  final bool solved;
  final bool isPrivate;
  final DateTime createdAt;
  final VoidCallback onTap;

  const _ThreadCard({
    required this.title,
    required this.author,
    required this.replies,
    required this.solved,
    required this.isPrivate,
    required this.createdAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: solved ? 0.7 : 1,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (solved)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.check_circle, size: 18, color: cs.primary),
                      ),
                    if (isPrivate)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.lock_outline, size: 16, color: cs.onSurfaceVariant),
                      ),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(author, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                    const Spacer(),
                    Icon(Icons.chat_bubble_outline, size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('$replies', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(width: 10),
                    Text(DateFormat('MMM d').format(createdAt),
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
