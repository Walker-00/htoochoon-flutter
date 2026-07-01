import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/organisation_provider.dart';
import 'package:htoochoon_flutter/Providers/auth_provider.dart';
import 'package:htoochoon_flutter/Providers/enrollment_provider.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/course_detail_screen.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/program_detail_screen.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';
import 'package:htoochoon_flutter/Widgets/user_appbar.dart';
import 'package:htoochoon_flutter/core/userorgrole_manager.dart';
import 'package:htoochoon_flutter/lms/forms/screens/lms_home_screen.dart';
// ── Demo Data ─────────────────────────────────────────────────────────────────

import 'package:htoochoon_flutter/Providers/AdminProviders/courses_provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/programs_provider.dart';
import 'package:htoochoon_flutter/models/api_models/course_model.dart';
import 'package:htoochoon_flutter/models/api_models/enrollment_model.dart';
import 'package:htoochoon_flutter/models/api_models/program_model.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

class MyLearningTab extends StatefulWidget {
  final String organisationId;
  final VoidCallback onProfileTap;
  const MyLearningTab({
    super.key,
    required this.organisationId,
    required this.onProfileTap,
  });

  @override
  State<MyLearningTab> createState() => _MyLearningTabState();
}

class _MyLearningTabState extends State<MyLearningTab> {
  // 🔄 High-level perspective modes
  String _currentViewMode = 'LEARNING'; // Can be 'LEARNING' or 'TEACHING'
  String _selected = 'Programs';
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (!mounted) return;

      final userId = UserSessionManager.userId;
      if (userId != null && !_hasInitialized) {
        _hasInitialized = true;
        _fetchAll(userId);
      }
    });
  }

  Future<void> _fetchAll(String userId) async {
    await context.read<EnrollmentProvider>().fetchCurrentUserEnrollments(
      userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enrollProv = context.watch<EnrollmentProvider>();
    final orgProv = context.watch<OrganizationProvider>(); // 🔐 Watching roles

    // ── 1. SEGREGATE ENROLLMENTS BY USER ROLE ─────────────────────────

    // Filter down to elements where user is explicitly a STUDENT
    // ── 1. SEGREGATE ENROLLMENTS BY USER ROLE (NULL-SAFE) ─────────────────

    // Filter down to elements where user is explicitly a STUDENT
    final learningPrograms = enrollProv.myProgramEnrollments
        .where((e) {
          if (e.status != EnrollmentStatus.ACTIVE) return false;

          // 🎯 FIX: Cast carefully and handle potential null nested object properties safely
          final String programOrgId =
              e.program?.organizationId?.toString() ?? '';
          final targetOrgId = programOrgId.isNotEmpty
              ? programOrgId
              : widget.organisationId;

          return orgProv.getOrgRole(targetOrgId) == Role.STUDENT;
        })
        .map((e) => e.program)
        .whereType<EnrollmentProgram>()
        .toList();

    final learningCourses = enrollProv.myCourseEnrollments
        .where((e) {
          if (e.status != EnrollmentStatus.ACTIVE) return false;

          // 🎯 FIX: Prevent unexpected null string subtype assignment exceptions
          final String courseOrgId = e.course?.organizationId?.toString() ?? '';
          final targetOrgId = courseOrgId.isNotEmpty
              ? courseOrgId
              : widget.organisationId;

          return orgProv.getOrgRole(targetOrgId) == Role.STUDENT;
        })
        .map((e) => e.course)
        .whereType<EnrollmentCourse>()
        .toList();

    // Filter down to elements where user is a TEACHER or ORG_ADMIN
    final teachingPrograms = enrollProv.myProgramEnrollments
        .where((e) {
          if (e.status != EnrollmentStatus.ACTIVE) return false;

          final String programOrgId =
              e.program?.organizationId?.toString() ?? '';
          final targetOrgId = programOrgId.isNotEmpty
              ? programOrgId
              : widget.organisationId;

          final role = orgProv.getOrgRole(targetOrgId);
          return role == Role.TEACHER || role == Role.ORG_ADMIN;
        })
        .map((e) => e.program)
        .whereType<EnrollmentProgram>()
        .toList();

    final teachingCourses = enrollProv.myCourseEnrollments
        .where((e) {
          if (e.status != EnrollmentStatus.ACTIVE) return false;

          final String courseOrgId = e.course?.organizationId?.toString() ?? '';
          final targetOrgId = courseOrgId.isNotEmpty
              ? courseOrgId
              : widget.organisationId;

          final role = orgProv.getOrgRole(targetOrgId);
          return role == Role.TEACHER || role == Role.ORG_ADMIN;
        })
        .map((e) => e.course)
        .whereType<EnrollmentCourse>()
        .toList();
    // ── 2. DYNAMICALLY CHOOSE ACTIVE DATA BUCKET ──────────────────────
    final isLearning = _currentViewMode == 'LEARNING';
    final activePrograms = isLearning ? learningPrograms : teachingPrograms;
    final activeCourses = isLearning ? learningCourses : teachingCourses;

    final isLoading = enrollProv.isLoading;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: UserAppBar(
        title: 'HtooChoon',
        showSearchIcon: true,
        leadIcon: Icons.dashboard,
        onProfileTap: widget.onProfileTap,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(
                overscroll: true,
                physics: const BouncingScrollPhysics(),
              ),
              child: RefreshIndicator(
                onRefresh: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final userId = prefs.getString("user_id");
                  await Future.wait([
                    context.read<ProgramsProvider>().fetchAllPrograms(),
                    context.read<CoursesProvider>().fetchAllCourses(),
                    if (userId != null)
                      context
                          .read<EnrollmentProvider>()
                          .fetchCurrentUserEnrollments(userId),
                  ]);
                },
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  children: [
                    Text(
                      isLearning ? 'My Learning' : 'My Teaching',
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppTheme.space2xs),
                    Text(
                      isLearning
                          ? 'Continue your educational journey and track your milestones across all enrolled tracks.'
                          : 'Manage setups, review students rosters, and track administrative instruction milestones.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.tertiary,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLg),

                    // 🎛️ STEP 1: PERSPECTIVE SWITCHER (Learning vs Teaching)
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'LEARNING',
                          label: Text('Learning Desk'),
                          icon: Icon(Icons.school_rounded, size: 16),
                        ),
                        ButtonSegment(
                          value: 'TEACHING',
                          label: Text('Teaching Desk'),
                          icon: Icon(Icons.co_present_rounded, size: 16),
                        ),
                      ],
                      selected: {_currentViewMode},
                      onSelectionChanged: (v) =>
                          setState(() => _currentViewMode = v.first),
                      style: SegmentedButton.styleFrom(
                        backgroundColor: AppTheme.getSurfaceVariant(context),
                        selectedBackgroundColor: cs.secondaryContainer,
                        selectedForegroundColor: cs.onSecondaryContainer,
                        side: BorderSide(color: AppTheme.getBorder(context)),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.borderRadiusMd,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    const Divider(height: 24),
                    const SizedBox(height: AppTheme.spaceSm),

                    // ── Sub-Category Filters (Programs vs Skill Courses) ──
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'Programs',
                          label: Text('Programs'),
                        ),
                        ButtonSegment(
                          value: 'Skill Courses',
                          label: Text('Skill Courses'),
                        ),
                      ],
                      selected: {_selected},
                      onSelectionChanged: (v) =>
                          setState(() => _selected = v.first),
                      style: SegmentedButton.styleFrom(
                        backgroundColor: AppTheme.getSurfaceVariant(context),
                        selectedBackgroundColor: cs.primary,
                        selectedForegroundColor: cs.onPrimary,
                        foregroundColor: AppTheme.getTextSecondary(context),
                        side: BorderSide(color: AppTheme.getBorder(context)),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.borderRadiusMd,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLg),

                    // ── RENDERING LAYER ───────────────────────────────────
                    if (_selected == 'Programs') ...[
                      if (activePrograms.isEmpty)
                        _EmptyEnrollmentState(
                          message: isLearning
                              ? 'No active program enrollments'
                              : 'No active teaching programs assigned',
                          subtitle: isLearning
                              ? 'Browse programs in the Courses tab and enroll to see them here.'
                              : 'When you are assigned as a teacher or admin to a program, it will appear here.',
                          icon: Icons.school_outlined,
                        )
                      else
                        ...activePrograms.map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppTheme.spaceMd,
                            ),
                            child: _ProgramCard(
                              program: p,
                              organisationId: widget.organisationId,
                            ),
                          ),
                        ),
                    ] else ...[
                      if (activeCourses.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.08),
                            borderRadius: AppTheme.borderRadiusMd,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt, size: 14, color: cs.primary),
                              const SizedBox(width: 4),
                              Text(
                                '${activeCourses.length} Active Skill Courses',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: AppTheme.spaceMd),
                      if (activeCourses.isEmpty)
                        _EmptyEnrollmentState(
                          message: isLearning
                              ? 'No active course enrollments'
                              : 'No active teaching courses assigned',
                          subtitle: isLearning
                              ? 'Browse skill courses in the Courses tab and enroll to see them here.'
                              : 'When you are added as a teacher to a standalone course layout, it will show up here.',
                          icon: Icons.menu_book_outlined,
                        )
                      else
                        ...activeCourses.map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppTheme.spaceMd,
                            ),
                            child: _SkillCourseCard(course: s),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
    );
  }
}

