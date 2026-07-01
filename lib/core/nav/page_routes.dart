import 'package:flutter/material.dart';

/// Reusable page transitions to replace bare [MaterialPageRoute] where a softer
/// motion is wanted (appendix §21). Drop-in: `Navigator.push(context, fadeRoute(MyPage()))`.

/// Cross-fade. Good for tab-like / sibling navigation.
Route<T> fadeRoute<T>(Widget page, {Duration duration = const Duration(milliseconds: 250)}) {
  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// Slide-up + fade. Good for detail / modal-ish pushes.
Route<T> slideUpRoute<T>(Widget page, {Duration duration = const Duration(milliseconds: 300)}) {
  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Scale + fade. Good for hero-paired card → detail.
Route<T> scaleFadeRoute<T>(Widget page, {Duration duration = const Duration(milliseconds: 280)}) {
  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
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
