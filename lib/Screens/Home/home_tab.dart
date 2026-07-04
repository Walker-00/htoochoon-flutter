import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Constants/app_colors.dart';
import 'package:htoochoon_flutter/Screens/InDevelopment/in_development_screen.dart';
import 'package:htoochoon_flutter/Constants/text_constants.dart';

import 'package:htoochoon_flutter/Providers/AdminProviders/live_sessions_provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/organisation_provider.dart';
import 'package:htoochoon_flutter/Providers/auth_provider.dart';
import 'package:htoochoon_flutter/Providers/enrollment_provider.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/classroom_detail_screen.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/program_detail_screen.dart';
import 'package:htoochoon_flutter/Screens/Helpers/calculate_progress_helper.dart';
import 'package:htoochoon_flutter/widgets/program_progress_bar.dart';
import 'package:htoochoon_flutter/Widgets/empty_state_widget.dart';
import 'package:htoochoon_flutter/Widgets/user_appbar.dart';
import 'package:htoochoon_flutter/core/userorgrole_manager.dart';
import 'package:htoochoon_flutter/core/services/streak_service.dart';
import 'package:htoochoon_flutter/models/api_models/enrollment_model.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:htoochoon_flutter/models/api_models/live_session_model.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import 'package:htoochoon_flutter/Theme/themedata.dart';
// home_tab.dart
// Refactored to match ClassesTab / CoursesTab patterns:
//  - AppTheme helpers everywhere (no hardcoded colors)
//  - colorScheme.primary replaces AppColors.buttonPrimary / primaryColor
//  - InkWell hover/ripple on all interactive cards
//  - Consistent AppTheme border, radius, spacing tokens
//  - Shimmer uses theme-aware colors for dark/light mode
//  - GestureDetector → Material + InkWell on CourseCard CTA

class HomeTab extends StatefulWidget {
  final VoidCallback onProfileTap;
  const HomeTab({super.key, required this.onProfileTap});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  @override
  void initState() {
    super.initState();
    // Home is the default tab; load the current user's real data once it mounts
    // so the activity counts, enrolled courses and upcoming live sessions are
    // populated from the backend instead of showing empty/placeholder state.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHomeData());
  }

  Future<void> _loadHomeData() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final userId = user?.id ?? UserSessionManager.userId;

    if (userId != null && userId.isNotEmpty) {
      await context
          .read<EnrollmentProvider>()
          .fetchCurrentUserEnrollments(userId);
    }
    if (!mounted) return;

    // Upcoming/live sessions are scoped to an organization the user belongs to.
    final memberships = user?.memberships;
    final orgId = (memberships != null && memberships.isNotEmpty)
        ? memberships.first.organization.id
        : null;
    if (orgId != null && orgId.isNotEmpty) {
      await context.read<LiveSessionProvider>().fetchStudentHomeSessions(orgId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    // ── Loading ─────────────────────────────────────────────────────────────
    if (authProvider.isLoading && user == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    // ── Error ────────────────────────────────────────────────────────────────
    if (user == null) {
      return Scaffold(
        body: EmptyStateWidget(
          type: EmptyStateType.error,
          title: 'Unable to load profile',
          message: 'Please check your connection and try again.',
          actionLabel: 'Retry',
          onAction: () => _loadHomeData(),
        ),
      );
    }

    // ── Main ─────────────────────────────────────────────────────────────────
    return Scaffold(
      appBar: UserAppBar(
        title: 'HtooChoon',
        showSearchIcon: true,
        leadIcon: Icons.dashboard,
        onProfileTap: widget.onProfileTap,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWeb = constraints.maxWidth > 800;

          if (isWeb) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppTheme.spaceMd),
                        child: LeftUserDashboard(),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          0,
                          AppTheme.spaceMd,
                          AppTheme.spaceMd,
                          AppTheme.spaceMd,
                        ),
                        child: const _RightDashboard(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadHomeData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: Column(
                children: const [
                  LeftUserDashboard(),
                  SizedBox(height: AppTheme.spaceLg),
                  UpcomingLiveSection(),
                  SizedBox(height: AppTheme.spaceLg),
                  EnrolledProgramsSection(),
                  SizedBox(height: AppTheme.spaceLg),
                  EnrolledCoursesSection(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Right Dashboard (web) ────────────────────────────────────────────────────

class _RightDashboard extends StatelessWidget {
  const _RightDashboard();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        UpcomingLiveSection(),
        SizedBox(height: AppTheme.spaceLg),
        EnrolledProgramsSection(),
        SizedBox(height: AppTheme.spaceLg),
        EnrolledCoursesSection(),
      ],
    );
  }
}

// ── Left Dashboard ───────────────────────────────────────────────────────────

class LeftUserDashboard extends StatelessWidget {
  const LeftUserDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.user?.name ?? 'User';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WELCOME BACK, $userName',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.tertiary,
            letterSpacing: 1.2,

            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppTheme.space2xs),
        Text(
          'Ready to Learn?',
          style: Theme.of(
            context,
          ).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppTheme.spaceLg),
        const AiMentorSuggestion(),
        const SizedBox(height: AppTheme.spaceMd),
        const ActivityBox(),
      ],
    );
  }
}

// ── AI Mentor Suggestion ─────────────────────────────────────────────────────

class AiMentorSuggestion extends StatelessWidget {
  const AiMentorSuggestion({super.key});

