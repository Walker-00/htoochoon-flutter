import 'package:json_annotation/json_annotation.dart';
part 'enums.g.dart';

@JsonEnum()
enum Role {
  @JsonValue('ORG_ADMIN')
  ORG_ADMIN,

  @JsonValue('TEACHER')
  TEACHER,

  @JsonValue('STUDENT')
  STUDENT,

  @JsonValue('STAFF')
  STAFF,

  @JsonValue('USER')
  USER,
}

// Role roleFromString(String role) => $enumDecode(_$RoleEnumMap, role);

@JsonEnum(alwaysCreate: true)
enum InvitationStatus { PENDING, ACCEPTED, REJECTED }

enum LiveSessionStatus {
  @JsonValue('SCHEDULED')
  scheduled,

  @JsonValue('LIVE')
  live,

  @JsonValue('ENDED')
  ended,
}

@JsonEnum(alwaysCreate: true)
enum AttendanceStatus { PRESENT, LATE, LEFT, ABSENT }

@JsonEnum(alwaysCreate: true)
enum OtpType { VERIFY_EMAIL, RESET_PASSWORD, TWO_FACTOR_SETUP }

@JsonEnum(alwaysCreate: true)
enum ProgramType { DEGREE, CERTIFICATION, BOOTCAMP }

@JsonEnum(alwaysCreate: true)
enum CourseType { SKILL, ACADEMIC, TEST_PREP }

@JsonEnum()
enum EnrollmentStatus {
  @JsonValue('PENDING')
  PENDING,

  @JsonValue('ACTIVE')
  ACTIVE,

  @JsonValue('COMPLETED')
  COMPLETED,

  @JsonValue('DROPPED')
  DROPPED,
}

@JsonEnum()
enum AssignmentType {
  @JsonValue('ASSIGNMENT')
  ASSIGNMENT,
  @JsonValue('TEST')
  TEST,
  @JsonValue('QUIZ')
  QUIZ,
  @JsonValue('EXAM')
  EXAM,
}

@JsonEnum()
enum QuestionType {
  @JsonValue('MULTIPLE_CHOICE')
  MULTIPLE_CHOICE,
  @JsonValue('SHORT_ANSWER')
  SHORT_ANSWER,
  @JsonValue('ESSAY')
  ESSAY,
  @JsonValue('TRUE_FALSE')
  TRUE_FALSE;

  // ✅ Add this getter for UI display
  String get displayLabel {
    return name
        .replaceAll('_', ' ') // "MULTIPLE_CHOICE" → "MULTIPLE CHOICE"
        .split(' ') // Split into words
        .map(
          (word) => // Capitalize each word
          word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
              : word,
        )
        .join(' '); // Join back: "Multiple Choice"
  }
}

@JsonEnum()
enum SubmissionStatus {
  @JsonValue('SUBMITTED')
  SUBMITTED,
  @JsonValue('GRADED')
  GRADED,
}
