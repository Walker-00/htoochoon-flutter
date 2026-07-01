/// Codegen-free notification model (parses REST rows + WS push payloads).
class AppNotification {
  final String id;
  final String type; // SESSION_LIVE | SESSION_SCHEDULED | GENERIC
  final String title;
  final String body;
  final Map<String, dynamic> data;
  bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: (j['id'] as String?) ??
            't-${DateTime.now().microsecondsSinceEpoch}', // WS push has no id
        type: (j['type'] as String?) ?? 'GENERIC',
        title: (j['title'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
        data: (j['data'] is Map) ? Map<String, dynamic>.from(j['data']) : {},
        isRead: (j['isRead'] as bool?) ?? false,
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'body': body,
        'data': data,
        'isRead': isRead,
        'createdAt': createdAt.toIso8601String(),
      };
}
