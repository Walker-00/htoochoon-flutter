import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:json_annotation/json_annotation.dart';

part 'assignment_model.g.dart';

// assignment_model.dart
// flutter pub run build_runner build --delete-conflicting-outputs

// ─────────────────────────────────────────────────────────────────────────────
// REQUEST — AssignmentRequest (multipart reference)
// ─────────────────────────────────────────────────────────────────────────────

@JsonSerializable(explicitToJson: true)
class AssignmentRequest {
  final String title;
  final String content;
  final String classId;
  final DateTime dueDate;
  final AssignmentType type;
  final int duration;
  final bool published;

  /// When false, students can't preview the exam content before starting.
  final bool showContentPreview;
  final String questions;
  final List<String>? attachments;

  AssignmentRequest({
    required this.title,
    required this.content,
    required this.classId,
    required this.dueDate,
    required this.type,
    required this.duration,
    required this.published,
    this.showContentPreview = true,
    required this.questions,
    this.attachments,
  });

  factory AssignmentRequest.fromJson(Map<String, dynamic> json) =>
      _$AssignmentRequestFromJson(json);
  Map<String, dynamic> toJson() => _$AssignmentRequestToJson(this);
}

// ─────────────────────────────────────────────────────────────────────────────
// REQUEST — QuestionRequest (inside the questions JSON string)
// ─────────────────────────────────────────────────────────────────────────────

@JsonSerializable(explicitToJson: true)
class QuestionRequest {
  final int order;
  final QuestionType type;
  final String text;
  final int points;
  final bool isRequired;
  final List<int> files;
  final List<OptionRequest> options;

  @JsonKey(includeIfNull: false)
  final String? correctAnswer;

  QuestionRequest({
    required this.order,
    required this.type,
    required this.text,
    required this.points,
    required this.isRequired,
    required this.files,
    required this.options,
    this.correctAnswer,
  });

  factory QuestionRequest.fromJson(Map<String, dynamic> json) =>
      _$QuestionRequestFromJson(json);
  Map<String, dynamic> toJson() => _$QuestionRequestToJson(this);
}

// ─────────────────────────────────────────────────────────────────────────────
// REQUEST — OptionRequest
// ─────────────────────────────────────────────────────────────────────────────

@JsonSerializable()
class OptionRequest {
  final String label;
  final String text;

  @JsonKey(includeIfNull: false)
  final bool? isCorrect;

  OptionRequest({required this.label, required this.text, this.isCorrect});

  factory OptionRequest.fromJson(Map<String, dynamic> json) =>
      _$OptionRequestFromJson(json);
  Map<String, dynamic> toJson() => _$OptionRequestToJson(this);
}

// ─────────────────────────────────────────────────────────────────────────────
// REQUEST — SubmissionRequest
//
// POST /submissions
// {
//   "studentId": "string",
//   "assessmentId": "string",   ← single id for both assignment and test
//   "content": "string",
//   "startedAt": "2026-05-04T16:04:03.908Z",
//   "submittedAt": "2026-05-04T16:04:03.908Z",
//   "answers": [
//     { "questionId": "q1", "type": "MULTIPLE_CHOICE", "selectedOptionId": "b" }
//   ]
// }
// ─────────────────────────────────────────────────────────────────────────────
//TODO to re-add content and submittedat if need
@JsonSerializable(explicitToJson: true)
class SubmissionRequest {
  final String studentId;
  final String assessmentId; // same field for both assignment and test
  // final String? content;
  final String startedAt; // ISO8601 string
  // final String? submittedAt; // ISO8601 string
  final List<AnswerRequest> answers;

  SubmissionRequest({
    required this.studentId,
    required this.assessmentId,
    // this.content,210
    required this.startedAt,
    // this.submittedAt,
    required this.answers,
  });

  factory SubmissionRequest.fromJson(Map<String, dynamic> json) =>
      _$SubmissionRequestFromJson(json);
  Map<String, dynamic> toJson() => _$SubmissionRequestToJson(this);
}

// ─────────────────────────────────────────────────────────────────────────────
// REQUEST — one answer inside SubmissionRequest
// ─────────────────────────────────────────────────────────────────────────────

@JsonSerializable()
class AnswerRequest {
  final String questionId;
  // final String
  // type; // "MULTIPLE_CHOICE" | "TRUE_FALSE" | "SHORT_ANSWER" | "ESSAY"

