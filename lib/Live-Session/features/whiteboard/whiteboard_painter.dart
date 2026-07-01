import 'dart:math';
import 'package:flutter/material.dart';
import 'whiteboard_models.dart';

class WhiteboardPainter extends CustomPainter {
  final List<WbElement> elements;
  final WbElement? activeElement;
  final double gridSize;
  final Color gridColor;

  WhiteboardPainter({
    required this.elements,
    this.activeElement,
    this.gridSize = 24.0,
    this.gridColor = const Color(0x1A000000),
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    for (final el in elements) {
      _drawElement(canvas, el);
    }
    if (activeElement != null) {
      _drawElement(canvas, activeElement!);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.2;
    final dotRadius = 1.5;
    for (double x = 0; x < size.width; x += gridSize) {
      for (double y = 0; y < size.height; y += gridSize) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  void _drawElement(Canvas canvas, WbElement el) {
    final paint = Paint()
      ..color = el.color
      ..strokeWidth = el.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    switch (el.type) {
      case 'pen':
        _drawPen(canvas, el, paint);
        break;
      case 'eraser':
        paint.color = Colors.white;
        paint.strokeWidth = el.strokeWidth * 3;
        paint.blendMode = BlendMode.srcOver;
        _drawPen(canvas, el, paint);
        break;
      case 'line':
        _drawLine(canvas, el, paint);
        break;
      case 'rect':
        _drawRect(canvas, el, paint);
        break;
      case 'circle':
        _drawCircle(canvas, el, paint);
        break;
      case 'arrow':
        _drawArrow(canvas, el, paint);
        break;
      case 'text':
        _drawText(canvas, el);
        break;
    }
  }

  void _drawPen(Canvas canvas, WbElement el, Paint paint) {
    if (el.points.length < 2) {
      if (el.points.length == 1) {
        canvas.drawCircle(el.points[0], paint.strokeWidth / 2, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
      }
      return;
    }
    final path = Path()..moveTo(el.points[0].dx, el.points[0].dy);
    for (int i = 1; i < el.points.length; i++) {
      final p0 = el.points[i - 1];
      final p1 = el.points[i];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.lineTo(el.points.last.dx, el.points.last.dy);
    canvas.drawPath(path, paint);
  }

  void _drawLine(Canvas canvas, WbElement el, Paint paint) {
    if (el.start == null || el.end == null) return;
    canvas.drawLine(el.start!, el.end!, paint);
  }

  void _drawRect(Canvas canvas, WbElement el, Paint paint) {
    if (el.start == null || el.end == null) return;
    canvas.drawRect(Rect.fromPoints(el.start!, el.end!), paint);
  }

  void _drawCircle(Canvas canvas, WbElement el, Paint paint) {
    if (el.start == null || el.end == null) return;
    final center = Offset(
      (el.start!.dx + el.end!.dx) / 2,
      (el.start!.dy + el.end!.dy) / 2,
    );
    final rx = (el.end!.dx - el.start!.dx).abs() / 2;
    final ry = (el.end!.dy - el.start!.dy).abs() / 2;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 2, height: ry * 2),
      paint,
    );
  }

  void _drawArrow(Canvas canvas, WbElement el, Paint paint) {
    if (el.start == null || el.end == null) return;
    canvas.drawLine(el.start!, el.end!, paint);

    final dx = el.end!.dx - el.start!.dx;
    final dy = el.end!.dy - el.start!.dy;
    final angle = atan2(dy, dx);
    const headLen = 16.0;
    const headAngle = 0.5;

    final p1 = Offset(
      el.end!.dx - headLen * cos(angle - headAngle),
      el.end!.dy - headLen * sin(angle - headAngle),
    );
    final p2 = Offset(
      el.end!.dx - headLen * cos(angle + headAngle),
      el.end!.dy - headLen * sin(angle + headAngle),
    );
    final arrowHead = Path()
      ..moveTo(el.end!.dx, el.end!.dy)
      ..lineTo(p1.dx, p1.dy)
      ..moveTo(el.end!.dx, el.end!.dy)
      ..lineTo(p2.dx, p2.dy);
    canvas.drawPath(arrowHead, paint);
  }

  void _drawText(Canvas canvas, WbElement el) {
    if (el.text == null || el.start == null) return;
    final tp = TextPainter(
      text: TextSpan(
        text: el.text,
        style: TextStyle(
          color: el.color,
          fontSize: el.fontSize,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, el.start!);
  }

  @override
  bool shouldRepaint(covariant WhiteboardPainter old) => true;
}
