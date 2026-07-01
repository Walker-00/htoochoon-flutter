import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Widgets/responsive.dart';
import '../../Widgets/stat_card.dart';
import '../../api/api_service.dart';

/// 📚 Per-course analytics for staff: completion/dropout, average score, material
/// engagement, exam analytics (high/low/avg/median/pass + distribution) and
/// per-question correct/skip rates.
/// Data: GET /teacher/courses/{courseId}/analytics.
class CourseAnalyticsScreen extends StatefulWidget {
  final String courseId;
  final String? courseName;

  const CourseAnalyticsScreen({super.key, required this.courseId, this.courseName});

  @override
  State<CourseAnalyticsScreen> createState() => _CourseAnalyticsScreenState();
}

class _CourseAnalyticsScreenState extends State<CourseAnalyticsScreen> {
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
    try {
      final res = await context.read<ApiService>().getCourseAnalytics(widget.courseId);
      if (!mounted) return;
      setState(() {
        _data = res is Map ? Map<String, dynamic>.from(res) : null;
        _error = _data == null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : const {};
  List<Map<String, dynamic>> _list(dynamic v) => v is List
      ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];
  String _pct(dynamic v) => v is num ? '${v.round()}%' : '—';
  String _num(dynamic v) => v is num ? '${v.round()}' : '0';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Course analytics',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (widget.courseName != null)
              Text(widget.courseName!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error || _data == null
              ? Center(
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
                )
              : RefreshIndicator(onRefresh: _load, child: _content(cs)),
    );
  }

  Widget _content(ColorScheme cs) {
    final d = _data!;
    final exam = _map(d['examAnalytics']);
    final materials = _map(d['materials']);
    final questions = _list(d['questionAnalytics']);

    return ListView(
      padding: centeredPagePadding(context, max: 720),
      children: [
        StatCardGrid(
          crossAxisCount: MediaQuery.of(context).size.width > 540 ? 3 : 2,
          cards: [
            AnimatedStatCard(label: 'Enrollment', value: _num(d['enrollment']), icon: Icons.people_rounded, color: const Color(0xFF4F46E5), index: 0),
            AnimatedStatCard(label: 'Completion', value: _pct(d['completionRate']), icon: Icons.task_alt_rounded, color: const Color(0xFF16A34A), index: 1),
            AnimatedStatCard(label: 'Avg score', value: _pct(d['avgScore']), icon: Icons.grade_rounded, color: const Color(0xFF7C3AED), index: 2),
            AnimatedStatCard(label: 'Dropouts', value: _num(d['dropoutCount']), icon: Icons.person_off_rounded, color: const Color(0xFFE11D48), index: 3),
            AnimatedStatCard(label: 'Materials viewed', value: _pct(materials['viewRate']), icon: Icons.menu_book_rounded, color: const Color(0xFF0D9488), index: 4),
            AnimatedStatCard(label: 'Exam pass', value: _pct(exam['passRate']), icon: Icons.workspace_premium_rounded, color: const Color(0xFFEA580C), index: 5),
          ],
        ),
        const SizedBox(height: 24),

        // ── Exam analytics ──
        Text('Exam analytics',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if ((exam['submissions'] ?? 0) == 0)
          _emptyCard(cs, 'No graded exams yet.')
        else ...[
          Row(
            children: [
              _miniStat(cs, 'High', _pct(exam['highest'])),
              _miniStat(cs, 'Avg', _pct(exam['average'])),
              _miniStat(cs, 'Median', _pct(exam['median'])),
              _miniStat(cs, 'Low', _pct(exam['lowest'])),
            ],
          ),
          const SizedBox(height: 16),
          _distributionChart(cs, _list(exam['distribution'])),
        ],
        const SizedBox(height: 24),

        // ── Question analytics ──
        Text('Question analytics',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Low correct-rate questions may signal a confusing concept or wording.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        const SizedBox(height: 12),
        if (questions.isEmpty)
          _emptyCard(cs, 'No exam questions answered yet.')
        else
          ...(questions
                ..sort((a, b) => ((a['correctRate'] ?? 101) as num).compareTo((b['correctRate'] ?? 101) as num)))
              .take(20)
              .map((q) => _questionTile(cs, q)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _miniStat(ColorScheme cs, String label, String value) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      );

  Widget _distributionChart(ColorScheme cs, List<Map<String, dynamic>> dist) {
    if (dist.isEmpty) return const SizedBox.shrink();
    final values = dist.map((e) => (e['count'] is num ? (e['count'] as num).toDouble() : 0.0)).toList();
    final maxY = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(8, 16, 12, 8),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
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
                  if (i < 0 || i >= dist.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(dist[i]['range']?.toString() ?? '',
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
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _questionTile(ColorScheme cs, Map<String, dynamic> q) {
    final correct = q['correctRate'];
    final pct = correct is num ? correct.toDouble() : 0.0;
    final color = pct >= 70 ? Colors.green : pct >= 40 ? Colors.orange : Colors.red;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(q['text']?.toString() ?? 'Question',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              Text(correct is num ? '${correct.round()}%' : '—',
                  style: TextStyle(fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: cs.outline.withValues(alpha: 0.15),
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text('correct · skip ${q['skipRate'] ?? '—'}%',
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _emptyCard(ColorScheme cs, String msg) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: cs.onSurfaceVariant, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
      );
}