// ── Empty Enrollment State ────────────────────────────────
class _EmptyEnrollmentState extends StatelessWidget {
  final String message;
  final String subtitle;
  final IconData icon;

  const _EmptyEnrollmentState({
    required this.message,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space2xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: cs.outline),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cards ─────────────────────────────────────────────────────────────────────

class _ProgramCard extends StatelessWidget {
  final EnrollmentProgram program;
  final String organisationId;
  const _ProgramCard({required this.program, required this.organisationId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumb
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: AppTheme.borderRadiusSm,
                  ),
                  child: Text(
                    program.type?.name ?? '',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: AppTheme.borderRadiusSm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.apartment,
                        color: Theme.of(context).colorScheme.tertiary,
                        size: 16,
                      ),
                      Text(
                        " ${program.organizationName?.toString() ?? ''}",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXs),
                Text(
                  program.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppTheme.space2xs),
                Text(
                  program.description ?? "No description provided",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentProgramDetailScreen(
                            program: program,
                            organisationId: organisationId,
                          ),
                        ),
                      );
                    },
                    child: const Text('Open Program'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillCourseCard extends StatelessWidget {
  final EnrollmentCourse course;
  const _SkillCourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final thumbColors = const [Color(0xFFC75D30), Color(0xFFE8935A)];
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient thumb
          Stack(
            children: [
              Container(
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  gradient: LinearGradient(
                    colors: thumbColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: AppTheme.borderRadiusSm,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: const Text(
                    'STANDALONE SKILL',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: AppTheme.borderRadiusSm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.apartment,
                        color: Theme.of(context).colorScheme.tertiary,
                        size: 16,
                      ),
                      Text(
                        " ${course.organization?.name.toString() ?? ''}",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                Text(
                  course.description ?? "No description",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentCourseDetailScreen(
                            orgId: course.organizationId.toString(),
                            courseId: course.id,
                            courseName: course.name,
                            description: course.description,
                          ),
                        ),
                      );
                    },
                    child: const Text('Enter Classroom'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
