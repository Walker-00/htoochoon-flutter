import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart' as fhtml;
import 'package:markdown/markdown.dart' as md;
import 'package:htoochoon_flutter/Theme/themedata.dart';

/// Renders question / answer / assignment content that may be **Markdown**
/// (new) or **HTML** (legacy) — without any data migration.
///
/// Authoring moved from "type raw HTML into a TextField" to Markdown. Old rows
/// are still stored as HTML, so we detect the format and route accordingly:
///   • looks like HTML  → render as-is via flutter_html (legacy path, untouched)
///   • otherwise        → treat as Markdown, convert to HTML, render via the
///                        same themed flutter_html pipeline (one renderer, one
///                        Peacock style map, consistent everywhere).
class RichContent extends StatelessWidget {
  final String? data;
  final double fontSize;

  const RichContent(this.data, {super.key, this.fontSize = 14});

  /// Conservative HTML sniff: must start with a real tag opener (`<p`, `</`,
  /// `<!`) so plain text like "2 < 3" is treated as Markdown, not HTML.
  static bool _looksLikeHtml(String t) {
    final s = t.trimLeft();
    if (!s.startsWith('<')) return false;
    return RegExp(r'^<\s*[a-zA-Z!/]').hasMatch(s);
  }

  String _toHtml(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (_looksLikeHtml(trimmed)) return trimmed; // legacy HTML, passed through
    return md.markdownToHtml(
      trimmed,
      extensionSet: md.ExtensionSet.gitHubWeb,
    );
  }

  @override
  Widget build(BuildContext context) {
    final raw = data;
    if (raw == null || raw.trim().isEmpty) return const SizedBox.shrink();

    final primary = AppTheme.getTextPrimary(context);
    final surfaceVariant = AppTheme.getSurfaceVariant(context);

    return fhtml.Html(
      data: _toHtml(raw),
      style: {
        'body': fhtml.Style(
          margin: fhtml.Margins.zero,
          padding: fhtml.HtmlPaddings.zero,
          color: primary,
          fontSize: fhtml.FontSize(fontSize),
          lineHeight: const fhtml.LineHeight(1.5),
        ),
        'p': fhtml.Style(margin: fhtml.Margins.only(bottom: 6, top: 0)),
        'strong': fhtml.Style(color: primary),
        'em': fhtml.Style(color: primary),
        'ul': fhtml.Style(
          margin: fhtml.Margins.only(left: 16, top: 0, bottom: 6),
        ),
        'ol': fhtml.Style(
          margin: fhtml.Margins.only(left: 16, top: 0, bottom: 6),
        ),
        'li': fhtml.Style(margin: fhtml.Margins.only(bottom: 2)),
        'code': fhtml.Style(
          backgroundColor: surfaceVariant,
          fontFamily: 'monospace',
          padding: fhtml.HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
        ),
        'pre': fhtml.Style(
          backgroundColor: surfaceVariant,
          padding: fhtml.HtmlPaddings.all(10),
          margin: fhtml.Margins.only(bottom: 6),
        ),
        'blockquote': fhtml.Style(
          margin: fhtml.Margins.only(left: 8, bottom: 6),
          padding: fhtml.HtmlPaddings.only(left: 10),
          color: AppTheme.getTextSecondary(context),
        ),
        'a': fhtml.Style(color: AppTheme.peacockTeal),
      },
    );
  }
}
