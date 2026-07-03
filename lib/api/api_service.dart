import 'package:dio/dio.dart' hide Headers;
import 'package:htoochoon_flutter/models/api_models/assignment_model.dart';
import 'package:htoochoon_flutter/models/api_models/attendance_model.dart';
import 'package:htoochoon_flutter/models/api_models/class_model.dart';
import 'package:htoochoon_flutter/models/api_models/course_model.dart';
import 'package:htoochoon_flutter/models/api_models/enrollment_model.dart'
    hide EnrollmentStatus;
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:htoochoon_flutter/models/api_models/live_session_model.dart';
import 'package:htoochoon_flutter/models/api_models/organization_model.dart';
import 'package:htoochoon_flutter/models/api_models/program_model.dart';
import 'package:htoochoon_flutter/models/api_models/school_model.dart';
import 'package:htoochoon_flutter/models/api_models/student_enrollment_model.dart';
import 'package:htoochoon_flutter/models/api_models/submission_model.dart';
import 'package:htoochoon_flutter/models/api_models/subscription_model.dart';
import 'package:htoochoon_flutter/models/api_models/teacher_stats_model.dart';
import 'package:htoochoon_flutter/models/api_models/user_model.dart';
import 'package:htoochoon_flutter/models/auth/auth_model.dart';
import 'package:retrofit/retrofit.dart';

part 'api_service.g.dart';

@RestApi()
abstract class ApiService {
  factory ApiService(Dio dio, {String baseUrl}) = _ApiService;

  // =========================================================
  // 🔐 AUTH
  // =========================================================

  @POST("/auth/register")
  Future<RegisterResponse> register(@Body() RegisterRequest body);

  @POST("/auth/request-otp")
  Future<RequestOtpResponse> requestOtp(@Body() RequestOtpRequest request);

  @POST("/auth/verify-otp")
  Future<VerifyOtpResponse> verifyOtp(@Body() VerifyOtpRequest request);

  @POST("/auth/login")
  Future<LoginResponse> login(@Body() LoginRequest request);
  // @POST("/auth/login")
  // Future<LoginResponse> login(@Body() LoginRequest request);

  @POST("/auth/reset-password")
  Future<ResetPasswordResponse> resetPassword(
    @Body() ResetPasswordRequest request,
  );

  // @GET("/auth/me")
  // Future<User> fetchMe();

  /// Mark attendance
  @POST("/attendance")
  Future<Attendance> markAttendance(@Body() AttendanceRequest request);

  /// Get attendance by course (optionally filter by liveSessionId)
  @GET("/attendance/course/{courseId}")
  Future<List<Attendance>> getAttendanceByCourse(
    @Path("courseId") String courseId,
    @Query("liveSessionId") String? liveSessionId,
  );

  /// Get attendance by student
  @GET("/attendance/student/{studentId}")
  Future<List<Attendance>> getAttendanceByStudent(
    @Path("studentId") String studentId,
    @Query("studentId") String? queryStudentId,
  );
  // =========================================================
  // 👤 USERS
  // =========================================================

  @GET("/users")
  Future<List<User>> getUsers(@Query("search") String? search);

  @GET("/users/{id}")
  Future<User> getUser(@Path("id") String id);

  @POST("/users")
  Future<User> createUser(@Body() CreateUserRequest request);
  @GET("/users/me")
  Future<User> getMe();

  @POST("/users/{organizationId}/leave")
  Future<void> userLeaveOrg(@Path("organizationId") String orgId);

  @POST("/users/{id}/change-password")
  Future<void> changePassword(
    @Path("id") String id,
    @Body() Map<String, dynamic> body,
  );

  @PATCH("/users/{id}")
  Future<User> updateUser(
    @Path("id") String id,
    @Body() Map<String, dynamic> body, // or UpdateUserRequest
  );

  @DELETE("/users/{id}")
  Future<void> deleteUser(@Path("id") String id);

  @POST("/users/upload/{id}")
  @MultiPart()
  Future<UploadResponse> uploadUserProfile(
    @Path("id") String id,
    @Part(name: "file") MultipartFile file,
  );
  // =========================================================
  // 🏫 SCHOOLS
  // =========================================================

  @GET("/schools")
  Future<List<SchoolResponse>> getSchools();

