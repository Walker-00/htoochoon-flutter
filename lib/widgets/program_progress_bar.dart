import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';

/// Computed program progress + human-readable contextual label.
class ProgramProgress {
  final double percent; // 0..1
  final String label; // primary text, e.g. "Week 3 of 12"
  final String? sub; // optional secondary, e.g. "12 days left"
  const ProgramProgress({required this.percent, required this.label, this.sub});

  /// Returns null when the schedule is missing or invalid (`end <= start`),
  /// so callers can simply hide the bar.
  static ProgramProgress? of(DateTime? start, DateTime? end) {
    if (start == null || end == null) return null;
    if (!end.isAfter(start)) return null;

    final now = DateTime.now();
    if (now.isBefore(start)) {
      final days = start.difference(now).inDays;
      return ProgramProgress(
        percent: 0,
        label: days <= 0 ? 'Starts today' : 'Starts in $days ${_days(days)}',
      );
    }
    if (now.isAfter(end)) {
      return const ProgramProgress(percent: 1, label: 'Completed');
    }

    final total = end.difference(start).inSeconds;
    final elapsed = now.difference(start).inSeconds;
    final pct = (elapsed / total).clamp(0.0, 1.0);
    final daysLeft = end.difference(now).inDays;
    final spanDays = end.difference(start).inDays;

    if (spanDays >= 14) {
      final totalWeeks = (spanDays / 7).ceil();
      final currentWeek =
          ((now.difference(start).inDays / 7).floor() + 1).clamp(1, totalWeeks);
      return ProgramProgress(
        percent: pct,
        label: 'Week $currentWeek of $totalWeeks',
        sub: daysLeft <= 0 ? 'Last day' : '$daysLeft ${_days(daysLeft)} left',
      );
    }
    return ProgramProgress(
      percent: pct,
      label: daysLeft <= 0
          ? 'Last day'
          : '$daysLeft ${_days(daysLeft)} remaining',
    );
  }

  static String _days(int n) => n == 1 ? 'day' : 'days';
}

/// Peacock progress bar for a program's cohort schedule. Renders nothing when
/// the schedule is missing/invalid. `light: true` = white-on-teal for use on
/// the dark/gradient detail header.
class ProgramProgressBar extends StatelessWidget {
  final DateTime? start;
  final DateTime? end;
  final bool light;

  const ProgramProgressBar({
    super.key,
    required this.start,
    required this.end,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = ProgramProgress.of(start, end);
    if (p == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final fill = light ? Colors.white : AppTheme.peacockTeal;
    final track =
        light ? Colors.white.withValues(alpha: 0.25) : cs.surfaceContainerHighest;
    final textColor = light ? Colors.white : AppTheme.getTextPrimary(context);
    final subColor = light
        ? Colors.white.withValues(alpha: 0.85)
        : AppTheme.getTextSecondary(context);
    final pctLabel = '${(p.percent * 100).round()}%';

    return Semantics(
      label: 'Program progress',
      value: '$pctLabel complete. ${p.label}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  p.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                p.sub ?? pctLabel,
                style: TextStyle(fontSize: 11, color: subColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: p.percent,
              minHeight: 8,
              backgroundColor: track,
              valueColor: AlwaysStoppedAnimation<Color>(fill),
            ),
          ),
        ],
      ),
    );
  }
}
