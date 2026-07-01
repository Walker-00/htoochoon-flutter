import 'dart:ui';

enum WbTool { pen, eraser, line, rect, circle, arrow, text, select }

class WbElement {
  final String id;
  final String type;
  final String userId;
  final Color color;
  final double strokeWidth;
  final List<Offset> points;
  final Offset? start;
  final Offset? end;
  final String? text;
  final double fontSize;

  WbElement({
    required this.id,
    required this.type,
    required this.userId,
    this.color = const Color(0xFF000000),
    this.strokeWidth = 3.0,
    this.points = const [],
    this.start,
    this.end,
    this.text,
    this.fontSize = 18.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'userId': userId,
        'color': '#${color.value.toRadixString(16).padLeft(8, '0')}',
        'strokeWidth': strokeWidth,
        'points': points.map((p) => [p.dx, p.dy]).toList(),
        'startX': start?.dx,
        'startY': start?.dy,
        'endX': end?.dx,
        'endY': end?.dy,
        'text': text,
        'fontSize': fontSize,
      };

  factory WbElement.fromJson(Map<String, dynamic> j) {
    final colorStr = j['color'] as String? ?? '#FF000000';
    final colorVal =
        int.parse(colorStr.replaceFirst('#', ''), radix: 16);
    final pts = (j['points'] as List?)
            ?.map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
            .toList() ??
        [];
    return WbElement(
      id: j['id'] as String,
      type: j['type'] as String,
      userId: j['userId'] as String? ?? '',
      color: Color(colorVal),
      strokeWidth: (j['strokeWidth'] as num?)?.toDouble() ?? 3.0,
      points: pts,
      start: j['startX'] != null
          ? Offset((j['startX'] as num).toDouble(),
              (j['startY'] as num).toDouble())
          : null,
      end: j['endX'] != null
          ? Offset(
              (j['endX'] as num).toDouble(), (j['endY'] as num).toDouble())
          : null,
      text: j['text'] as String?,
      fontSize: (j['fontSize'] as num?)?.toDouble() ?? 18.0,
    );
  }

  WbElement copyWith({
    List<Offset>? points,
    Offset? start,
    Offset? end,
    String? text,
  }) =>
      WbElement(
        id: id,
        type: type,
        userId: userId,
        color: color,
        strokeWidth: strokeWidth,
        points: points ?? this.points,
        start: start ?? this.start,
        end: end ?? this.end,
        text: text ?? this.text,
        fontSize: fontSize,
      );
}

class WbPermissions {
  final bool canDraw;
  final bool canErase;
  final bool canClear;

  const WbPermissions({
    this.canDraw = false,
    this.canErase = false,
    this.canClear = false,
  });

  static const teacher = WbPermissions(
    canDraw: true,
    canErase: true,
    canClear: true,
  );

  static const studentEnabled = WbPermissions(
    canDraw: true,
    canErase: true,
    canClear: false,
  );

  static const studentDisabled = WbPermissions(
    canDraw: false,
    canErase: false,
    canClear: false,
  );
}
