import 'package:flutter/material.dart';
import 'legal_content.dart';

/// Read-only viewers for the Terms of Service and Privacy Policy. Reachable from
/// the pre-exam proctoring consent sheet (and can be linked from settings).

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const _LegalScaffold(title: 'Terms of Service', markdown: termsOfServiceMd);
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const _LegalScaffold(title: 'Privacy Policy', markdown: privacyPolicyMd);
}

class _LegalScaffold extends StatelessWidget {
  final String title;
  final String markdown;
  const _LegalScaffold({required this.title, required this.markdown});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: MarkdownLiteView(markdown: markdown),
        ),
      ),
    );
  }
}

/// Tiny renderer for the lightweight markdown used in [legal_content.dart]:
/// `#` / `##` headings, `- ` bullets, `_italic_` emphasis lines, blank lines as
/// spacing, everything else as a paragraph. Avoids pulling a markdown package.
class MarkdownLiteView extends StatelessWidget {
  final String markdown;
  const MarkdownLiteView({super.key, required this.markdown});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final blocks = <Widget>[];

    for (final rawLine in markdown.trim().split('\n')) {
      final line = rawLine.trimRight();
      if (line.isEmpty) {
        blocks.add(const SizedBox(height: 10));
        continue;
      }
      if (line.startsWith('## ')) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Text(line.substring(3),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ));
      } else if (line.startsWith('# ')) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(line.substring(2),
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900)),
        ));
      } else if (line.startsWith('- ')) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•  ',
                  style: TextStyle(color: cs.primary, height: 1.5)),
              Expanded(
                child: Text(_stripEmphasis(line.substring(2)),
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
              ),
            ],
          ),
        ));
      } else {
        final italic = line.startsWith('_') && line.endsWith('_');
        blocks.add(Text(
          _stripEmphasis(line),
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.5,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            color: italic ? cs.onSurface.withValues(alpha: 0.6) : null,
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  String _stripEmphasis(String s) {
    var out = s;
    if (out.startsWith('_') && out.endsWith('_') && out.length > 1) {
      out = out.substring(1, out.length - 1);
    }
    // Strip inline **bold** / _italic_ markers (kept simple).
    out = out.replaceAll('**', '');
    return out;
  }
}