  @GET("/schools/{id}")
  Future<SchoolResponse> getSchool(@Path("id") String id);

  @POST("/schools")
  Future<SchoolResponse> createSchool(@Body() SchoolRequest request);

  @PATCH("/schools/{id}")
  Future<SchoolResponse> updateSchool(
    @Path("id") String id,
    @Body() UpdateSchoolRequest request,
  );

  @DELETE("/schools/{id}")
  Future<void> deleteSchool(@Path("id") String id);

  // =========================================================
  // 🏢 ORGANIZATIONS
  // =========================================================

  @GET("/organizations")
  Future<List<OrganizationResponse>> getOrganizations();

  @GET("/organizations/{id}")
  Future<OrganizationResponse> getOrganization(@Path("id") String id);

  @POST("/organizations")
  Future<OrganizationResponse> createOrganisation(
    @Body() OrganizationRequest request,
    // @Query("ownerEmail") String ownerEmail,
  );

  @PATCH("/organizations/{id}")
  Future<OrganizationResponse> updateOrganization(
    @Path("id") String id,
    @Body() OrganizationRequest request,
  );

  @DELETE("/organizations/{id}")
  Future<void> deleteOrganization(@Path("id") String id);

  /// Add member to organisation
  @POST("/organizations/{id}/members")
  Future<void> addMember(
    @Path("id") String organisationId,
    @Body() OrganisationMemberRequest request,
  );

  /// Get members (optionally filtered by role)
  @GET("/organizations/{id}/members")
  Future<List<OrganisationMember>> getMembers(
    @Path("id") String organisationId,
    @Query("role") String? role,
    @Query("search") String? search,
  );
  @DELETE("/organizations/{id}/members/{userId}")
  Future<void> removeMember(
    @Path("id") String organisationId,
    @Path("userId") String userId,
  );

  @POST("/organizations/{id}/transfer-ownership")
  Future<void> transferOwnership(
    @Path("id") String organisationId,
    @Body() String newOwnerId,
  );
  @POST("/organizations/upload/{id}")
  @MultiPart()
  Future<void> uploadOrganizationLogo(
    @Path("id") String organizationId,
    @Part(name: "file") MultipartFile file,
  );
  // @GET("/organizations/{id}/usage")
  // Future<UsageCheckResponse> getUsageStats(@Path("id") String organisationId);
  // =========================================================
  // 📚 COURSES
  // =========================================================
  //
  // @GET("/courses")
  // Future<List<CourseResponse>> getAllCourses(); // ← no params

  @GET("/courses")
  Future<CourseListResponse> getCourses(
    @Query("organizationId") String? organizationId,
    @Query("type") CourseType? type,
    @Query("search") String? search,
    @Query("page") num? page,
    @Query("limit") num? limit,
  );

  @GET("/courses/{id}")
  Future<CourseResponse> getCourseById(@Path("id") String id);

  @POST("/courses")
  Future<CourseResponse> createCourse(@Body() CourseRequest request);

  @PATCH("/courses/{id}")
  Future<CourseResponse> updateCourse(
    @Path("id") String id,
    @Body() CourseRequest request,
  );

  @DELETE("/courses/{id}")
  Future<void> deleteCourse(@Path("id") String id);

  /// ---------------------------
  /// CLASS CRUD
  /// ---------------------------

  @POST("/classes")
  Future<ClassModel> createClass(@Body() ClassRequest request);

  @GET("/classes")
  Future<ClassResponse> getClasses(
    @Query("organizationId") String? organizationId,
    @Query("limit") int? limit,
    @Query("page") int? page,
    @Query("search") String? search,
    @Query("teacherId") String? teacherId,
    @Query("courseId") String? courseId,
  );

  @GET("/classes/{id}")
  Future<ClassModel> getClassById(@Path("id") String id);

  @PATCH("/classes/{id}")
  Future<ClassModel> updateClass(
    @Path("id") String id,
    @Body() ClassRequest request,
  );

  @DELETE("/classes/{id}")
  Future<void> deleteClass(@Path("id") String id);

  /// ---------------------------
  /// CLASS STUDENTS
  /// ---------------------------

  /// Add student to class
  @POST("/classes/{id}/students")
  Future<AddStudentResponse> addStudentToClass(
    @Path("id") String classId,
    @Body() ClassStudentRequest request,
  );

