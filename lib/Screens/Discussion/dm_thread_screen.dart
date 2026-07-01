import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../Providers/discussion_provider.dart';
import '../../Widgets/state/async_view.dart';
import '../../core/haptics.dart';
import '../../core/userorgrole_manager.dart';
import '../../models/api_models/discussion_model.dart';

/// 1:1 direct message thread (student ↔ teacher/mod), optionally anchored to an
/// assignment context.
class DmThreadScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String? peerAvatar;
  final String? assignmentId;
  const DmThreadScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    this.peerAvatar,
    this.assignmentId,
  });

  @override
  State<DmThreadScreen> createState() => _DmThreadScreenState();
}

class _DmThreadScreenState extends State<DmThreadScreen> {
  final _composer = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiscussionProvider>().loadConversation(widget.peerId);
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
    final ok = await context.read<DiscussionProvider>().sendDm(
          widget.peerId,
          body,
          assignmentId: widget.assignmentId,
        );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (ok) _composer.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<DiscussionProvider>();
    final me = UserSessionManager.userId;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.primaryContainer,
              child: Text(
                widget.peerName.isNotEmpty ? widget.peerName[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.peerName, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: AsyncView<List<dynamic>>(
              loading: p.loadingDm,
              data: p.dmMessages,
              isEmpty: (m) => m.isEmpty,
              emptyIcon: Icons.forum_outlined,
              emptyTitle: 'No messages yet',
              emptyMessage: 'Say hello to ${widget.peerName}.',
              builder: (_) {
                final msgs = p.dmMessages!;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final DmMessage m = msgs[i];
                    final mine = m.senderId == me;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.72),
                        decoration: BoxDecoration(
                          color: mine ? cs.primary : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.body,
                                style: TextStyle(
                                    color: mine ? cs.onPrimary : cs.onSurface)),
                            const SizedBox(height: 3),
                            Text(
                              DateFormat('h:mm a').format(m.createdAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: (mine ? cs.onPrimary : cs.onSurfaceVariant)
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
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
                    onPressed: _sending ? null : _send,
                    icon: _sending
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