  @JsonKey(includeIfNull: false)
  final String? selectedOptionId; // for MULTIPLE_CHOICE and TRUE_FALSE

  @JsonKey(includeIfNull: false)
  final String? textAnswer; // for SHORT_ANSWER and ESSAY

  AnswerRequest({
    required this.questionId,
    // required this.type,
    this.selectedOptionId,
    this.textAnswer,
  });

  factory AnswerRequest.fromJson(Map<String, dynamic> json) =>
      _$AnswerRequestFromJson(json);
  Map<String, dynamic> toJson() => _$AnswerRequestToJson(this);
}

// ─────────────────────────────────────────────────────────────────────────────
// REQUEST — GradeRequest
// ─────────────────────────────────────────────────────────────────────────────
@JsonSerializable()
class QuestionGrades {
  final String questionId;
  final int pointEarned;

  final String? feedback;
  QuestionGrades({
    required this.questionId,
    required this.pointEarned,
    required this.feedback,
  });
  factory QuestionGrades.fromJson(Map<String, dynamic> json) =>
      _$QuestionGradesFromJson(json);

  Map<String, dynamic> toJson() => _$QuestionGradesToJson(this);
}

@JsonSerializable()
class GradeRequest {
  final double score;
  @JsonKey(includeIfNull: false)
  final List<QuestionGrades>? questionGrades;

  final SubmissionStatus status;

  GradeRequest({
    required this.score,
    this.questionGrades,
    required this.status,
  });

  factory GradeRequest.fromJson(Map<String, dynamic> json) =>
      _$GradeRequestFromJson(json);
  Map<String, dynamic> toJson() => _$GradeRequestToJson(this);
}

// ─────────────────────────────────────────────────────────────────────────────
// RESPONSE — Assignment
// ─────────────────────────────────────────────────────────────────────────────

@JsonSerializable(explicitToJson: true)
class Assignment {
  final String id;
  final String title;
  final String content;
  final AssignmentType type;
  final bool published;

  /// When false, students can't see the exam content (questions) before they
  /// choose to start. Defaults true (matches the backend default + old data).
  @JsonKey(defaultValue: true)
  final bool showContentPreview;
  final String classId;

  @JsonKey(name: 'class')
  final AssignmentClass? assignmentClass;

  // Nullable to match backend `Assessment.dueDate DateTime?` — an assessment
  // created without a due date returns null, which previously crashed list
  // deserialization (DateTime.parse(null)) and made exams "disappear".
  final DateTime? dueDate;
  final int? duration;
  @JsonKey(nullable: true)
  final String? accessCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Attachment>? attachments;

  @JsonKey(name: '_count')
  final AssignmentCount? count;

  // Populated only on /details endpoint — parsed manually via fromJson
  final List<Question> questions;

  // Anti-cheat safety policy (see exam_safety.dart). Defaults match the backend
  // column defaults so old data deserializes cleanly.
  @JsonKey(defaultValue: 'MID')
  final String safetyLevel;
  @JsonKey(defaultValue: 'MOBILE')
  final String safetyScope;
  @JsonKey(defaultValue: 'CAMERA')
  final String safetyMeasure;

