import 'package:flutter/material.dart';

/// Status pill for a submission's review lifecycle:
/// Submitted → Under review → Graded → Returned.
class ReturnStatusBadge extends StatelessWidget {
  /// Raw status string from the backend (review_status), case-insensitive.
  final String? status;
  const ReturnStatusBadge({super.key, this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = (status ?? 'SUBMITTED').toUpperCase();
    late final Color bg;
    late final Color fg;
    late final String label;
    late final IconData icon;
    switch (s) {
      case 'RETURNED':
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
        label = 'Returned';
        icon = Icons.assignment_turned_in;
        break;
      case 'GRADED':
        bg = cs.tertiaryContainer;
        fg = cs.onTertiaryContainer;
        label = 'Graded';
        icon = Icons.grading;
        break;
      case 'UNDER_REVIEW':
        bg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
        label = 'Under review';
        icon = Icons.hourglass_top;
        break;
      default:
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
        label = 'Submitted';
        icon = Icons.upload_file;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}
