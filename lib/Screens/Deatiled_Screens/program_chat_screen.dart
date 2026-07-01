import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Providers/chat_provider.dart';
import '../../Live-Session/core/services/socket_service.dart';
import '../../models/api_models/chat_model.dart';
import '../../widgets/lms_dialog.dart';
import '../../Widgets/user_info_sheet.dart';

/// Backend origin for serving uploaded media (`/uploads/...`) and avatars.
const String kMediaBase = 'https://backend.htoochoon.com';

String _prettySize(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

String _fmtDuration(int? ms) {
  if (ms == null || ms <= 0) return '0:00';
  final s = (ms / 1000).round();
  final m = s ~/ 60;
  final sec = (s % 60).toString().padLeft(2, '0');
  return '$m:$sec';
}

class ProgramChatScreen extends StatefulWidget {
  final String programId;
  final String programName;
  const ProgramChatScreen({
    super.key,
    required this.programId,
    required this.programName,
  });

  @override
  State<ProgramChatScreen> createState() => _ProgramChatScreenState();
}

class _ProgramChatScreenState extends State<ProgramChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late final ChatProvider _chat;
  bool _typingSent = false;

  // @mention autocomplete: the token currently being typed after '@' (or null).
  String? _mentionQuery;

  // Voice recording (Telegram-style: hold the mic to record, release to send,
  // slide left to cancel).
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _cancelArmed = false; // slid left far enough → release cancels
  Duration _recordElapsed = Duration.zero;
  Timer? _recordTimer;
  String? _recordPath;

  @override
  void initState() {
    super.initState();
    _chat = context.read<ChatProvider>();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chat.open(widget.programId, context.read<SocketService>());
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    // Provider outlives the screen → tear the room down explicitly.
    _chat.close();
    super.dispose();
  }

  void _onScroll() {
    // reverse:true → older messages live at the END (maxScrollExtent).
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      _chat.loadMore();
    }
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _chat.sendMessage(text);
    _input.clear();
    if (_mentionQuery != null) setState(() => _mentionQuery = null);
    if (_typingSent) {
      _chat.sendTyping(false);
      _typingSent = false;
    }
    // Snap to newest.
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _onInputChanged(String v) {
    final hasText = v.trim().isNotEmpty;
    if (hasText && !_typingSent) {
      _typingSent = true;
      _chat.sendTyping(true);
    } else if (!hasText && _typingSent) {
      _typingSent = false;
      _chat.sendTyping(false);
    }
    _updateMentionQuery();
  }

  // ── @mention autocomplete ────────────────────────────────────────────────

  void _updateMentionQuery() {
    final sel = _input.selection.baseOffset;
    final text = _input.text;
    String? query;
    if (sel >= 0 && sel <= text.length) {
      final before = text.substring(0, sel);
      // '@' + a run of non-space characters at the cursor.
      final m = RegExp(r'@([^@\s]*)$').firstMatch(before);
      if (m != null) query = m.group(1) ?? '';
    }
    if (query != _mentionQuery) {
      setState(() => _mentionQuery = query);
    }
  }

  List<ChatSender> get _mentionSuggestions {
    final q = _mentionQuery;
    if (q == null) return const [];
    final lc = q.toLowerCase();
    final list = _chat.members
        .where((m) => m.id != _chat.myUserId && m.name.toLowerCase().contains(lc))
        .take(6)
        .toList();
    return list;
  }

  void _applyMention(ChatSender member) {
    final sel = _input.selection.baseOffset;
    final text = _input.text;
    if (sel < 0 || sel > text.length) return;
    final before = text.substring(0, sel);
    final at = before.lastIndexOf('@');
    if (at < 0) return;
    final after = text.substring(sel);
    final insert = '@${member.name} ';
    final newText = text.substring(0, at) + insert + after;
    final newOffset = at + insert.length;
    _input.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    setState(() => _mentionQuery = null);
  }

  // ── Attachments ──────────────────────────────────────────────────────────

  Future<void> _showAttachSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('File'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'gallery') {
      await _pickImage(ImageSource.gallery);
    } else if (choice == 'camera') {
      await _pickImage(ImageSource.camera);
    } else if (choice == 'file') {
      await _pickFile();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
      if (picked == null) return;
      await _chat.sendAttachment(filePath: picked.path, kind: 'IMAGE');
      _showErrorIfAny();
    } catch (e) {
      _toast('Could not attach image');
    }
  }

  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(withData: false);
      final path = res?.files.single.path;
      if (path == null) return;
      await _chat.sendAttachment(filePath: path, kind: 'FILE');
      _showErrorIfAny();
    } catch (e) {
      _toast('Could not attach file');
    }
  }

  // ── Voice notes ──────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        _toast('Microphone permission denied');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      _recordPath = path;
      _recordElapsed = Duration.zero;
      setState(() => _isRecording = true);
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _recordElapsed += const Duration(seconds: 1));
      });
    } catch (e) {
      _toast('Could not start recording');
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {}
    final path = _recordPath;
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    _recordPath = null;
    if (mounted) {
      setState(() {
        _isRecording = false;
        _cancelArmed = false;
      });
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    final ms = _recordElapsed.inMilliseconds;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    path ??= _recordPath;
    if (mounted) {
      setState(() {
        _isRecording = false;
        _cancelArmed = false;
      });
    }
    _recordPath = null;
    if (path == null || ms < 800) {
      _toast('Recording too short');
      return;
    }
    await _chat.sendAttachment(filePath: path, kind: 'VOICE', durationMs: ms);
    _showErrorIfAny();
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _showErrorIfAny() {
    final err = _chat.error;
    if (err != null && mounted) _toast(err);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showMessageActions(ChatMessage m) async {
    if (m.isDeleted) return;
    final isMine = m.senderId == _chat.myUserId;
    if (!isMine) return; // edit/delete restricted to author here
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(ctx).colorScheme.error),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'delete') {
      if (!mounted) return;
      final ok = await LMSConfirmDialog.show(
        context,
        icon: Icons.delete_outline,
        title: 'Delete message?',
        message: 'This message will be removed for everyone.',
        confirmLabel: 'Delete',
        danger: true,
      );
      if (ok) _chat.deleteMessage(m);
    } else if (action == 'edit') {
      _promptEdit(m);
    }
  }

  Future<void> _promptEdit(ChatMessage m) async {
    final ctrl = TextEditingController(text: m.content);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty && result.trim() != m.content) {
      _chat.editMessage(m, result.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chat = context.watch<ChatProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.programName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(
              chat.typingUserIds.isNotEmpty ? 'typing…' : 'Program Chat',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Reconnecting banner.
          if (chat.reconnecting)
            Container(
              width: double.infinity,
              color: cs.errorContainer,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.onErrorContainer),
                  ),
                  const SizedBox(width: 8),
                  Text('Reconnecting…',
                      style: TextStyle(color: cs.onErrorContainer, fontSize: 12)),
                ],
              ),
            ),
          Expanded(child: _buildMessageList(chat, cs)),
          if (chat.uploading)
            LinearProgressIndicator(minHeight: 2, color: cs.primary),
          _buildMentionSuggestions(cs),
          _buildComposer(chat, cs),
        ],
      ),
    );
  }

  Widget _buildMentionSuggestions(ColorScheme cs) {
    final items = _mentionSuggestions;
    if (_mentionQuery == null || items.isEmpty) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (_, i) {
          final m = items[i];
          final avatar = m.avatar;
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: cs.secondaryContainer,
              backgroundImage: (avatar != null && avatar.isNotEmpty)
                  ? NetworkImage('$kMediaBase$avatar')
                  : null,
              child: (avatar == null || avatar.isEmpty)
                  ? Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 12, color: cs.onSecondaryContainer))
                  : null,
            ),
            title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            onTap: () => _applyMention(m),
          );
        },
      ),
    );
  }

  Widget _buildMessageList(ChatProvider chat, ColorScheme cs) {
    if (chat.loading && chat.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (chat.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 44, color: cs.onSurfaceVariant),
            const SizedBox(height: 8),
            Text('No messages yet — say hello! 👋',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      itemCount: chat.messages.length + (chat.loadingMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= chat.messages.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final m = chat.messages[i];
        return _MessageBubble(
          message: m,
          isMine: m.senderId == chat.myUserId,
          members: chat.members,
          onLongPress: () => _showMessageActions(m),
        );
      },
    );
  }

  Widget _buildComposer(ChatProvider chat, ColorScheme cs) {
    if (!chat.isEnabled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: cs.surfaceContainerHighest,
        child: Text(
          'Chat is currently disabled for this program.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // While recording, the attach + text field are replaced by the
            // live recording indicator. The trailing mic button stays mounted
            // throughout so its long-press gesture is never torn down mid-hold.
            if (_isRecording)
              Expanded(child: _recordingIndicator(cs))
            else ...[
              IconButton(
                icon: Icon(Icons.add_circle_outline, color: cs.primary),
                onPressed: _showAttachSheet,
                tooltip: 'Attach',
              ),
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: _onInputChanged,
                  onTap: _updateMentionQuery,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Message…',
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            _trailingButton(cs),
          ],
        ),
      ),
    );
  }

  /// Send button when there's text; otherwise the hold-to-record mic. Kept in a
  /// stable position so swapping send↔mic never disturbs an active recording.
  Widget _trailingButton(ColorScheme cs) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _input,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        if (hasText && !_isRecording) {
          return CircleAvatar(
            backgroundColor: cs.primary,
            child: IconButton(
              icon: Icon(Icons.send, color: cs.onPrimary, size: 20),
              onPressed: _send,
            ),
          );
        }
        return _micButton(cs);
      },
    );
  }

  Widget _micButton(ColorScheme cs) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toast('Hold to record, release to send'),
      onLongPressStart: (_) => _startRecording(),
      onLongPressMoveUpdate: (d) {
        if (!_isRecording) return;
        final armed = d.offsetFromOrigin.dx < -90; // slid left to cancel
        if (armed != _cancelArmed) setState(() => _cancelArmed = armed);
      },
      onLongPressEnd: (_) {
        if (!_isRecording) return;
        if (_cancelArmed) {
          _cancelRecording();
        } else {
          _stopAndSendRecording();
        }
      },
      onLongPressCancel: () {
        if (_isRecording) _cancelRecording();
      },
      child: AnimatedScale(
        scale: _isRecording ? 1.5 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: CircleAvatar(
          backgroundColor: _isRecording
              ? (_cancelArmed ? cs.error : cs.primary)
              : cs.surfaceContainerHighest,
          child: Icon(
            _cancelArmed ? Icons.delete_outline : Icons.mic,
            color: _isRecording ? cs.onPrimary : cs.onSurfaceVariant,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _recordingIndicator(ColorScheme cs) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          // Blinking record dot.
          _BlinkingDot(color: cs.error),
          const SizedBox(width: 10),
          Text(_fmtDuration(_recordElapsed.inMilliseconds),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          if (_cancelArmed)
            Text('Release to cancel',
                style: TextStyle(color: cs.error, fontWeight: FontWeight.w600))
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left, size: 18, color: cs.onSurfaceVariant),
                Text('Slide to cancel',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
        ],
      ),
    );
  }
}

