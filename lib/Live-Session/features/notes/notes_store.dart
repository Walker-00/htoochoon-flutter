import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Local-only persistence for live-session personal notes. One markdown file per
/// (session, user). Used as the autosave target (fallback save) and as the data
/// source for the Library → Notes tab. Never synced, never shared automatically.
class NotesStore {
  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/htoochoon_notes');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-');

  static Future<File> fileFor(String sessionId, String userId) async {
    final dir = await _dir();
    return File('${dir.path}/${_safe(sessionId)}_${_safe(userId)}.md');
  }

  /// Autosave / fallback save.
  static Future<void> save(String sessionId, String userId, String text) async {
    final f = await fileFor(sessionId, userId);
    await f.writeAsString(text, flush: true);
  }

  static Future<String> load(String sessionId, String userId) async {
    final f = await fileFor(sessionId, userId);
    if (await f.exists()) return f.readAsString();
    return '';
  }

  /// All saved notes (for the Library screen), newest first.
  static Future<List<NoteEntry>> listAll() async {
    final dir = await _dir();
    if (!await dir.exists()) return [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList();
    files.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files
        .map((f) => NoteEntry(
              path: f.path,
              name: f.uri.pathSegments.last,
              modified: f.statSync().modified,
            ))
        .toList();
  }

  static Future<void> delete(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}

class NoteEntry {
  final String path;
  final String name;
  final DateTime modified;
  const NoteEntry({required this.path, required this.name, required this.modified});
}
