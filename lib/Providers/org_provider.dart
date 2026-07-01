import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../models/api_models/organization_model.dart';
import '../models/api_models/program_model.dart';
import '../models/api_models/course_model.dart';
import '../models/api_models/class_model.dart';
import '../models/api_models/live_session_model.dart';
import '../models/api_models/enrollment_model.dart';
import '../models/api_models/attendance_model.dart';

enum Role { admin, user, guest }

enum OrgAction { none, switched, exited }

//
// enum MemberFilter { all, owner, teacher, student }
//
// class OrgProvider extends ChangeNotifier {
//   final ApiService _apiService;
//
//   OrgProvider(this._apiService);
//
//   bool _isLoading = false;
//   bool _isMutating = false;
//   bool _justSwitched = false;
//   OrgAction _lastAction = OrgAction.none;
//   MemberFilter _filter = MemberFilter.all;
//
//   String? _currentOrgId;
//   String? _error;
//
//   List<OrganizationResponse> _organisations = [];
//   OrganizationResponse? _selectedOrg;
//   List<OrganisationMember> _members = [];
//   List<OrganisationMember> _teachers = [];
//   List<OrganisationMember> _students = [];
//   List<ProgramResponse> _programs = [];
//   List<CourseResponse> _courses = [];
//   List<ClassModel> _classes = [];
//   List<LiveSession> _liveSessions = [];
//
//   // Getters
//   bool get isLoading => _isLoading;
//   bool get isMutating => _isMutating;
//   bool get justSwitched => _justSwitched;
//   OrgAction get lastAction => _lastAction;
//   MemberFilter get filter => _filter;
//   String? get currentOrgId => _currentOrgId;
//   String? get currentOrgName => _selectedOrg?.name;
//   String? get error => _error;
//   List<OrganizationResponse> get organisations => _organisations;
//   OrganizationResponse? get selectedOrg => _selectedOrg;
//   List<OrganisationMember> get members => _members;
//   List<OrganisationMember> get teachers => _teachers;
//   List<OrganisationMember> get students => _students;
//   List<ProgramResponse> get programs => _programs;
//   List<CourseResponse> get courses => _courses;
//   List<ClassModel> get classes => _classes;
//   List<LiveSession> get liveSessions => _liveSessions;
//
//   /// Load all organisations
//   Future<void> loadOrganisations() async {
//     _isLoading = true;
//     _error = null;
//     notifyListeners();
//     try {
//       _organisations = await _apiService.getOrganizations();
//       if (_selectedOrg == null && _organisations.isNotEmpty) {
//         _selectedOrg = _organisations.first;
//         _currentOrgId = _selectedOrg!.id;
//       }
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error loading organisations: $e");
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }
//
//   /// Select an organisation
//   Future<void> selectOrganisation(String id) async {
//     _isLoading = true;
//     _error = null;
//     _lastAction = OrgAction.none;
//     _justSwitched = false;
//     notifyListeners();
//     try {
//       _selectedOrg = await _apiService.getOrganization(id);
//       _currentOrgId = id;
//       _lastAction = OrgAction.switched;
//       _justSwitched = true;
//       // Clear cached data when switching orgs
//       _members = [];
//       _teachers = [];
//       _students = [];
//       _programs = [];
//       _courses = [];
//       _classes = [];
//       _liveSessions = [];
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error selecting organisation: $e");
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }
//
//   /// Clear the justSwitched flag
//   void clearJustSwitched() {
//     _justSwitched = false;
//     notifyListeners();
//   }
//
//   String? _currentUserId; // store logged-in user id
//
//   // Getter for current user's role
//   String get role {
//     final user = _members.firstWhere(
//       (m) => m.userId == _currentUserId,
//       orElse: () => _members.first,
//     );
//     return user?.role ?? 'guest';
//   }
//
//   void setCurrentUser(String userId) {
//     _currentUserId = userId;
//   }
//////   bool _justSwitched = false;
// //   /// Load all organisations
// //   Future<void> loadOrganisations() async {
// //     _isLoading = true;
// //     _error = null;
// //     notifyListeners();
// //     try {
// //       _organisations = await _apiService.getOrganizations();
// //       if (_selectedOrg == null && _organisations.isNotEmpty) {
// //         _selectedOrg = _organisations.first;
// //         _currentOrgId = _selectedOrg!.id;
// //       }
// //     } catch (e) {
// //       _error = e.toString();
// //       debugPrint("Error loading organisations: $e");
// //     } finally {
// //       _isLoading = false;
// //       notifyListeners();
// //     }
// //   }
// //
//   /// Leave current organisation
//   Future<void> leaveOrganisation() async {
//     _currentOrgId = null;
//     _selectedOrg = null;
//     _members = [];
//     _teachers = [];
//     _students = [];
//     _programs = [];
//     _courses = [];
//     _classes = [];
//     _liveSessions = [];
//     _lastAction = OrgAction.exited;
//     notifyListeners();
//   }
//
//   /// Create organisation
//   Future<OrganizationResponse?> createOrganisation(
//     String name,
//     String email, {
//     String? description,
//     String? logoUrl,
//   }) async {
//     _isMutating = true;
//     _error = null;
//     notifyListeners();
//     try {
//       final request = OrganizationRequest(
//         name: name,
//         email: email,
//         description: description,
//         logoUrl: logoUrl,
//       );
//       final created = await _apiService.createOrganisation(request, email);
//       _organisations = [..._organisations, created];
//       _selectedOrg = created;
//       _currentOrgId = created.id;
//       notifyListeners();
//       return created;
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error creating organisation: $e");
//       return null;
//     } finally {
//       _isMutating = false;
//       notifyListeners();
//     }
//   }
//
//   /// Update organisation
//   Future<bool> updateOrganisation(
//     String id,
//     String name,
//     String email, {
//     String? description,
//     String? logoUrl,
//   }) async {
//     _isMutating = true;
//     _error = null;
//     notifyListeners();
//     try {
//       final request = OrganizationRequest(
//         name: name,
//         email: email,
//         description: description,
//         logoUrl: logoUrl,
//       );
//       final updated = await _apiService.updateOrganization(id, request);
//       _organisations = [
//         for (final o in _organisations) o.id == id ? updated : o,
//       ];
//       if (_selectedOrg?.id == id) _selectedOrg = updated;
//       notifyListeners();
//       return true;
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error updating organisation: $e");
//       return false;
//     } finally {
//       _isMutating = false;
//       notifyListeners();
//     }
//   }
//
//   /// Delete organisation
//   Future<bool> deleteOrganisation(String id) async {
//     _isMutating = true;
//     _error = null;
//     notifyListeners();
//     try {
//       await _apiService.deleteOrganization(id);
//       _organisations = _organisations.where((o) => o.id != id).toList();
//       if (_selectedOrg?.id == id) {
//         _selectedOrg = _organisations.isNotEmpty ? _organisations.first : null;
//         _currentOrgId = _selectedOrg?.id;
//       }
//       notifyListeners();
//       return true;
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error deleting organisation: $e");
//       return false;
//     } finally {
//       _isMutating = false;
//       notifyListeners();
//     }
//   }
//
//   // ── Members ────────────────────────────────────────────────────────────────
//
//   /// Fetch members with optional role filter
//   Future<void> fetchMembers({String? role}) async {
//     if (_currentOrgId == null) return;
//     _isLoading = true;
//     _error = null;
//     notifyListeners();
//     try {
//       _members = await _apiService.getMembers(_currentOrgId!, role);
//       _filter = role != null
//           ? MemberFilter.values.byName(role)
//           : MemberFilter.all;
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error fetching members: $e");
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }
//
//   /// Fetch teachers
//   Future<void> fetchTeachers() async {
//     if (_currentOrgId == null) return;
//     _isLoading = true;
//     _error = null;
//     notifyListeners();
//     try {
//       _teachers = await _apiService.getMembers(_currentOrgId!, 'teacher');
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error fetching teachers: $e");
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }
//
//   /// Fetch students
//   Future<void> fetchStudents() async {
//     if (_currentOrgId == null) return;
//     _isLoading = true;
//     _error = null;
//     notifyListeners();
//     try {
//       _students = await _apiService.getMembers(_currentOrgId!, 'student');
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error fetching students: $e");
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }
//
//   /// Add member
//   Future<bool> addMember(
//     String organisationId,
//     OrganisationMemberRequest request,
//   ) async {
//     _isMutating = true;
//     _error = null;
//     notifyListeners();
//     try {
//       await _apiService.addMember(organisationId, request);
//       notifyListeners();
//       return true;
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error adding member: $e");
//       return false;
//     } finally {
//       _isMutating = false;
//       notifyListeners();
//     }
//   }
//
//   // ── Programs ───────────────────────────────────────────────────────────────
//
//   /// Fetch programs
//   Future<void> fetchPrograms() async {
//     _isLoading = true;
//     _error = null;
//     notifyListeners();
//     try {
//       _programs = await _apiService.getPrograms();
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error fetching programs: $e");
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }
//
//   /// Create program
//   Future<ProgramResponse?> createProgram(ProgramRequest request) async {
//     _isMutating = true;
//     _error = null;
//     notifyListeners();
//     try {
//       final program = await _apiService.createProgram(request);
//       _programs = [..._programs, program];
//       notifyListeners();
//       return program;
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error creating program: $e");
//       return null;
//     } finally {
//       _isMutating = false;
//       notifyListeners();
//     }
//   }
//
//   /// Update program
//   Future<bool> updateProgram(String id, ProgramRequest request) async {
//     _isMutating = true;
//     _error = null;
//     notifyListeners();
//     try {
//       final updated = await _apiService.updateProgram(id, request);
//       _programs = [for (final p in _programs) p.id == id ? updated : p];
//       notifyListeners();
//       return true;
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error updating program: $e");
//       return false;
//     } finally {
//       _isMutating = false;
//       notifyListeners();
//     }
//   }
//
//   /// Delete program
//   Future<bool> deleteProgram(String id) async {
//     _isMutating = true;
//     _error = null;
//     notifyListeners();
//     try {
//       await _apiService.deleteProgram(id);
//       _programs = _programs.where((p) => p.id != id).toList();
//       notifyListeners();
//       return true;
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error deleting program: $e");
//       return false;
//     } finally {
//       _isMutating = false;
//       notifyListeners();
//     }
//   }
//
//   // ── Courses ────────────────────────────────────────────────────────────────
//
//   /// Fetch courses
//   Future<void> fetchCourses() async {
//     _isLoading = true;
//     _error = null;
//     notifyListeners();
//     try {
//       _courses = await _apiService.getCourses();
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error fetching courses: $e");
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }
//
//   /// Create course
//   Future<CourseResponse?> createCourse(CourseRequest request) async {
//     _isMutating = true;
//     _error = null;
//     notifyListeners();
//     try {
//       final course = await _apiService.createCourse(request);
//       _courses = [..._courses, course];
//       notifyListeners();
//       return course;
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error creating course: $e");
//       return null;
//     } finally {
//       _isMutating = false;
//       notifyListeners();
//     }
//   }
//
//   /// Update course
//   Future<bool> updateCourse(String id, CourseRequest request) async {
//     _isMutating = true;
//     _error = null;
//     notifyListeners();
//     try {
//       final updated = await _apiService.updateCourse(id, request);
//       _courses = [for (final c in _courses) c.id == id ? updated : c];
//       notifyListeners();
//       return true;
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error updating course: $e");
//       return false;
//     } finally {
//       _isMutating = false;
//       notifyListeners();
//     }
//   }
//
//   /// Delete course
//   Future<bool> deleteCourse(String id) async {
//     _isMutating = true;
//     _error = null;
//     notifyListeners();
//     try {
//       await _apiService.deleteCourse(id);
//       _courses = _courses.where((c) => c.id != id).toList();
//       notifyListeners();
//       return true;
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error deleting course: $e");
//       return false;
//     } finally {
//       _isMutating = false;
//       notifyListeners();
//     }
//   }
//
//   // ── Classes ────────────────────────────────────────────────────────────────
//
//   /// Fetch classes
//   Future<void> fetchClasses() async {
//     _isLoading = true;
//     _error = null;
//     notifyListeners();
//     try {
//       _classes = await _apiService.getClasses();
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error fetching classes: $e");
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }
//
//   /// Create class
//   Future<ClassModel?> createClass(ClassRequest request) async {
//     _isMutating = true;
//     _error = null;
//     notifyListeners();
//     try {
//       final classModel = await _apiService.createClass(request);
//       _classes = [..._classes, classModel];
//       notifyListeners();
//       return classModel;
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error creating class: $e");
//       return null;
//     } finally {
//       _isMutating = false;
//       notifyListeners();
//     }
//   }
//
//   /// Update class
//   Future<bool> updateClass(String id, ClassRequest request) async {
//     _isMutating = true;
//     _error = null;
//     notifyListeners();
//     try {
//       final updated = await _apiService.updateClass(id, request);
//       _classes = [for (final c in _classes) c.id == id ? updated : c];
//       notifyListeners();
//       return true;
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error updating class: $e");
//       return false;
//     } finally {
//       _isMutating = false;
//       notifyListeners();
//     }
//   }
//
//   /// Delete class
//   Future<bool> deleteClass(String id) async {
//     _isMutating = true;
//     _error = null;
//     notifyListeners();
//     try {
//       await _apiService.deleteClass(id);
//       _classes = _classes.where((c) => c.id != id).toList();
//       notifyListeners();
//       return true;
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error deleting class: $e");
//       return false;
//     } finally {
//       _isMutating = false;
//       notifyListeners();
//     }
//   }
//
//   // ── Live Sessions ──────────────────────────────────────────────────────────
//
//   /// Fetch live sessions
//   Future<void> fetchLiveSessions() async {
//     _isLoading = true;
//     _error = null;
//     notifyListeners();
//     try {
//       _liveSessions = await _apiService.getLiveSessions();
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error fetching live sessions: $e");
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }
//
//   /// Fetch upcoming live sessions
//   Future<List<LiveSession>> fetchUpcomingLiveSessions({String? classId}) async {
//     try {
//       return await _apiService.getAllUpcomingLiveSessions(
//         _currentOrgId,
//         classId,
//       );
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error fetching upcoming live sessions: $e");
//       return [];
//     }
//   }
//
//   /// Create live session
//   Future<LiveSession?> createLiveSession(LiveSessionRequest request) async {
//     _isMutating = true;
//     _error = null;
//     notifyListeners();
//     try {
//       final session = await _apiService.createLiveSession(request);
//       _liveSessions = [..._liveSessions, session];
//       notifyListeners();
//       return session;
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error creating live session: $e");
//       return null;
//     } finally {
//       _isMutating = false;
//       notifyListeners();
//     }
//   }
//
//   /// Start live session
//   Future<LiveSession?> startLiveSession(String id) async {
//     _isMutating = true;
//     _error = null;
//     notifyListeners();
//     try {
//       final session = await _apiService.updateStartLiveSession(id);
//       _liveSessions = [for (final s in _liveSessions) s.id == id ? session : s];
//       notifyListeners();
//       return session;
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error starting live session: $e");
//       return null;
//     } finally {
//       _isMutating = false;
//       notifyListeners();
//     }
//   }
//
//   /// End live session
//   Future<LiveSession?> endLiveSession(String id) async {
//     _isMutating = true;
//     _error = null;
//     notifyListeners();
//     try {
//       final session = await _apiService.updateEndLiveSession(id);
//       _liveSessions = [for (final s in _liveSessions) s.id == id ? session : s];
//       notifyListeners();
//       return session;
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error ending live session: $e");
//       return null;
//     } finally {
//       _isMutating = false;
//       notifyListeners();
//     }
//   }
//
//   /// Delete live session
//   Future<bool> deleteLiveSession(String id) async {
//     _isMutating = true;
//     _error = null;
//     notifyListeners();
//     try {
//       await _apiService.deleteLiveSession(id);
//       _liveSessions = _liveSessions.where((s) => s.id != id).toList();
//       notifyListeners();
//       return true;
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error deleting live session: $e");
//       return false;
//     } finally {
//       _isMutating = false;
//       notifyListeners();
//     }
//   }
//
//   // ── Enrollment ─────────────────────────────────────────────────────────────
//
//   /// Enroll in a course
//   Future<Enrollment?> enrollCourse(CourseEnrollmentRequest request) async {
//     _isMutating = true;
//     _error = null;
//     notifyListeners();
//     try {
//       final enrollment = await _apiService.enrollCourse(request);
//       notifyListeners();
//       return enrollment;
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error enrolling in course: $e");
//       return null;
//     } finally {
//       _isMutating = false;
//       notifyListeners();
//     }
//   }
//
//   /// Get course enrollments for a user
//   Future<List<Enrollment>> getCourseEnrollments(
//     String userId, {
//     EnrollmentStatus? status,
//   }) async {
//     try {
//       return await _apiService.getCourseEnrollmentsByUser(userId, status);
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error fetching course enrollments: $e");
//       return [];
//     }
//   }
//
//   // ── Attendance ─────────────────────────────────────────────────────────────
//
//   /// Mark attendance
//   Future<void> markAttendance(AttendanceRequest request) async {
//     _isMutating = true;
//     _error = null;
//     notifyListeners();
//     try {
//       await _apiService.markAttendance(request);
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error marking attendance: $e");
//     } finally {
//       _isMutating = false;
//       notifyListeners();
//     }
//   }
//
//   /// Get attendance by class
//   Future<List<Attendance>> getAttendanceByClass(
//     String classId, {
//     String? liveSessionId,
//   }) async {
//     try {
//       return await _apiService.getAttendanceByClass(classId, liveSessionId);
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error fetching attendance: $e");
//       return [];
//     }
//   }
//
//   /// Get attendance by student
//   Future<List<Attendance>> getAttendanceByStudent(String studentId) async {
//     try {
//       return await _apiService.getAttendanceByStudent(studentId, studentId);
//     } catch (e) {
//       _error = e.toString();
//       debugPrint("Error fetching student attendance: $e");
//       return [];
//     }
//   }
//
//   void setFilter(MemberFilter filter) {
//     _filter = filter;
//     fetchMembers(role: filter == MemberFilter.all ? null : filter.name);
//   }
//
//   void clearError() {
//     _error = null;
//     notifyListeners();
//   }
// }