/// A small dot that pulses while a voice note is being recorded.
class _BlinkingDot extends StatefulWidget {
  final Color color;
  const _BlinkingDot({required this.color});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_c),
      child: Icon(Icons.fiber_manual_record, color: widget.color, size: 14),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final List<ChatSender> members;
  final VoidCallback onLongPress;
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.members,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final time = message.createdAt != null
        ? DateFormat('HH:mm').format(message.createdAt!.toLocal())
        : '';

    final bubbleColor = message.isDeleted
        ? cs.surfaceContainerHighest
        : (isMine ? cs.primary : cs.surfaceContainerHigh);
    final textColor = message.isDeleted
        ? cs.onSurfaceVariant
        : (isMine ? cs.onPrimary : cs.onSurface);

    final bubble = GestureDetector(
      onLongPress: message.isDeleted ? null : onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.74),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMine && message.sender != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  message.sender!.name,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.primary),
                ),
              ),
            if (message.replyTo != null && !message.isDeleted)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isMine ? cs.onPrimary : cs.primary).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  message.replyTo!.content.isEmpty
                      ? 'deleted message'
                      : message.replyTo!.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: textColor.withValues(alpha: 0.8)),
                ),
              ),
            _buildBody(context, cs, textColor, isMine),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.isEdited)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text('edited',
                        style: TextStyle(
                            fontSize: 9,
                            color: textColor.withValues(alpha: 0.7))),
                  ),
                Text(time,
                    style: TextStyle(
                        fontSize: 9, color: textColor.withValues(alpha: 0.7))),
                if (message.pending)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.schedule,
                        size: 10, color: textColor.withValues(alpha: 0.7)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            _Avatar(sender: message.sender, cs: cs),
            const SizedBox(width: 6),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, ColorScheme cs, Color textColor, bool mine) {
    if (message.isDeleted) {
      return Text('This message was deleted',
          style: TextStyle(color: textColor, fontStyle: FontStyle.italic));
    }

    final caption = message.content.trim();
    if (message.isImage && message.attachmentUrl != null) {
      return Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          _ImageBubble(message: message),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildText(context, caption, textColor),
          ],
        ],
      );
    }
    if (message.isVoice && message.attachmentUrl != null) {
      return _VoiceBubble(message: message, textColor: textColor, cs: cs, mine: mine);
    }
    if (message.isFile && message.attachmentUrl != null) {
      return Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          _FileChip(message: message, textColor: textColor),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildText(context, caption, textColor),
          ],
        ],
      );
    }
    return _buildText(context, message.content, textColor);
  }

  /// Render text, highlighting `@Name` tokens that match a known chat member.
  /// Tapping a mention opens that member's info sheet.
  Widget _buildText(BuildContext context, String content, Color textColor) {
    final base = TextStyle(color: textColor);
    if (content.isEmpty || members.isEmpty || !content.contains('@')) {
      return Text(content, style: base);
    }

    // Candidate mention strings, longest first so "@John Doe" wins over "@John".
    final candidates = members
        .where((m) => m.name.trim().isNotEmpty)
        .map((m) => '@${m.name}')
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    final highlight = base.copyWith(fontWeight: FontWeight.w700);
    final spans = <InlineSpan>[];
    final lc = content.toLowerCase();
    int i = 0;
    final buf = StringBuffer();
    while (i < content.length) {
      String? hit;
      if (content[i] == '@') {
        for (final c in candidates) {
          if (i + c.length <= content.length &&
              lc.substring(i, i + c.length) == c.toLowerCase()) {
            hit = c;
            break;
          }
        }
      }
      if (hit != null) {
        if (buf.isNotEmpty) {
          spans.add(TextSpan(text: buf.toString(), style: base));
          buf.clear();
        }
        final hitText = content.substring(i, i + hit.length);
        ChatSender? mem;
        for (final m in members) {
          if ('@${m.name}'.toLowerCase() == hit.toLowerCase()) {
            mem = m;
            break;
          }
        }
        spans.add(TextSpan(
          text: hitText,
          style: highlight,
          recognizer: TapGestureRecognizer()
            ..onTap = () => showUserInfoSheet(
                  context,
                  name: mem?.name ?? hitText.substring(1),
                  userId: mem?.id,
                  avatar: mem?.avatar,
                ),
        ));
        i += hit.length;
      } else {
        buf.write(content[i]);
        i++;
      }
    }
    if (buf.isNotEmpty) spans.add(TextSpan(text: buf.toString(), style: base));
    return Text.rich(TextSpan(children: spans));
  }
}

