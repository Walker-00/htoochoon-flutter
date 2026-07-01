import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/live_sessions_provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/subscription_provider.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/student_overview_screen.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/instructor_analytics_screen.dart';
import 'package:htoochoon_flutter/Widgets/responsive.dart';
import 'package:htoochoon_flutter/Widgets/stat_card.dart';
import 'package:htoochoon_flutter/api/api_service.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:htoochoon_flutter/models/api_models/live_session_model.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  final String organisationId;
  final bool isInShell;

  const DashboardScreen({
    super.key,
    required this.organisationId,
    this.isInShell = false,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _analytics;
  bool _analyticsLoading = true;
  bool _analyticsError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().loadForOrg(widget.organisationId);
      _loadAnalytics();
    });
  }

  Future<void> _loadAnalytics() async {
    if (mounted) setState(() => _analyticsLoading = true);
    try {
      final res =
          await context.read<ApiService>().getOrgAnalytics(widget.organisationId);
      if (!mounted) return;
      setState(() {
        _analytics = res is Map ? Map<String, dynamic>.from(res) : null;
        _analyticsError = _analytics == null;
        _analyticsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _analyticsError = true;
        _analyticsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Consumer<LiveSessionProvider>(
        builder: (context, liveSessionsProvider, child) {
          return RefreshIndicator(
            onRefresh: _loadAnalytics,
            child: _DashboardBody(
              orgId: widget.organisationId,
              analytics: _analytics,
              analyticsLoading: _analyticsLoading,
              analyticsError: _analyticsError,
              onRetry: _loadAnalytics,
              liveSessionsProvider: liveSessionsProvider,
              isInShell: widget.isInShell,
            ),
          );
        },
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final String orgId;
  final Map<String, dynamic>? analytics;
  final bool analyticsLoading;
  final bool analyticsError;
  final VoidCallback onRetry;
  final LiveSessionProvider liveSessionsProvider;
  final bool isInShell;

  const _DashboardBody({
    required this.orgId,
    required this.analytics,
    required this.analyticsLoading,
    required this.analyticsError,
    required this.onRetry,
    required this.liveSessionsProvider,
    required this.isInShell,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          automaticallyImplyLeading: !isInShell,
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          surfaceTintColor: Colors.transparent,
          pinned: true,
          title: Text(
            'Overview',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: cs.onSurface,
            ),
          ),
        ),

        SliverPadding(
          padding: centeredPagePadding(context),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── Org analytics ─────────────────────────
              if (analyticsLoading && analytics == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (analyticsError || analytics == null)
                _EmptyCard(
                  icon: Icons.bar_chart_rounded,
                  message: 'Analytics unavailable. Pull to refresh.',
                )
              else
                _OrgAnalytics(orgId: orgId, data: analytics!),

              const SizedBox(height: 24),

              // ── Upcoming sessions ─────────────────────
              Text(
                'Upcoming Live Sessions',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (liveSessionsProvider.upcomingSessions.isEmpty)
                _EmptyCard(
                  icon: Icons.videocam_off_rounded,
                  message: 'No upcoming sessions',
                )
              else
                ...liveSessionsProvider.upcomingSessions
                    .take(5)
                    .map((s) => _SessionCard(session: s)),

              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }
}

// ── Org analytics dashboard ──────────────────────────
class _OrgAnalytics extends StatelessWidget {
  final String orgId;
  final Map<String, dynamic> data;
  const _OrgAnalytics({required this.orgId, required this.data});

  Map<String, dynamic> _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : const {};
  List<Map<String, dynamic>> _list(dynamic v) => v is List
      ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];
  String _pct(dynamic v) => v is num ? '${v.round()}%' : '—';
  String _num(dynamic v) => v is num ? '${v.round()}' : '0';

  @override
  Widget build(BuildContext context) {
    final enrollment = _map(data['enrollment']);
    final performance = _map(data['performance']);
    final atRisk = _map(data['atRisk']);
    final courses = _map(data['courses']);
    final instructors = _list(data['instructors']);
    final trends = _map(data['trends']);

    final screenW = MediaQuery.of(context).size.width;
    final crossCount = screenW > 900 ? 4 : (screenW > 500 ? 3 : 2);

    final heroKpis = <AnimatedStatCard>[
      AnimatedStatCard(label: 'Students', value: _num(enrollment['totalStudents']), icon: Icons.people_rounded, color: const Color(0xFF4F46E5), index: 0),
      AnimatedStatCard(label: 'Active (14d)', value: _num(enrollment['activeStudents']), icon: Icons.bolt_rounded, color: const Color(0xFF16A34A), index: 1),
      AnimatedStatCard(label: 'Teachers', value: _num(enrollment['totalTeachers']), icon: Icons.school_rounded, color: const Color(0xFF0D9488), index: 2),
      AnimatedStatCard(label: 'New (30d)', value: _num(enrollment['newEnrollments']), icon: Icons.person_add_rounded, color: const Color(0xFF2563EB), index: 3),
    ];

    final perfKpis = <AnimatedStatCard>[
      AnimatedStatCard(label: 'Avg grade', value: _pct(performance['avgGrade']), icon: Icons.grade_rounded, color: const Color(0xFF7C3AED), index: 0),
      AnimatedStatCard(label: 'Attendance', value: _pct(performance['avgAttendanceRate']), icon: Icons.event_available_rounded, color: const Color(0xFFEA580C), index: 1),
      AnimatedStatCard(label: 'Exam pass', value: _pct(performance['examPassRate']), icon: Icons.workspace_premium_rounded, color: const Color(0xFF16A34A), index: 2),
      AnimatedStatCard(label: 'Submission', value: _pct(performance['assignmentSubmissionRate']), icon: Icons.upload_file_rounded, color: const Color(0xFF0891B2), index: 3),
      AnimatedStatCard(label: 'Engagement', value: _pct(performance['avgEngagement']), icon: Icons.local_fire_department_rounded, color: const Color(0xFFE11D48), index: 4),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'People', Icons.groups_rounded, const Color(0xFF4F46E5)),
        const SizedBox(height: 10),
        StatCardGrid(cards: heroKpis, crossAxisCount: crossCount),
        const SizedBox(height: 20),
        _sectionTitle(context, 'Performance', Icons.insights_rounded, const Color(0xFF7C3AED)),
        const SizedBox(height: 10),
        StatCardGrid(cards: perfKpis, crossAxisCount: crossCount),
        const SizedBox(height: 24),

        if (_list(atRisk['students']).isNotEmpty || (atRisk['highCount'] is num && (atRisk['highCount'] as num) > 0)) ...[
          _sectionTitle(context, 'At-risk students', Icons.warning_amber_rounded, const Color(0xFFE11D48)),
          const SizedBox(height: 4),
          Text(
            '${_num(atRisk['highCount'])} high · ${_num(atRisk['mediumCount'])} medium risk',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          ..._list(atRisk['students']).take(5).map((s) => _RiskTile(orgId: orgId, student: s)),
          const SizedBox(height: 24),
        ],

        if (_list(trends['enrollments']).isNotEmpty) ...[
          _sectionTitle(context, 'Enrollment trend', Icons.trending_up_rounded, const Color(0xFF2563EB)),
          const SizedBox(height: 12),
          _TrendChart(points: _list(trends['enrollments'])),
          const SizedBox(height: 24),
        ],

        if (_list(courses['top']).isNotEmpty) ...[
          _sectionTitle(context, 'Top courses', Icons.menu_book_rounded, const Color(0xFF0D9488)),
          const SizedBox(height: 10),
          ..._list(courses['top']).take(5).map((c) => _CourseTile(course: c)),
          const SizedBox(height: 24),
        ],

        if (instructors.isNotEmpty) ...[
          _sectionTitle(context, 'Instructors', Icons.co_present_rounded, const Color(0xFF7C3AED)),
          const SizedBox(height: 10),
          ...instructors.take(5).map((t) => _InstructorTile(orgId: orgId, instructor: t)),
        ],

        if (_list(courses['top']).isEmpty && instructors.isEmpty && _list(atRisk['students']).isEmpty)
          _EmptyCard(icon: Icons.analytics_rounded, message: 'More analytics will appear as data accumulates'),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String t, IconData icon,
      [Color? color]) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: c),
        ),
        const SizedBox(width: 9),
        Text(t, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _RiskTile extends StatelessWidget {
  final String orgId;
  final Map<String, dynamic> student;
  const _RiskTile({required this.orgId, required this.student});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final band = (student['riskBand'] ?? '').toString();
    final score = student['riskScore'];
    final (color, label) = switch (band) {
      'HIGH' => (Colors.red, 'High'),
      'MEDIUM' => (Colors.orange, 'Medium'),
      _ => (Colors.green, 'Low'),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentOverviewScreen(
              organizationId: orgId,
              studentId: (student['id'] ?? '').toString(),
              studentName: student['name']?.toString(),
            ),
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(Icons.warning_amber_rounded, color: color, size: 18),
        ),
        title: Text(student['name']?.toString() ?? 'Student',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          'Attendance ${student['attendanceRate'] ?? '—'}% · Submission ${student['submissionRate'] ?? '—'}%',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$label${score is num ? ' · ${score.round()}' : ''}',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
        ),
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  final Map<String, dynamic> course;
  const _CourseTile({required this.course});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final completion = course['completionRate'];
    final pct = completion is num ? completion.toDouble() : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(course['name']?.toString() ?? 'Course',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Text(completion is num ? '${completion.round()}%' : '—',
                  style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: cs.outline.withValues(alpha: 0.15),
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${course['enrollment'] ?? 0} students · avg ${course['avgScore'] ?? '—'}%',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _InstructorTile extends StatelessWidget {
  final String orgId;
  final Map<String, dynamic> instructor;
  const _InstructorTile({required this.orgId, required this.instructor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InstructorAnalyticsScreen(
              teacherId: (instructor['id'] ?? '').toString(),
              organizationId: orgId,
              teacherName: instructor['name']?.toString(),
            ),
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: cs.primary.withValues(alpha: 0.12),
          child: Icon(Icons.person_rounded, color: cs.primary, size: 18),
        ),
        title: Text(instructor['name']?.toString() ?? 'Instructor',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          '${instructor['courses'] ?? 0} courses · ${instructor['sessionsConducted'] ?? 0} sessions',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(instructor['avgCompletion'] is num ? '${(instructor['avgCompletion'] as num).round()}%' : '—',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            Text('completion', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> points;
  const _TrendChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final values = points.map((p) => (p['value'] is num ? (p['value'] as num).toDouble() : 0.0)).toList();
    final maxY = (values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b));
    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(8, 16, 12, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY <= 0 ? 1 : maxY * 1.2,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= points.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(points[i]['label']?.toString() ?? '',
                        style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: values[i],
                  color: cs.primary,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

// ── Session card ─────────────────────────────────────
class _SessionCard extends StatelessWidget {
  final LiveSession session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLive = session.status == LiveSessionStatus.live;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLive
              ? Colors.green.withValues(alpha: 0.4)
              : cs.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isLive
                  ? Colors.green.withValues(alpha: 0.1)
                  : cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.videocam_rounded,
              color: isLive ? Colors.green : cs.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              session.topic,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isLive
                  ? Colors.green.withValues(alpha: 0.1)
                  : cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isLive ? 'LIVE' : session.status.name.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isLive ? Colors.green : cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ───────────────────────────────────
class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(message, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        ],
      ),
    );
  }
}

