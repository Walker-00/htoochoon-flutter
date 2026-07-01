import 'package:flutter/material.dart';

/// Default max readable content width. Beyond this, layouts get centered with
/// empty gutters instead of stretching full-bleed (which looks ugly on wide
/// desktop / web windows).
const double kContentMaxWidth = 1100;

/// Narrower cap for form-like screens (settings, single-column reading).
const double kFormMaxWidth = 760;

/// Horizontal padding that centers content at [max] on wide screens, falling
/// back to [pad] gutters on narrow screens. Use as the padding of a
/// `SliverPadding` so sliver lists/grids never stretch full width.
EdgeInsets centeredPagePadding(
  BuildContext context, {
  double max = kContentMaxWidth,
  double pad = 16,
  double top = 16,
  double bottom = 16,
}) {
  final w = MediaQuery.of(context).size.width;
  final side = w > max ? (w - max) / 2 : pad;
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

/// Centers [child] within [maxWidth] for non-sliver (box) layouts.
class MaxWidthBox extends StatelessWidget {
  final double maxWidth;
  final Widget child;
  const MaxWidthBox({
    super.key,
    this.maxWidth = kContentMaxWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}
