import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/courses_provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/programs_provider.dart';
import 'package:provider/provider.dart';
import 'package:htoochoon_flutter/Providers/auth_provider.dart';

import 'package:htoochoon_flutter/Providers/structure_provider.dart';
import 'package:htoochoon_flutter/models/api_models/program_model.dart';
import 'package:htoochoon_flutter/models/api_models/course_model.dart';
import 'package:htoochoon_flutter/models/api_models/class_model.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/class_provider.dart';
import 'package:provider/provider.dart';
import 'package:htoochoon_flutter/Providers/structure_provider.dart';
import 'package:htoochoon_flutter/models/api_models/class_model.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/instructor_analytics_screen.dart';
import 'package:htoochoon_flutter/api/api_service.dart';
import 'package:htoochoon_flutter/models/api_models/teacher_stats_model.dart';
// Navigate into classroom detail — adjust import to your actual screen path
// import 'package:htoochoon_flutter/Screens/ClassroomScreen/classroom_screen.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';

class TeacherDashboardScreen extends StatefulWidget {
  final String organisationId;
  final String teacherId;
  final bool isInShell;
  const TeacherDashboardScreen({
    super.key,
    required this.organisationId,
    required this.teacherId,
    this.isInShell = false,
  });

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  bool _loading = false;
  String? _error;
  List<ClassModel> _myClasses = [];
  List<ProgramResponse> _programs = [];

  // Headline stats from GET /teacher/me/stats. studentCount is DISTINCT active
  // enrollees across the teacher's programs (deduped), not a sum of class caps.
  int? _statClasses;
  int? _statPrograms;
  int? _statStudents;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context
          .read<CoursesProvider>(); // piggyback on existing providers
      // Fetch all classes then filter by teacherId
      final classProv = context.read<ClassProvider>();
      await classProv.fetchClasses(null, null, null);

      final programsProv = context.read<ProgramsProvider>();
      await programsProv.fetchProgramsInOrgId(widget.organisationId);

      // Authoritative headline numbers (deduped student count) from the backend.
      TeacherStats? stats;
      try {
        stats = await context.read<ApiService>().getTeacherStats();
      } catch (_) {
        // Non-fatal: fall back to locally computed values below.
      }

      if (mounted) {
        setState(() {
          _myClasses = classProv.classes
              .where((c) => c.teacherId == widget.teacherId)
              .toList();
          _programs = programsProv.programs;
          _statClasses = stats?.classCount;
          _statPrograms = stats?.programCount;
          _statStudents = stats?.studentCount;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final authProv = context.watch<AuthProvider>();
    final teacherName = authProv.user?.name ?? 'Teacher';

    return Scaffold(
      backgroundColor: cs.surface,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──────────────────────────────────────
            SliverAppBar(
              automaticallyImplyLeading: !widget.isInShell,
              backgroundColor: const Color(0xFF0F7B6C),
              foregroundColor: Colors.white,
              pinned: true,
              expandedHeight: 140,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      teacherName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
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
              actions: [
                IconButton(
                  tooltip: 'My teaching analytics',
                  icon: const Icon(Icons.insights_rounded),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InstructorAnalyticsScreen(
                        teacherId: '',
                        teacherName: teacherName,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_loading)
              const SliverToBoxAdapter(child: LinearProgressIndicator()),

            if (_error != null)
              SliverToBoxAdapter(
                child: _ErrorBanner(
                  message: _error!,
                  onDismiss: () => setState(() => _error = null),
                ),
              ),

            // ── Stats Row ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceLg),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.class_rounded,
                        label: 'My Classes',
                        value: (_statClasses ?? _myClasses.length).toString(),
                        color: const Color(0xFF0F7B6C),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.school_rounded,
                        label: 'My Programs',
                        value: (_statPrograms ?? _programs.length).toString(),
                        color: const Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.people_alt_rounded,
                        label: 'Students',
                        // Distinct enrolled students across the teacher's
                        // programs (deduped server-side). Shows "—" until loaded
                        // rather than a misleading sum of class capacities.
                        value: _statStudents?.toString() ?? '—',
                        color: const Color(0xFF6A1B9A),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── My Classes Section ───────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceLg,
                  0,
                  AppTheme.spaceLg,
                  AppTheme.spaceSm,
                ),
                child: Text(
                  'My Classes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            if (_myClasses.isEmpty && !_loading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceLg,
                  ),
                  child: _EmptyCard(
                    icon: Icons.class_outlined,
                    message: 'No classes assigned to you yet.',
                  ),
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
                      child: _ClassTile(classModel: _myClasses[index]),
                    ),
                    childCount: _myClasses.length,
                  ),
                ),
              ),

            // ── Programs Section ─────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceLg,
                  AppTheme.spaceLg,
                  AppTheme.spaceLg,
                  AppTheme.spaceSm,
                ),
                child: Text(
                  'Organisation Programs',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            if (_programs.isEmpty && !_loading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceLg,
                  ),
                  child: _EmptyCard(
                    icon: Icons.school_outlined,
                    message: 'No programs in this organisation.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceLg,
                  0,
                  AppTheme.spaceLg,
                  AppTheme.spaceLg,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                      child: _ProgramTile(program: _programs[index]),
                    ),
                    childCount: _programs.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// WIDGETS
// ─────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppTheme.borderRadiusMd,
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassTile extends StatelessWidget {
  final ClassModel classModel;

  const _ClassTile({required this.classModel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();

    final isActive =
        (classModel.startDate?.isBefore(now) ?? false) &&
        (classModel.endDate?.isAfter(now) ?? false);

    final isUpcoming = classModel.startDate?.isAfter(now) ?? false;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0F7B6C).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.class_rounded,
              color: Color(0xFF0F7B6C),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classModel.name.toString(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  classModel.course?.name ?? 'Unknown Course',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${classModel.maxStudents} max students',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.green.withValues(alpha: 0.1)
                  : isUpcoming
                  ? Colors.orange.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isActive
                  ? 'Active'
                  : isUpcoming
                  ? 'Upcoming'
                  : 'Ended',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? Colors.green[700]
                    : isUpcoming
                    ? Colors.orange[700]
                    : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramTile extends StatelessWidget {
  final ProgramResponse program;

  const _ProgramTile({required this.program});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.school_rounded, color: cs.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  program.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (program.description != null &&
                    program.description!.isNotEmpty &&
                    program.description != 'null')
                  Text(
                    program.description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.getTextSecondary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              program.type.name,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: cs.primary,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceVariant(context),
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: AppTheme.getTextSecondary(context)),
          const SizedBox(width: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.getTextSecondary(context),
            ),
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
