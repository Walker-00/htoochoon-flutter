import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Providers/insights_provider.dart';
import '../../Widgets/state/async_view.dart';
import '../../Widgets/state/shimmer_skeletons.dart';

/// "Who's falling behind?" — at-risk students for a course, ranked by risk with
/// a red/yellow/green dot and trigger reasons (Google-Classroom "Review" style).
class AtRiskScreen extends StatefulWidget {
  final String courseId;
  final String courseName;
  const AtRiskScreen({super.key, required this.courseId, required this.courseName});

  @override
  State<AtRiskScreen> createState() => _AtRiskScreenState();
}

class _AtRiskScreenState extends State<AtRiskScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InsightsProvider>().loadAtRisk(widget.courseId);
    });
  }

  Color _dot(String level, ColorScheme cs) {
    switch (level) {
      case 'red':
        return Colors.red.shade400;
      case 'yellow':
        return Colors.amber.shade600;
      default:
        return Colors.green.shade500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<InsightsProvider>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.courseName} · At Risk')),
      body: RefreshIndicator(
        onRefresh: () => context.read<InsightsProvider>().loadAtRisk(widget.courseId),
        child: AsyncView<List<dynamic>>(
          loading: p.loadingAtRisk,
          error: p.atRiskError,
          data: p.atRisk,
          isEmpty: (l) => l.isEmpty,
          onRetry: () => context.read<InsightsProvider>().loadAtRisk(widget.courseId),
          skeleton: SkeletonKind.list,
          emptyIcon: Icons.verified_user_outlined,
          emptyTitle: 'Everyone\'s on track',
          emptyMessage: 'No at-risk students for this course right now.',
          builder: (_) {
            final list = p.atRisk!;
            final atRisk = list.where((s) => s.level != 'green').toList();
            final ok = list.where((s) => s.level == 'green').toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                if (atRisk.isNotEmpty) ...[
                  _sectionHeader(context, 'Needs attention', atRisk.length),
                  ...atRisk.map((s) => _RiskCard(student: s, dotColor: _dot(s.level, cs))),
                  const SizedBox(height: 16),
                ],
                if (ok.isNotEmpty) ...[
                  _sectionHeader(context, 'On track', ok.length),
                  ...ok.map((s) => _RiskCard(student: s, dotColor: _dot(s.level, cs))),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, int count) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Text(title,
              style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count', style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  final AtRiskStudent student;
  final Color dotColor;
  const _RiskCard({required this.student, required this.dotColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 12, height: 12,
                    decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(student.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                Text('${student.riskScore.toStringAsFixed(0)}',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: dotColor)),
                Text(' risk', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _stat(context, 'Avg', '${student.avgScore.toStringAsFixed(0)}%'),
                const SizedBox(width: 14),
                _stat(context, 'Done', '${student.graded}/${student.totalAssessments}'),
              ],
            ),
            if (student.reasons.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: student.reasons
                    .map((r) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: dotColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(r, style: TextStyle(fontSize: 11, color: cs.onSurface)),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text('$label ', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
