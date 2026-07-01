import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Providers/assignment_provider.dart';

/// Teacher/admin view of a single student's performance + integrity summary
/// within a class. Data comes from
/// GET /teacher/classes/{classId}/students/{studentId}/analytics.
class StudentAnalyticsScreen extends StatefulWidget {
  final String classId;
  final String studentId;
  final String? studentName;

  const StudentAnalyticsScreen({
    super.key,
    required this.classId,
    required this.studentId,
    this.studentName,
  });

  @override
  State<StudentAnalyticsScreen> createState() => _StudentAnalyticsScreenState();
}

class _StudentAnalyticsScreenState extends State<StudentAnalyticsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    final data = await context.read<AssignmentProvider>().fetchStudentAnalytics(
          classId: widget.classId,
          studentId: widget.studentId,
        );
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
      _error = data == null;
    });
  }

  int _int(dynamic v) => (v is num) ? v.round() : 0;
  int? _intOrNull(dynamic v) => (v is num) ? v.round() : null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = widget.studentName ??
        (_data?['student']?['name'] as String?) ??
        'Student';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Student progress',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(name, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error || _data == null
              ? _buildError(cs)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _buildContent(cs),
                ),
    );
  }

  Widget _buildError(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 44, color: cs.error),
          const SizedBox(height: 8),
          const Text('Could not load analytics'),
          const SizedBox(height: 8),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    final d = _data!;
    final progress = _int(d['progressRate']);
    final success = _intOrNull(d['successRate']);
    final correct = _intOrNull(d['examCorrectRate']);
    final submitted = _int(d['submittedCount']);
    final total = _int(d['totalAssessments']);
    final graded = _int(d['gradedCount']);
    final v = (d['violations'] as Map?)?.cast<String, dynamic>() ?? const {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Progress',
                value: '$progress%',
                caption: '$submitted / $total submitted',
                color: cs.primary,
                icon: Icons.timeline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Success rate',
                value: success == null ? '—' : '$success%',
                caption: '$graded graded',
                color: Colors.green,
                icon: Icons.emoji_events_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MetricCard(
          label: 'Exam correct answers',
          value: correct == null ? '—' : '$correct%',
          caption: 'Across auto/graded answers',
          color: Colors.blue,
          icon: Icons.fact_check_outlined,
          wide: true,
        ),
        const SizedBox(height: 20),
        Text('Integrity',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _IntegrityRow(
          label: 'Violations recorded',
          value: '${_int(v['totalViolations'])}',
          icon: Icons.warning_amber_rounded,
        ),
        _IntegrityRow(
          label: 'Flagged submissions',
          value: '${_int(v['flaggedCount'])}',
          icon: Icons.flag_outlined,
        ),
        _IntegrityRow(
          label: 'Forced exits (left the app)',
          value: '${_int(v['forcedExitCount'])}',
          icon: Icons.exit_to_app,
        ),
        _IntegrityRow(
          label: 'Average integrity (cheat) score',
          value: '${_int(v['avgCheatScore'])} / 100',
          icon: Icons.speed,
        ),
        _IntegrityRow(
          label: 'Highest integrity (cheat) score',
          value: '${_int(v['maxCheatScore'])} / 100',
          icon: Icons.trending_up,
        ),
        _IntegrityRow(
          label: 'Results revoked',
          value: '${_int(v['revokedCount'])}',
          icon: Icons.gpp_bad,
        ),
        const SizedBox(height: 16),
        Text(
          'Integrity scores are advisory only and never change a grade.',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String caption;
  final Color color;
  final IconData icon;
  final bool wide;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
    required this.icon,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(caption,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _IntegrityRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _IntegrityRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
