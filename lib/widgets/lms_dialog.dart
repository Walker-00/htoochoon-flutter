import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';

/// Branded Peacock dialog shell: rounded 16px card with an icon header, a
/// scrollable content area, and an optional action row. Pair with
/// [showLMSDialog] for the scale+fade entrance. The global `dialogTheme`
/// already gives every dialog the 16px corner + surface; this adds the
/// branded header/buttons + consistent spacing for first-class flows.
class LMSDialog extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final bool showClose;
  final double maxWidth;

  const LMSDialog({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.subtitle,
    this.actions,
    this.showClose = true,
    this.maxWidth = 480,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: const RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusXl),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppTheme.peacockTeal.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: AppTheme.peacockTeal, size: 20),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.getTextPrimary(context),
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle!,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.getTextSecondary(context),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (showClose)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: child,
              ),
            ),
            if (actions != null && actions!.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions!.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      actions![i],
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows a dialog with a smooth scale+fade entrance (Peacock motion, ~180ms).
Future<T?> showLMSDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String barrierLabel = 'Dialog',
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, _, __) => builder(ctx),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Branded confirm dialog. Returns true if the user confirmed.
class LMSConfirmDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    IconData icon = Icons.help_outline,
    bool danger = false,
  }) async {
    final res = await showLMSDialog<bool>(
      context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return LMSDialog(
          icon: icon,
          title: title,
          showClose: false,
          maxWidth: 400,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(cancelLabel),
            ),
            FilledButton(
              style: danger
                  ? FilledButton.styleFrom(
                      backgroundColor: cs.error,
                      foregroundColor: cs.onError,
                    )
                  : null,
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmLabel),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppTheme.getTextPrimary(ctx),
              ),
            ),
          ),
        );
      },
    );
    return res ?? false;
  }
}
