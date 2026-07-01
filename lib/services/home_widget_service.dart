import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../core/log/app_logger.dart';

/// Pushes "next upcoming session / deadline" data to the native home-screen
/// widgets (iOS WidgetKit, Android AppWidget). The native widget layouts live in
/// the platform projects — see NATIVE_TODO.md. This Dart side only shares data
/// and asks the OS to refresh; it no-ops gracefully if no widget is installed.
class HomeWidgetService {
  HomeWidgetService._();
  static final HomeWidgetService instance = HomeWidgetService._();

  static const _appGroupId = 'group.com.example.htoochoon_flutter';
  static const _androidWidgetName = 'HtooChoonWidgetProvider';
  static const _iOSWidgetName = 'HtooChoonWidget';

  final _log = const AppLog('HomeWidgetService');
  bool _inited = false;

  Future<void> _ensureInit() async {
    if (_inited) return;
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
      _inited = true;
    } catch (e) {
      _log.w('HomeWidget init failed', e);
    }
  }

  /// Update the widget with the next session + next deadline. Safe to call
  /// whenever the dashboard/session list refreshes.
  Future<void> updateUpcoming({
    String? nextSessionTitle,
    DateTime? nextSessionAt,
    String? nextDeadlineTitle,
    DateTime? nextDeadlineAt,
    int? streakDays,
  }) async {
    if (kIsWeb) return; // widgets are mobile-only
    await _ensureInit();
    try {
      await HomeWidget.saveWidgetData<String>(
          'next_session_title', nextSessionTitle ?? 'No upcoming session');
      await HomeWidget.saveWidgetData<String>(
          'next_session_at', nextSessionAt?.toIso8601String() ?? '');
      await HomeWidget.saveWidgetData<String>(
          'next_deadline_title', nextDeadlineTitle ?? '');
      await HomeWidget.saveWidgetData<String>(
          'next_deadline_at', nextDeadlineAt?.toIso8601String() ?? '');
      await HomeWidget.saveWidgetData<int>('streak_days', streakDays ?? 0);
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iOSWidgetName,
      );
    } catch (e) {
      _log.w('updateUpcoming failed (widget may not be installed)', e);
    }
  }
}
