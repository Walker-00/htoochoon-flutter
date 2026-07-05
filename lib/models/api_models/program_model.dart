import 'package:htoochoon_flutter/models/api_models/course_model.dart';
import 'package:htoochoon_flutter/models/api_models/enrollment_model.dart';
import 'package:htoochoon_flutter/models/api_models/organization_model.dart';
import 'package:json_annotation/json_annotation.dart';
import 'enums.dart';

part 'program_model.g.dart';

/// REQUEST
@JsonSerializable()
class ProgramRequest {
  final String name;
  final String? description;
  final String organizationId;
  final ProgramType type;
  // Cohort schedule — REQUIRED (serialized as ISO strings for the backend).
  final DateTime startDate;
  final DateTime endDate;

  // 💳 Pricing (fake payment flow). Defaults to a free program.
  @JsonKey(defaultValue: ProgramPricingType.FREE)
  final ProgramPricingType pricingType;
  @JsonKey(defaultValue: 0)
  final int price;
  @JsonKey(defaultValue: 'MMK')
  final String currency;

  ProgramRequest({
    required this.name,
    this.description,
    required this.organizationId,
    required this.type,
    required this.startDate,
    required this.endDate,
    this.pricingType = ProgramPricingType.FREE,
    this.price = 0,
    this.currency = 'MMK',
  });

  factory ProgramRequest.fromJson(Map<String, dynamic> json) =>
      _$ProgramRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ProgramRequestToJson(this);
}

/// RESPONSE
@JsonSerializable(explicitToJson: true)
class ProgramResponse {
  final String id;
  final String name;
  final String? description;
  final String? organizationId;
  final ProgramType type;
  // Cohort schedule — REQUIRED on the backend (existing rows backfilled).
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // 💳 Pricing (fake payment flow).
  @JsonKey(defaultValue: ProgramPricingType.FREE)
  final ProgramPricingType pricingType;
  @JsonKey(defaultValue: 0)
  final int price;
  @JsonKey(defaultValue: 'MMK')
  final String currency;

  // ✅ NEW FIELDS
  final OrgResForProgramResponse? organization;
  @JsonKey(defaultValue: [])
  final List<ProgramCourseResponse> programCourses;
  @JsonKey(defaultValue: [])
  final List<Enrollment> enrollment;

  @JsonKey(name: '_count')
  final ProgramCount? count;

  ProgramResponse({
    required this.id,
    required this.name,
    this.description,
    required this.organizationId,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    this.updatedAt,
    required this.enrollment,
    this.pricingType = ProgramPricingType.FREE,
    this.price = 0,
    this.currency = 'MMK',
    this.organization,
    this.programCourses = const [],
    this.count,
  });

  /// True if this program costs money (not FREE).
  bool get isPaid => pricingType != ProgramPricingType.FREE && price > 0;

  /// Human price label, e.g. "50,000 MMK", "10,000 MMK / month", "Free".
  String get priceLabel {
    if (!isPaid) return 'Free';
    final n = price.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return pricingType == ProgramPricingType.MONTHLY
        ? '$n $currency / month'
        : '$n $currency';
  }

  factory ProgramResponse.fromJson(Map<String, dynamic> json) =>
      _$ProgramResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ProgramResponseToJson(this);
}

@JsonSerializable()
class ProgramCount {
  @JsonKey(defaultValue: 0)
  final int enrollments;
  @JsonKey(defaultValue: 0)
  final int programCourses;

  ProgramCount({required this.enrollments, this.programCourses = 0});

  factory ProgramCount.fromJson(Map<String, dynamic> json) =>
      _$ProgramCountFromJson(json);

  Map<String, dynamic> toJson() => _$ProgramCountToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ProgramCourseResponse {
  final String id;
  final String? programId;
  final String? courseId;
  final int order;
  final bool isRequired;

  final DateTime createdAt;
  final DateTime updatedAt;

  final CourseResponseForProgram course;

  ProgramCourseResponse({
    required this.id,
    required this.programId,
    required this.courseId,
    required this.order,
    required this.isRequired,
    required this.createdAt,
    required this.updatedAt,
    required this.course,
  });

  factory ProgramCourseResponse.fromJson(Map<String, dynamic> json) =>
      _$ProgramCourseResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ProgramCourseResponseToJson(this);
}

/// ProgramCourses
@JsonSerializable()
class ProgramCourseRequest {
  final String courseId;
  int? order;
  final bool isRequired;
  // Teacher assigned to this course inside this program (the clone gets it).
  final String? teacherId;
  ProgramCourseRequest({
    required this.courseId,
    this.order,
    this.isRequired = false,
    this.teacherId,
  });

  factory ProgramCourseRequest.fromJson(Map<String, dynamic> json) =>
      _$ProgramCourseRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ProgramCourseRequestToJson(this);
}
