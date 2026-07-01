// student_class_enrollment.dart
import 'package:json_annotation/json_annotation.dart';
import 'class_model.dart';

part 'student_enrollment_model.g.dart';

@JsonSerializable(explicitToJson: true)
class StudentClassEnrollment {
  final String id;
  // The Class layer was removed — this is now the courseId.
  final String courseId;
  final String userId;
  final String role;
  final DateTime joinedAt;

  @JsonKey(name: 'course')
  final ClassModel? enrolledClass;

  StudentClassEnrollment({
    required this.id,
    required this.courseId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.enrolledClass,
  });

  factory StudentClassEnrollment.fromJson(Map<String, dynamic> json) =>
      _$StudentClassEnrollmentFromJson(json);

  Map<String, dynamic> toJson() => _$StudentClassEnrollmentToJson(this);
}
