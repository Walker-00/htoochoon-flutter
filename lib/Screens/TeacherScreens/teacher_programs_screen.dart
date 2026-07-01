import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/program_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:htoochoon_flutter/Providers/structure_provider.dart';
import 'package:htoochoon_flutter/models/api_models/program_model.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:htoochoon_flutter/widgets/program_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/courses_provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/programs_provider.dart';
import 'package:provider/provider.dart';
import 'package:htoochoon_flutter/Providers/auth_provider.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';

import 'package:htoochoon_flutter/Providers/structure_provider.dart';
import 'package:htoochoon_flutter/models/api_models/program_model.dart';
import 'package:htoochoon_flutter/models/api_models/course_model.dart';

import 'package:htoochoon_flutter/Theme/themedata.dart';
// Navigate into classroom detail — adjust import to your actual screen path
// import 'package:htoochoon_flutter/Screens/ClassroomScreen/classroom_screen.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';

class TeacherProgramsScreen extends StatefulWidget {
  final String organisationId;
  final bool isInShell;
  const TeacherProgramsScreen({
    super.key,
    required this.organisationId,
    this.isInShell = false,
  });

  @override
  State<TeacherProgramsScreen> createState() => _TeacherProgramsScreenState();
}

class _TeacherProgramsScreenState extends State<TeacherProgramsScreen> {
  String _selected = 'Programs';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CoursesProvider>().fetchCoursesInOrg(
        widget.organisationId,
        null,
      );
      context.read<ProgramsProvider>().fetchProgramsInOrgId(
        widget.organisationId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final coursesProv = context.watch<CoursesProvider>();
    final programsProv = context.watch<ProgramsProvider>();

    final skillCourses = coursesProv.courses
        .where((c) => c.type == CourseType.SKILL)
        .toList();
    final programs = programsProv.programs;
    final isLoading = coursesProv.isLoading || programsProv.isLoading;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ────────────────────────────────────────
          SliverAppBar(
            automaticallyImplyLeading: !widget.isInShell,
            backgroundColor: const Color(0xFF0F7B6C),
            foregroundColor: Colors.white,
            pinned: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Learning Paths',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F7B6C), Color(0xFF13A896)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // ⚠️ No add button — teachers are read-only here
          ),

          if (isLoading)
            const SliverToBoxAdapter(child: LinearProgressIndicator()),

          if (coursesProv.error != null)
            SliverToBoxAdapter(
              child: _ErrorBanner(
                message: coursesProv.error!,
                onDismiss: coursesProv.clearError,
              ),
            ),
          if (programsProv.error != null)
            SliverToBoxAdapter(
              child: _ErrorBanner(
                message: programsProv.error!,
                onDismiss: programsProv.clearError,
              ),
            ),

          // ── Segment Toggle ─────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Programs', label: Text('Programs')),
                  ButtonSegment(
                    value: 'Skill Courses',
                    label: Text('Skill Courses'),
                  ),
                ],
                selected: {_selected},
                onSelectionChanged: (v) => setState(() => _selected = v.first),
                style: SegmentedButton.styleFrom(
                  backgroundColor: AppTheme.getSurfaceVariant(context),
                  selectedBackgroundColor: const Color(0xFF0F7B6C),
                  selectedForegroundColor: Colors.white,
                  foregroundColor: AppTheme.getTextSecondary(context),
                  side: BorderSide(color: AppTheme.getBorder(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.borderRadiusMd,
                  ),
                ),
              ),
            ),
          ),

          // ── Info banner: read-only for teachers ───────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceLg,
                0,
                AppTheme.spaceLg,
                AppTheme.spaceMd,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F7B6C).withValues(alpha: 0.08),
                  borderRadius: AppTheme.borderRadiusSm,
                  border: Border.all(
                    color: const Color(0xFF0F7B6C).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: const Color(0xFF0F7B6C),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You can view programs and courses. Contact your admin to make changes.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF0F7B6C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Content ────────────────────────────────────────
          if (_selected == 'Programs') ...[
            if (programs.isEmpty && !isLoading)
              SliverFillRemaining(
                child: _EmptyState(
                  icon: Icons.school_outlined,
                  message: 'No programs in this organisation yet.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceLg,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                      child: _TeacherProgramCard(program: programs[index]),
                    ),
                    childCount: programs.length,
                  ),
                ),
              ),
          ] else ...[
            if (skillCourses.isEmpty && !isLoading)
              SliverFillRemaining(
                child: _EmptyState(
                  icon: Icons.menu_book_outlined,
                  message: 'No skill courses in this organisation yet.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceLg,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                      child: _TeacherCourseCard(course: skillCourses[index]),
                    ),
                    childCount: skillCourses.length,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Program Card (read-only — no delete/add-course menu)
// ─────────────────────────────────────────────────────
class _TeacherProgramCard extends StatelessWidget {
  final ProgramResponse program;

  const _TeacherProgramCard({required this.program});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final courseCount = program.programCourses.length;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          Container(
            height: 80,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              color: const Color(0xFF0F7B6C).withValues(alpha: 0.12),
            ),
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                program.name.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Color(0xFF0F7B6C),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F7B6C).withValues(alpha: 0.08),
                        borderRadius: AppTheme.borderRadiusSm,
                      ),
                      child: Text(
                        program.type.name,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF0F7B6C),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$courseCount ${courseCount == 1 ? 'course' : 'courses'}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceXs),
                Text(
                  program.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (program.description != null &&
                    program.description!.isNotEmpty &&
                    program.description != 'null') ...[
                  const SizedBox(height: AppTheme.space2xs),
                  Text(
                    program.description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.getTextSecondary(context),
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.spaceMd),
                ProgramProgressBar(
                  start: program.startDate,
                  end: program.endDate,
                ),
                const SizedBox(height: AppTheme.spaceMd),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProgramDetailScreen(
                            program: program,
                            from: "TEACHER",
                          ),
                        ),
                      );
                    },
                    child: const Text('View Program'),
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

// ─────────────────────────────────────────────────────
// Skill Course Card (read-only)
// ─────────────────────────────────────────────────────
class _TeacherCourseCard extends StatelessWidget {
  final CourseResponse course;

  const _TeacherCourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final thumbColors = _courseThumbColors(course.type);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 80,
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
                if (course.description != null) ...[
                  const SizedBox(height: AppTheme.space2xs),
                  Text(
                    course.description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.getTextSecondary(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<Color> _courseThumbColors(CourseType type) {
  switch (type) {
    case CourseType.SKILL:
      return const [Color(0xFFC75D30), Color(0xFFE8935A)];
    case CourseType.ACADEMIC:
      return const [Color(0xFF1565C0), Color(0xFF42A5F5)];
    case CourseType.TEST_PREP:
      return const [Color(0xFF6A1B9A), Color(0xFFAB47BC)];
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
