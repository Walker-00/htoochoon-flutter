import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/organisation_provider.dart';
import 'package:htoochoon_flutter/Providers/auth_provider.dart';
import 'package:htoochoon_flutter/Providers/enrollment_provider.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/shared_member_enrollment_widgets.dart';
import 'package:htoochoon_flutter/api/api_service.dart';
import 'package:htoochoon_flutter/core/userorgrole_manager.dart';
import 'package:htoochoon_flutter/models/api_models/enrollment_model.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:htoochoon_flutter/models/api_models/organization_model.dart';
import 'package:htoochoon_flutter/models/auth/auth_model.dart';
import 'package:provider/provider.dart';
import 'package:htoochoon_flutter/Providers/class_provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/subscription_provider.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/classroom_detail_screen.dart';
import 'package:htoochoon_flutter/models/api_models/class_model.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';

class StudentCourseDetailScreen extends StatefulWidget {
  final String courseId;
  final String courseName;
  final String? description;
  final String? programName;
  final String orgId;

  const StudentCourseDetailScreen({
    super.key,
    required this.courseId,
    required this.courseName,
    this.description,
    this.programName,
    required this.orgId,
  });

  @override
  State<StudentCourseDetailScreen> createState() =>
      _StudentCourseDetailScreenState();
}

class _StudentCourseDetailScreenState extends State<StudentCourseDetailScreen> {
  @override
  Widget build(BuildContext context) {
    // No more class layer — a student opening a course lands directly on the
    // teaching page (materials/exams/assignments/sessions), keyed on courseId.
    return ClassroomScreen(
      args: ClassroomArgs(
        courseId: widget.courseId,
        classId: widget.courseId,
        courseName: widget.courseName,
        courseCode: '',
        description: widget.description ?? '',
        className: widget.courseName,
        orgId: widget.orgId,
        programName: widget.programName,
        isTemplate: false,
        entryPoint: widget.programName != null
            ? ClassEntryPoint.fromProgram
            : ClassEntryPoint.direct,
      ),
    );
  }
}

class _ClassesBody extends StatelessWidget {
  final String courseId;
  final String orgId;
  final String? programName;
  final bool loadingStudents;

  const _ClassesBody({
    required this.courseId,
    required this.orgId,
    required this.programName,
    required this.loadingStudents,
  });

