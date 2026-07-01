import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight on-device learning-streak tracker.
///
/// The backend has no streak field, so we derive one locally from how many
/// consecutive calendar days the user has opened the app:
/// - opened again the same day  → unchanged
/// - opened the next day        → +1
/// - a day (or more) was missed → reset to 1
///
/// This makes the home "Learning Streak" tile reflect real usage instead of a
/// hardcoded number. Persisted per device via SharedPreferences.
class StreakService {
  static const _countKey = 'learning_streak_count';
  static const _lastDayKey = 'learning_streak_last_day';

  /// Records today's open and returns the current streak (>= 1).
  static Future<int> recordAndGet() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dayNumber(DateTime.now());
    final lastDay = prefs.getInt(_lastDayKey);
    var count = prefs.getInt(_countKey) ?? 0;

    if (lastDay == null) {
      count = 1;
    } else if (today == lastDay) {
      // Same day — keep current streak (at least 1).
      if (count < 1) count = 1;
      return count;
    } else if (today == lastDay + 1) {
      count += 1;
    } else {
      count = 1;
    }

    await prefs.setInt(_countKey, count);
    await prefs.setInt(_lastDayKey, today);
    return count;
  }

  /// Days since epoch in local time (ignores time-of-day).
  static int _dayNumber(DateTime dt) {
    final local = DateTime(dt.year, dt.month, dt.day);
    return local.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }
}
