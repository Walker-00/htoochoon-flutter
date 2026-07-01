import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:media_store_plus/media_store_plus.dart';

/// Saves user-facing artifacts (live-session recordings + exported notes) to the
/// device in a shared `HtooChoon` folder, plus an app-private mirror used by the
/// in-app Library so files are always listable even when the public gallery is
/// unavailable (desktop / permission denied).
///
/// Recordings: `<Video>/HtooChoon/Live_<Org>_<Program>_<Date>.<ext>`
/// Notes:      `<Documents>/HtooChoon/<name>.<ext>` (+ gallery copy where possible)
class DeviceStorage {
  static final MediaStore _mediaStore = MediaStore();
  static bool _mediaStoreInit = false;

  static Future<void> _ensureMediaStore() async {
    if (_mediaStoreInit) return;
    MediaStore.appFolder = 'HtooChoon';
    _mediaStoreInit = true;
  }

  /// Sanitize a label for use inside a filename (org / program names).
  static String sanitize(String s) =>
      s.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-').replaceAll(RegExp(r'-+'), '-');

  /// `Live_<Org>_<Program>_<yyyy-MM-dd_HHmm>.<ext>`
  static String recordingName({
    required String org,
    required String program,
    required DateTime date,
    String ext = 'mp4',
  }) {
    final d = date;
    final stamp =
        '${d.year}-${_pad2(d.month)}-${_pad2(d.day)}_${_pad2(d.hour)}${_pad2(d.minute)}';
    return 'Live_${sanitize(org)}_${sanitize(program)}_$stamp.$ext';
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');

  /// App-private library dir (always writable) for the Library screen to list.
  static Future<Directory> libraryDir(String sub) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/htoochoon_library/$sub');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Move a finished recording temp file into the gallery (Movies/HtooChoon on
  /// Android) and mirror into the app library. Returns the final library path.
  static Future<String> saveRecording(File tempFile, String fileName) async {
    final lib = await libraryDir('recordings');
    final dest = File('${lib.path}/$fileName');
    try {
      await tempFile.copy(dest.path);
    } catch (_) {}

    if (Platform.isAndroid) {
      try {
        await _ensureMediaStore();
        await _mediaStore.saveFile(
          tempFilePath: tempFile.path,
          dirType: DirType.video,
          dirName: DirName.movies,
        );
      } catch (_) {
        // Gallery write failed (permission / API) — app-library copy still exists.
      }
    } else {
      // Desktop: also drop a copy under ~/Videos/HtooChoon for discoverability.
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'];
      if (home != null) {
        try {
          final vids = Directory('$home/Videos/HtooChoon');
          if (!await vids.exists()) await vids.create(recursive: true);
          await tempFile.copy('${vids.path}/$fileName');
        } catch (_) {}
      }
    }
    try {
      if (await tempFile.exists()) await tempFile.delete();
    } catch (_) {}
    return dest.path;
  }

  /// Write an exported note. Returns the app-library path (used for share).
  static Future<String> saveNote(String fileName, String content) async {
    final lib = await libraryDir('notes');
    final dest = File('${lib.path}/$fileName');
    await dest.writeAsString(content);

    if (Platform.isAndroid) {
      try {
        await _ensureMediaStore();
        await _mediaStore.saveFile(
          tempFilePath: dest.path,
          dirType: DirType.download,
          dirName: DirName.download,
        );
      } catch (_) {}
    }
    return dest.path;
  }
}
