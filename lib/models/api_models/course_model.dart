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

  // final String? campaignId;
  // final String? schoolId;

  CourseRequest({
    required this.name,
    this.description,

    required this.type,
    required this.organizationId,
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
  CourseResponseForProgram({required this.id, required this.name, this.type});
  factory CourseResponseForProgram.fromJson(Map<String, dynamic> json) =>
      _$CourseResponseForProgramFromJson(json);

  Map<String, dynamic> toJson() => _$CourseResponseForProgramToJson(this);
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