class _ImageBubble extends StatelessWidget {
  final ChatMessage message;
  const _ImageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final url = '$kMediaBase${message.attachmentUrl}';
    final aspect = (message.attachmentWidth != null &&
            message.attachmentHeight != null &&
            message.attachmentHeight! > 0)
        ? (message.attachmentWidth! / message.attachmentHeight!)
        : null;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _ImageViewer(url: url)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240, maxHeight: 280),
          child: aspect != null
              ? AspectRatio(
                  aspectRatio: aspect,
                  child: Image.network(url, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _BrokenImage()),
                )
              : Image.network(url, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _BrokenImage()),
        ),
      ),
    );
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();
  @override
  Widget build(BuildContext context) => Container(
        width: 160,
        height: 120,
        color: Colors.black12,
        child: const Icon(Icons.broken_image_outlined),
      );
}

class _ImageViewer extends StatelessWidget {
  final String url;
  const _ImageViewer({required this.url});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(url, errorBuilder: (_, __, ___) => const _BrokenImage()),
        ),
      ),
    );
  }
}

class _FileChip extends StatelessWidget {
  final ChatMessage message;
  final Color textColor;
  const _FileChip({required this.message, required this.textColor});

  @override
  Widget build(BuildContext context) {
    final name = message.attachmentName ?? 'File';
    final size = _prettySize(message.attachmentSize);
    return InkWell(
      onTap: () async {
        final uri = Uri.parse('$kMediaBase${message.attachmentUrl}');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_outlined, color: textColor),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                if (size.isNotEmpty)
                  Text(size,
                      style: TextStyle(
                          color: textColor.withValues(alpha: 0.7), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.download_rounded, size: 18, color: textColor.withValues(alpha: 0.8)),
        ],
      ),
    );
  }
}