  @GET("/classes/{id}/students")
  Future<ClassStudentsResponse> getAllStudentsInAClass(
    @Query("id") String classId,
    // @Body() ClassStudentRequest request,
  );

  // @GET("/classes/{id}/student")
  // Future<void> getAllStudentFromClass(
  //   @Path("id") String classId,
  //   @Body() ClassStudentRequest request,
  // );

  /// Remove student from class
  @DELETE("/classes/{id}/students/{userId}")
  Future<void> removeStudentFromClass(
    @Path("id") String classId,
    @Path("userId") String userId,
  );

  /// ---------------------------
  /// TEACHER
  /// ---------------------------

  // =========================================================
  // 🎓 PROGRAMS
  // =========================================================
  // @GET("/programs")
  // Future<List<ProgramResponse>> getAllPrograms(); // ← no params

  @GET("/programs")
  Future<List<ProgramResponse>> getPrograms(
    @Query("search") String? search,
    @Query("organizationId") String? organizationId,
  );

  @GET("/programs/{id}")
  Future<ProgramResponse> getProgramById(@Path("id") String id);

  @POST("/programs")
  Future<ProgramResponse> createProgram(@Body() ProgramRequest request);

  @PATCH("/programs/{id}")
  Future<ProgramResponse> updateProgram(
    @Path("id") String id,
    @Body() ProgramRequest request,
  );

  @DELETE("/programs/{id}")
  Future<void> deleteProgram(@Path("id") String id);
  @POST("/programs/{programId}/courses")
  Future<void> createProgramCourse(
    @Path("programId") String programId,
    @Body() ProgramCourseRequest request,
  );

  // @GET("/programs/{programId}/courses")
  // Future<List<CourseResponse>> getProgramCourses(
  //   @Path("programId") String programId,
  // );

  @DELETE("/programs/{programId}/courses/{courseId}")
  Future<void> deleteProgramCourse(
    @Path("programId") String programId,

    @Path("courseId") String courseId,
  );

  // =========================================================
  // 🎥 LIVE SESSIONS
  // =========================================================
  @POST('/live-sessions')
  Future<LiveSession> createLiveSession(@Body() LiveSessionRequest request);
  @GET('/live-sessions')
  Future<LiveSessionResponse> getLiveSessions(
    @Query('organizationId') String? organizationId,
    @Query('courseId') String? courseId,
    @Query('status') List<String> status,
    @Query("startTime") DateTime? startTime,
    @Query("endTime") DateTime? endTime,
    @Query("limit") int? limit,
    @Query("page") int? page,
  );

  @PATCH('/live-sessions/{id}/start')
  Future<LiveSession> startLiveSession(@Path('id') String id);

  @PATCH('/live-sessions/{id}/end')
  Future<LiveSession> endLiveSession(@Path('id') String id);

  // @GET('/live-sessions/upcoming')
  // Future<LiveSessionResponse> getUpcomingLiveSessions(
  //   @Query('organizationId') String? organizationId,
  //   @Query('classId') String? classId,
  //   @Query("status") String? status,
  //   @Query("startTime") DateTime? startTime,
  //   @Query("endTime") DateTime? endTime,
  //   @Query("limit") int? limit,
  //   @Query("page") int? page,
  // );

  // @POST('/student/live-sessions/{id}/join')
  // Future<void> joinLiveSession(@Path('id') String id);

  @GET('/student/live-sessions/{id}/join')
  Future<JoinLiveSessionResponse> joinStudentLiveSession(@Path('id') String id);
  @POST('/teacher/live-sessions/{id}/join')
  Future<JoinLiveSessionResponse> joinTeacherLiveSession(@Path('id') String id);

  /// Headline dashboard stats for the signed-in teacher. studentCount is the
  /// count of DISTINCT students with an active enrollment across the teacher's
  /// programs (deduped server-side).
  @GET('/teacher/me/stats')
  Future<TeacherStats> getTeacherStats();

  @GET("/live-sessions/{id}")
  Future<LiveSession> getLiveSession(@Path("id") String id);

  @DELETE("/live-sessions/{id}")
  Future<void> deleteLiveSession(@Path("id") String id);

  /// ---------------------------
  /// COURSE ENROLLMENT
  /// ---------------------------

