enum LiveSessionStatus { SCHEDULED, LIVE, ENDED }

class LiveSessionModel {
  final String id;
  final String topic;
  final String roomId;
  final String hostId;
  final String? classId;
  final LiveSessionStatus status;
  final DateTime startTime;
  final DateTime? endTime;

  LiveSessionModel({
    required this.id,
    required this.topic,
    required this.roomId,
    required this.hostId,
    this.classId,
    required this.status,
    required this.startTime,
    this.endTime,
  });

  bool get isLive => status == LiveSessionStatus.LIVE;

  factory LiveSessionModel.fromJson(Map<String, dynamic> json) {
    return LiveSessionModel(
      id: json['id'],
      topic: json['topic'],
      roomId: json['roomId'],
      hostId: json['hostId'],
      classId: json['classId'],
      status: LiveSessionStatus.values.firstWhere(
            (e) => e.name == json['status'],
        orElse: () => LiveSessionStatus.SCHEDULED,
      ),
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
    );
  }
}