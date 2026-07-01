import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';
import 'package:htoochoon_flutter/widgets/rich_content.dart';

/// A Markdown text input with a "Write / Preview" toggle. Replaces the old
/// "type raw HTML into a TextField" authoring flow for question text and
/// assignment instructions. Preview renders live through [RichContent].
class MarkdownField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const MarkdownField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.minLines = 3,
    this.maxLines = 8,
    this.onChanged,
  });

  @override
  State<MarkdownField> createState() => _MarkdownFieldState();
}

class _MarkdownFieldState extends State<MarkdownField> {
  bool _preview = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
            ),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Write'),
                  icon: Icon(Icons.edit_outlined, size: 14),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Preview'),
                  icon: Icon(Icons.visibility_outlined, size: 14),
                ),
              ],
              selected: {_preview},
              onSelectionChanged: (s) => setState(() => _preview = s.first),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_preview)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.getSurfaceVariant(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.getBorder(context)),
            ),
            child: widget.controller.text.trim().isEmpty
                ? Text(
                    'Nothing to preview yet',
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : RichContent(widget.controller.text),
          )
        else
          TextField(
            controller: widget.controller,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: widget.hint,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          'Markdown:  **bold**  *italic*  - list  `code`  # heading',
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.getTextSecondary(context),
          ),
        ),
      ],
    );
  }
}
