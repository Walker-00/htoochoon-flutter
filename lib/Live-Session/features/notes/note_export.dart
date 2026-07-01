import 'package:share_plus/share_plus.dart';
import 'package:htoochoon_flutter/Live-Session/core/services/device_storage.dart';

enum NoteFormat { txt, md, html }

extension NoteFormatX on NoteFormat {
  String get ext => switch (this) {
        NoteFormat.txt => 'txt',
        NoteFormat.md => 'md',
        NoteFormat.html => 'html',
      };
  String get label => switch (this) {
        NoteFormat.txt => 'Plain text (.txt)',
        NoteFormat.md => 'Markdown (.md)',
        NoteFormat.html => 'Web page (.html)',
      };
}

class NoteExport {
  /// Render the raw note text into the chosen format.
  static String render(String text, NoteFormat format, {String title = 'Note'}) {
    switch (format) {
      case NoteFormat.txt:
      case NoteFormat.md:
        return text;
      case NoteFormat.html:
        return '<!DOCTYPE html>\n<html><head><meta charset="utf-8">'
            '<title>${_esc(title)}</title>'
            '<style>body{font-family:system-ui,sans-serif;max-width:42rem;'
            'margin:2rem auto;padding:0 1rem;line-height:1.6;white-space:pre-wrap}'
            '</style></head><body>${_esc(text)}</body></html>';
    }
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  /// Save to device + return the saved file path.
  static Future<String> saveToDevice(
    String text,
    NoteFormat format, {
    String baseName = 'note',
  }) async {
    final content = render(text, format, title: baseName);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${DeviceStorage.sanitize(baseName)}_$stamp.${format.ext}';
    return DeviceStorage.saveNote(fileName, content);
  }

  /// Save then open the OS share sheet.
  static Future<void> shareNote(
    String text,
    NoteFormat format, {
    String baseName = 'note',
  }) async {
    final path = await saveToDevice(text, format, baseName: baseName);
    await Share.shareXFiles([XFile(path)], subject: baseName);
  }
}
