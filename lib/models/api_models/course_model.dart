import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'package:htoochoon_flutter/models/api_models/class_model.dart';
import 'package:htoochoon_flutter/models/api_models/enrollment_model.dart';
import 'package:htoochoon_flutter/models/api_models/program_model.dart';
import 'package:htoochoon_flutter/models/auth/auth_model.dart';
import 'package:json_annotation/json_annotation.dart';
import 'enums.dart';

part 'course_model.g.dart';

/// REQUEST
@JsonSerializable()
class CourseRequest {
  final String name;
  final String? description;
  final CourseType type;
  final String organizationId;

  /// Subject / category the course belongs to (English, Math, GED, IELTS…).
  final String? category;

  /// Free-form topics covered, shown as chips.
  @JsonKey(defaultValue: [])
  final List<String> topics;

  // final String? campaignId;
  // final String? schoolId;

  CourseRequest({
    required this.name,
    this.description,

    required this.type,
    required this.organizationId,
    this.category,
    this.topics = const [],
    // this.campaignId,
    // this.schoolId,
  });

  factory CourseRequest.fromJson(Map<String, dynamic> json) =>
      _$CourseRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CourseRequestToJson(this);
}

@JsonSerializable()
class CourseResponseForProgram {
  final String id;
  final String name;
  final CourseType? type;
  final String? description;

  /// Subject / catalog metadata surfaced on the program detail page.
  final String? category;
  @JsonKey(defaultValue: [])
  final List<String> topics;

  /// Teacher assigned to this (program) course, if any.
  final TeacherBrief? teacher;

  @JsonKey(name: '_count')
  final CourseForProgramCount? count;

  CourseResponseForProgram({
    required this.id,
    required this.name,
    this.type,
    this.description,
    this.category,
    this.topics = const [],
    this.teacher,
    this.count,
  });
  factory CourseResponseForProgram.fromJson(Map<String, dynamic> json) =>
      _$CourseResponseForProgramFromJson(json);

  Map<String, dynamic> toJson() => _$CourseResponseForProgramToJson(this);
}

/// Minimal teacher info for program/course cards.
@JsonSerializable()
class TeacherBrief {
  final String id;
  final String? name;
  final String? email;
  final String? avatar;
  TeacherBrief({required this.id, this.name, this.email, this.avatar});
  factory TeacherBrief.fromJson(Map<String, dynamic> json) =>
      _$TeacherBriefFromJson(json);
  Map<String, dynamic> toJson() => _$TeacherBriefToJson(this);

  /// Full avatar URL (backend serves relative paths).
  String? get absoluteAvatarUrl {
    if (avatar == null || avatar!.isEmpty) return null;
    if (avatar!.startsWith('http')) return avatar;
    return 'https://backend.htoochoon.com$avatar';
  }
}

@JsonSerializable()
class CourseForProgramCount {
  @JsonKey(defaultValue: 0)
  final int enrollments;
  @JsonKey(defaultValue: 0)
  final int materials;
  CourseForProgramCount({this.enrollments = 0, this.materials = 0});
  factory CourseForProgramCount.fromJson(Map<String, dynamic> json) =>
      _$CourseForProgramCountFromJson(json);
  Map<String, dynamic> toJson() => _$CourseForProgramCountToJson(this);
}

@JsonSerializable()
class CourseListResponse {
  final List<CourseResponse> data;
  final Meta meta;

  CourseListResponse({required this.data, required this.meta});

  factory CourseListResponse.fromJson(Map<String, dynamic> json) =>
      _$CourseListResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CourseListResponseToJson(this);
}

/// RESPONSE
@JsonSerializable(explicitToJson: true)
class CourseResponse {
  final String id;
  final String name;
  final String? description;
  final String? organizationId;
  final CourseType type;
  final String? category;
  @JsonKey(defaultValue: [])
  final List<String> topics;
  final String? campaignId;
  final String? schoolId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Templating: a template (academic) course is a blueprint — you build classes,
  // materials and unpublished template assessments on it, but it has no students,
  // teachers or live sessions until it's added to a program (which clones it).
  @JsonKey(defaultValue: false)
  final bool isTemplate;

  final Organization? organization;
  @JsonKey(defaultValue: [])
  final List<ClassModel>? classes;
  @JsonKey(defaultValue: [])
  final List<ProgramCourse> programCourses;
  @JsonKey(defaultValue: [])
  final List<Enrollment> enrollments;

  CourseResponse({
    required this.id,
    required this.name,
    this.description,
    this.organizationId,
    required this.type,
    this.category,
    this.topics = const [],
    this.campaignId,
    this.schoolId,
    required this.createdAt,
    required this.updatedAt,
    this.isTemplate = false,
    this.organization,
    this.classes = const [],
    this.programCourses = const [],
    this.enrollments = const [],
  });

  factory CourseResponse.fromJson(Map<String, dynamic> json) {
    // 🚨 DEBUG LOGS: This will find the null field instantly
    logD("--- 🔬 CHECKING BACKEND JSON VALUES ---");
    logD("id: ${json['id']} (${json['id'].runtimeType})");
    logD("name: ${json['name']} (${json['name'].runtimeType})");
    logD(
      "organizationId: ${json['organizationId']} (${json['organizationId'].runtimeType})",
    );
    logD("type: ${json['type']} (${json['type'].runtimeType})");
    logD("createdAt: ${json['createdAt']} (${json['createdAt'].runtimeType})");
    logD("updatedAt: ${json['updatedAt']} (${json['updatedAt'].runtimeType})");
    logD("--------------------------------------");

    return _$CourseResponseFromJson(json);
  }

  Map<String, dynamic> toJson() => _$CourseResponseToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ProgramCourse {
  final String id;
  final String programId;
  final String courseId;
  final int order;
  final bool isRequired;
  final ProgramResponse? program;
  final String? createdAt;
  final String? updatedAt;
  ProgramCourse({
    required this.id,
    required this.programId,
    required this.courseId,
    required this.order,
    required this.isRequired,
    this.program,
    this.createdAt,
    this.updatedAt,
  });

  factory ProgramCourse.fromJson(Map<String, dynamic> json) =>
      _$ProgramCourseFromJson(json);

  Map<String, dynamic> toJson() => _$ProgramCourseToJson(this);
}

// @JsonSerializable()
// class CourseResponse {
//   final String id;
//   final String name;
//   final String? description;
//   final String organizationId;
//   final CourseType type;
//   final String? campaignId;
//   final String? schoolId;
//   final DateTime createdAt;
//   final DateTime updatedAt;
//   final Organization? organization;
//   // final List<ClassResponse>? classes
//
//   CourseResponse({
//     required this.id,
//     required this.name,
//     this.description,
//     required this.organizationId,
//     required this.type,
//     this.campaignId,
//     this.schoolId,
//     required this.createdAt,
//     required this.updatedAt,
//     required this.organization,
//   });
//
//   factory CourseResponse.fromJson(Map<String, dynamic> json) =>
//       _$CourseResponseFromJson(json);
//
//   Map<String, dynamic> toJson() => _$CourseResponseToJson(this);
// }