  @override
  Widget build(BuildContext context) {
    final classProv = context.watch<ClassProvider>();
    final userId = UserSessionManager.userId;

    final currentUserId = userId;

    final classes = classProv.classes
        .where((c) => c.courseId == courseId)
        .toList();

    if (classProv.isLoading || loadingStudents) {
      return const Center(child: CircularProgressIndicator());
    }

    if (classes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.class_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              'No classes available yet',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      itemCount: classes.length,
      itemBuilder: (context, index) {
        final cls = classes[index];

        /// students inside this class
        final students = classProv.getStudents(cls.id.toString());

        /// check if current user belongs to class or isadmin
        final orgProv = context.watch<OrganizationProvider>();
        final role = orgProv.currentOrgRole;

        final roleCheck = orgProv.getOrgRole(orgId);
        final isTeacherOrAdmin =
            (roleCheck == Role.ORG_ADMIN || roleCheck == Role.TEACHER);

        final isOrgAdmin = role == Role.ORG_ADMIN;
        final isTeacher = role == Role.TEACHER;
        final hasAccess =
            isOrgAdmin ||
            isTeacher ||
            students.any((s) => s.id == currentUserId);

        return Opacity(
          opacity: hasAccess ? 1 : 0.45,
          child: IgnorePointer(
            ignoring: !hasAccess,
            child: Stack(
              children: [
                ClassCard(
                  orgId: orgId,
                  classItem: cls,
                  courseName: cls.course?.name ?? 'Unknown Course',
                  programName: programName,
                  isEditable: isTeacherOrAdmin,
                ),

                /// locked overlay
                if (!hasAccess)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.lock_outline,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'No Access',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Explains the template model on a template (academic) course screen.
class _TemplateBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.extension_rounded, color: cs.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Template course',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: cs.primary)),
                const SizedBox(height: 2),
                Text(
                  'Build classes, upload materials, and draft (unpublished) '
                  'assignments & exams here. Students, teachers and live '
                  'sessions are added per program — adding this course to a '
                  'program creates its own independent copy.',
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurface.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CourseDetailScreen extends StatefulWidget {
  final String courseId;
  final String courseName;
  final String? programName;
  final String orgId;
  // True when this is a template (academic) course — a blueprint with no
  // students/teachers/live sessions until added to a program.
  final bool isTemplate;

  const CourseDetailScreen({
    super.key,
    required this.courseId,
    required this.courseName,
    this.programName,
    required this.orgId,
    this.isTemplate = false,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final orgProv = context.read<OrganizationProvider>();
      final enrollProv = context.read<EnrollmentProvider>();

      context.read<ClassProvider>().fetchClasses(
        widget.orgId,
        null,
        widget.courseId,
      );
      context.read<SubscriptionProvider>().loadForOrg(widget.orgId);

      if (orgProv.userCache.isEmpty && orgProv.members.isNotEmpty) {
        await orgProv.preloadMembers(orgProv.members);
      }

      final userIds = orgProv.members.map((m) => m.userId).toList();
      await enrollProv.fetchAllCourseEnrollments(userIds, widget.courseId);
    });
  }

  @override
  Widget build(BuildContext context) {
    // The Class layer was removed — viewing a course drops you straight into the
    // teaching page. Teaching content (materials, exams, assignments, and — for
    // program courses — sessions/people) hangs directly off the course, so the
    // course id is used as the teach-page identifier.
    return ClassroomScreen(
      args: ClassroomArgs(
        courseId: widget.courseId,
        classId: widget.courseId,
        courseName: widget.courseName,
        courseCode: '',
        description: '',
        className: widget.courseName,
        orgId: widget.orgId,
        programName: widget.programName,
        isTemplate: widget.isTemplate,
        entryPoint: widget.programName != null
            ? ClassEntryPoint.fromProgram
            : ClassEntryPoint.direct,
      ),
    );
  }
}

// ── Classes Tab (moved from original body) ────────────────
class _ClassesTab extends StatelessWidget {
  final bool isTeacher;
  final String courseId;
  final String courseName;
  final String? programName;
  final String orgId;

  const _ClassesTab({
    required this.isTeacher,
    required this.courseId,
    required this.courseName,
    this.programName,
    required this.orgId,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer3<ClassProvider, SubscriptionProvider, OrganizationProvider>(
      builder: (context, classProv, subProv, orgProv, _) {
        final classes = classProv.classes
            .where((c) => c.courseId == courseId)
            .toList();
        final orgProv = context.watch<OrganizationProvider>();
        final userRole = orgProv.getOrgRole(orgId);
        final isAuthorizedStaff =
            (userRole == Role.ORG_ADMIN || userRole == Role.TEACHER);
        if (classProv.isLoading && classProv.classes.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (classes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.class_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No classes found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),

                ElevatedButton.icon(
                  onPressed: () => _showCreateDialog(
                    context,
                    classProv,
                    orgProv,
                    subProv,
                    courseId,
                    orgId,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Class'),
                ),
              ],
            ),
          );
        }

        return Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              itemCount: classes.length,
              itemBuilder: (context, index) => ClassCard(
                classItem: classes[index],
                courseName: courseName,
                programName: programName,
                orgId: orgId,
                isEditable: isAuthorizedStaff,
              ),
            ),
            if (isTeacher)
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton.extended(
                  onPressed: () => _showCreateDialog(
                    context,
                    classProv,
                    orgProv,
                    subProv,
                    courseId,
                    orgId,
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  label: const Text(
                    'New Class',
                    style: TextStyle(color: Colors.white),
                  ),
                  icon: const Icon(Icons.add, color: Colors.white),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showCreateDialog(
    BuildContext context,
    ClassProvider prov,
    OrganizationProvider orgProv,
    SubscriptionProvider subProv,
    String courseId,
    String orgId,
  ) async {
    final limit = subProv.canCreateClass();
    if (!limit.allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(limit.reason ?? "Class limit reached.")),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final maxStudentsCtrl = TextEditingController(text: '30');

    final startDate = DateTime.now();
    final endDate = DateTime.now().add(const Duration(days: 90));

    OrganisationMember? selectedTeacher;
    List<OrganisationMember> teachers = [];

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setInner) {
            return AlertDialog(
              title: const Text('New Class'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// Class Name
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Class Name',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    /// ✅ Teacher Autocomplete
                    Autocomplete<OrganisationMember>(
                      displayStringForOption: (m) =>
                          "${m.user.name} (${m.user.email})",

                      optionsBuilder: (text) {
                        return teachers.where(
                          (t) =>
                              t.user.name.toLowerCase().contains(
                                text.text.toLowerCase(),
                              ) ||
                              t.user.email.toLowerCase().contains(
                                text.text.toLowerCase(),
                              ),
                        );
                      },

                      onSelected: (teacher) {
                        setInner(() {
                          selectedTeacher = teacher;
                        });
                        logD("SELECTED TEACHER: ${teacher.user.id}");
                      },

                      fieldViewBuilder: (context, controller, focusNode, _) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Search Teacher',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) async {
                            if (value.isEmpty) return;

                            await orgProv.searchTeachers(orgId, value);

                            setInner(() {
                              teachers = orgProv.teachers; // from provider
                            });
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    /// Max Students
                    TextField(
                      controller: maxStudentsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max Students',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty || selectedTeacher == null) {
                      logD("❌ Missing data");
                      return;
                    }

                    Navigator.pop(ctx);

                    await prov.createClass(
                      ClassRequest(
                        organizationId: orgId,
                        name: nameCtrl.text,
                        courseId: courseId,
                        startDate: startDate,
                        endDate: endDate,
                        maxStudents: int.tryParse(maxStudentsCtrl.text) ?? 30,

                        /// ✅ ONLY allow teacher from org
                        teacherId: selectedTeacher!.user.id,
                      ),
                    );
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CourseMembersTab extends StatefulWidget {
  final String courseId;
  final EnrollmentStatus status;
  final String orgId;

  const _CourseMembersTab({
    required this.courseId,
    required this.status,
    required this.orgId,
  });

  @override
  State<_CourseMembersTab> createState() => _CourseMembersTabState();
}

class _CourseMembersTabState extends State<_CourseMembersTab> {
  final ScrollController _scrollController = ScrollController();
  int _page = 1;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    _fetchInitial();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _CourseMembersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status ||
        oldWidget.courseId != widget.courseId) {
      _fetchInitial();
    }
  }

  void _fetchInitial() {
    _page = 1;
    // Delay slightly to prevent mutating context state during ongoing tree renders
    Future.microtask(() {
      context.read<EnrollmentProvider>().fetchEnrollmentsByCourseId(
        courseId: widget.courseId,
        page: _page,
        limit: _limit,
        organizationId: widget.orgId,
        status: widget
            .status
            .name, // 🔥 FIXED: Targeting specific course route matching UI extraction
        loadMore: false,
      );
    });
  }

  void _loadMore() {
    final prov = context.read<EnrollmentProvider>();
    if (prov.isFetchingMore || !prov.hasMore) return;

    _page++;
    prov.fetchEnrollmentsByCourseId(
      courseId: widget.courseId,
      page: _page,
      limit: _limit,
      organizationId: widget.orgId,
      status: widget.status.name,
      loadMore: true,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enrollProv = context.watch<EnrollmentProvider>();

    // Filter locally to match the target context
    final members = enrollProv.courseSpecificEnrollments
        .where(
          (e) =>
              e.courseId == widget.courseId &&
              e.status.toString().contains(widget.status.name),
        )
        .map(
          (e) => MemberEnrollment(
            enrollment: e,
            user: e.user != null
                ? User(
                    id: e.user!.id ?? '',
                    name: e.user!.name ?? 'Unknown User',
                    email: e.user!.email ?? '',
                    role: Role.USER,
                    isActive: true,
                    createdAt: DateTime.now(),
                  )
                : null,
          ),
        )
        .toList();

    if (enrollProv.isLoading && members.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (members.isEmpty) {
      return Center(
        child: Text(
          widget.status == EnrollmentStatus.ACTIVE
              ? 'No active members'
              : 'No pending requests',
          style: TextStyle(color: Colors.grey[500], fontSize: 15),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      itemCount: members.length + (enrollProv.isFetchingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= members.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final m = members[index];

        return MemberTile(
          memberEnrollment: m,
          isPending: widget.status == EnrollmentStatus.PENDING,
          onApprove: widget.status == EnrollmentStatus.PENDING
              ? () async {
                  await enrollProv.updateCourseEnrollmentStatus(
                    m.enrollment.id,
                    UpdateEnrollmentStatusRequest(
                      status: EnrollmentStatus.ACTIVE,
                    ),
                  );
                  if (context.mounted) {
                    _fetchInitial();
                  }
                }
              : null,
          onDrop: () async {
            await enrollProv.updateCourseEnrollmentStatus(
              m.enrollment.id,
              UpdateEnrollmentStatusRequest(status: EnrollmentStatus.DROPPED),
            );
            if (context.mounted) {
              _fetchInitial();
            }
          },
        );
      },
    );
  }
}
// members_widgets.dart
// Make _MemberEnrollment and _MemberTile public by removing the underscore

// class MemberEnrollment {
//   final Enrollment enrollment;
//   final User? user;
//   MemberEnrollment({required this.enrollment, this.user});
// }
// class StudentCourseDetailScreen extends StatefulWidget {
//   final String courseId;
//   final String courseName;
//   final String? description;
//   final String? programName;
//   final String orgId;
//
//   const StudentCourseDetailScreen({
//     super.key,
//     required this.courseId,
//     required this.courseName,
//     this.description,
//     this.programName,
//     required this.orgId,
//   });
//
//   @override
//   State<StudentCourseDetailScreen> createState() =>
//       _StudentCourseDetailScreenState();
// }
//
// class _StudentCourseDetailScreenState extends State<StudentCourseDetailScreen> {
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       context.read<ClassProvider>().fetchClasses();
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final classProv = context.watch<ClassProvider>();
//
//     final classes = classProv.classes
//         .where((c) => c.courseId == widget.courseId)
//         .toList();
//
//     return Scaffold(
//       backgroundColor: Theme.of(context).scaffoldBackgroundColor,
//       appBar: AppBar(
//         title: Text(widget.courseName),
//         backgroundColor: cs.primary,
//         foregroundColor: cs.onPrimary,
//       ),
//       body: classProv.isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : classes.isEmpty
//           ? Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.class_outlined, size: 56, color: cs.outline),
//                   const SizedBox(height: AppTheme.spaceMd),
//                   Text(
//                     'No classes available yet',
//                     style: Theme.of(context).textTheme.bodyLarge?.copyWith(
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                 ],
//               ),
//             )
//           : ListView.builder(
//               padding: const EdgeInsets.all(AppTheme.spaceLg),
//               itemCount: classes.length,
//               itemBuilder: (context, index) {
//                 final cls = classes[index];
//                 return ClassCard(
//                   orgId: widget.orgId,
//                   classItem: cls,
//                   courseName: cls.course.name,
//                   programName: widget.programName,
//                 );
//               },
//             ),
//     );
//   }
// }
