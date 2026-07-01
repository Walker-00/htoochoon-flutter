import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Screens/Legal/legal_screens.dart';

/// Pre-exam consent prompt. Shown before a proctored exam starts. The student
/// must explicitly agree before monitoring begins; declining returns them to the
/// exam detail without starting.
///
/// Returns `true` if the student agreed, `false`/`null` otherwise.
class ProctoringConsentSheet {
  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _ConsentBody(),
    );
    return result ?? false;
  }
}

class _ConsentBody extends StatelessWidget {
  const _ConsentBody();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget point(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: text.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(body,
                        style: text.bodySmall?.copyWith(
                            height: 1.4,
                            color: cs.onSurface.withValues(alpha: 0.7))),
                  ],
                ),
              ),
            ],
          ),
        );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.shield_outlined, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('This exam is monitored',
                      style: text.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            point(Icons.phone_android, 'Stay in the app',
                'Keep the exam open. Switching apps, split-view, or covering the exam with another app is recorded.'),
            point(Icons.warning_amber_rounded, 'Leaving is recorded',
                'A brief absence gives a warning and adds to an integrity score. Leaving for too long ends the exam automatically.'),
            point(Icons.videocam_outlined, 'Camera & microphone',
                'With your permission, your camera and microphone are analysed on your device to detect behaviour (no face, multiple people, looking away, talking) and to scan your room. No images or audio are recorded or uploaded — only the events.'),
            point(Icons.vpn_lock_outlined, 'Network guard',
                'On supported devices, a local VPN blocks other apps from the internet during the exam. Turning it off is recorded and reported. We never inspect your traffic.'),
            point(Icons.fact_check_outlined, 'Score is advisory',
                'An integrity score (0–100) and a timeline are sent to your teacher and admin. It never changes your grade by itself — your teacher reviews it.'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 16,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const TermsOfServiceScreen()),
                  ),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36)),
                  child: const Text('Terms of Service'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen()),
                  ),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36)),
                  child: const Text('Privacy Policy'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('I agree & start',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
