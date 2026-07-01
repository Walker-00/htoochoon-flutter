import 'package:flutter/material.dart';

enum EmptyStateType {
  noCourses,
  noPrograms,
  noAssignments,
  noSessions,
  noStudents,
  noData,
  noResults,
  error,
  welcome,
}

class EmptyStateWidget extends StatelessWidget {
  final EmptyStateType type;
  final String? title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double illustrationSize;

  const EmptyStateWidget({
    super.key,
    required this.type,
    this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.illustrationSize = 160,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final defaults = _defaults;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: illustrationSize,
              height: illustrationSize,
              child: _Illustration(type: type, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title ?? defaults.$1,
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message ?? defaults.$2,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (String, String) get _defaults => switch (type) {
        EmptyStateType.noCourses => (
            'No courses yet',
            'Courses will appear here once they are created or assigned to you.'
          ),
        EmptyStateType.noPrograms => (
            'No programs available',
            'Learning programs will show up here when they become available.'
          ),
        EmptyStateType.noAssignments => (
            'All caught up!',
            'No assignments right now. Check back later for new tasks.'
          ),
        EmptyStateType.noSessions => (
            'No sessions scheduled',
            'Live sessions will appear here when your instructor schedules them.'
          ),
        EmptyStateType.noStudents => (
            'No students yet',
            'Students will appear here once they join your organization.'
          ),
        EmptyStateType.noData => (
            'No data available',
            'There is nothing to display at the moment.'
          ),
        EmptyStateType.noResults => (
            'No results found',
            'Try adjusting your search or filters.'
          ),
        EmptyStateType.error => (
            'Something went wrong',
            'We could not load this content. Please try again.'
          ),
        EmptyStateType.welcome => (
            'Welcome to Htoo Choon',
            'Start exploring courses and programs to begin your learning journey.'
          ),
      };
}

class _Illustration extends StatelessWidget {
  final EmptyStateType type;
  final Color color;
  const _Illustration({required this.type, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _IllustrationPainter(type: type, color: color),
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  final EmptyStateType type;
  final Color color;
  _IllustrationPainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.38;

    // Background circle
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = color.withValues(alpha: 0.08),
    );

    // Secondary decorative circle
    canvas.drawCircle(
      Offset(cx + r * 0.5, cy - r * 0.4),
      r * 0.25,
      Paint()..color = color.withValues(alpha: 0.05),
    );

    switch (type) {
      case EmptyStateType.noCourses:
        _drawBook(canvas, size, cx, cy, r);
      case EmptyStateType.noPrograms:
        _drawGradCap(canvas, size, cx, cy, r);
      case EmptyStateType.noAssignments:
        _drawChecklist(canvas, size, cx, cy, r);
      case EmptyStateType.noSessions:
        _drawCalendar(canvas, size, cx, cy, r);
      case EmptyStateType.noStudents:
        _drawPeople(canvas, size, cx, cy, r);
      case EmptyStateType.noData:
        _drawChart(canvas, size, cx, cy, r);
      case EmptyStateType.noResults:
        _drawSearch(canvas, size, cx, cy, r);
      case EmptyStateType.error:
        _drawWarning(canvas, size, cx, cy, r);
      case EmptyStateType.welcome:
        _drawRocket(canvas, size, cx, cy, r);
    }
  }

  Paint get _stroke => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint get _fill => Paint()
    ..color = color.withValues(alpha: 0.15)
    ..style = PaintingStyle.fill;

  void _drawBook(Canvas c, Size s, double cx, double cy, double r) {
    final p = _stroke;
    final f = _fill;
    final bw = r * 0.7;
    final bh = r * 0.55;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: bw, height: bh),
      const Radius.circular(4),
    );
    c.drawRRect(rect, f);
    c.drawRRect(rect, p);
    c.drawLine(Offset(cx, cy - bh / 2), Offset(cx, cy + bh / 2), p);
    // Pages
    c.drawLine(Offset(cx - bw * 0.3, cy - bh * 0.2), Offset(cx - bw * 0.05, cy - bh * 0.1), p..strokeWidth = 1.5);
    c.drawLine(Offset(cx - bw * 0.3, cy + bh * 0.05), Offset(cx - bw * 0.05, cy + bh * 0.1), p);
    c.drawLine(Offset(cx + bw * 0.05, cy - bh * 0.1), Offset(cx + bw * 0.3, cy - bh * 0.2), p);
    c.drawLine(Offset(cx + bw * 0.05, cy + bh * 0.1), Offset(cx + bw * 0.3, cy + bh * 0.05), p);
    p.strokeWidth = 2.5;
  }

  void _drawGradCap(Canvas c, Size s, double cx, double cy, double r) {
    final p = _stroke;
    final f = _fill;
    final w = r * 0.8;
    // Diamond/rhombus cap top
    final capPath = Path()
      ..moveTo(cx, cy - w * 0.3)
      ..lineTo(cx + w * 0.5, cy)
      ..lineTo(cx, cy + w * 0.15)
      ..lineTo(cx - w * 0.5, cy)
      ..close();
    c.drawPath(capPath, f);
    c.drawPath(capPath, p);
    // Tassel
    c.drawLine(Offset(cx + w * 0.5, cy), Offset(cx + w * 0.5, cy + w * 0.45), p);
    c.drawCircle(Offset(cx + w * 0.5, cy + w * 0.48), 3, Paint()..color = color);
  }

  void _drawChecklist(Canvas c, Size s, double cx, double cy, double r) {
    final p = _stroke;
    final f = _fill;
    final bw = r * 0.55;
    final bh = r * 0.7;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: bw, height: bh),
      const Radius.circular(6),
    );
    c.drawRRect(rect, f);
    c.drawRRect(rect, p);
    // Checkmark lines
    for (var i = 0; i < 3; i++) {
      final y = cy - bh * 0.25 + i * bh * 0.22;
      c.drawLine(Offset(cx - bw * 0.25, y), Offset(cx + bw * 0.3, y), p..strokeWidth = 1.5);
      // Checkbox
      final cbx = cx - bw * 0.35;
      c.drawRect(Rect.fromCenter(center: Offset(cbx, y), width: 8, height: 8), p);
      if (i == 0) {
        final check = Path()
          ..moveTo(cbx - 2, y)
          ..lineTo(cbx, y + 2.5)
          ..lineTo(cbx + 3, y - 2.5);
        c.drawPath(check, p..strokeWidth = 2);
      }
    }
    p.strokeWidth = 2.5;
  }

  void _drawCalendar(Canvas c, Size s, double cx, double cy, double r) {
    final p = _stroke;
    final f = _fill;
    final bw = r * 0.6;
    final bh = r * 0.6;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + r * 0.05), width: bw, height: bh),
      const Radius.circular(6),
    );
    c.drawRRect(rect, f);
    c.drawRRect(rect, p);
    // Header line
    c.drawLine(
      Offset(cx - bw / 2, cy - bh * 0.2),
      Offset(cx + bw / 2, cy - bh * 0.2),
      p,
    );
    // Calendar hooks
    for (final dx in [-0.2, 0.2]) {
      final x = cx + bw * dx;
      c.drawLine(Offset(x, cy - bh * 0.35 - 4), Offset(x, cy - bh * 0.35 + 8), p);
    }
    // Dots for days
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 3; col++) {
        c.drawCircle(
          Offset(cx - bw * 0.2 + col * bw * 0.2, cy + bh * 0.05 + row * bh * 0.2),
          3,
          Paint()..color = color.withValues(alpha: row == 0 && col == 0 ? 1.0 : 0.3),
        );
      }
    }
  }

  void _drawPeople(Canvas c, Size s, double cx, double cy, double r) {
    final p = _stroke;
    // Person 1 (center)
    c.drawCircle(Offset(cx, cy - r * 0.2), r * 0.15, p);
    c.drawArc(
      Rect.fromCenter(center: Offset(cx, cy + r * 0.15), width: r * 0.5, height: r * 0.35),
      3.14, 3.14, false, p,
    );
    // Person 2 (left, smaller)
    c.drawCircle(Offset(cx - r * 0.45, cy - r * 0.12), r * 0.11, p..strokeWidth = 2);
    c.drawArc(
      Rect.fromCenter(center: Offset(cx - r * 0.45, cy + r * 0.18), width: r * 0.38, height: r * 0.28),
      3.14, 3.14, false, p,
    );
    // Person 3 (right, smaller)
    c.drawCircle(Offset(cx + r * 0.45, cy - r * 0.12), r * 0.11, p);
    c.drawArc(
      Rect.fromCenter(center: Offset(cx + r * 0.45, cy + r * 0.18), width: r * 0.38, height: r * 0.28),
      3.14, 3.14, false, p,
    );
    p.strokeWidth = 2.5;
  }

  void _drawChart(Canvas c, Size s, double cx, double cy, double r) {
    final p = _stroke;
    final f = _fill;
    // Axes
    c.drawLine(Offset(cx - r * 0.4, cy - r * 0.35), Offset(cx - r * 0.4, cy + r * 0.35), p);
    c.drawLine(Offset(cx - r * 0.4, cy + r * 0.35), Offset(cx + r * 0.45, cy + r * 0.35), p);
    // Bars
    final bars = [0.5, 0.8, 0.35, 0.65];
    final barW = r * 0.14;
    for (var i = 0; i < bars.length; i++) {
      final x = cx - r * 0.25 + i * r * 0.22;
      final h = bars[i] * r * 0.55;
      final rect = Rect.fromLTWH(x - barW / 2, cy + r * 0.35 - h, barW, h);
      c.drawRect(rect, f);
      c.drawRect(rect, p..strokeWidth = 1.5);
    }
    p.strokeWidth = 2.5;
  }

  void _drawSearch(Canvas c, Size s, double cx, double cy, double r) {
    final p = _stroke;
    c.drawCircle(Offset(cx - r * 0.08, cy - r * 0.08), r * 0.28, p);
    c.drawLine(
      Offset(cx + r * 0.1, cy + r * 0.1),
      Offset(cx + r * 0.35, cy + r * 0.35),
      p..strokeWidth = 3.5,
    );
    p.strokeWidth = 2.5;
  }

  void _drawWarning(Canvas c, Size s, double cx, double cy, double r) {
    final p = _stroke;
    final f = _fill;
    final path = Path()
      ..moveTo(cx, cy - r * 0.35)
      ..lineTo(cx + r * 0.4, cy + r * 0.3)
      ..lineTo(cx - r * 0.4, cy + r * 0.3)
      ..close();
    c.drawPath(path, f);
    c.drawPath(path, p);
    c.drawLine(Offset(cx, cy - r * 0.12), Offset(cx, cy + r * 0.08), p..strokeWidth = 3);
    c.drawCircle(Offset(cx, cy + r * 0.18), 2.5, Paint()..color = color);
    p.strokeWidth = 2.5;
  }

  void _drawRocket(Canvas c, Size s, double cx, double cy, double r) {
    final p = _stroke;
    final f = _fill;
    // Body
    final bodyPath = Path()
      ..moveTo(cx, cy - r * 0.45)
      ..quadraticBezierTo(cx + r * 0.2, cy - r * 0.1, cx + r * 0.15, cy + r * 0.25)
      ..lineTo(cx - r * 0.15, cy + r * 0.25)
      ..quadraticBezierTo(cx - r * 0.2, cy - r * 0.1, cx, cy - r * 0.45)
      ..close();
    c.drawPath(bodyPath, f);
    c.drawPath(bodyPath, p);
    // Window
    c.drawCircle(Offset(cx, cy - r * 0.08), r * 0.08, p);
    // Fins
    c.drawLine(Offset(cx - r * 0.15, cy + r * 0.15), Offset(cx - r * 0.28, cy + r * 0.32), p);
    c.drawLine(Offset(cx + r * 0.15, cy + r * 0.15), Offset(cx + r * 0.28, cy + r * 0.32), p);
    // Flame
    final flamePath = Path()
      ..moveTo(cx - r * 0.08, cy + r * 0.25)
      ..quadraticBezierTo(cx, cy + r * 0.45, cx + r * 0.08, cy + r * 0.25);
    c.drawPath(flamePath, Paint()..color = Colors.orange.withValues(alpha: 0.6)..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _IllustrationPainter old) =>
      old.type != type || old.color != color;
}
