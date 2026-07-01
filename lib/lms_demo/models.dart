class DemoOrganization {
  final String id;
  final String name;

  DemoOrganization({required this.id, required this.name});
}

class DemoClassroom {
  final String id;
  final String name;
  final String orgId;

  DemoClassroom({required this.id, required this.name, required this.orgId});
}

class DemoCourse {
  final String id;
  final String title;
  final String classId;
  final String teacherName;

  DemoCourse({
    required this.id,
    required this.title,
    required this.classId,
    required this.teacherName,
  });
}

class DemoLiveSession {
  final String id;
  final String courseId;
  final String teacherId;
  final DateTime startTime;
  String joinCode;

  String status; // "scheduled" | "live" | "ended"

  DemoLiveSession({
    required this.id,
    required this.courseId,
    required this.teacherId,
    required this.startTime,
    required this.joinCode,
    required this.status,
  });
}
