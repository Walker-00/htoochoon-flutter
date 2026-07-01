// lib/Live-Session/features/meeting/widgets/meeting_chat_overlay.dart
//
// Ephemeral, text-only in-meeting chat. Messages are relayed by the live gateway
// (`live:chat:send` → `live:chat:message`) and never persisted — they exist only
// for the duration of the session. Supports directed delivery: everyone, the
// teacher(s), all students, or one specific participant.
//
// UI: a right-side slide-in panel (Meet/Zoom style), opened from the meeting
// control bar — NOT a floating bubble. Open/closed state is owned by the parent
// (meeting_page) via [isOpen] + [onClose]; unread is reported up via
// [onUnreadChanged] so the control-bar button can badge it.
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/services/socket_service.dart';

/// A participant the (teacher) sender can privately address.
class LiveChatParticipant {
  final String userId;
  final String name;
  const LiveChatParticipant(this.userId, this.name);
}

class _ChatTarget {
  final String label;
  final dynamic value; // 'ALL' | 'TEACHERS' | 'STUDENTS' | {kind:'USER',userId}
  const _ChatTarget(this.label, this.value);
}

class _LiveMsg {
  final String fromName;
  final String text;
  final dynamic target;
  final bool mine;
  _LiveMsg({
    required this.fromName,
    required this.text,
    required this.target,
    required this.mine,
  });
}

class MeetingChatOverlay extends StatefulWidget {
  final SocketService socket;
  final String roomId;
  final String myName; // display name used to mark "my" messages
  final String role; // 'teacher' | 'student'
  final List<LiveChatParticipant> participants; // for USER targeting
  final bool isOpen;
  final VoidCallback? onClose;
  final ValueChanged<int>? onUnreadChanged;

  const MeetingChatOverlay({
    super.key,
    required this.socket,
    required this.roomId,
    required this.myName,
    required this.role,
    required this.participants,
    this.isOpen = false,
    this.onClose,
    this.onUnreadChanged,
  });

  @override
  State<MeetingChatOverlay> createState() => _MeetingChatOverlayState();
}

class _MeetingChatOverlayState extends State<MeetingChatOverlay> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_LiveMsg> _messages = [];
  int _unread = 0;
  late _ChatTarget _target;

  @override
  void initState() {
    super.initState();
    _target = _targetOptions.first;
    widget.socket.on('live:chat:message', _onMessage);
  }

  @override
  void didUpdateWidget(covariant MeetingChatOverlay old) {
    super.didUpdateWidget(old);
    // Opening the panel clears unread.
    if (widget.isOpen && !old.isOpen && _unread != 0) {
      _unread = 0;
      widget.onUnreadChanged?.call(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  void dispose() {
    widget.socket.off('live:chat:message', _onMessage);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<_ChatTarget> get _targetOptions {
    if (widget.role == 'teacher') {
      return [
        const _ChatTarget('Everyone', 'ALL'),
        const _ChatTarget('Students', 'STUDENTS'),
        for (final p in widget.participants)
          _ChatTarget(p.name, {'kind': 'USER', 'userId': p.userId}),
      ];
    }
    return const [
      _ChatTarget('Everyone', 'ALL'),
      _ChatTarget('Teacher', 'TEACHERS'),
    ];
  }

  void _onMessage(dynamic data) {
    if (data is! Map) return;
    final fromName = (data['fromName'] ?? 'Unknown').toString();
    final text = (data['text'] ?? '').toString();
    if (text.isEmpty) return;
    final mine = fromName == widget.myName;
    setState(() {
      _messages.add(_LiveMsg(
        fromName: fromName,
        text: text,
        target: data['target'],
        mine: mine,
      ));
      if (!widget.isOpen && !mine) {
        _unread++;
        widget.onUnreadChanged?.call(_unread);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.socket.emit('live:chat:send', {
      'roomId': widget.roomId,
      'text': text,
      'target': _target.value,
    });
    _controller.clear();
  }

  String _targetLabel(_LiveMsg m) {
    final t = m.target;
    if (t is Map && t['kind'] == 'USER') {
      return m.mine ? 'private' : 'to you';
    }
    switch (t) {
      case 'TEACHERS':
        return 'to teacher';
      case 'STUDENTS':
        return 'to students';
      default:
        return 'everyone';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final panelW = size.width < 420 ? size.width : 360.0;
    final open = widget.isOpen;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !open,
        child: Stack(
          children: [
            // Dim backdrop — tap to close.
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: open ? 1 : 0,
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(color: Colors.black.withValues(alpha: 0.45)),
              ),
            ),
            // Sliding panel pinned to the right edge, full height.
            AnimatedPositioned(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              top: 0,
              bottom: 0,
              right: open ? 0 : -panelW,
              width: panelW,
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(22)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF121218).withValues(alpha: 0.92),
                      border: Border(
                        left: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                    ),
                    child: SafeArea(
                      left: false,
                      child: _buildPanel(context),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              Icon(Icons.forum_rounded, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Session chat',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    Text('Messages are not saved',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
        // Messages
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          color: Colors.white24, size: 34),
                      const SizedBox(height: 8),
                      const Text('No messages yet',
                          style: TextStyle(color: Colors.white38)),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) => _buildBubble(context, _messages[i]),
                ),
        ),
        // Target selector (chips)
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: _targetOptions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final t = _targetOptions[i];
              final selected = identical(t, _target) || t.label == _target.label;
              return GestureDetector(
                onTap: () => setState(() => _target = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? cs.primary
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_targetIcon(t),
                          size: 14,
                          color: selected ? cs.onPrimary : Colors.white60),
                      const SizedBox(width: 5),
                      Text(t.label,
                          style: TextStyle(
                              color: selected ? cs.onPrimary : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Input
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Message ${_target.label}…',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: cs.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _send,
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: Icon(Icons.send_rounded,
                        color: cs.onPrimary, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _targetIcon(_ChatTarget t) {
    final v = t.value;
    if (v is Map && v['kind'] == 'USER') return Icons.person_rounded;
    switch (v) {
      case 'TEACHERS':
        return Icons.school_rounded;
      case 'STUDENTS':
        return Icons.groups_rounded;
      default:
        return Icons.public_rounded;
    }
  }

  Widget _buildBubble(BuildContext context, _LiveMsg m) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.62),
        decoration: BoxDecoration(
          color: m.mine ? cs.primary : Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(m.mine ? 16 : 4),
            bottomRight: Radius.circular(m.mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              m.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(m.mine ? 'You' : m.fromName,
                    style: TextStyle(
                        color: m.mine
                            ? cs.onPrimary.withValues(alpha: 0.8)
                            : Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Text('· ${_targetLabel(m)}',
                    style: TextStyle(
                        color: m.mine
                            ? cs.onPrimary.withValues(alpha: 0.6)
                            : Colors.white38,
                        fontSize: 9)),
              ],
            ),
            const SizedBox(height: 2),
            Text(m.text,
                style: TextStyle(
                    color: m.mine ? cs.onPrimary : Colors.white, height: 1.3)),
          ],
        ),
      ),
    );
  }
}
