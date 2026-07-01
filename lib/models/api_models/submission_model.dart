import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:json_annotation/json_annotation.dart';
// part 'submission_model.g.dart';

// @JsonEnum()
// enum SubmissionStatus {
//   @JsonValue('SUBMITTED')
//   submitted,
//
//   @JsonValue('GRADED')
//   graded,
// }
//
// @JsonSerializable()
// class SubmissionRequest {
//   final String studentId;
//   final String? assignmentId;
//   final String? testId;
//   final String content;
//
//   SubmissionRequest({
//     required this.studentId,
//     this.assignmentId,
//     this.testId,
//     required this.content,
//   });
//
//   factory SubmissionRequest.fromJson(Map<String, dynamic> json) =>
//       _$SubmissionRequestFromJson(json);
//
//   Map<String, dynamic> toJson() => _$SubmissionRequestToJson(this);
// }
//
// @JsonSerializable()
// class Submission {
//   final String id;
//   final String content;
//   final double score;
//   final SubmissionStatus status;
//
//   final String studentId;
//   final SubmissionStudent student;
//
//   final String? assignmentId;
//   final String? testId;
//
//   final DateTime createdAt;
//
//   Submission({
//     required this.id,
//     required this.content,
//     required this.score,
//     required this.status,
//     required this.studentId,
//     required this.student,
//     this.assignmentId,
//     this.testId,
//     required this.createdAt,
//   });
//
//   factory Submission.fromJson(Map<String, dynamic> json) =>
//       _$SubmissionFromJson(json);
//
//   Map<String, dynamic> toJson() => _$SubmissionToJson(this);
// }
//
// @JsonSerializable()
// class SubmissionStudent {
//   final String id;
//   final String name;
//
//   SubmissionStudent({required this.id, required this.name});
//
//   factory SubmissionStudent.fromJson(Map<String, dynamic> json) =>
//       _$SubmissionStudentFromJson(json);
//
//   Map<String, dynamic> toJson() => _$SubmissionStudentToJson(this);
// }
//
// @JsonSerializable()
// class GradeRequest {
//   final double score;
//   SubmissionStatus status;
//
//   GradeRequest({required this.score, required this.status});
//
//   factory GradeRequest.fromJson(Map<String, dynamic> json) =>
//       _$GradeRequestFromJson(json);
//
//   Map<String, dynamic> toJson() => _$GradeRequestToJson(this);
// }