  @POST("/enrollment/courses")
  Future<Enrollment> enrollCourse(@Body() CourseEnrollmentRequest request);

  @PATCH("/enrollment/courses/{enrollmentId}/status")
  Future<Enrollment> updateCourseEnrollmentStatus(
    @Path("enrollmentId") String enrollmentId,
    @Body() UpdateEnrollmentStatusRequest request,
  );

  @GET("/enrollment/courses/user/{userId}")
  Future<List<Enrollment>> getCourseEnrollmentsByUser(
    @Path("userId") String userId,
    @Query("status") String? status,
  );

  /// ---------------------------
  /// PROGRAM ENROLLMENT
  /// ---------------------------

  @POST("/enrollment/programs")
  Future<Enrollment> enrollProgram(@Body() ProgramEnrollmentRequest request);
  @GET("/enrollment/courses")
  Future<EnrollmentResponse> getAllCourseEnrollments(
    @Query("status") String status,
    @Query("search") String search,
    @Query("organizationId") String? organizationId,
    @Query("page") int page,
    @Query("limit") int limit,
  );

  @GET("/enrollment/courses/{id}")
  Future<EnrollmentResponse> getCourseEnrollmentsByCourseId(
    @Path("id") String id,

    @Query("page") int? page,
    @Query("limit") int? limit,
    @Query("organizationId") String? organizationId,
    @Query("search") String? search,
    @Query("status") String? status,
  );
  @GET("/enrollment/programs")
  Future<EnrollmentResponse> getAllProgramEnrollments(
    @Query("page") int page,
    @Query("limit") int limit,
    @Query("organizationId") String? organizationId,
    @Query("status") String status,
    @Query("search") String search,
  );

  @GET("/enrollment/programs/{id}")
  Future<EnrollmentResponse> getProgramEnrollmentsByProgramId(
    @Path("id") String id,

    @Query("page") int? page,
    @Query("limit") int? limit,
    @Query("organizationId") String? organizationId,
    @Query("search") String? search,
    @Query("status") String? status,
  );
  @PATCH("/enrollment/programs/{enrollmentId}/status")
  Future<Enrollment> updateProgramEnrollmentStatus(
    @Path("enrollmentId") String enrollmentId,
    @Body() UpdateEnrollmentStatusRequest request,
  );

  @GET("/enrollment/programs/user/{userId}")
  Future<List<Enrollment>> getProgramEnrollmentsByUser(
    @Path("userId") String userId,
    @Query("status") String? status,
  );

  /// ---------------------------
  /// ASSIGNMENTS & TESTS
  /// ---------------------------

  @POST("/assignments")
  @MultiPart()
  Future<Assignment> createAssignment(
    @Part(name: "title") String title,
    @Part(name: "content") String content,
    @Part(name: "courseId") String courseId,
    @Part(name: "type") String type, // "ASSIGNMENT" or "TEST"
    @Part(name: "duration") int duration,
    @Part(name: "showContentPreview") bool showContentPreview,
    @Part(name: "questions") String questions, // JSON string
    // Optional relative deadline: due this many minutes after publish.
    @Part(name: "dueDurationMinutes") int? dueDurationMinutes,
    @Part(name: "attachments") List<MultipartFile>? attachments,
    // Anti-cheat safety policy (NONE|MID|HIGH|EXTREME / ALL|DESKTOP|MOBILE /
    // CAMERA|NETWORK).
    @Part(name: "safetyLevel") String? safetyLevel,
    @Part(name: "safetyScope") String? safetyScope,
    @Part(name: "safetyMeasure") String? safetyMeasure,
  );

  @PATCH("/assignments/{id}")
  Future<Assignment> updateAssignment(
    @Path("id") String id,
    @Body() Map<String, dynamic> request,
  );

  @DELETE("/assignments/{id}")
  Future<void> deleteAssignment(@Path("id") String id);

  @GET("/assignments/{id}/details")
  Future<Assignment> getAssignmentDetails(@Path("id") String id);

  @GET("/assignments/course/{courseId}")
  Future<List<Assignment>> getAssignmentsByCourse(
    @Path("courseId") String courseId, {
    // When true the backend returns only published assessments — used for the
    // student view so drafts stay hidden. Omitted (null) for teachers/admins.
    @Query("publishedOnly") bool? publishedOnly,
  });

