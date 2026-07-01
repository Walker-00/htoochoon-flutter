import 'package:flutter/material.dart';

/// Error state with a recovery path (UX §8 `error-recovery`): message + Retry.
/// Keep the message human and actionable, not a raw exception dump.
class ErrorRetry extends StatelessWidget {
  final String message;
  final Future<void> Function()? onRetry;
  final IconData icon;

  const ErrorRetry({
    super.key,
    this.message = 'Something went wrong.',
    this.onRetry,
    this.icon = Icons.cloud_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: cs.error),
            const SizedBox(height: 16),
            Text(
              message,
              style: tt.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => onRetry!.call(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