class _VoiceBubble extends StatefulWidget {
  final ChatMessage message;
  final Color textColor;
  final ColorScheme cs;
  final bool mine;
  const _VoiceBubble({
    required this.message,
    required this.textColor,
    required this.cs,
    required this.mine,
  });

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource('$kMediaBase${widget.message.attachmentUrl}'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle,
              color: widget.textColor, size: 30),
          onPressed: _toggle,
        ),
        const SizedBox(width: 8),
        Icon(Icons.graphic_eq, color: widget.textColor.withValues(alpha: 0.8)),
        const SizedBox(width: 8),
        Text(_fmtDuration(widget.message.attachmentDurationMs),
            style: TextStyle(color: widget.textColor, fontSize: 12)),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final ChatSender? sender;
  final ColorScheme cs;
  const _Avatar({required this.sender, required this.cs});

  @override
  Widget build(BuildContext context) {
    final avatar = sender?.avatar;
    final initial =
        (sender?.name.isNotEmpty ?? false) ? sender!.name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 13,
      backgroundColor: cs.secondaryContainer,
      backgroundImage: (avatar != null && avatar.isNotEmpty)
          ? NetworkImage('https://backend.htoochoon.com$avatar')
          : null,
      child: (avatar == null || avatar.isEmpty)
          ? Text(initial,
              style: TextStyle(fontSize: 11, color: cs.onSecondaryContainer))
          : null,
    );
  }
}