  Assignment({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.published,
    this.showContentPreview = true,
    required this.classId,
    this.assignmentClass,
    required this.attachments,
    this.dueDate,
    this.duration,
    this.accessCode,
    required this.createdAt,
    required this.updatedAt,
    this.count,
    this.questions = const [],
    this.safetyLevel = 'MID',
    this.safetyScope = 'MOBILE',
    this.safetyMeasure = 'CAMERA',
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    // Post class→course refactor the backend returns `courseId` and no longer a
    // `classId`; question-based exams may also omit `content`. Normalize before
    // the generated parser, whose non-null String casts otherwise throw
    // "type 'Null' is not a subtype of type 'String'".
    json = {
      ...json,
      'classId': json['classId'] ?? json['courseId'] ?? '',
      'content': json['content'] ?? '',
    };
    final base = _$AssignmentFromJson(json);
    // Parse questions manually since @JsonKey excludes them from generated code
    final rawQuestions = json['questions'] as List<dynamic>?;
    final questions =
        rawQuestions
            ?.map((e) => Question.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return Assignment(
      attachments: base.attachments,
      id: base.id,
      title: base.title,
      content: base.content,
      type: base.type,
      published: base.published,
      showContentPreview: base.showContentPreview,
      classId: base.classId,
      assignmentClass: base.assignmentClass,
      dueDate: base.dueDate,
      duration: base.duration,
      accessCode: base.accessCode,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      count: base.count,
      questions: questions,
      safetyLevel: base.safetyLevel,
      safetyScope: base.safetyScope,
      safetyMeasure: base.safetyMeasure,
    );
  }

  Map<String, dynamic> toJson() => _$AssignmentToJson(this);
}

@JsonSerializable()
class AssignmentCount {
  final int submissions;
  final int questions;

  AssignmentCount({required this.submissions, required this.questions});

  factory AssignmentCount.fromJson(Map<String, dynamic> json) =>
      _$AssignmentCountFromJson(json);
  Map<String, dynamic> toJson() => _$AssignmentCountToJson(this);
}

// ─────────────────────────────────────────────────────────────────────────────
// RESPONSE — Question
// ─────────────────────────────────────────────────────────────────────────────

@JsonSerializable(explicitToJson: true)
class Question {
  final String id;
  final String? assessmentId;
  final int order;
  final QuestionType type;
  final String text;
  final int points;
  final bool isRequired;
  final String? correctOptionId;
  final String? correctAnswer;
  final DateTime? createdAt;
  @JsonKey(defaultValue: [])
  final List<Option> options;

  @JsonKey(defaultValue: [])
  final List<Attachment> attachments;

  Question({
    required this.id,
    required this.assessmentId,
    required this.order,
    required this.type,
    required this.text,
    required this.points,
    required this.isRequired,
    this.correctOptionId,
    this.correctAnswer,
    required this.createdAt,
    this.options = const [],
    this.attachments = const [],
  });

  factory Question.fromJson(Map<String, dynamic> json) =>
      _$QuestionFromJson(json);
  Map<String, dynamic> toJson() => _$QuestionToJson(this);
}

// ─────────────────────────────────────────────────────────────────────────────
// RESPONSE — Option
// ─────────────────────────────────────────────────────────────────────────────

@JsonSerializable()
class Option {
  final String id;
  final String questionId;
  final String label;
  final String text;
  final bool isCorrect;

  Option({
    required this.id,
    required this.questionId,
    required this.label,
    required this.text,
    required this.isCorrect,
  });

  factory Option.fromJson(Map<String, dynamic> json) => _$OptionFromJson(json);
  Map<String, dynamic> toJson() => _$OptionToJson(this);
}

// ─────────────────────────────────────────────────────────────────────────────
// RESPONSE — Attachment
// ─────────────────────────────────────────────────────────────────────────────

@JsonSerializable()
class Attachment {
  final String id;
  final String questionId;
  final String fileName;
  final String fileUrl;
  final String fileType;
  final int fileSize;
  final DateTime createdAt;

  Attachment({
    required this.id,
    required this.questionId,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    required this.createdAt,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) =>
      _$AttachmentFromJson(json);
  Map<String, dynamic> toJson() => _$AttachmentToJson(this);
}

// ─────────────────────────────────────────────────────────────────────────────
// RESPONSE — AssignmentClass
// ─────────────────────────────────────────────────────────────────────────────

@JsonSerializable()
class AssignmentClass {
  final String id;
  final String name;
  final String? courseId;

  AssignmentClass({required this.id, required this.name, this.courseId});

  factory AssignmentClass.fromJson(Map<String, dynamic> json) =>
      _$AssignmentClassFromJson(json);
  Map<String, dynamic> toJson() => _$AssignmentClassToJson(this);
}

@JsonSerializable(explicitToJson: true, createToJson: true)
class Submission {
  final String id;
  // ✅ Handle both "assessmentId" (full) and "assignmentId/testId" (grade response)
  @JsonKey(name: 'assessmentId', includeIfNull: false)
  final String? assessmentId;

  @JsonKey(name: 'assignmentId', includeIfNull: false)
  final String? assignmentId;
  @JsonKey(name: 'testId', includeIfNull: false)
  final String? testId;
  final String studentId;
  @JsonKey(includeIfNull: false)
  final String? content;

  @JsonKey(includeIfNull: false)
  final num? score;

  final String status;

  // ✅ Helper getter to get the assessment ID regardless of format
  String get effectiveAssessmentId =>
      assessmentId ?? assignmentId ?? testId ?? '';

  final DateTime createdAt;

  // ✅ Optional fields only present in full submission response
  @JsonKey(includeIfNull: false)
  final DateTime? startedAt;
  @JsonKey(includeIfNull: false)
  final DateTime? submittedAt;

  @JsonKey(includeIfNull: false)
  final StudentSummary? student;
  @JsonKey(includeIfNull: false)
  final AssessmentSummary? assessment;
  @JsonKey(includeIfNull: false)
  final List<SubmissionAnswer>? answers;

  // ── Anti-cheat (advisory only — never affects the grade) ──────────────────
  @JsonKey(includeIfNull: false)
  final int? cheatScore; // 0-100, higher = more likely cheating
  @JsonKey(includeIfNull: false)
  final int? violationCount;
  @JsonKey(includeIfNull: false)
  final bool? flagged;
  @JsonKey(includeIfNull: false)
  final bool? forcedExit; // exam ended because the student left the app
  @JsonKey(includeIfNull: false)
  final Map<String, dynamic>? proctorReport; // violation timeline

  // ── Result revocation (staff) ─────────────────────────────────────────────
  @JsonKey(includeIfNull: false)
  final bool? resultRevoked;
  @JsonKey(includeIfNull: false)
  final String? revokedReason;
  @JsonKey(includeIfNull: false)
  final DateTime? revokedAt;
  // ORG_ADMIN | TEACHER — who last revoked. A teacher cannot reverse an
  // ORG_ADMIN revoke (backend-enforced; UI hides the option too).
  @JsonKey(includeIfNull: false)
  final String? revokedByRole;

  bool get isRevoked => resultRevoked == true;
  bool get revokedByAdmin => revokedByRole == 'ORG_ADMIN';

  Submission copyWith({
    String? status,
    num? score,
    List<SubmissionAnswer>? answers,
    bool? resultRevoked,
    String? revokedReason,
    DateTime? revokedAt,
    String? revokedByRole,
  }) {
    return Submission(
      id: this.id,
      studentId: this.studentId,
      status: status ?? this.status,
      score: score ?? this.score,
      createdAt: this.createdAt,
      assessmentId: this.assessmentId,
      assignmentId: this.assignmentId,
      testId: this.testId,
      startedAt: this.startedAt,
      submittedAt: this.submittedAt,
      student: this.student,
      assessment: this.assessment,
      answers: answers ?? this.answers,
      cheatScore: this.cheatScore,
      violationCount: this.violationCount,
      flagged: this.flagged,
      forcedExit: this.forcedExit,
      proctorReport: this.proctorReport,
      resultRevoked: resultRevoked ?? this.resultRevoked,
      revokedReason: revokedReason ?? this.revokedReason,
      revokedAt: revokedAt ?? this.revokedAt,
      revokedByRole: revokedByRole ?? this.revokedByRole,
    );
  }

  Submission({
    required this.id,
    this.content,
    this.score,
    required this.status,
    required this.studentId,
    this.assessmentId,
    this.assignmentId,
    this.testId,
    required this.createdAt,
    this.startedAt,
    this.submittedAt,
    this.student,
    this.assessment,
    this.answers,
    this.cheatScore,
    this.violationCount,
    this.flagged,
    this.forcedExit,
    this.proctorReport,
    this.resultRevoked,
    this.revokedReason,
    this.revokedAt,
    this.revokedByRole,
  });

  factory Submission.fromJson(Map<String, dynamic> json) =>
      _$SubmissionFromJson(json);

  Map<String, dynamic> toJson() => _$SubmissionToJson(this);

  // ✅ Helper: Check if this is a "full" submission or just a grade summary
  bool get isFullSubmission => answers != null && startedAt != null;
}

@JsonSerializable(explicitToJson: true)
class SubmissionAnswer {
  final String id;
  final String submissionId;
  final String questionId;
  @JsonKey(includeIfNull: false)
  final String? selectedOptionId;
  @JsonKey(includeIfNull: false)
  final String? selectedAnswer;
  @JsonKey(includeIfNull: false)
  // @JsonKey(name: 'answerText')
  final String? textAnswer;
  @JsonKey(includeIfNull: false)
  final bool? isCorrect;
  @JsonKey(includeIfNull: false)
  final num? pointsEarned;
  final String? feedback;
  final DateTime createdAt;
  final QuestionDetail? question;
  SubmissionAnswer copyWith({bool? isCorrect, num? pointsEarned}) {
    return SubmissionAnswer(
      id: this.id,

      submissionId: this.submissionId,
      questionId: this.questionId,
      selectedOptionId: this.selectedOptionId,
      selectedAnswer: this.selectedAnswer,
      textAnswer: this.textAnswer,
      isCorrect: isCorrect ?? this.isCorrect,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      feedback: this.feedback,
      createdAt: this.createdAt,
      question: this.question,
    );
  }

  SubmissionAnswer({
    required this.id,
    required this.submissionId,
    required this.questionId,
    this.selectedOptionId,
    this.selectedAnswer,
    this.textAnswer,
    this.isCorrect,
    this.pointsEarned,
    this.feedback,
    required this.createdAt,
    this.question,
  });

  factory SubmissionAnswer.fromJson(Map<String, dynamic> json) =>
      _$SubmissionAnswerFromJson(json);

  Map<String, dynamic> toJson() => _$SubmissionAnswerToJson(this);
}

@JsonSerializable(explicitToJson: true)
class QuestionDetail {
  final String id;
  final String assessmentId;
  final int order;
  final String type;
  final String text;
  final num points;
  final bool isRequired;
  @JsonKey(includeIfNull: false)
  final String? correctOptionId;
  @JsonKey(includeIfNull: false)
  final String? correctAnswer;
  final DateTime createdAt;

  QuestionDetail({
    required this.id,
    required this.assessmentId,
    required this.order,
    required this.type,
    required this.text,
    required this.points,
    required this.isRequired,
    this.correctOptionId,
    this.correctAnswer,
    required this.createdAt,
  });

  factory QuestionDetail.fromJson(Map<String, dynamic> json) =>
      _$QuestionDetailFromJson(json);

  Map<String, dynamic> toJson() => _$QuestionDetailToJson(this);
}

@JsonSerializable(explicitToJson: true)
class StudentSummary {
  final String? id; // ← Added (response includes it)
  final String name;
  final String email;
  @JsonKey(includeIfNull: false)
  final String? role; // ← Optional (not in this response)
  @JsonKey(includeIfNull: false)
  final String? avatar; // ← Optional

  StudentSummary({
    this.id,
    required this.name,
    required this.email,
    this.role,
    this.avatar,
  });

  factory StudentSummary.fromJson(Map<String, dynamic> json) =>
      _$StudentSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$StudentSummaryToJson(this);
}

@JsonSerializable()
class ClassSummary {
  final String id;
  final String name;

  ClassSummary({required this.id, required this.name});

  factory ClassSummary.fromJson(Map<String, dynamic> json) =>
      _$ClassSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$ClassSummaryToJson(this);
}

@JsonSerializable(explicitToJson: true)
class AssessmentSummary {
  final String id;
  final String title;
  final String type;
  @JsonKey(name: 'class', includeIfNull: false)
  final ClassSummary? classroom;
  // These are NOT in the list endpoint response → make optional
  @JsonKey(includeIfNull: false)
  final String? content;
  @JsonKey(includeIfNull: false)
  final String? classId;
  @JsonKey(includeIfNull: false)
  final bool? published;
  @JsonKey(includeIfNull: false)
  final DateTime? dueDate;
  @JsonKey(includeIfNull: false)
  final int? duration;
  @JsonKey(includeIfNull: false)
  final String? accessCode;
  @JsonKey(includeIfNull: false)
  final DateTime? createdAt;
  @JsonKey(includeIfNull: false)
  final DateTime? updatedAt;

  AssessmentSummary({
    required this.id,
    required this.title,
    required this.type,
    this.classroom,
    this.content,
    this.classId,
    this.published,
    this.dueDate,
    this.duration,
    this.accessCode,
    this.createdAt,
    this.updatedAt,
  });

  factory AssessmentSummary.fromJson(Map<String, dynamic> json) =>
      _$AssessmentSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$AssessmentSummaryToJson(this);
}

@JsonSerializable()
class SubmissionStudent {
  final String id;
  final String name;
  final String? email;

  SubmissionStudent({required this.id, required this.name, this.email});

  factory SubmissionStudent.fromJson(Map<String, dynamic> json) =>
      _$SubmissionStudentFromJson(json);
  Map<String, dynamic> toJson() => _$SubmissionStudentToJson(this);
}
