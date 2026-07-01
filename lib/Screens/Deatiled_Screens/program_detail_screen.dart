import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Screens/Join/share_link_sheet.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/organisation_provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/programs_provider.dart';
import 'package:htoochoon_flutter/Providers/class_provider.dart';
import 'package:htoochoon_flutter/Providers/enrollment_provider.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/classroom_detail_screen.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/course_detail_screen.dart';
import 'package:htoochoon_flutter/widgets/program_progress_bar.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/shared_member_enrollment_widgets.dart';

import 'package:htoochoon_flutter/models/api_models/enrollment_model.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:htoochoon_flutter/models/api_models/program_model.dart';
import 'package:htoochoon_flutter/models/api_models/course_model.dart';
import 'package:htoochoon_flutter/Providers/structure_provider.dart';
import 'package:htoochoon_flutter/Providers/chat_provider.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/program_chat_screen.dart';
import 'package:htoochoon_flutter/models/auth/auth_model.dart';
import 'package:provider/provider.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';

// ─────────────────────────────────────────────────────────────
// ADMIN: Program Detail Screen
// ─────────────────────────────────────────────────────────────
class ProgramDetailScreen extends StatefulWidget {
  final ProgramResponse program;
  final String? from;
  const ProgramDetailScreen({super.key, required this.program, this.from});

  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // @override
  // void initState() {
  //   super.initState();
  //   _tabController = TabController(length: 3, vsync: this);
  //   Future.microtask(() async {
  //     final orgProv = context.read<OrganizationProvider>();
  //     final enrollProv = context.read<EnrollmentProvider>();
  //
  //     await context.read<StructureProvider>().getProgramDetailById(
  //       widget.program.id,
  //     );
  //
  //     if (orgProv.userCache.isEmpty && orgProv.members.isNotEmpty) {
  //       await orgProv.preloadMembers(orgProv.members);
  //     }
  //
  //     final userIds = orgProv.members.map((m) => m.userId).toList();
  //     await enrollProv.fetchAllProgramEnrollments(userIds, widget.program.id);
  //   });
  // }
  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);

    // Peek whether the program chat room is enabled so the AppBar can decide
    // to surface the "Program Chat" action (Phase H, task 1).
    Future.microtask(
        () => context.read<ChatProvider>().peekRoom(widget.program.id));

    Future.microtask(() async {
      final orgProv = context.read<OrganizationProvider>();
      final enrollProv = context.read<EnrollmentProvider>();
      final structProv = context.read<StructureProvider>();
      final programsProv = context.read<ProgramsProvider>();

      await structProv.getProgramDetailById(widget.program.id);

      final program = structProv.programDetail;

      if (program == null || program.organization == null) {
        return;
      }
      final orgId = program.organization?.id ?? program.organizationId;
      if (orgId == null) {
        debugPrint("Program missing organizationId");

        return;
      }
      final role = orgProv.getRoleForOrganization(orgId);

      logD("ROLE IN PROGRAM DETAIL = $role");

      // ADMIN / TEACHER FLOW
      if (role == Role.ORG_ADMIN || role == Role.TEACHER) {
        await programsProv.fetchProgramsInOrgId(orgId);
      } else {
        // STUDENT FLOW
        if (orgProv.userCache.isEmpty && orgProv.members.isNotEmpty) {
          await orgProv.preloadMembers(orgProv.members);
        }

        final userIds = orgProv.members.map((m) => m.userId).toList();

        await enrollProv.fetchAllProgramEnrollments(userIds, widget.program.id);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Program-level "Manage Students": enroll an org member into this program.
  /// They immediately inherit access to every class under the program.
  Future<void> _showEnrollStudentSheet(
    BuildContext context,
    String orgId,
    String programId,
  ) async {
    final orgProv = context.read<OrganizationProvider>();

    if (orgProv.members.isEmpty) {
      await orgProv.fetchMembers(orgId, null);
    }
    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EnrollStudentSheet(orgId: orgId, programId: programId),
    );

    // Refresh the active members list so the newly enrolled student appears.
    if (!context.mounted) return;
    await context.read<EnrollmentProvider>().fetchEnrollmentsByProgramId(
      programId: programId,
      organizationId: orgId,
      status: EnrollmentStatus.ACTIVE.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final structProv = context.watch<StructureProvider>();

    if (structProv.isLoading || structProv.programDetail == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final program = structProv.programDetail!;
    final courses = program.programCourses.map((pc) => pc.course).toList();
    logD("PROGRAM DETAIL SCREEN LOADED");
    logD("program courses raw = ${program.programCourses.length}");
    logD("mapped courses = ${courses.length}");

    // Program is the place to manage students now (they inherit class access).
    final orgId =
        program.organization?.id?.toString() ??
        program.organizationId?.toString();
    final role = orgId != null
        ? context.read<OrganizationProvider>().getRoleForOrganization(orgId)
        : null;
    final canManageStudents =
        role == Role.ORG_ADMIN || role == Role.TEACHER;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: (canManageStudents && orgId != null)
          ? FloatingActionButton.extended(
              onPressed: () =>
                  _showEnrollStudentSheet(context, orgId, program.id),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Enroll student'),
            )
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            backgroundColor: (widget.from == "TEACHER")
                ? cs.secondary
                : cs.primary,
            foregroundColor: cs.onPrimary,
            actions: [
              // Staff can generate + share a join link for this program.
              if (canManageStudents)
                IconButton(
                  tooltip: 'Share invite link',
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  onPressed: () => showShareLinkSheet(
                    context,
                    type: 'PROGRAM',
                    targetId: program.id,
                    organizationId: program.organizationId ?? '',
                    targetName: program.name,
                  ),
                ),
              // Show chat when the room is enabled, or always for staff who can
              // access/manage it. Tap → ProgramChatScreen.
              if ((context.watch<ChatProvider>().peekedEnabled(program.id) ??
                      false) ||
                  canManageStudents)
                IconButton(
                  tooltip: 'Program Chat',
                  icon: const Icon(Icons.forum_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProgramChatScreen(
                        programId: program.id,
                        programName: program.name,
                      ),
                    ),
                  ),
                ),
            ],
            // Collapse-aware header: the program name, type badge and progress
            // bar all live in the flowing background (no overlap). The floating
            // FlexibleSpaceBar title is shown ONLY once collapsed, so it never
            // sits on top of the progress bar.
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final topPad = MediaQuery.of(context).padding.top;
                final collapsed =
                    constraints.maxHeight <= kToolbarHeight + topPad + 8;
                final headerColor = (widget.from == "TEACHER")
                    ? cs.secondary
                    : cs.primary;
                return FlexibleSpaceBar(
                  titlePadding: const EdgeInsetsDirectional.only(
                    start: 56,
                    bottom: 16,
                    end: 16,
                  ),
                  title: collapsed
                      ? Text(
                          program.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: cs.onPrimary,
                          ),
                        )
                      : null,
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          headerColor,
                          headerColor.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(20, topPad + 58, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: cs.onPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            program.type.name,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: cs.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          program.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            color: cs.onPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ProgramProgressBar(
                          start: program.startDate,
                          end: program.endDate,
                          light: true,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: cs.onPrimary,
              labelColor: cs.onPrimary,
              unselectedLabelColor: cs.onPrimary.withValues(alpha: 0.6),
              tabs: const [
                Tab(text: 'Courses'),
                Tab(text: 'Members'),
                Tab(text: 'Pending'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _CoursesTab(
              courses: courses,
              program: program,
              organizationId:
                  program.organization?.id.toString() ??
                  program.organizationId.toString(),
            ),
            _ProgramMembersTab(
              orgId: widget.program.organizationId.toString(),
              programId: widget.program.id,
              status: EnrollmentStatus.ACTIVE,
            ),
            _ProgramMembersTab(
              orgId: widget.program.organizationId.toString(),
              programId: widget.program.id,
              status: EnrollmentStatus.PENDING,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Admin Courses Tab ─────────────────────────────────────
class _CoursesTab extends StatelessWidget {
  final List<CourseResponseForProgram> courses;
  final ProgramResponse program;
  final String organizationId;
  const _CoursesTab({
    required this.courses,
    required this.program,
    required this.organizationId,
  });

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return const Center(child: Text('No courses in this program'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
          child: CourseCard(
            organizationId: organizationId,
            course: courses[index],
            programName: program.name,
            program: program,
          ),
        );
      },
    );
  }
}

// ── Admin Program Members Tab ─────────────────────────────

class _ProgramMembersTab extends StatefulWidget {
  final String programId;
  final EnrollmentStatus status;
  final String orgId;

  const _ProgramMembersTab({
    required this.programId,
    required this.status,
    required this.orgId,
  });

  @override
  State<_ProgramMembersTab> createState() => _ProgramMembersTabState();
}

class _ProgramMembersTabState extends State<_ProgramMembersTab> {
  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void didUpdateWidget(covariant _ProgramMembersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status ||
        oldWidget.programId != widget.programId) {
      _fetchData();
    }
  }

  void _fetchData() {
    Future.microtask(() {
      context.read<EnrollmentProvider>().fetchEnrollmentsByProgramId(
        programId: widget.programId,
        organizationId: widget.orgId,
        status: widget.status.name,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final enrollProv = context.watch<EnrollmentProvider>();

    if (enrollProv.isLoading && enrollProv.programSpecificEnrollments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (enrollProv.error != null &&
        enrollProv.programSpecificEnrollments.isEmpty) {
      return Center(
        child: Text(
          enrollProv.error!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    // 🔥 FIXED: Accessing nested program id (e.program?.id) instead of flat key
    final members = enrollProv.programSpecificEnrollments
        .where((e) {
          final targetProgramId =
              e.program?.id ?? e.programId; // Fallback support
          final itemStatusStr = e.status.toString().toUpperCase();
          final targetStatusStr = widget.status.name.toUpperCase();

          return targetProgramId == widget.programId &&
              itemStatusStr.contains(targetStatusStr);
        })
        .map(
          (e) => MemberEnrollment(
            enrollment: e,
            user: e.user != null
                ? User(
                    id: e.user!.id ?? '',
                    name: e.user!.name?.toString() ?? 'Unknown User',
                    email: e.user!.email?.toString() ?? '',
                    role: Role.USER,
                    isActive: true,
                    createdAt: DateTime.now(),
                  )
                : null,
          ),
        )
        .toList();

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
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final memberData = members[index];
        return MemberTile(
          memberEnrollment: memberData,
          isPending: widget.status == EnrollmentStatus.PENDING,
          onApprove: widget.status == EnrollmentStatus.PENDING
              ? () async {
                  await enrollProv.updateProgramEnrollmentStatus(
                    memberData.enrollment.id,
                    UpdateEnrollmentStatusRequest(
                      status: EnrollmentStatus.ACTIVE,
                    ),
                  );
                  _fetchData();
                }
              : null,
          onDrop: () async {
            await enrollProv.updateProgramEnrollmentStatus(
              memberData.enrollment.id,
              UpdateEnrollmentStatusRequest(status: EnrollmentStatus.DROPPED),
            );
            _fetchData();
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STUDENT: Program Detail Screen
// ─────────────────────────────────────────────────────────────
class StudentProgramDetailScreen extends StatelessWidget {
  final EnrollmentProgram program;
  final String organisationId;
  const StudentProgramDetailScreen({
    super.key,
    required this.program,
    required this.organisationId,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final courses = program.programCourses.map((pc) => pc.course).toList();

    // Surface the Program Chat entry for students only when the room is enabled.
    final chat = context.watch<ChatProvider>();
    if (chat.peekedEnabled(program.id) == null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => chat.peekRoom(program.id));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            actions: [
              if (chat.peekedEnabled(program.id) == true)
                IconButton(
                  tooltip: 'Program Chat',
                  icon: const Icon(Icons.forum_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProgramChatScreen(
                        programId: program.id,
                        programName: program.name,
                      ),
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              title: Text(
                program.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: cs.onPrimary,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cs.primary, cs.primary.withValues(alpha: 0.75)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cs.onPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        program.type?.name.toUpperCase() ?? '',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: cs.onPrimary,
                        ),
                      ),
                    ),
                    if (program.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        program.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onPrimary.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
        body: courses.isEmpty
            ? const Center(child: Text('No courses in this program yet.'))
            : ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spaceLg),

                itemCount: courses.length,
                itemBuilder: (context, index) {
                  final orgProv = context.watch<OrganizationProvider>();
                  final role = orgProv.getOrgRole(organisationId);

                  logD("ROLE IS NOWWWWW ${role}");
                  final bool accessedByAdmin = role == Role.ORG_ADMIN;
                  final bool accessedByTeacher = role == Role.TEACHER;

                  final course = courses[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                    child: GestureDetector(
                      onTap: () {
                        logD("CALLED ON TAO");
                        if (accessedByAdmin || accessedByTeacher) {
                          logD(
                            "accessed by admin/teacher program_detail screen",
                          );

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CourseDetailScreen(
                                courseId: course.id,
                                courseName: course.name,
                                orgId: course.organizationId.toString(),
                              ),
                            ),
                          );
                        } else {
                          logD("acessed by student program_detail screen");
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StudentCourseDetailScreen(
                                orgId: course.organizationId.toString(),
                                courseId: course.id,
                                courseName: course.name,
                                // programName: program.name,
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: AppTheme.borderRadiusLg,
                          border: Border.all(
                            color: AppTheme.getBorder(context),
                          ),
                        ),
                        padding: const EdgeInsets.all(AppTheme.spaceMd),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.1),
                                borderRadius: AppTheme.borderRadiusMd,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spaceMd),
                            Expanded(
                              child: Text(
                                course.name,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: AppTheme.getTextSecondary(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Enroll-student picker (program-level student management)
// ─────────────────────────────────────────────────────────────
class _EnrollStudentSheet extends StatefulWidget {
  final String orgId;
  final String programId;
  const _EnrollStudentSheet({required this.orgId, required this.programId});

  @override
  State<_EnrollStudentSheet> createState() => _EnrollStudentSheetState();
}

class _EnrollStudentSheetState extends State<_EnrollStudentSheet> {
  String _query = '';
  String? _enrollingUserId;

  Future<void> _enroll(BuildContext context, String userId, String name) async {
    setState(() => _enrollingUserId = userId);
    final enrollProv = context.read<EnrollmentProvider>();
    final result = await enrollProv.enrollProgram(
      ProgramEnrollmentRequest(
        userId: userId,
        programId: widget.programId,
        status: EnrollmentStatus.ACTIVE,
      ),
    );
    if (!mounted) return;
    setState(() => _enrollingUserId = null);

    final ok = result != null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '$name enrolled — now has access to all program classes'
              : (enrollProv.error ?? 'Failed to enroll $name'),
        ),
      ),
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final orgProv = context.watch<OrganizationProvider>();

    // Only STUDENT-role org members can be enrolled as program students.
    final students = orgProv.members
        .where((m) => m.role == Role.STUDENT)
        .where((m) {
          if (_query.isEmpty) return true;
          final q = _query.toLowerCase();
          return m.user.name.toLowerCase().contains(q) ||
              m.user.email.toLowerCase().contains(q);
        })
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            const Text(
              'Enroll student in program',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search members by name or email',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: students.isEmpty
                  ? const Center(child: Text('No student members found'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: students.length,
                      itemBuilder: (context, i) {
                        final m = students[i];
                        final isEnrolling = _enrollingUserId == m.userId;
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              m.user.name.isNotEmpty
                                  ? m.user.name[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(m.user.name),
                          subtitle: Text(m.user.email),
                          trailing: isEnrolling
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : TextButton(
                                  onPressed: _enrollingUserId != null
                                      ? null
                                      : () => _enroll(
                                          context,
                                          m.userId,
                                          m.user.name,
                                        ),
                                  child: const Text('Enroll'),
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
