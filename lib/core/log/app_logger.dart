import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

/// Structured, leveled logging to replace raw `print()`.
///
/// Routes through `dart:developer.log` so output is tagged with a level + source
/// name and shows in DevTools / IDE logging panels with severity colouring,
/// instead of an undifferentiated `print` stream. Debug/info are suppressed in
/// release builds; warnings and errors always emit so crash/issue context
/// survives in production logs.
///
/// Usage:
/// ```dart
/// final _log = AppLog('ChatProvider');
/// _log.d('sendMessage ${msg.id}');
/// _log.e('send failed', err, stack);
/// ```
/// Or the global shorthands for quick swaps from `print`:
/// `logD(x)` `logI(x)` `logW(x, [e, s])` `logE(x, [e, s])`.
class AppLog {
  final String name;
  const AppLog(this.name);

  // All levels emit (verbose by request). Each also mirrors to the console via
  // print() so logs are visible in `flutter run` / device logs, not just DevTools.
  void d(Object? msg) => _emit('D', 500, msg);
  void i(Object? msg) => _emit('I', 800, msg);
  void w(Object? msg, [Object? error, StackTrace? stack]) =>
      _emit('W', 900, msg, error, stack);
  void e(Object? msg, [Object? error, StackTrace? stack]) =>
      _emit('E', 1000, msg, error, stack);

  void _emit(String tag, int level, Object? msg,
      [Object? error, StackTrace? stack]) {
    dev.log('$msg', name: name, level: level, error: error, stackTrace: stack);
    // Console mirror (debugPrint is rate-limit-safe for long lines).
    debugPrint('[$tag/$name] $msg');
    if (error != null) debugPrint('[$tag/$name] error: $error');
    if (stack != null) debugPrint('[$tag/$name] stack: $stack');
  }
}

const AppLog _app = AppLog('app');

void logD(Object? msg) => _app.d(msg);
void logI(Object? msg) => _app.i(msg);
void logW(Object? msg, [Object? error, StackTrace? stack]) =>
    _app.w(msg, error, stack);
void logE(Object? msg, [Object? error, StackTrace? stack]) =>
    _app.e(msg, error, stack);
