import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Providers/insights_provider.dart';
import '../../Widgets/state/async_view.dart';

/// Per-student engagement: attendance split (pie), daily active minutes over the
/// last 14 days (line), and recent exam scores (bar). Data from the backend
/// `/analytics/engagement/{studentId}` endpoint.
class EngagementScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  const EngagementScreen({super.key, required this.studentId, required this.studentName});

  @override
  State<EngagementScreen> createState() => _EngagementScreenState();
}

class _EngagementScreenState extends State<EngagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InsightsProvider>().loadEngagement(widget.studentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<InsightsProvider>();
    return Scaffold(
      appBar: AppBar(title: Text('${widget.studentName} · Engagement')),
      body: RefreshIndicator(
        onRefresh: () => context.read<InsightsProvider>().loadEngagement(widget.studentId),
        child: AsyncView<EngagementData>(
          loading: p.loadingEngagement,
          error: p.engagementError,
          data: p.engagement,
          onRetry: () => context.read<InsightsProvider>().loadEngagement(widget.studentId),
          skeleton: SkeletonKind.chart,
          builder: (d) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AttendanceCard(data: d),
              const SizedBox(height: 16),
              _DailyMinutesCard(data: d),
              const SizedBox(height: 16),
              _ExamScoresCard(data: d),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final EngagementData data;
  const _AttendanceCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (data.totalSessions == 0) {
      return const _ChartCard(
        title: 'Attendance',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: Text('No attendance recorded yet')),
        ),
      );
    }
    final present = Colors.green.shade500;
    final late = Colors.amber.shade600;
    final absent = Colors.red.shade400;
    return _ChartCard(
      title: 'Attendance',
      child: Row(
        children: [
          SizedBox(
            height: 130,
            width: 130,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 32,
                sectionsSpace: 2,
                sections: [
                  if (data.present > 0)
                    PieChartSectionData(
                        value: data.present.toDouble(), color: present,
                        title: '${data.present}', radius: 26,
                        titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                  if (data.late > 0)
                    PieChartSectionData(
                        value: data.late.toDouble(), color: late,
                        title: '${data.late}', radius: 26,
                        titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                  if (data.absent > 0)
                    PieChartSectionData(
                        value: data.absent.toDouble(), color: absent,
                        title: '${data.absent}', radius: 26,
                        titleStyle: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _legend(present, 'Present', data.present, cs),
                const SizedBox(height: 8),
                _legend(late, 'Late', data.late, cs),
                const SizedBox(height: 8),
                _legend(absent, 'Absent', data.absent, cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label, int value, ColorScheme cs) {
    return Row(
      children: [
        Container(width: 12, height: 12,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
        const Spacer(),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _DailyMinutesCard extends StatelessWidget {
  final EngagementData data;
  const _DailyMinutesCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pts = data.dailyMinutes;
    if (pts.isEmpty) {
      return const _ChartCard(
        title: 'Daily active minutes (14 days)',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: Text('No activity recorded yet')),
        ),
      );
    }
    final maxY = pts.map((e) => e.value).fold<double>(0, (a, b) => b > a ? b : a);
    return _ChartCard(
      title: 'Daily active minutes (14 days)',
      child: SizedBox(
        height: 160,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY <= 0 ? 10 : maxY * 1.2,
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, m) {
                  return Text('${v.toInt()}', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant));
                }),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: (pts.length / 5).ceilToDouble().clamp(1, 99),
                  getTitlesWidget: (v, m) {
                    final i = v.toInt();
                    if (i < 0 || i >= pts.length) return const SizedBox.shrink();
                    final day = pts[i].key.split('-');
                    final label = day.length >= 3 ? '${day[1]}/${day[2]}' : pts[i].key;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(label, style: TextStyle(fontSize: 8, color: cs.onSurfaceVariant)),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [for (var i = 0; i < pts.length; i++) FlSpot(i.toDouble(), pts[i].value)],
                isCurved: true,
                color: cs.primary,
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: cs.primary.withValues(alpha: 0.12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamScoresCard extends StatelessWidget {
  final EngagementData data;
  const _ExamScoresCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scores = data.examScores;
    if (scores.isEmpty) {
      return const _ChartCard(
        title: 'Recent exam scores',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: Text('No graded work yet')),
        ),
      );
    }
    final shown = scores.take(8).toList().reversed.toList();
    return _ChartCard(
      title: 'Recent exam scores',
      child: SizedBox(
        height: 170,
        child: BarChart(
          BarChartData(
            maxY: 100,
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 25, getTitlesWidget: (v, m) {
                  return Text('${v.toInt()}', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant));
                }),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, m) {
                    final i = v.toInt();
                    if (i < 0 || i >= shown.length) return const SizedBox.shrink();
                    final t = shown[i].key;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(t.length > 6 ? '${t.substring(0, 6)}…' : t,
                          style: TextStyle(fontSize: 8, color: cs.onSurfaceVariant)),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < shown.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: shown[i].value.clamp(0, 100),
                    color: shown[i].value >= 60 ? cs.primary : Colors.red.shade400,
                    width: 14,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}
