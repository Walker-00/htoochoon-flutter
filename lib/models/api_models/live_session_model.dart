import 'package:htoochoon_flutter/models/api_models/class_model.dart';
import 'package:htoochoon_flutter/models/api_models/enrollment_model.dart';
import 'package:json_annotation/json_annotation.dart';
import 'enums.dart';

part 'live_session_model.g.dart';

//
// REQUEST
//
@JsonSerializable()
class JoinLiveSessionResponse {
  final String? id;
  final String? studentId;
  final String? courseId;
  final String? liveSessionId;
  final String? joinedAt;
  final String? leftAt;
  final String? status;
  final String meetingCode;
  final String accessToken;
  final String refreshToken;
  JoinLiveSessionResponse({
    this.id,
    this.studentId,
    this.courseId,
    this.liveSessionId,
    this.joinedAt,
    this.leftAt,
    this.status,
    required this.meetingCode,
    required this.accessToken,
    required this.refreshToken,
  });

  factory JoinLiveSessionResponse.fromJson(Map<String, dynamic> json) =>
      _$JoinLiveSessionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$JoinLiveSessionResponseToJson(this);
}

@JsonSerializable()
class LiveSessionRequest {
  final String topic;
  final String courseId;
  final String hostId;
  final String startTime;
  final String endTime;
  final LiveSessionStatus status;

  LiveSessionRequest({
    required this.topic,
    required this.courseId,
    required this.hostId,
    required this.startTime,
    required this.endTime,
    this.status = LiveSessionStatus.scheduled,
  });

  factory LiveSessionRequest.fromJson(Map<String, dynamic> json) =>
      _$LiveSessionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$LiveSessionRequestToJson(this);
}

//
// RESPONSE
//
@JsonSerializable()
class LiveSessionResponse {
  final List<LiveSession> data;
  final Meta meta;

  LiveSessionResponse({required this.data, required this.meta});

  factory LiveSessionResponse.fromJson(Map<String, dynamic> json) =>
      _$LiveSessionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$LiveSessionResponseToJson(this);
}

@JsonSerializable(explicitToJson: true)
class LiveSession {
  final String id;

  final String topic;

  final String? roomId;

  final String hostId;

  @JsonKey(includeIfNull: false)
  final LiveSessionHost? host;

  final String courseId;

  @JsonKey(includeIfNull: false)
  @JsonKey(name: 'course')
  final ClassModel? liveClass;

  final LiveSessionStatus status;

  final DateTime startTime;
  final DateTime endTime;

  final DateTime createdAt;
  final DateTime updatedAt;

  LiveSession({
    required this.id,
    required this.topic,
    this.roomId,
    required this.hostId,
    this.host,
    required this.courseId,
    this.liveClass,
    required this.status,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LiveSession.fromJson(Map<String, dynamic> json) =>
      _$LiveSessionFromJson(json);

  Map<String, dynamic> toJson() => _$LiveSessionToJson(this);
}

//
// HOST SUMMARY
//

@JsonSerializable()
class LiveSessionHost {
  final String? id;
  final String name;
  final String? avatar;
  final String email;

  LiveSessionHost({
    this.id,
    required this.name,
    this.avatar,
    required this.email,
  });

  factory LiveSessionHost.fromJson(Map<String, dynamic> json) =>
      _$LiveSessionHostFromJson(json);

  Map<String, dynamic> toJson() => _$LiveSessionHostToJson(this);
}

//
// CLASS SUMMARY
//

@JsonSerializable()
class LiveSessionClass {
  final String id;
  final String name;

  LiveSessionClass({required this.id, required this.name});

  factory LiveSessionClass.fromJson(Map<String, dynamic> json) =>
      _$LiveSessionClassFromJson(json);

  Map<String, dynamic> toJson() => _$LiveSessionClassToJson(this);
}

//
// LIST RESPONSE
//

@JsonSerializable(explicitToJson: true)
class LiveSessionListResponse {
  final List<LiveSession> data;

  LiveSessionListResponse({required this.data});

  factory LiveSessionListResponse.fromJson(Map<String, dynamic> json) =>
      _$LiveSessionListResponseFromJson(json);

  Map<String, dynamic> toJson() => _$LiveSessionListResponseToJson(this);
}
