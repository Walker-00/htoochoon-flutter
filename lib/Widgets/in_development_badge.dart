import 'package:flutter/material.dart';

/// A compact "In development" pill used to flag features that are static
/// placeholders / not yet wired to real data or the backend.
///
/// Keep it small — it is meant to sit inline next to a title/label without
/// dominating the layout.
class InDevelopmentBadge extends StatelessWidget {
  const InDevelopmentBadge({
    super.key,
    this.label = 'In development',
    this.icon = Icons.construction,
    this.compact = false,
  });

  final String label;
  final IconData icon;

  /// When true, shows the icon only (no text) for very tight spaces.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Amber / warning tone so it reads as "work in progress" everywhere.
    const bg = Color(0xFFFEF3C7); // Amber 100
    const fg = Color(0xFF92400E); // Amber 800

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          if (!compact) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: fg,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shows a standard "coming soon" SnackBar. Use this for taps on controls that
/// are visually present but not yet functional.
void showComingSoonSnackBar(BuildContext context, [String? feature]) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.construction, size: 18, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                feature == null
                    ? 'This feature is coming soon.'
                    : '$feature is coming soon.',
              ),
            ),
          ],
        ),
      ),
    );
}

/// Wraps [child] so tapping it surfaces the "coming soon" SnackBar. Handy for
/// making a static tile clearly signal that it is not yet wired up.
class ComingSoonTap extends StatelessWidget {
  const ComingSoonTap({
    super.key,
    required this.child,
    this.feature,
  });

  final Widget child;
  final String? feature;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showComingSoonSnackBar(context, feature),
      child: child,
    );
  }
}
