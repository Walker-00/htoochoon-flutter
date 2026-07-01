import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:htoochoon_flutter/models/api_models/program_model.dart';
import 'package:json_annotation/json_annotation.dart';
// enrollment_model.dart
part 'enrollment_model.g.dart';

// REQUESTS
// ─────────────────────────────────────────────────────────────

@JsonSerializable()
class CourseEnrollmentRequest {
  final String userId;
  final String courseId;
  final String classId;
  final String status;

  CourseEnrollmentRequest({
    required this.userId,
    required this.courseId,
    required this.classId,
    required this.status,
  });

  factory CourseEnrollmentRequest.fromJson(Map<String, dynamic> json) =>
      _$CourseEnrollmentRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CourseEnrollmentRequestToJson(this);
}

@JsonSerializable()
class ProgramEnrollmentRequest {
  final String userId;

  final String programId;
  final EnrollmentStatus status;
  ProgramEnrollmentRequest({
    required this.userId,
    required this.programId,

    required this.status,
  });

  factory ProgramEnrollmentRequest.fromJson(Map<String, dynamic> json) =>
      _$ProgramEnrollmentRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ProgramEnrollmentRequestToJson(this);
}

@JsonSerializable()
class UpdateEnrollmentStatusRequest {
  final EnrollmentStatus status;

  UpdateEnrollmentStatusRequest({required this.status});

  factory UpdateEnrollmentStatusRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateEnrollmentStatusRequestFromJson(json);
  Map<String, dynamic> toJson() => _$UpdateEnrollmentStatusRequestToJson(this);
}

// ─────────────────────────────────────────────────────────────
// RESPONSES
// ─────────────────────────────────────────────────────────────

/// Paginated wrapper — used by GET /enrollment/courses
@JsonSerializable()
class EnrollmentResponse {
  final List<Enrollment> data;
  final Meta meta;

  EnrollmentResponse({required this.data, required this.meta});

  factory EnrollmentResponse.fromJson(Map<String, dynamic> json) =>
      _$EnrollmentResponseFromJson(json);
  Map<String, dynamic> toJson() => _$EnrollmentResponseToJson(this);
}