  // /// ---------------------------
  // /// ASSIGNMENTS
  // /// ---------------------------
  //
  // @POST("/assignments")
  // Future<Assignment> createAssignment(@Body() AssignmentRequest request);
  //
  // @GET("/assignments/class/{classId}")
  // Future<List<Assignment>> getAssignmentsByClass(
  //   @Path("classId") String classId,
  // );
  //
  // /// ---------------------------
  // /// TESTS
  // /// ---------------------------
  //
  // @POST("/assignments/tests")
  // Future<TestModel> createTest(@Body() AssignmentRequest request);
  //
  // @GET("/assignments/tests/class/{classId}")
  // Future<List<TestModel>> getTestsByClass(@Path("classId") String classId);

  /// ---------------------------
  /// SUBMISSIONS
  /// ---------------------------

  @POST("/submissions")
  @Headers(<String, String>{
    "Content-Type": "application/json",
    "Accept": "application/json",
  })
  Future<Submission> submitWork(@Body() SubmissionRequest body);
  @POST("/submissions")
  Future<Submission> submitWorkRaw(@Body() Map<String, dynamic> body);
  @PATCH("/submissions/{id}/grade")
  Future<Submission> gradeSubmission(
    @Path("id") String submissionId,
    @Body() GradeRequest request,
  );

  @PATCH("/submissions/{id}/revoke")
  Future<Submission> revokeSubmission(
    @Path("id") String submissionId,
    @Body() Map<String, dynamic> body, // { reason }
  );

  @PATCH("/submissions/{id}/restore")
  Future<Submission> restoreSubmission(
    @Path("id") String submissionId,
  );

  // ── Exam lockout (kick-out → teacher must approve a retake) ──────────────
  // Student client locks the exam on a forced exit / kick-out.
  @POST("/exam-locks")
  Future<dynamic> createExamLock(@Body() Map<String, dynamic> body);

  // Student gate: is this exam locked for me? → { locked, status, reason }.
  @GET("/exam-locks/check")
  Future<dynamic> checkExamLock(@Query("assessmentId") String assessmentId);

  // Teacher/admin: list locked/flagged attempts for a course.
  @GET("/exam-locks")
  Future<dynamic> listExamLocks(
    @Query("courseId") String courseId,
    @Query("status") String status,
  );

  // Teacher/admin: approve a student's retake (clears the lock).
  @POST("/exam-locks/{id}/approve")
  Future<dynamic> approveExamLock(@Path("id") String id);

  // Returns `dynamic` (the decoded JSON map) rather than Map<String,dynamic> so
  // Retrofit's generator doesn't try to call `.fromJson` on the map's values.
  @GET("/teacher/courses/{courseId}/students/{studentId}/analytics")
  Future<dynamic> getStudentAnalytics(
    @Path("courseId") String courseId,
    @Path("studentId") String studentId,
  );

  // Comprehensive org-scoped student overview (programs, attendance, exams,
  // materials, violations…). `dynamic` for the same Retrofit-codegen reason.
  @GET("/organizations/{orgId}/students/{studentId}/overview")
  Future<dynamic> getStudentOverview(
    @Path("orgId") String orgId,
    @Path("studentId") String studentId,
  );

  // Advanced student search/filter within an org.
  @GET("/organizations/{orgId}/students/search")
  Future<dynamic> searchOrgStudents(
    @Path("orgId") String orgId, {
    @Query("search") String? search,
    @Query("programId") String? programId,
    @Query("status") String? status,
    @Query("joinedFrom") String? joinedFrom,
    @Query("joinedTo") String? joinedTo,
    @Query("enrolledFrom") String? enrolledFrom,
    @Query("enrolledTo") String? enrolledTo,
    @Query("sortBy") String? sortBy,
    @Query("order") String? order,
    @Query("page") int? page,
    @Query("limit") int? limit,
  });

  // 📊 Org-level analytics dashboard (enrollment, performance, at-risk, course +
  // instructor leaderboards, trends). `dynamic` for the Retrofit-codegen reason.
  @GET("/organizations/{orgId}/analytics")
  Future<dynamic> getOrgAnalytics(@Path("orgId") String orgId);

  // 📚 Course analytics: completion, exam + question analytics, materials.
  @GET("/teacher/courses/{courseId}/analytics")
  Future<dynamic> getCourseAnalytics(@Path("courseId") String courseId);

