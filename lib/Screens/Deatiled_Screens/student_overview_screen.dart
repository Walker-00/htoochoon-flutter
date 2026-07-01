import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../api/api_service.dart';
import '../Analytics/engagement_screen.dart';

const String _kMediaBase = 'https://backend.htoochoon.com';

/// Comprehensive admin/teacher view of ONE student inside an organization.
/// Data: GET /organizations/{orgId}/students/{studentId}/overview.
///
/// Shows per-program progress, exam/assignment completion ("did they actually
/// take it?"), live-session attendance (only sessions that actually ran — a
/// dismissed class / holiday is not counted), material engagement, integrity
/// violations, and last-active time.
class StudentOverviewScreen extends StatefulWidget {
  final String organizationId;
  final String studentId;
  final String? studentName;

  const StudentOverviewScreen({
    super.key,
    required this.organizationId,
    required this.studentId,
    this.studentName,
  });

  @override
  State<StudentOverviewScreen> createState() => _StudentOverviewScreenState();
}

class _StudentOverviewScreenState extends State<StudentOverviewScreen> {
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
      final res = await context
          .read<ApiService>()
          .getStudentOverview(widget.organizationId, widget.studentId);
      if (!mounted) return;
      setState(() {
        _data = res is Map ? res.cast<String, dynamic>() : null;
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

  // ── parsing helpers ────────────────────────────────────────────────────────
  int _int(dynamic v) => v is num ? v.round() : 0;
  int? _intN(dynamic v) => v is num ? v.round() : null;
  Map<String, dynamic> _map(dynamic v) =>
      v is Map ? v.cast<String, dynamic>() : const {};
  List<Map<String, dynamic>> _list(dynamic v) => v is List
      ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
      : const [];
  String _date(dynamic v) {
    if (v is! String || v.isEmpty) return '—';
    final d = DateTime.tryParse(v);
    return d == null ? '—' : DateFormat('d MMM yyyy').format(d.toLocal());
  }

  String _ago(dynamic v) {
    if (v is! String || v.isEmpty) return 'No activity yet';
    final d = DateTime.tryParse(v);
    if (d == null) return '—';
    final diff = DateTime.now().difference(d.toLocal());
    if (diff.inDays > 30) return DateFormat('d MMM yyyy').format(d.toLocal());
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = widget.studentName ??
        (_map(_data?['student'])['name'] as String?) ??
        'Student';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Student overview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(name,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Engagement',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EngagementScreen(
                  studentId: widget.studentId,
                  studentName: name,
                ),
              ),
            ),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error || _data == null
              ? _errorView(cs)
              : RefreshIndicator(onRefresh: _load, child: _content(cs)),
    );
  }

  Widget _errorView(ColorScheme cs) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 44, color: cs.error),
            const SizedBox(height: 8),
            const Text('Could not load this student'),
            const SizedBox(height: 8),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );

  Widget _content(ColorScheme cs) {
    final d = _data!;
    final student = _map(d['student']);
    final membership = _map(d['membership']);
    final programs = _list(d['programs']);
    final exams = _map(d['exams']);
    final assignments = _map(d['assignments']);
    final attendance = _map(d['attendance']);
    final violations = _map(d['violations']);
    final materials = _map(d['materials']);
    final correctRate = _intN(d['examCorrectRate']);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _header(cs, student, membership, d['lastActiveAt']),
        const SizedBox(height: 20),

        // ── Performance summary (the stored-per-student headline metrics) ──
        _sectionTitle('Performance summary'),
        const SizedBox(height: 8),
        _summaryGrid(cs, d),
        const SizedBox(height: 20),

        // ── Attendance (headline — the most-asked question) ──
        _sectionTitle('Live-session attendance'),
        const SizedBox(height: 8),
        _attendanceCard(cs, attendance),
        const SizedBox(height: 20),

        // ── Exams & assignments ──
        _sectionTitle('Exams & assignments'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _completionCard(
                cs,
                title: 'Exams taken',
                taken: _int(exams['taken']),
                total: _int(exams['total']),
                notTaken: _int(exams['notTaken']),
                avg: _intN(exams['avgScore']),
                color: Colors.indigo,
                icon: Icons.quiz_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _completionCard(
                cs,
                title: 'Assignments',
                taken: _int(assignments['taken']),
                total: _int(assignments['total']),
                notTaken: _int(assignments['notTaken']),
                avg: _intN(assignments['avgScore']),
                color: Colors.teal,
                icon: Icons.assignment_turned_in_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _statTile(cs, Icons.fact_check_outlined, 'Exam correct-answer rate',
            correctRate == null ? '—' : '$correctRate%'),
        const SizedBox(height: 20),

        // ── Material engagement ──
        _sectionTitle('Material engagement'),
        const SizedBox(height: 8),
        _materialsCard(cs, materials),
        const SizedBox(height: 20),

        // ── Programs ──
        _sectionTitle('Programs (${programs.length})'),
        const SizedBox(height: 8),
        if (programs.isEmpty)
          _emptyCard(cs, 'Not enrolled in any program in this organization.')
        else
          ...programs.map((p) => _programCard(cs, p)),
        const SizedBox(height: 20),

        // ── Integrity ──
        _sectionTitle('Integrity & proctoring'),
        const SizedBox(height: 8),
        _statTile(cs, Icons.warning_amber_rounded, 'Violations recorded',
            '${_int(violations['totalViolations'])}'),
        _statTile(cs, Icons.flag_outlined, 'Flagged submissions',
            '${_int(violations['flaggedCount'])}'),
        _statTile(cs, Icons.exit_to_app, 'Forced exits (left the app)',
            '${_int(violations['forcedExitCount'])}'),
        _statTile(cs, Icons.speed, 'Average integrity score',
            '${_int(violations['avgCheatScore'])} / 100'),
        _statTile(cs, Icons.trending_up, 'Highest integrity score',
            '${_int(violations['maxCheatScore'])} / 100'),
        _statTile(cs, Icons.gpp_bad, 'Results revoked',
            '${_int(violations['revokedCount'])}'),
        const SizedBox(height: 12),
        Text(
          'Integrity scores are advisory only and never change a grade. '
          'Attendance counts only sessions that actually ran — dismissed '
          'classes and holidays are excluded.',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── widgets ──────────────────────────────────────────────────────────────
  Widget _header(ColorScheme cs, Map student, Map membership, dynamic lastActive) {
    final avatar = student['avatar'] as String?;
    final url = (avatar != null && avatar.isNotEmpty)
        ? (avatar.startsWith('http') ? avatar : '$_kMediaBase$avatar')
        : null;
    final active = membership['isActive'] == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: cs.onPrimary.withValues(alpha: 0.2),
                backgroundImage: url != null ? NetworkImage(url) : null,
                child: url == null
                    ? Text(
                        (student['name'] as String?)?.isNotEmpty == true
                            ? (student['name'] as String)[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            color: cs.onPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student['name']?.toString() ?? 'Student',
                        style: TextStyle(
                            color: cs.onPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    if (student['email'] != null)
                      Text(student['email'].toString(),
                          style: TextStyle(
                              color: cs.onPrimary.withValues(alpha: 0.85),
                              fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.onPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(active ? 'Active' : 'Inactive',
                    style: TextStyle(
                        color: cs.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _headerStat(cs, 'Joined org',
                    _date(membership['joinedAt'])),
              ),
              Container(
                  width: 1,
                  height: 28,
                  color: cs.onPrimary.withValues(alpha: 0.25)),
              Expanded(
                child: _headerStat(cs, 'Last active', _ago(lastActive)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(ColorScheme cs, String label, String value) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: cs.onPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: cs.onPrimary.withValues(alpha: 0.85), fontSize: 11)),
        ],
      );

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800));

  Widget _summaryGrid(ColorScheme cs, Map<String, dynamic> d) {
    final riskBand = (d['riskBand'] ?? '').toString();
    final riskScore = _intN(d['riskScore']);
    final (riskColor, riskLabel) = switch (riskBand) {
      'HIGH' => (Colors.red, 'High'),
      'MEDIUM' => (Colors.orange, 'Medium'),
      'LOW' => (Colors.green, 'Low'),
      _ => (cs.outline, '—'),
    };
    String pct(dynamic v) => v is num ? '${v.round()}%' : '—';

    final hrs = d['totalLearningHours'];
    final chips = <Widget>[
      _metricChip(cs, 'Avg grade', pct(d['averageGrade']), Icons.grade_rounded, Colors.indigo),
      _metricChip(cs, 'Engagement', pct(d['engagementScore']), Icons.local_fire_department_rounded, Colors.deepOrange),
      _metricChip(
        cs,
        'Risk',
        riskScore == null ? riskLabel : '$riskLabel · $riskScore',
        Icons.health_and_safety_rounded,
        riskColor,
      ),
      _metricChip(cs, 'Learning', hrs is num ? '${hrs}h' : '—', Icons.schedule_rounded, Colors.blueGrey),
      _metricChip(cs, 'Submission rate', pct(d['submissionRate']), Icons.upload_file_rounded, Colors.teal),
      _metricChip(cs, 'Exam pass rate', pct(d['examPassRate']), Icons.workspace_premium_rounded, Colors.green),
      _metricChip(
        cs,
        'Courses done',
        '${_int(d['coursesCompleted'])}/${_int(d['coursesEnrolled'])}',
        Icons.school_rounded,
        Colors.purple,
      ),
      _metricChip(cs, 'Active days', '${_int(d['activeDays'])}', Icons.calendar_month_rounded, Colors.cyan),
      _metricChip(cs, 'Last login', _ago(d['lastLogin']), Icons.login_rounded, cs.primary),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        const spacing = 10.0;
        final w = (c.maxWidth - spacing * 2) / 3;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: chips.map((e) => SizedBox(width: w, child: e)).toList(),
        );
      },
    );
  }

  Widget _metricChip(ColorScheme cs, String label, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(label,
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );

  Widget _attendanceCard(ColorScheme cs, Map a) {
    final held = _int(a['heldSessions']);
    final rate = _intN(a['attendanceRate']);
    final color = rate == null
        ? cs.outline
        : rate >= 75
            ? Colors.green
            : rate >= 50
                ? Colors.orange
                : cs.error;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(cs),
      child: held == 0
          ? Row(
              children: [
                Icon(Icons.event_busy, color: cs.onSurfaceVariant),
                const SizedBox(width: 10),
                const Expanded(
                    child: Text('No sessions have been held yet.')),
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    _ring(rate ?? 0, color),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_int(a['attended'])} of $held sessions',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('attended (held sessions only)',
                              style: TextStyle(
                                  fontSize: 12, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _pill(cs, 'Present', _int(a['present']), Colors.green),
                    const SizedBox(width: 8),
                    _pill(cs, 'Late', _int(a['late']), Colors.orange),
                    const SizedBox(width: 8),
                    _pill(cs, 'Absent', _int(a['absent']), cs.error),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _ring(int pct, Color color) => SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: pct / 100,
                strokeWidth: 7,
                backgroundColor: color.withValues(alpha: 0.15),
                color: color,
              ),
            ),
            Text('$pct%',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      );

  Widget _pill(ColorScheme cs, String label, int value, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text('$value',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color)),
              Text(label,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      );

  Widget _completionCard(
    ColorScheme cs, {
    required String title,
    required int taken,
    required int total,
    required int notTaken,
    required int? avg,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(cs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('$taken / $total',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: taken / total,
                minHeight: 6,
                backgroundColor: color.withValues(alpha: 0.15),
                color: color,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            notTaken > 0 ? '$notTaken not taken' : 'All completed',
            style: TextStyle(
                fontSize: 11,
                color: notTaken > 0 ? cs.error : Colors.green),
          ),
          if (avg != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Avg score $avg%',
                  style:
                      TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }

  Widget _materialsCard(ColorScheme cs, Map m) {
    final total = _int(m['total']);
    final viewed = _int(m['viewed']);
    final rate = _intN(m['viewRate']);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(cs),
      child: Row(
        children: [
          Icon(Icons.menu_book_outlined, color: cs.primary, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    total == 0
                        ? 'No materials shared yet'
                        : '$viewed of $total materials viewed',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                if (total > 0)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (rate ?? 0) / 100,
                      minHeight: 7,
                      backgroundColor: cs.primary.withValues(alpha: 0.15),
                      color: cs.primary,
                    ),
                  ),
              ],
            ),
          ),
          if (rate != null) ...[
            const SizedBox(width: 12),
            Text('$rate%',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: cs.primary)),
          ],
        ],
      ),
    );
  }

  Widget _programCard(ColorScheme cs, Map p) {
    final progress = _int(p['progressRate']);
    final success = _intN(p['successRate']);
    final status = (p['status'] ?? '').toString();
    final statusColor = switch (status) {
      'ACTIVE' => Colors.green,
      'COMPLETED' => cs.primary,
      'DROPPED' => cs.error,
      _ => Colors.orange,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(cs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(p['name']?.toString() ?? 'Program',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(status.isEmpty ? '—' : status,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Enrolled ${_date(p['enrolledAt'])}',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Progress',
                            style: TextStyle(
                                fontSize: 11, color: cs.onSurfaceVariant)),
                        Text(
                            '$progress%  ·  ${_int(p['submittedCount'])}/${_int(p['totalAssessments'])}',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        minHeight: 6,
                        backgroundColor: cs.primary.withValues(alpha: 0.12),
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (success != null) ...[
                const SizedBox(width: 14),
                Column(
                  children: [
                    Text('$success%',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    Text('avg grade',
                        style: TextStyle(
                            fontSize: 10, color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(ColorScheme cs, IconData icon, String label, String value) =>
      Padding(
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

  Widget _emptyCard(ColorScheme cs, String msg) => Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco(cs),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: cs.onSurfaceVariant, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
      );

  BoxDecoration _cardDeco(ColorScheme cs) => BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      );
}
