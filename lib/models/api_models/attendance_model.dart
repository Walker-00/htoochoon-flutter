import 'package:json_annotation/json_annotation.dart';

part 'attendance_model.g.dart';

@JsonEnum()
enum AttendanceStatus {
  @JsonValue('PRESENT')
  present,

  @JsonValue('ABSENT')
  absent,

  @JsonValue('LATE')
  late,
}

@JsonSerializable()
class AttendanceRequest {
  final String studentId;
  final String classId;
  final String liveSessionId;
  final AttendanceStatus status;
  final DateTime joinedAt;
  final DateTime leftAt;

  AttendanceRequest({
    required this.studentId,
    required this.classId,
    required this.liveSessionId,
    required this.status,
    required this.joinedAt,
    required this.leftAt,
  });

  factory AttendanceRequest.fromJson(Map<String, dynamic> json) =>
      _$AttendanceRequestFromJson(json);

  Map<String, dynamic> toJson() => _$AttendanceRequestToJson(this);
}

@JsonSerializable()
class AttendanceStudent {
  final String id;
  final String name;

  AttendanceStudent({required this.id, required this.name});

  factory AttendanceStudent.fromJson(Map<String, dynamic> json) =>
      _$AttendanceStudentFromJson(json);

  Map<String, dynamic> toJson() => _$AttendanceStudentToJson(this);
}

@JsonSerializable()
class AttendanceClass {
  final String id;
  final String name;

  AttendanceClass({required this.id, required this.name});

  factory AttendanceClass.fromJson(Map<String, dynamic> json) =>
      _$AttendanceClassFromJson(json);

  Map<String, dynamic> toJson() => _$AttendanceClassToJson(this);
}

@JsonSerializable()
class AttendanceLiveSession {
  final String id;
  final String topic;

  AttendanceLiveSession({required this.id, required this.topic});

  factory AttendanceLiveSession.fromJson(Map<String, dynamic> json) =>
      _$AttendanceLiveSessionFromJson(json);

  Map<String, dynamic> toJson() => _$AttendanceLiveSessionToJson(this);
}

@JsonSerializable()
class Attendance {
  final String id;

  final String studentId;
  final AttendanceStudent student;

  final String classId;

  @JsonKey(name: 'class')
  final AttendanceClass attendanceClass;

  final String liveSessionId;
  final AttendanceLiveSession liveSession;

  final DateTime joinedAt;
  final DateTime leftAt;

  final String markedBy;
  final AttendanceStatus status;

  Attendance({
    required this.id,
    required this.studentId,
    required this.student,
    required this.classId,
    required this.attendanceClass,
    required this.liveSessionId,
    required this.liveSession,
    required this.joinedAt,
    required this.leftAt,
    required this.markedBy,
    required this.status,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) =>
      _$AttendanceFromJson(json);

  Map<String, dynamic> toJson() => _$AttendanceToJson(this);
}
