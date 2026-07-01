import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';

/// 🦚 Scalable Peacock brand mark — a peacock "eye" feather rising from a
/// graduation cap (knowledge as the foundation, the plume of intelligence/growth
/// above it). Pure [CustomPainter] vector art, so it stays crisp at any size and
/// needs no asset/SVG dependency.
///
/// - [size]    : square edge in logical px.
/// - [mono]    : render a single-color silhouette (with a punched feather eye)
///               for tight spots like an AppBar; otherwise full Peacock palette.
/// - [monoColor]: the silhouette color (defaults to the theme's onSurface).
class PeacockLogo extends StatelessWidget {
  final double size;
  final bool mono;
  final Color? monoColor;

  const PeacockLogo({
    super.key,
    this.size = 48,
    this.mono = false,
    this.monoColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = monoColor ?? Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PeacockLogoPainter(mono: mono, monoColor: c),
      ),
    );
  }
}

class _PeacockLogoPainter extends CustomPainter {
  final bool mono;
  final Color monoColor;
  _PeacockLogoPainter({required this.mono, required this.monoColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Everything is authored on a 100×100 grid, then scaled to `size`.
    final double u = size.shortestSide / 100.0;
    Offset p(double x, double y) => Offset(x * u, y * u);
    double s(double v) => v * u;

    Paint fill(Color color) => Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = color;
    Paint stroke(Color color, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..strokeWidth = s(w)
      ..color = color;

    // ── Geometry ──────────────────────────────────────────────────────────
    // Feather plume (almond / leaf).
    final plume = Path()
      ..moveTo(p(50, 5).dx, p(50, 5).dy)
      ..cubicTo(p(75, 15).dx, p(75, 15).dy, p(77, 44).dx, p(77, 44).dy,
          p(50, 60).dx, p(50, 60).dy)
      ..cubicTo(p(23, 44).dx, p(23, 44).dy, p(25, 15).dx, p(25, 15).dy,
          p(50, 5).dx, p(50, 5).dy)
      ..close();

    final innerPlume = Path()
      ..moveTo(p(50, 12).dx, p(50, 12).dy)
      ..cubicTo(p(68, 20).dx, p(68, 20).dy, p(69, 42).dx, p(69, 42).dy,
          p(50, 55).dx, p(50, 55).dy)
      ..cubicTo(p(31, 42).dx, p(31, 42).dy, p(32, 20).dx, p(32, 20).dy,
          p(50, 12).dx, p(50, 12).dy)
      ..close();

    // Spine + a couple of barbs.
    final spine = Path()
      ..moveTo(p(50, 58).dx, p(50, 58).dy)
      ..quadraticBezierTo(p(52, 72).dx, p(52, 72).dy, p(50, 84).dx, p(50, 84).dy);
    final barbs = Path()
      ..moveTo(p(50, 64).dx, p(50, 64).dy)
      ..lineTo(p(41, 61).dx, p(41, 61).dy)
      ..moveTo(p(50, 64).dx, p(50, 64).dy)
      ..lineTo(p(59, 61).dx, p(59, 61).dy)
      ..moveTo(p(51, 70).dx, p(51, 70).dy)
      ..lineTo(p(43, 68).dx, p(43, 68).dy)
      ..moveTo(p(51, 70).dx, p(51, 70).dy)
      ..lineTo(p(59, 68).dx, p(59, 68).dy);

    // Graduation cap (mortarboard) at the base — the feather rises out of it.
    final board = Path()
      ..moveTo(p(50, 75).dx, p(50, 75).dy)
      ..lineTo(p(76, 83).dx, p(76, 83).dy)
      ..lineTo(p(50, 91).dx, p(50, 91).dy)
      ..lineTo(p(24, 83).dx, p(24, 83).dy)
      ..close();

    final eyeCenter = p(50, 30);

    // ── Render ────────────────────────────────────────────────────────────
    if (mono) {
      // Silhouette with a punched-out feather eye (so it still reads as a
      // peacock feather even in a single color).
      canvas.saveLayer(Offset.zero & size, Paint());
      canvas.drawPath(plume, fill(monoColor));
      canvas.drawPath(spine, stroke(monoColor, 3));
      canvas.drawPath(barbs, stroke(monoColor, 1.6));
      canvas.drawPath(board, fill(monoColor));
      canvas.drawCircle(eyeCenter, s(8), fill(monoColor)); // widen eye area
      // Punch the eye ring, then drop a solid pupil back in.
      final clear = Paint()..blendMode = BlendMode.clear;
      canvas.drawCircle(eyeCenter, s(7), clear);
      canvas.drawCircle(eyeCenter, s(3), fill(monoColor));
      // tassel
      canvas.drawLine(p(50, 84), p(67, 86), stroke(monoColor, 1.6));
      canvas.drawLine(p(67, 86), p(67, 94), stroke(monoColor, 1.6));
      canvas.drawCircle(p(67, 95), s(2.2), fill(monoColor));
      canvas.restore();
      return;
    }

    // Full Peacock palette.
    canvas.drawPath(plume, fill(AppTheme.peacockTeal));
    canvas.drawPath(innerPlume, fill(AppTheme.peacockEmerald));
    canvas.drawPath(plume, stroke(AppTheme.peacockNavy, 1.4));

    canvas.drawPath(spine, stroke(AppTheme.peacockNavy, 3));
    canvas.drawPath(barbs, stroke(AppTheme.peacockNavy, 1.6));

    // Eye: navy ring → gold iris → navy pupil.
    canvas.drawCircle(eyeCenter, s(10), fill(AppTheme.peacockNavy));
    canvas.drawCircle(eyeCenter, s(6.5), fill(AppTheme.peacockGold));
    canvas.drawCircle(eyeCenter, s(2.6), fill(AppTheme.peacockNavy));

    // Cap.
    canvas.drawPath(board, fill(AppTheme.peacockNavy));
    canvas.drawCircle(p(50, 83), s(2.4), fill(AppTheme.peacockGold)); // button
    // Gold tassel hanging off the board.
    canvas.drawLine(p(50, 83), p(67, 86), stroke(AppTheme.peacockGold, 1.8));
    canvas.drawLine(p(67, 86), p(67, 94), stroke(AppTheme.peacockGold, 1.8));
    canvas.drawCircle(p(67, 95), s(2.4), fill(AppTheme.peacockGold));
  }

  @override
  bool shouldRepaint(covariant _PeacockLogoPainter old) =>
      old.mono != mono || old.monoColor != monoColor;
}

/// Convenience lockup: the mark + wordmark, for the login / splash header.
class PeacockLogoLockup extends StatelessWidget {
  final double markSize;
  final String title;
  final bool mono;
  const PeacockLogoLockup({
    super.key,
    this.markSize = 72,
    this.title = 'Htoo Choon',
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PeacockLogo(size: markSize, mono: mono),
        const SizedBox(height: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: mono ? null : cs.primary,
                letterSpacing: -0.2,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          'Learn · Grow · Excel',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 1.5,
              ),
        ),
      ],
    );
  }
}