@JsonSerializable()
class Meta {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  Meta({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory Meta.fromJson(Map<String, dynamic> json) => _$MetaFromJson(json);
  Map<String, dynamic> toJson() => _$MetaToJson(this);
}

/// Unified enrollment — handles both course and program enrollments.
///
/// Course enrollment shape:
///   { id, userId, courseId, classId, status, enrolledAt, completedAt,
///     course: { id, name }, class: { id, name, ... }, user: { id, name, email } }
///
/// Program enrollment shape:
///   { id, userId, programId, status, enrolledAt, completedAt,
///     program: { id, name, ..., programCourses: [...] },
///     user: { id, name, email } }
@JsonSerializable(explicitToJson: true)
class Enrollment {
  final String id; //
  final EnrollmentStatus status; //
  final DateTime enrolledAt; //
  final String? userId; //

  final DateTime? completedAt; //
  final UserResEnrollment? user;

  // Course enrollment fields
  final String? courseId; //
  final String? classId; //
  final EnrollmentCourse? course;
  @JsonKey(name: 'class')
  final EnrollmentClass? enrollmentClass;

  // Program enrollment fields
  final String? programId;
  final EnrollmentProgram? program;
  @JsonKey(includeIfNull: false)
  final String? organizationName;
  Enrollment({
    required this.id,
    this.userId,
    required this.status,
    required this.enrolledAt,
    this.completedAt,
    this.user,
    this.courseId,
    this.classId,
    this.course,
    this.enrollmentClass,
    this.programId,
    this.program,
    this.organizationName,
  });

  factory Enrollment.fromJson(Map<String, dynamic> json) =>
      _$EnrollmentFromJson(json);
  Map<String, dynamic> toJson() => _$EnrollmentToJson(this);
}

// ─────────────────────────────────────────────────────────────
// Nested: course inside a course-enrollment
// { "id": "...", "name": "Python Fundamentals",
//   "description": "...", "organizationId": "...", "type": "SKILL",
//   "campaignId": null, "createdAt": "...", "updatedAt": "...",
//   "organization": { "name": "..." } }
// ─────────────────────────────────────────────────────────────
@JsonSerializable(explicitToJson: true)
class EnrollmentCourse {
  final String id;
  final String name;
  final String? description;
  final String? organizationId;
  final String? type;
  final String? campaignId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final EnrollmentOrganization? organization;

  EnrollmentCourse({
    required this.id,
    required this.name,
    this.description,
    this.organizationId,
    this.type,
    this.campaignId,
    this.createdAt,
    this.updatedAt,
    this.organization,
  });

  factory EnrollmentCourse.fromJson(Map<String, dynamic> json) =>
      _$EnrollmentCourseFromJson(json);
  Map<String, dynamic> toJson() => _$EnrollmentCourseToJson(this);
}

// ─────────────────────────────────────────────────────────────
// Nested: class inside a course-enrollment  (key: "class")
// { "id", "name", "courseId", "startDate", "endDate",
//   "maxStudents", "teacherId", "createdAt", "updatedAt" }
// ─────────────────────────────────────────────────────────────
@JsonSerializable()
class EnrollmentClass {
  final String id;
  final String name;
  final String? courseId;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? maxStudents;
  final String? teacherId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EnrollmentClass({
    required this.id,
    required this.name,
    this.courseId,
    this.startDate,
    this.endDate,
    this.maxStudents,
    this.teacherId,
    this.createdAt,
    this.updatedAt,
  });

  factory EnrollmentClass.fromJson(Map<String, dynamic> json) =>
      _$EnrollmentClassFromJson(json);
  Map<String, dynamic> toJson() => _$EnrollmentClassToJson(this);
}

// ─────────────────────────────────────────────────────────────
// Nested: organization inside EnrollmentCourse
// { "name": "Arc Academy" }
// ─────────────────────────────────────────────────────────────
@JsonSerializable()
class EnrollmentOrganization {
  final String name;

  EnrollmentOrganization({required this.name});

  factory EnrollmentOrganization.fromJson(Map<String, dynamic> json) =>
      _$EnrollmentOrganizationFromJson(json);
  Map<String, dynamic> toJson() => _$EnrollmentOrganizationToJson(this);
}

// ─────────────────────────────────────────────────────────────
// Nested: program inside a program-enrollment
// ─────────────────────────────────────────────────────────────

@JsonSerializable(explicitToJson: true)
class EnrollmentProgram {
  final String id;
  final String name;
  final String? description;
  final String? organizationId;
  final String? organizationName;
  final ProgramType? type;
  // Cohort schedule — drives the program progress bar on Home / detail.
  // Nullable for backward-compat with payloads that predate the dates feature.
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final List<EnrollmentProgramCourse> programCourses;

  EnrollmentProgram({
    required this.id,
    required this.name,
    this.description,
    this.organizationId,
    this.organizationName,
    required this.type,
    this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
    this.programCourses = const [],
  });

  factory EnrollmentProgram.fromJson(Map<String, dynamic> json) =>
      _$EnrollmentProgramFromJson(json);
  Map<String, dynamic> toJson() => _$EnrollmentProgramToJson(this);
}

// ─────────────────────────────────────────────────────────────
// Nested: programCourse entry inside EnrollmentProgram
// ─────────────────────────────────────────────────────────────
@JsonSerializable(explicitToJson: true)
class EnrollmentProgramCourse {
  final String id;
  final String? programId;
  final String? courseId;
  final int order;
  final bool isRequired;
  final DateTime createdAt;
  final DateTime updatedAt;
  final EnrollmentCourse course;

  EnrollmentProgramCourse({
    required this.id,
    this.programId,
    this.courseId,
    required this.order,
    required this.isRequired,
    required this.createdAt,
    required this.updatedAt,
    required this.course,
  });

  factory EnrollmentProgramCourse.fromJson(Map<String, dynamic> json) =>
      _$EnrollmentProgramCourseFromJson(json);
  Map<String, dynamic> toJson() => _$EnrollmentProgramCourseToJson(this);
}

// ─────────────────────────────────────────────────────────────
// Nested: user inside any enrollment
// ─────────────────────────────────────────────────────────────
@JsonSerializable()
class UserResEnrollment {
  final String? id;
  final String? name;
  final String? email;
  final String? avatar;

  UserResEnrollment({this.id, this.name, this.email, this.avatar});

  factory UserResEnrollment.fromJson(Map<String, dynamic> json) =>
      _$UserResEnrollmentFromJson(json);
  Map<String, dynamic> toJson() => _$UserResEnrollmentToJson(this);
}
