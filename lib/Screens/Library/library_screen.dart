import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:htoochoon_flutter/Live-Session/core/services/device_storage.dart';
import 'package:htoochoon_flutter/Live-Session/features/notes/notes_store.dart';

/// In-app library of locally-saved live-session recordings + exported notes.
/// Reached from the Profile tab. Everything here is on-device only.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Recordings & Notes'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Recordings', icon: Icon(Icons.videocam_outlined)),
            Tab(text: 'Notes', icon: Icon(Icons.sticky_note_2_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_RecordingsTab(), _NotesTab()],
      ),
    );
  }
}

class _RecordingsTab extends StatefulWidget {
  const _RecordingsTab();
  @override
  State<_RecordingsTab> createState() => _RecordingsTabState();
}

class _RecordingsTabState extends State<_RecordingsTab> {
  List<File> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dir = await DeviceStorage.libraryDir('recordings');
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.mp4'))
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    if (!mounted) return;
    setState(() {
      _files = files;
      _loading = false;
    });
  }

  String _size(File f) {
    final mb = f.statSync().size / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_files.isEmpty) {
      return const _Empty(
        icon: Icons.videocam_off_outlined,
        text: 'No recordings yet.\nRecord a live session to see it here.',
      );
    }
    return ListView.separated(
      itemCount: _files.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final f = _files[i];
        return ListTile(
          leading: const Icon(Icons.movie_outlined),
          title: Text(f.uri.pathSegments.last,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(_size(f)),
          trailing: PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'share') {
                await Share.shareXFiles([XFile(f.path)]);
              } else if (v == 'delete') {
                await f.delete();
                _load();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'share', child: Text('Share')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        );
      },
    );
  }
}

class _NotesTab extends StatefulWidget {
  const _NotesTab();
  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  List<NoteEntry> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notes = await NotesStore.listAll();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_notes.isEmpty) {
      return const _Empty(
        icon: Icons.note_outlined,
        text: 'No notes yet.\nTake notes in a live session to see them here.',
      );
    }
    return ListView.separated(
      itemCount: _notes.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final n = _notes[i];
        return ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(n.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${n.modified.toLocal()}'.split('.').first),
          onTap: () async {
            final text = await File(n.path).readAsString();
            if (!ctx.mounted) return;
            showDialog(
              context: ctx,
              builder: (_) => AlertDialog(
                title: Text(n.name),
                content: SingleChildScrollView(child: Text(text)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
          trailing: PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'share') {
                await Share.shareXFiles([XFile(n.path)]);
              } else if (v == 'delete') {
                await NotesStore.delete(n.path);
                _load();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'share', child: Text('Share')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
