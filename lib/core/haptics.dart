import 'package:flutter/services.dart';

/// Thin, safe wrapper over [HapticFeedback]. Centralizes tactile responses so
/// they stay consistent and are easy to disable app-wide later. All calls are
/// best-effort — they no-op on platforms/devices without a vibrator.
class Haptics {
  Haptics._();

  /// Light tap — selection, toggles, small confirmations.
  static void light() => HapticFeedback.selectionClick();

  /// Medium — primary button press, send actions.
  static void medium() => HapticFeedback.lightImpact();

  /// Heavy — important/destructive confirmations.
  static void heavy() => HapticFeedback.mediumImpact();

  /// Success / completion buzz.
  static void success() => HapticFeedback.heavyImpact();

  /// Long-press affordance.
  static void longPress() => HapticFeedback.vibrate();
}
