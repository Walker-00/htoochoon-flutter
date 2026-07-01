class MeetingModel {
  final String id;
  final String code; // Short code for joining (e.g., "ABC123")
  final String title;
  final String teacherId;
  final String classId;
  final DateTime scheduledAt;
  final Duration duration;
  final bool isActive;
  final List<String> participantIds;

  MeetingModel({
    required this.id,
    required this.code,
    required this.title,
    required this.teacherId,
    required this.classId,
    required this.scheduledAt,
    required this.duration,
    this.isActive = false,
    this.participantIds = const [],
  });

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    return MeetingModel(
      id: json['id'] as String,
      code: json['code'] as String,
      title: json['title'] as String,
      teacherId: json['teacherId'] as String,
      classId: json['classId'] as String,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      duration: Duration(minutes: json['durationMinutes'] as int),
      isActive: json['isActive'] as bool? ?? false,
      participantIds: List<String>.from(json['participantIds'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'title': title,
      'teacherId': teacherId,
      'classId': classId,
      'scheduledAt': scheduledAt.toIso8601String(),
      'durationMinutes': duration.inMinutes,
      'isActive': isActive,
      'participantIds': participantIds,
    };
  }

  // 🎀 Helper: Generate random 6-char meeting code
  static String generateMeetingCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(6, (_) => chars[DateTime.now().millisecond % chars.length]).join();
  }

  @override
  String toString() => 'Meeting($code: $title) ✧';
}