  // 🎓 Instructor analytics (admin view; org-scoped via query for the guard).
  @GET("/teacher/instructors/{teacherId}/analytics")
  Future<dynamic> getInstructorAnalytics(
    @Path("teacherId") String teacherId,
    @Query("organizationId") String organizationId,
  );

  // 🎓 Instructor analytics for the current teacher.
  @GET("/teacher/me/analytics")
  Future<dynamic> getMyInstructorAnalytics();

  // 📈 Activity heartbeat → learning hours + active days.
  @POST("/activity/ping")
  Future<dynamic> pingActivity(@Body() Map<String, dynamic> body);

  // 🔗 Shareable join links (org / program / live-session).
  @POST("/join-links")
  Future<dynamic> createJoinLink(@Body() Map<String, dynamic> body);

  @GET("/join-links/{token}")
  Future<dynamic> getJoinLinkPreview(@Path("token") String token);

  @POST("/join-links/{token}/redeem")
  Future<dynamic> redeemJoinLink(@Path("token") String token);

  @GET("/join-links")
  Future<dynamic> listJoinLinks(@Query("organizationId") String organizationId);

  @DELETE("/join-links/{id}")
  Future<dynamic> revokeJoinLink(
    @Path("id") String id,
    @Query("organizationId") String organizationId,
  );

  // 🎯 Gamified onboarding — save interests / heardFrom / role.
  @PATCH("/users/me/onboarding")
  Future<dynamic> saveOnboarding(@Body() Map<String, dynamic> body);

  // 🙋 Access requests (self-service join an org).
  @GET("/organizations")
  Future<dynamic> searchOrganizations(@Query("search") String? search);

  @POST("/access-requests")
  Future<dynamic> createAccessRequest(@Body() Map<String, dynamic> body);

  @GET("/access-requests/mine")
  Future<dynamic> myAccessRequests();

  @GET("/access-requests/org/{organizationId}")
  Future<dynamic> listOrgAccessRequests(
    @Path("organizationId") String organizationId,
    @Query("status") String? status,
  );

  @PATCH("/access-requests/{id}/decide")
  Future<dynamic> decideAccessRequest(
    @Path("id") String id,
    @Body() Map<String, dynamic> body,
  );

  // Records that the current student opened a material (engagement tracking).
  @POST("/materials/{id}/view")
  Future<dynamic> markMaterialViewed(@Path("id") String id);

  @GET("/submissions/course/{courseId}/{itemId}")
  Future<List<Submission>> getCourseSubmissions(
    @Path("courseId") String courseId,
    @Path("itemId") String itemId,
    @Path("type") String type, // "assignment" | "test
    @Query("page") num page,
    @Query("limit") num limit,
    @Query("search") String search,
  );

  @GET("/submissions/student/{studentId}")
  Future<List<Submission>> getStudentSubmissions(
    @Path("studentId") String studentId,
  );

  // =========================================================
  // 💳 SUBSCRIPTION / PLANS
  // =========================================================

  @GET("/organizations/{organizationId}/plan")
  Future<SubscriptionPlan> fetchCurrentPlan(
    @Path("organizationId") String organizationId,
  );

  @PATCH("/organizations/{organizationId}/plan")
  Future<SubscriptionPlan> updatePlan(
    @Path("organizationId") String organisationId,
    @Body() Map<String, dynamic> body,
  );

  @GET("/organizations/{organizationId}/plan/available")
  Future<List<PlanTier>> fetchAvailablePlans(
    @Path("organizationId") String organisationId,
  );

  @POST("/organizations/{organizationId}/plan/check")
  Future<UsageCheckResponse> checkResourceLimit(
    @Path("organizationId") String organisationId,
    @Body() Map<String, dynamic> body, // e.g., {"resourceType": "student"}
  );

  @GET("/organizations/{organizationId}/plan/usage")
  Future<DashboardUsage> fetchUsageDashboard(
    @Path("organizationId") String organisationId,
  );

  // =========================================================
  // 👤 STUDENT
  // =========================================================
  @GET('/student/courses')
  Future<List<StudentClassEnrollment>> getStudentCourses();
  // =========================================================
  // LIVE
  // =========================================================
}
