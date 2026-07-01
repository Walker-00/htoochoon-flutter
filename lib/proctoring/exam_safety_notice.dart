import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'exam_safety.dart';

/// Pre-exam transparency screen. Shown before any monitoring starts: it tells
/// the student the exam's safety level, EXACTLY what will be tracked on their
/// device, and that proceeding = consent. No checkbox — tapping "Start exam" is
/// the agreement (matches the login terms-acceptance model).
///
/// Returns true if the student chose to proceed, false if they backed out.
class ExamSafetyNotice {
  static Future<bool> show(BuildContext context, ExamSafety safety) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SafetyNoticeDialog(safety: safety),
    );
    return result ?? false;
  }
}

class _MonitorItem {
  final IconData icon;
  final String text;
  const _MonitorItem(this.icon, this.text);
}

class _SafetyNoticeDialog extends StatelessWidget {
  final ExamSafety safety;
  const _SafetyNoticeDialog({required this.safety});

  Color _levelColor(BuildContext context) {
    switch (safety.level) {
      case ExamSafetyLevel.none:
        return Colors.grey;
      case ExamSafetyLevel.mid:
        return Colors.blue;
      case ExamSafetyLevel.high:
        return Colors.orange;
      case ExamSafetyLevel.extreme:
        return Colors.red;
    }
  }

  List<_MonitorItem> _items() {
    final items = <_MonitorItem>[];
    if (safety.appSwitchProctor) {
      items.add(const _MonitorItem(Icons.swap_horiz,
          'Leaving or switching away from the exam app is detected and recorded. Repeated/long absences end the exam.'));
    }
    if (safety.cameraProctor) {
      items.add(const _MonitorItem(Icons.videocam_outlined,
          'Your front camera and microphone are monitored for faces and voices during the exam.'));
    }
    if (safety.roomScan) {
      items.add(const _MonitorItem(Icons.threesixty,
          'A short camera scan of your room is taken before you start.'));
    }
    if (safety.networkDetect) {
      items.add(const _MonitorItem(Icons.wifi_find_outlined,
          'Your network is checked for a proxy/VPN, and your public IP is recorded (and re-checked for changes).'));
    }
    if (safety.networkBlock) {
      items.add(const _MonitorItem(Icons.block,
          'Known answer/AI/chat sites are blocked for the duration of the exam (this asks for an admin prompt on desktop).'));
    }
    if (items.isEmpty) {
      items.add(const _MonitorItem(Icons.check_circle_outline,
          'No monitoring is enabled for this exam.'));
    }
    return items;
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(context);
    final items = _items();
    final base = TextStyle(
      fontSize: 11.5,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
    );
    final link = base.copyWith(color: color, fontWeight: FontWeight.w700);

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Illustration: shield + a row of the active-measure icons ──
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.verified_user_outlined,
                          size: 44, color: color),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      children: items
                          .take(5)
                          .map((i) => CircleAvatar(
                                radius: 16,
                                backgroundColor: color.withValues(alpha: 0.10),
                                child: Icon(i.icon, size: 17, color: color),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('Exam safety: ',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(safety.levelString,
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'For fairness, this exam is monitored. Here is exactly what '
                'happens on your device:',
                style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: items
                        .map((i) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(i.icon, size: 18, color: color),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(i.text,
                                        style: const TextStyle(fontSize: 12.5)),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('By starting, you agree to our ', style: base),
                  InkWell(
                      onTap: () => _open('https://htoochoon.com/terms'),
                      child: Text('Terms', style: link)),
                  Text(' and ', style: base),
                  InkWell(
                      onTap: () => _open('https://htoochoon.com/privacy'),
                      child: Text('Privacy Policy', style: link)),
                  Text(', and to this monitoring.', style: base),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: color),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Start exam'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
