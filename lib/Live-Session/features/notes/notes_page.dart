import 'dart:async';
import 'package:flutter/material.dart';
import 'notes_store.dart';
import 'note_export.dart';

/// Personal note-taking surface for a live session. Unlike the whiteboard, this
/// is PRIVATE and UNRESTRICTED: every participant (incl. students) gets their
/// own notepad, never synced, never shared automatically. Autosaves locally
/// (fallback save) and can be exported/shared as .txt / .md / .html.
class NotesPage extends StatefulWidget {
  final String sessionId;
  final String userId;
  final String orgName;
  final String programName;

  /// How to close. Null → pop the route; a detached OS window passes a callback.
  final VoidCallback? onClose;

  const NotesPage({
    super.key,
    required this.sessionId,
    required this.userId,
    this.orgName = '',
    this.programName = '',
    this.onClose,
  });

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _autosave;
  bool _loaded = false;
  DateTime? _savedAt;

  String get _baseName {
    final p = widget.programName.isNotEmpty ? widget.programName : 'session';
    return 'Notes_$p';
  }

  @override
  void initState() {
    super.initState();
    _load();
    // Autosave every 3s while editing — the fallback save on crash/close.
    _autosave = Timer.periodic(const Duration(seconds: 3), (_) => _persist());
  }

  Future<void> _load() async {
    final text = await NotesStore.load(widget.sessionId, widget.userId);
    if (!mounted) return;
    setState(() {
      _ctrl.text = text;
      _loaded = true;
    });
  }

  Future<void> _persist() async {
    if (!_loaded) return;
    await NotesStore.save(widget.sessionId, widget.userId, _ctrl.text);
    if (mounted) setState(() => _savedAt = DateTime.now());
  }

  @override
  void dispose() {
    _autosave?.cancel();
    // Final fallback save (fire and forget).
    NotesStore.save(widget.sessionId, widget.userId, _ctrl.text);
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _export({required bool share}) async {
    final format = await showModalBottomSheet<NoteFormat>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Choose format',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            for (final f in NoteFormat.values)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(f.label),
                onTap: () => Navigator.pop(ctx, f),
              ),
          ],
        ),
      ),
    );
    if (format == null) return;
    await _persist();
    try {
      if (share) {
        await NoteExport.shareNote(_ctrl.text, format, baseName: _baseName);
      } else {
        final path =
            await NoteExport.saveToDevice(_ctrl.text, format, baseName: _baseName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved: ${path.split('/').last}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  void _close() {
    _persist();
    (widget.onClose ?? () => Navigator.of(context).pop())();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          _statusBar(cs),
          Expanded(
            child: _loaded
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _ctrl,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Type your notes…',
                      ),
                    ),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          _toolbar(cs),
        ],
      ),
    );
  }

  Widget _statusBar(ColorScheme cs) => Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: MediaQuery.of(context).padding.top + 8,
          bottom: 8,
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          border:
              Border(bottom: BorderSide(color: cs.outlineVariant, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.sticky_note_2_outlined, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Text('My Notes',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: cs.onSurface)),
            const Spacer(),
            Text(
              _savedAt == null ? 'Private' : 'Saved',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );

  Widget _toolbar(ColorScheme cs) => Container(
        padding: EdgeInsets.only(
          left: 8,
          right: 8,
          top: 6,
          bottom: MediaQuery.of(context).padding.bottom + 6,
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _btn(Icons.save_outlined, 'Save', _persist),
            _btn(Icons.download_outlined, 'Export', () => _export(share: false)),
            _btn(Icons.share_outlined, 'Share', () => _export(share: true)),
            _btn(Icons.close, 'Close', _close),
          ],
        ),
      );

  Widget _btn(IconData icon, String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      );
}
