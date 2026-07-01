/// Headline dashboard numbers for a teacher, from `GET /teacher/me/stats`.
///
/// Plain hand-rolled model (no codegen) so Retrofit deserializes it via the
/// [fromJson] factory instead of trying to treat the response as a map of
/// models.
class TeacherStats {
  final int classCount;
  final int programCount;

  /// DISTINCT students with an active enrollment across the teacher's programs
  /// (a student in two of the teacher's programs is counted once).
  final int studentCount;

  const TeacherStats({
    required this.classCount,
    required this.programCount,
    required this.studentCount,
  });

  factory TeacherStats.fromJson(Map<String, dynamic> json) => TeacherStats(
        classCount: (json['classCount'] as num?)?.toInt() ?? 0,
        programCount: (json['programCount'] as num?)?.toInt() ?? 0,
        studentCount: (json['studentCount'] as num?)?.toInt() ?? 0,
      );
}