  /// Picks one suggestion for the day. The pool depends on the user's state
  /// (active courses / enrolled programs / nothing yet) and the exact line is
  /// chosen by the day-of-year so it rotates daily but stays stable within a
  /// day.
  String _dailySuggestion({
    required List<dynamic> activeCourses,
    required int programCount,
  }) {
    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year)).inDays;

    List<String> pool;
    if (activeCourses.isNotEmpty) {
      final name = activeCourses.first.course?.name ?? 'your course';
      final count = activeCourses.length;
      final plural = count == 1 ? '' : 's';
      pool = [
        'Pick up where you left off in "$name" — $count active course$plural in progress.',
        'A little progress each day adds up. Continue "$name" today.',
        'You have $count course$plural going. Spend 15 focused minutes on "$name".',
        'Momentum matters — jump back into "$name" and keep your streak alive.',
        'Ready for today\'s session? "$name" is waiting for you.',
      ];
    } else if (programCount > 0) {
      final plural = programCount == 1 ? '' : 's';
      pool = [
        'You are enrolled in $programCount program$plural. Open one to start a course.',
        'Your program$plural are ready — dive into a lesson and make today count.',
        'Turn enrollment into progress: open a program and begin your first course.',
        'A new day, a new chapter. Start a course from your program$plural now.',
      ];
    } else {
      pool = [
        'Explore the Courses tab and enroll to start your learning journey.',
        'Every expert was once a beginner. Browse courses and enroll today.',
        'Find something that excites you in Explore and take the first step.',
        'Your learning starts with one click — discover a course to enroll in.',
      ];
    }
    return pool[dayOfYear % pool.length];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Build a data-driven suggestion from the user's real enrollments, then
    // rotate the wording each day so the card feels fresh (deterministic within
    // a day, changes at midnight).
    final enrollProv = context.watch<EnrollmentProvider>();
    final activeCourses = enrollProv.myCourseEnrollments
        .where((e) => e.status == EnrollmentStatus.ACTIVE)
        .toList();
    final suggestion = _dailySuggestion(
      activeCourses: activeCourses,
      programCount: enrollProv.myProgramEnrollments.length,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF005B51), Color(0xFF00766A)],
        ),
        borderRadius: AppTheme.borderRadiusLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: colorScheme.onPrimary,
                size: 18,
              ),
              const SizedBox(width: AppTheme.spaceXs),
              Text(
                'AI Mentor Suggestion',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            suggestion,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          // CTA with InkWell hover
          ClipRRect(
            borderRadius: AppTheme.borderRadiusMd,
            child: Material(
              color: colorScheme.onPrimary.withValues(alpha: 0.15),
              child: InkWell(
                onTap: () => openInDevelopment(context, 'AI Mentor Suggestion'),
                splashColor: colorScheme.onPrimary.withValues(alpha: 0.15),
                highlightColor: colorScheme.onPrimary.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMd,
                    vertical: AppTheme.spaceXs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Start Review',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(width: AppTheme.spaceXs),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: colorScheme.onPrimary,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Activity Box ─────────────────────────────────────────────────────────────

class ActivityBox extends StatefulWidget {
  const ActivityBox({super.key});

  @override
  State<ActivityBox> createState() => _ActivityBoxState();
}

class _ActivityBoxState extends State<ActivityBox> {
  int? _streak;

  @override
  void initState() {
    super.initState();
    // Record today's open and read back the live streak.
    StreakService.recordAndGet().then((value) {
      if (mounted) setState(() => _streak = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Listen to the EnrollmentProvider state changes
    final enrollProv = context.watch<EnrollmentProvider>();

    // 2. Fetch lists for the active user session or default to empty lists
    final userCourses = enrollProv.myCourseEnrollments;
    final userPrograms = enrollProv.myProgramEnrollments;

    final activeCoursesCount = userCourses
        .where(
          (e) =>
              e.status == EnrollmentStatus.ACTIVE || e.status.name == 'ACTIVE',
        )
        .length;

    final activeProgramsCount = userPrograms
        .where(
          (e) =>
              e.status == EnrollmentStatus.ACTIVE || e.status.name == 'ACTIVE',
        )
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.getBorder(context), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Activity',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          // IntrinsicHeight keeps both chips the same height even if one label
          // wraps to two lines (previously the right "Programs" chip looked
          // taller / overflowed).
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StatChip(
                    icon: Icons.menu_book_rounded,
                    number: activeCoursesCount,
                    label: 'Courses in progress',
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: _StatChip(
                    icon: Icons.workspace_premium_rounded,
                    number: activeProgramsCount,
                    label: 'Programs in progress',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceSm),
            decoration: BoxDecoration(
              color: AppTheme.getSurfaceVariant(context),
              borderRadius: AppTheme.borderRadiusMd,
              border: Border.all(color: AppTheme.getBorder(context)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Learning Streak',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space2xs),
                    Text(
                      _streak == null
                          ? '— Days'
                          : '$_streak ${_streak == 1 ? 'Day' : 'Days'}',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.local_fire_department_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final int number;
  final String label;

  const _StatChip({
    required this.icon,
    required this.number,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceSm),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceVariant(context),
        borderRadius: AppTheme.borderRadiusMd,
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                '$number',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space2xs),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Upcoming Live Section ────────────────────────────────────────────────────
class UpcomingLiveSection extends StatefulWidget {
  const UpcomingLiveSection({super.key});

  @override
  State<UpcomingLiveSection> createState() => _UpcomingLiveSectionState();
}

class _UpcomingLiveSectionState extends State<UpcomingLiveSection> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final sessionProv = context.watch<LiveSessionProvider>();
    final sessions = sessionProv.homeUpcomingSessions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming & Live',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppTheme.spaceMd),

        if (sessionProv.isLoadingHome)
          const _LiveSessionShimmer()
        else if (sessions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: AppTheme.borderRadiusLg,
              border: Border.all(color: AppTheme.getBorder(context)),
            ),
            child: Text(
              'No upcoming sessions right now',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.getTextSecondary(context),
              ),
            ),
          )
        else
          ...sessions.map((s) => _LiveSessionCard(session: s)),
      ],
    );
  }
}

class _LiveSessionCard extends StatelessWidget {
  final LiveSession session;
  const _LiveSessionCard({required this.session});

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final label = day == today
        ? 'Today'
        : day == today.add(const Duration(days: 1))
        ? 'Tomorrow'
        : '${dt.day}/${dt.month}';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$label • $h:$m';
  }

  // Build ClassroomArgs from the session's nested liveClass
  ClassroomArgs? _buildArgs() {
    final c = session.liveClass;
    if (c == null || c.id == null) return null;

    return ClassroomArgs(
      orgId: c.organizationId ?? '',
      courseId: c.courseId ?? '',
      courseName: c.course?.name ?? 'Class',
      courseCode: c.id!.substring(0, 4).toUpperCase(),
      description: 'Class: ${c.name ?? ''}',
      entryPoint: ClassEntryPoint.direct,
      classId: c.id!,
      className: c.name ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLive = session.status == LiveSessionStatus.live;
    final args = _buildArgs();

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(
          color: isLive
              ? Colors.red.withValues(alpha: 0.4)
              : AppTheme.getBorder(context),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: args == null
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClassroomScreen(args: args),
                  ),
                ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Row(
              children: [
                // Status dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isLive ? Colors.red : cs.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.topic,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space2xs),
                      Text(
                        _formatTime(session.startTime),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.getTextSecondary(context),
                        ),
                      ),
                      if (session.liveClass?.name != null)
                        Text(
                          session.liveClass!.name!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.getTextSecondary(context),
                              ),
                        ),
                    ],
                  ),
                ),

                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceSm,
                    vertical: AppTheme.spaceXs,
                  ),
                  decoration: BoxDecoration(
                    color: isLive ? Colors.red : cs.primary.withValues(alpha: 0.12),
                    borderRadius: AppTheme.borderRadiusMd,
                  ),
                  child: Text(
                    isLive ? 'Live Now' : 'Scheduled',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isLive ? Colors.white : cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// class UpcomingLiveSection extends StatelessWidget {
//   final bool isLoading;
//   final List<Map<String, String>> liveList;
//
//   const UpcomingLiveSection({
//     super.key,
//     this.isLoading = false,
//     this.liveList = const [
//       {'title': 'Physics Live Class', 'time': 'Today • 6 PM'},
//       {'title': 'Math Revision', 'time': 'Tomorrow • 4 PM'},
//     ],
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Upcoming & Live',
//           style: Theme.of(
//             context,
//           ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
//         ),
//         const SizedBox(height: AppTheme.spaceMd),
//         if (isLoading)
//           const _LiveSessionShimmer()
//         else
//           ...liveList.map(
//             (item) => _LiveCard(title: item['title']!, time: item['time']!),
//           ),
//       ],
//     );
//   }
// }

class _LiveSessionShimmer extends StatelessWidget {
  const _LiveSessionShimmer();

  @override
  Widget build(BuildContext context) {
    // Theme-aware shimmer colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlight = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Column(
        children: List.generate(
          3,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: AppTheme.borderRadiusLg,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 150, height: 14, color: Colors.white),
                    const SizedBox(height: 6),
                    Container(width: 100, height: 12, color: Colors.white),
                  ],
                ),
                Container(
                  width: 72,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppTheme.borderRadiusMd,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  final String title;
  final String time;

  const _LiveCard({required this.title, required this.time});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.getBorder(context), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          splashColor: colorScheme.primary.withValues(alpha: 0.08),
          highlightColor: colorScheme.primary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Live indicator dot + info
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: AppTheme.space2xs),
                        Text(
                          time,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.getTextSecondary(context),
                              ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Join Now button
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceSm,
                    vertical: AppTheme.spaceXs,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: AppTheme.borderRadiusMd,
                  ),
                  child: Text(
                    'Join Now',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Enrolled Programs Section ────────────────────────────────────────────────

/// Renders the current user's program enrollments on Home. Mirrors the course
/// section but is keyed off `myProgramEnrollments`. Programs have no cover
/// image, so each card uses a deterministic gradient + the program name/type
/// for visual identity, plus the cohort progress bar when dates are present.
class EnrolledProgramsSection extends StatelessWidget {
  const EnrolledProgramsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final enrollProv = context.watch<EnrollmentProvider>();
    // These come from /enrollment/programs/user/{id} — i.e. the user's OWN
    // enrollments — so we render all of them rather than re-filtering by role.
    final programs = enrollProv.myProgramEnrollments
        .where((e) => e.program != null)
        .toList();

    // Nothing to show and no spinner running → render nothing (keeps Home clean
    // for course-only learners).
    if (!enrollProv.isLoading && programs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enrolled Programs',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        if (enrollProv.isLoading && programs.isEmpty)
          const _EnrolledCoursesShimmer()
        else
          ...programs.map((e) => _EnrolledProgramCard(enrollment: e)),
      ],
    );
  }
}

// Deterministic two-stop gradient for a program header (no cover image).
List<Color> _programHeaderColors(String seed) {
  const palettes = <List<Color>>[
    [Color(0xFF0B6E74), Color(0xFF1AA179)], // peacock teal → emerald
    [Color(0xFF1A73E8), Color(0xFF66A2FF)],
    [Color(0xFF8E24AA), Color(0xFFBA68C8)],
    [Color(0xFF00ACC1), Color(0xFF4DD0E1)],
    [Color(0xFFE91E63), Color(0xFFF06292)],
    [Color(0xFF11998E), Color(0xFF38EF7D)],
    [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
    [Color(0xFF37474F), Color(0xFF78909C)],
  ];
  return palettes[seed.hashCode.abs() % palettes.length];
}

class _EnrolledProgramCard extends StatelessWidget {
  final Enrollment enrollment;
  const _EnrolledProgramCard({required this.enrollment});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final program = enrollment.program!;
    final orgName =
        program.organizationName ?? enrollment.organizationName ?? 'Program';
    final colors = _programHeaderColors(program.id);
    final isActive = enrollment.status.name == 'ACTIVE';

    void openDetail() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudentProgramDetailScreen(
            program: program,
            organisationId: program.organizationId ?? '',
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.getBorder(context), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: openDetail,
          splashColor: cs.primary.withValues(alpha: 0.08),
          highlightColor: cs.primary.withValues(alpha: 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Color header with program name (no cover image for programs).
              Container(
                height: 120,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.layers_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(height: AppTheme.spaceXs),
                      Text(
                        program.name.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (program.type != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.08),
                          borderRadius: AppTheme.borderRadiusSm,
                        ),
                        child: Text(
                          program.type!.name,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                        ),
                      ),
                    const SizedBox(height: AppTheme.spaceXs),
                    Text(
                      program.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    // Cohort progress — self-hides when the program has no dates.
                    ProgramProgressBar(
                      start: program.startDate,
                      end: program.endDate,
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    Text(
                      'Hosted by $orgName',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.tertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (isActive ? Colors.green : Colors.orange)
                                .withValues(alpha: 0.1),
                            borderRadius: AppTheme.borderRadiusSm,
                          ),
                          child: Text(
                            enrollment.status.name,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isActive ? Colors.green : Colors.orange,
                            ),
                          ),
                        ),
                        Text(
                          '${program.programCourses.length} course'
                          '${program.programCourses.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    ClipRRect(
                      borderRadius: AppTheme.borderRadiusMd,
                      child: Material(
                        color: cs.primary,
                        child: InkWell(
                          onTap: openDetail,
                          splashColor: Colors.white.withValues(alpha: 0.15),
                          highlightColor: Colors.white.withValues(alpha: 0.08),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spaceSm,
                              horizontal: AppTheme.spaceMd,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Open Program',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: cs.onPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(width: AppTheme.spaceXs),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: cs.onPrimary,
                                  size: 16,
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
            ],
          ),
        ),
      ),
    );
  }
}

// ── Enrolled Courses Section ─────────────────────────────────────────────────

class _EnrolledCoursesShimmer extends StatelessWidget {
  const _EnrolledCoursesShimmer();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlight = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Column(
        children: List.generate(
          2,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: AppTheme.borderRadiusLg,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  color: Colors.white,
                ),
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 120, height: 14, color: Colors.white),
                      const SizedBox(height: AppTheme.spaceSm),
                      Container(
                        height: 6,
                        width: double.infinity,
                        color: Colors.white,
                      ),
                      const SizedBox(height: AppTheme.spaceXs),
                      Container(width: 80, height: 12, color: Colors.white),
                      const SizedBox(height: AppTheme.spaceMd),
                      Container(
                        height: 40,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: AppTheme.borderRadiusMd,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EnrolledCoursesSection extends StatelessWidget {
  const EnrolledCoursesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final enrollProv = context.watch<EnrollmentProvider>();
    final courses = enrollProv.myCourseEnrollments;
    final enrollments = enrollProv.courseEnrollments;
    final orgProv = context.watch<OrganizationProvider>();

    final studentEnrollments = enrollments.where((e) {
      final orgId = e.course?.organizationId ?? '';
      final role = orgProv.getOrgRole(orgId);
      return role == Role.STUDENT;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enrolled Courses',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppTheme.spaceMd),

        if (enrollProv.isLoading)
          const _EnrolledCoursesShimmer()
        else if (studentEnrollments.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                'No Enrolled Course yet.. Enroll a course in "My Learning" to start learning!',
              ),
            ),
          )
        else if (courses.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: AppTheme.borderRadiusLg,
              border: Border.all(color: AppTheme.getBorder(context)),
            ),
            child: Text(
              'You are not enrolled in any active courses yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.getTextSecondary(context),
              ),
            ),
          )
        else
          ...courses.map(
            (enrollment) => _RealEnrolledCourseCard(enrollment: enrollment),
          ),
      ],
    );
  }
}

// ── Production Card Connected to Real Data Models ────────────────────────────
class _RealEnrolledCourseCard extends StatelessWidget {
  final Enrollment enrollment;
  const _RealEnrolledCourseCard({required this.enrollment});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final course = enrollment.course;
    final organizationId = course?.organizationId ?? '';
    final orgProv = context.watch<OrganizationProvider>();
    final userRole = orgProv.getOrgRole(organizationId);

    if (userRole == Role.ORG_ADMIN || userRole == Role.TEACHER) {
      return const SizedBox.shrink();
    }
    // Safety Fallback context handling blocks if API maps drop optional payload strings
    final title = course?.name ?? 'Untitled Course';
    final orgName =
        enrollment.organizationName ??
        course?.organization?.name ??
        'Digital Learning Hub';
    final targetClass = enrollment.enrollmentClass;
    final progress = calculateTimeProgress(
      targetClass?.startDate,
      targetClass?.endDate,
    );
    // Assign structural fallback asset image patterns if model has empty path variables
    const fallbackImage =
        'https://images.unsplash.com/photo-1635070041078-e363dbe005cb';

    // Build the cross-navigation argument configurations targeting Classroom layout structures
    ClassroomArgs? _buildArgs() {
      if (enrollment.classId == null || enrollment.courseId == null)
        return null;
      return ClassroomArgs(
        orgId: course?.organizationId ?? '',
        courseId: enrollment.courseId!,
        courseName: title,
        courseCode: enrollment.classId!.substring(0, 4).toUpperCase(),
        description: course?.description ?? '',
        entryPoint: ClassEntryPoint.direct,
        classId: enrollment.classId!,
        className: enrollment.enrollmentClass?.name ?? 'Active Room',
      );
    }

    final args = _buildArgs();

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.getBorder(context), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: args == null
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClassroomScreen(args: args),
                    ),
                  );
                },
          splashColor: colorScheme.primary.withValues(alpha: 0.08),
          highlightColor: colorScheme.primary.withValues(alpha: 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Thumbnail Display Port
              SizedBox(
                height: 140,
                width: double.infinity,
                child: Image.network(
                  fallbackImage,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: colorScheme.primaryContainer,
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: colorScheme.primary,
                      size: 48,
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: AppTheme.space2xs),
                    ClipRRect(
                      borderRadius: AppTheme.borderRadiusSm,
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: AppTheme.getSurfaceVariant(context),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress < 0.2 ? Colors.orange : colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceXs),

                    Text(
                      '${(progress * 100).toInt()}% through timeline',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    Text(
                      'Hosted by $orgName',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.tertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),

                    // Status Badge Label Configuration Mapping
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: enrollment.status.name == "ACTIVE"
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: AppTheme.borderRadiusSm,
                          ),
                          child: Text(
                            enrollment.status.name,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: enrollment.status.name == "ACTIVE"
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ),
                        if (enrollment.enrollmentClass?.name != null)
                          Text(
                            'Class: ${enrollment.enrollmentClass!.name}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppTheme.getTextSecondary(context),
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    // Navigation Action Redirect Trigger Button
                    if (args != null)
                      ClipRRect(
                        borderRadius: AppTheme.borderRadiusMd,
                        child: Material(
                          color: colorScheme.primary,
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ClassroomScreen(args: args),
                                ),
                              );
                            },
                            splashColor: Colors.white.withValues(alpha: 0.15),
                            highlightColor: Colors.white.withValues(alpha: 0.08),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppTheme.spaceSm,
                                horizontal: AppTheme.spaceMd,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Enter Classroom',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: colorScheme.onPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(width: AppTheme.spaceXs),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: colorScheme.onPrimary,
                                    size: 16,
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
            ],
          ),
        ),
      ),
    );
  }
}
