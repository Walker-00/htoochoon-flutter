import 'package:flutter/material.dart';

/// Full-screen "this feature is still being built" page.
///
/// Use for controls/notifications that point at a feature which exists in the
/// UI but is not wired to a real screen/backend yet (e.g. the AI ROI Insight
/// card, or a notification whose target screen isn't built). Prefer routing
/// here over a dead-end SnackBar when the user actively navigated to reach it.
class InDevelopmentScreen extends StatelessWidget {
  const InDevelopmentScreen({super.key, this.feature});

  /// Human-readable name of the feature, shown as a chip. `null` = generic.
  final String? feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Amber accent, matching InDevelopmentBadge, tuned per brightness.
    final accent = theme.brightness == Brightness.dark
        ? const Color(0xFFFBBF24) // Amber 400
        : const Color(0xFF92400E); // Amber 800
    final accentBg = theme.brightness == Brightness.dark
        ? const Color(0xFFFBBF24).withValues(alpha: 0.14)
        : const Color(0xFFFEF3C7); // Amber 100

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      color: accentBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.construction_rounded,
                        size: 56, color: accent),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Still in development',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "We're actively building this. It isn't ready yet — check "
                    'back after an update.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.65),
                      height: 1.5,
                    ),
                  ),
                  if (feature != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: accentBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: accent.withValues(alpha: 0.28), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              size: 15, color: accent),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              feature!,
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text('Go back'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text(
                                "We'll let you know when this is ready."),
                          ),
                        );
                    },
                    child: const Text('Notify me when ready'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pushes the [InDevelopmentScreen]. Use for taps on features not yet built.
void openInDevelopment(BuildContext context, [String? feature]) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => InDevelopmentScreen(feature: feature)),
  );
}
