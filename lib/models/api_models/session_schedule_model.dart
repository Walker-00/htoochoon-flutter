/// Recurrence config + RRULE builder for the scheduling wizard. No codegen.

enum Freq { none, daily, weekly, monthly }

enum EndMode { count, until }

enum EditScope { single, future, all }

extension EditScopeWire on EditScope {
  String get wire => switch (this) {
        EditScope.single => 'SINGLE',
        EditScope.future => 'FUTURE',
        EditScope.all => 'ALL',
      };
}

class RecurrenceConfig {
  Freq freq;
  int interval; // every N days/weeks/months
  Set<int> weekdays; // ISO 1=Mon .. 7=Sun (weekly only)
  EndMode endMode;
  int count; // # occurrences (capped 1..200 server-side)
  DateTime? until; // local end date

  RecurrenceConfig({
    this.freq = Freq.none,
    this.interval = 1,
    Set<int>? weekdays,
    this.endMode = EndMode.count,
    this.count = 8,
    this.until,
  }) : weekdays = weekdays ?? {};

  bool get isRecurring => freq != Freq.none;

  static const _byday = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
  static String _two(int n) => n.toString().padLeft(2, '0');

  /// RFC-5545 RRULE, or null for a one-off. `startLocal` seeds weekly/monthly.
  String? toRRule(DateTime startLocal) {
    if (freq == Freq.none) return null;
    final parts = <String>[];
    switch (freq) {
      case Freq.daily:
        parts.add('FREQ=DAILY');
        break;
      case Freq.weekly:
        parts.add('FREQ=WEEKLY');
        final days = (weekdays.isEmpty ? {startLocal.weekday} : weekdays).toList()
          ..sort();
        parts.add('BYDAY=${days.map((d) => _byday[d - 1]).join(',')}');
        break;
      case Freq.monthly:
        parts
          ..add('FREQ=MONTHLY')
          ..add('BYMONTHDAY=${startLocal.day}');
        break;
      case Freq.none:
        return null;
    }
    if (interval > 1) parts.add('INTERVAL=$interval');
    if (endMode == EndMode.count) {
      parts.add('COUNT=${count.clamp(1, 200)}');
    } else if (until != null) {
      final u = until!.toUtc();
      parts.add('UNTIL=${u.year}${_two(u.month)}${_two(u.day)}T'
          '${_two(u.hour)}${_two(u.minute)}00Z');
    }
    return parts.join(';');
  }

  static DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  static DateTime _addMonths(DateTime d, int months) {
    final total = d.month - 1 + months;
    final year = d.year + total ~/ 12;
    final month = total % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day; // day 0 → last day of month
    return DateTime(
        year, month, d.day > lastDay ? lastDay : d.day, d.hour, d.minute);
  }

  /// Concrete occurrence start-times for the preview list. One-off (none) →
  /// `[start]`. Honors interval + count/until; capped at [max] (mirrors the
  /// server's 200-occurrence cap in recurrence.util.ts).
  List<DateTime> expand(DateTime start, {int max = 200}) {
    if (freq == Freq.none) return [start];
    final limit = endMode == EndMode.count ? count.clamp(1, max) : max;
    bool withinUntil(DateTime d) {
      if (endMode != EndMode.until || until == null) return true;
      return !d.isAfter(DateTime(until!.year, until!.month, until!.day, 23, 59));
    }

    final out = <DateTime>[];
    switch (freq) {
      case Freq.daily:
        var d = start;
        var guard = 0;
        while (out.length < limit && withinUntil(d) && guard < max * 2) {
          out.add(d);
          d = d.add(Duration(days: interval));
          guard++;
        }
        break;
      case Freq.weekly:
        final days = (weekdays.isEmpty ? {start.weekday} : weekdays).toList()
          ..sort();
        final monday0 = _mondayOf(start);
        var w = 0;
        while (out.length < limit && w < 520) {
          final weekMonday = monday0.add(Duration(days: 7 * interval * w));
          for (final wd in days) {
            final occ = DateTime(weekMonday.year, weekMonday.month,
                    weekMonday.day, start.hour, start.minute)
                .add(Duration(days: wd - 1));
            if (occ.isBefore(start)) continue;
            if (withinUntil(occ) && out.length < limit) out.add(occ);
          }
          w++;
          if (endMode == EndMode.until &&
              until != null &&
              monday0
                  .add(Duration(days: 7 * interval * w))
                  .isAfter(until!.add(const Duration(days: 7)))) {
            break;
          }
        }
        out.sort();
        if (out.length > limit) out.removeRange(limit, out.length);
        break;
      case Freq.monthly:
        var n = 0;
        while (out.length < limit && n < max * 2) {
          final occ = _addMonths(start, interval * n);
          if (!withinUntil(occ)) break;
          out.add(occ);
          n++;
        }
        break;
      case Freq.none:
        return [start];
    }
    return out;
  }

  /// Human summary for the review step, e.g. "Every 2 weeks on Mon, Wed · 8 times".
  String summary(DateTime startLocal) {
    if (freq == Freq.none) return 'Does not repeat';
    final every = interval > 1 ? '$interval ' : '';
    String base;
    switch (freq) {
      case Freq.daily:
        base = 'Every ${every}day${interval > 1 ? 's' : ''}';
        break;
      case Freq.weekly:
        final days =
            (weekdays.isEmpty ? {startLocal.weekday} : weekdays).toList()..sort();
        const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        base = 'Every ${every}week${interval > 1 ? 's' : ''} on '
            '${days.map((d) => names[d - 1]).join(', ')}';
        break;
      case Freq.monthly:
        base = 'Every ${every}month${interval > 1 ? 's' : ''} on day ${startLocal.day}';
        break;
      case Freq.none:
        return 'Does not repeat';
    }
    final end = endMode == EndMode.count
        ? '$count times'
        : until != null
            ? 'until ${until!.month}/${until!.day}/${until!.year}'
            : '';
    return end.isEmpty ? base : '$base · $end';
  }
}

/// POST /live-sessions/series body (manual toJson).
class SeriesRequest {
  final String topic, courseId, hostId, timezone, rrule, startTime; // startTime: UTC ISO
  final int durationMin;
  SeriesRequest({
    required this.topic,
    required this.courseId,
    required this.hostId,
    required this.timezone,
    required this.rrule,
    required this.startTime,
    required this.durationMin,
  });
  Map<String, dynamic> toJson() => {
        'topic': topic,
        'courseId': courseId,
        'hostId': hostId,
        'timezone': timezone,
        'rrule': rrule,
        'startTime': startTime,
        'durationMin': durationMin,
      };
}
