import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Widgets/responsive.dart';
import '../../Widgets/stat_card.dart';
import '../../api/api_service.dart';

/// 🎓 Teaching-effectiveness + activity for one instructor.
/// Data: GET /teacher/instructors/{teacherId}/analytics?organizationId=...
/// (admin view), or GET /teacher/me/analytics for the current teacher.
class InstructorAnalyticsScreen extends StatefulWidget {
  final String teacherId;
  final String? organizationId; // null → "me" view
  final String? teacherName;

  const InstructorAnalyticsScreen({
    super.key,
    required this.teacherId,
    this.organizationId,
    this.teacherName,
  });

  @override
  State<InstructorAnalyticsScreen> createState() => _InstructorAnalyticsScreenState();
}

class _InstructorAnalyticsScreenState extends State<InstructorAnalyticsScreen> {
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
      final api = context.read<ApiService>();
      final res = widget.organizationId == null
          ? await api.getMyInstructorAnalytics()
          : await api.getInstructorAnalytics(widget.teacherId, widget.organizationId!);
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

  String _pct(dynamic v) => v is num ? '${v.round()}%' : '—';
  String _num(dynamic v) => v is num ? '${v.round()}' : '0';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final teacher = _data?['teacher'] is Map ? Map<String, dynamic>.from(_data!['teacher']) : const {};
    final name = widget.teacherName ?? teacher['name']?.toString() ?? 'Instructor';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Instructor analytics',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(name, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
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
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: centeredPagePadding(context, max: 720),
                    children: [
                      StatCardGrid(
                        crossAxisCount:
                            MediaQuery.of(context).size.width > 540 ? 3 : 2,
                        cards: [
                          AnimatedStatCard(label: 'Avg student score', value: _pct(_data!['avgStudentScore']), icon: Icons.grade_rounded, color: const Color(0xFF4F46E5), index: 0),
                          AnimatedStatCard(label: 'Pass rate', value: _pct(_data!['passRate']), icon: Icons.workspace_premium_rounded, color: const Color(0xFF16A34A), index: 1),
                          AnimatedStatCard(label: 'Students taught', value: _num(_data!['studentsTaught']), icon: Icons.people_rounded, color: const Color(0xFF0D9488), index: 2),
                          AnimatedStatCard(label: 'Courses', value: _num(_data!['courseCount']), icon: Icons.menu_book_rounded, color: const Color(0xFF7C3AED), index: 3),
                          AnimatedStatCard(label: 'Sessions held', value: _num(_data!['sessionsConducted']), icon: Icons.videocam_rounded, color: const Color(0xFFEA580C), index: 4),
                          AnimatedStatCard(label: 'Graded', value: _num(_data!['submissionsGraded']), icon: Icons.fact_check_rounded, color: const Color(0xFF2563EB), index: 5),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Effectiveness blends graded student scores, pass rate, and teaching '
                        'activity across this instructor’s courses.',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
    );
  }
}
