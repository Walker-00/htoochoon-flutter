import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/widgets/rich_content.dart';
import 'package:htoochoon_flutter/Providers/assignment_provider.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';
import 'package:htoochoon_flutter/models/api_models/assignment_model.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:htoochoon_flutter/core/userorgrole_manager.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/student_analytics_screen.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// StudentSubmissionDetailScreen
//
// FIX SUMMARY
// ───────────
// Root cause: `widget.assignment.questions` is empty when the assignment was
// loaded from the list endpoint (no /details call). The old code tried to
// match submission answers against those empty questions and found nothing.
//
// Solution: derive the authoritative question metadata from
// `submission.answers[*].question` (QuestionDetail) which is ALWAYS present
// in the submission response. We fall back to assignment.questions only as a
// secondary source for `options` (needed for MC display).
// ─────────────────────────────────────────────────────────────────────────────

class StudentSubmissionDetailScreen extends StatefulWidget {
  final Submission submission;
  final Assignment assignment;
  final VoidCallback? onGradeComplete;
  final bool isEditMode;
  const StudentSubmissionDetailScreen({
    super.key,
    required this.submission,
    required this.assignment,
    this.onGradeComplete,
    this.isEditMode = false,
  });

  @override
  State<StudentSubmissionDetailScreen> createState() =>
      _StudentSubmissionDetailScreenState();
}

class _StudentSubmissionDetailScreenState
    extends State<StudentSubmissionDetailScreen>
    with SingleTickerProviderStateMixin {
  // questionId → points the teacher assigns
  late Map<String, double> _scores;
  // questionId → optional teacher feedback
  late Map<String, String> _feedback;
  // questionId → feedback TextField controller
  late Map<String, TextEditingController> _feedbackControllers;

  bool _isSaving = false;
  bool _hasChanges = false;

  // Result revocation state (staff). Initialized from the submission, updated
  // locally after a revoke/restore so the UI reflects the change immediately.
  late bool _revoked = widget.submission.isRevoked;
  late String? _revokedReason = widget.submission.revokedReason;

  // Submission-based ASSIGNMENT grading (no per-question answers): one overall
  // score (0-100) for the written response.
  bool get _isAssignmentSubmission =>
      (widget.submission.answers ?? const []).isEmpty;
  final _assignmentScoreCtrl = TextEditingController();
  final _assignmentFeedbackCtrl = TextEditingController();

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // ── helpers ──────────────────────────────────────────────────────────────

  /// All answers ordered by their embedded question.order
  List<SubmissionAnswer> get _orderedAnswers {
    final answers = List<SubmissionAnswer>.from(
      widget.submission.answers ?? [],
    );
    answers.sort((a, b) => a.question!.order.compareTo(b.question!.order));
    return answers;
  }

  /// Look up the full Question from assignment.questions (has options list).
  /// May be null if the assignment was loaded without /details.
  Question? _questionFor(SubmissionAnswer answer) => widget.assignment.questions
      .firstWhereOrNull((q) => q.id == answer.questionId);

  double get _totalScore => _scores.values.fold(0.0, (s, v) => s + v);

  int get _maxScore =>
      _orderedAnswers.fold<int>(0, (s, a) => s + a.question!.points.toInt());

  // String get _durationLabel {
  //   final started = widget.submission.startedAt;
  //   // final submitted = widget.submission.submittedAt;
  //
  //   if (started == null || submitted == null) return '--:--';
  //
  //   final diff = submitted.difference(started);
  //   final m = diff.inMinutes;
  //   final s = diff.inSeconds % 60;
  //   return '${m}m ${s}s';
  // }

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _scores = {
      for (final a in widget.submission.answers ?? [])
        a.questionId: a.pointsEarned?.toDouble() ?? 0.0,
    };
    _feedback = {
      for (final a in widget.submission.answers ?? []) a.questionId: '',
    };
    _feedbackControllers = {
      for (final a in widget.submission.answers ?? [])
        a.questionId: TextEditingController(),
    };

    final existingScore = widget.submission.score;
    if (existingScore != null) {
      _assignmentScoreCtrl.text = existingScore.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    for (final c in _feedbackControllers.values) {
      c.dispose();
    }
    _assignmentScoreCtrl.dispose();
    _assignmentFeedbackCtrl.dispose();
    super.dispose();
  }

  // Grade a submission-based assignment with a single overall score (0-100).
  Future<void> _saveAssignmentGrade() async {
    if (_isSaving) return;
    final score = double.tryParse(_assignmentScoreCtrl.text.trim());
    if (score == null || score < 0 || score > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a score between 0 and 100.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final updated = await context.read<AssignmentProvider>().gradeSubmission(
        submissionId: widget.submission.id,
        request: GradeRequest(
          score: score,
          questionGrades: const [],
          status: SubmissionStatus.GRADED,
        ),
      );
      if (!mounted) return;
      if (updated != null) {
        widget.onGradeComplete?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Grade saved successfully!')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Failed to save grade.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('❌ Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── revoke / restore result (staff) ───────────────────────────────────────

  /// PopupMenuButton shown in the AppBar for revoking/restoring a result.
  Widget _revokeMenu(ColorScheme cs) {
    return PopupMenuButton<String>(
      tooltip: 'Result actions',
      icon: Icon(_revoked ? Icons.gpp_bad : Icons.more_vert,
          color: _revoked ? cs.error : null),
      onSelected: (v) {
        if (v == 'revoke') {
          _promptRevoke();
        } else if (v == 'restore') {
          _doRestore();
        } else if (v == 'progress') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentAnalyticsScreen(
                classId: widget.assignment.classId,
                studentId: widget.submission.studentId,
                studentName: widget.submission.student?.name,
              ),
            ),
          );
        }
      },
      itemBuilder: (_) => [
        if (!_revoked)
          const PopupMenuItem(
            value: 'revoke',
            child: ListTile(
              leading: Icon(Icons.block, color: Colors.red),
              title: Text('Revoke result'),
              contentPadding: EdgeInsets.zero,
            ),
          )
        // A teacher cannot reverse an ADMIN's revoke (backend-enforced). Hide
        // the restore option for them; admins always see it.
        else if (!widget.submission.revokedByAdmin ||
            UserSessionManager.isAnyOrgAdmin)
          const PopupMenuItem(
            value: 'restore',
            child: ListTile(
              leading: Icon(Icons.restore, color: Colors.green),
              title: Text('Restore result'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuItem(
          value: 'progress',
          child: ListTile(
            leading: Icon(Icons.insights),
            title: Text('Student progress'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildRevokedBanner(ColorScheme cs) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gpp_bad, color: cs.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Result revoked — hidden from the student',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: cs.onErrorContainer)),
                if ((_revokedReason ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(_revokedReason!,
                      style: TextStyle(color: cs.onErrorContainer, fontSize: 13)),
                ],
                if (widget.submission.revokedByRole != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Revoked by ${widget.submission.revokedByAdmin ? 'an admin' : 'a teacher'}'
                    '${widget.submission.revokedByAdmin ? ' — only an admin can restore it.' : '.'}',
                    style: TextStyle(
                        color: cs.onErrorContainer,
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _promptRevoke() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke result'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The student will no longer see their score or answers — only this reason. '
              'You can restore it later. Admins are notified.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    final updated = await context
        .read<AssignmentProvider>()
        .revokeSubmission(submissionId: widget.submission.id, reason: reason);
    if (!mounted) return;
    if (updated != null) {
      setState(() {
        _revoked = true;
        _revokedReason = reason;
      });
      widget.onGradeComplete?.call();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Result revoked.')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to revoke result.')));
    }
  }

  Future<void> _doRestore() async {
    final updated = await context
        .read<AssignmentProvider>()
        .restoreSubmission(submissionId: widget.submission.id);
    if (!mounted) return;
    if (updated != null) {
      setState(() {
        _revoked = false;
        _revokedReason = null;
      });
      widget.onGradeComplete?.call();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Result restored.')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to restore result.')));
    }
  }

  // ── save grade ────────────────────────────────────────────────────────────

  Future<void> _saveGrade() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final questionGrades = _orderedAnswers.map((a) {
        return QuestionGrades(
          questionId: a.questionId,
          pointEarned: (_scores[a.questionId] ?? 0).round(),
          feedback: _feedback[a.questionId]?.isNotEmpty == true
              ? _feedback[a.questionId]
              : null,
        );
      }).toList();

      final updated = await context.read<AssignmentProvider>().gradeSubmission(
        submissionId: widget.submission.id,
        request: GradeRequest(
          score: _totalScore,
          questionGrades: questionGrades,
          status: SubmissionStatus.GRADED,
        ),
      );

      if (!mounted) return;
      if (updated != null) {
        widget.onGradeComplete?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Grade saved successfully!')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Failed to save grade.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isGraded = widget.submission.status == "GRADED";

    final canEdit = !isGraded || widget.isEditMode;

    // Submission-based assignment → a written response + a single score field.
    if (_isAssignmentSubmission) {
      return _buildAssignmentGrading(cs, isGraded, canEdit);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(cs, isGraded, canEdit),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            // ── Score + meta header ──────────────────────────────────────
            _buildHeader(context, isGraded),

            if (_revoked)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildRevokedBanner(cs),
              ),

            // ── Question list ────────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: _orderedAnswers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) => _buildAnswerCard(
                  ctx,
                  _orderedAnswers[i],
                  isGraded,
                  canEdit,
                ),
              ),
            ),

            // ── Bottom save bar ──────────────────────────────────────────
            if (canEdit) _buildSaveBar(cs),
          ],
        ),
      ),
    );
  }

  // ── Assignment (submission-based) grading layout ──────────────────────────
  Widget _buildAssignmentGrading(
    ColorScheme cs,
    bool isGraded,
    bool canEdit,
  ) {
    final content = widget.submission.content?.trim() ?? '';
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.assignment.title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Grading · ${widget.submission.student?.name ?? ''}',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
        actions: [_revokeMenu(cs)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_revoked) _buildRevokedBanner(cs),
          Text(
            'Student response',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 80),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.getSurfaceVariant(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.getBorder(context)),
            ),
            child: Text(
              content.isEmpty ? '— No written response —' : content,
              style: TextStyle(
                height: 1.5,
                fontStyle: content.isEmpty ? FontStyle.italic : FontStyle.normal,
                color: content.isEmpty
                    ? AppTheme.getTextSecondary(context)
                    : AppTheme.getTextPrimary(context),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Score (out of 100)',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _assignmentScoreCtrl,
            enabled: canEdit,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '0 – 100',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.star_rate_rounded),
            ),
          ),
          const SizedBox(height: 24),
          if (canEdit)
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveAssignmentGrade,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_isSaving ? 'Saving…' : 'Save grade'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Graded · ${widget.submission.score?.toStringAsFixed(0) ?? '—'} / 100',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.green[800],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(
    ColorScheme cs,
    bool isGraded,
    bool canEdit,
  ) {
    return AppBar(
      backgroundColor: cs.surface,
      foregroundColor: Theme.of(context).colorScheme.background,
      elevation: 0,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.assignment.title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Grading · ${widget.submission.student?.name ?? ''}',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (canEdit)
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: FilledButton.icon(
              onPressed: (_isSaving || !_hasChanges) ? null : _saveGrade,
              icon: _isSaving
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 16),
              label: Text(
                _isSaving ? 'Saving…' : 'Save Grade',
                style: const TextStyle(fontSize: 13),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 0,
                ),
                backgroundColor: _hasChanges ? Colors.orange : null,
              ),
            ),
          ),
        _revokeMenu(cs),
      ],
    );
  }

  // ── Header (score summary + metadata chips) ───────────────────────────────

  Widget _buildHeader(BuildContext context, bool isGraded) {
    final cs = Theme.of(context).colorScheme;
    final pct = _maxScore > 0 ? (_totalScore / _maxScore * 100).round() : 0;
    final color = _hasChanges
        ? Colors.orange
        : (isGraded ? (pct >= 70 ? Colors.green : Colors.red) : cs.primary);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          // Score row
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(
                  _hasChanges
                      ? Icons.edit_rounded
                      : (isGraded ? Icons.verified_rounded : Icons.grading),
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasChanges
                          ? 'Unsaved Changes'
                          : (isGraded
                                ? 'Final Grade'
                                : 'Grade this submission'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${_totalScore.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                        Text(
                          ' / $_maxScore pts',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: color.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Percentage badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Metadata chips row
          Row(
            children: [
              // _InfoChip(
              //   icon: Icons.timer_outlined,
              //   label: 'Time taken',
              //   value: _durationLabel,
              // ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.quiz_outlined,
                label: 'Questions',
                value: '${_orderedAnswers.length}',
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.calendar_today_outlined,
                label: 'Submitted',
                value: _fmt(
                  widget.submission.submittedAt ?? widget.submission.createdAt,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Per-question answer card ───────────────────────────────────────────────

  Widget _buildAnswerCard(
    BuildContext context,
    SubmissionAnswer answer,
    bool isGraded,
    bool canEdit,
  ) {
    final qd = answer.question; // QuestionDetail — always present
    final fullQ = _questionFor(answer); // Question (has options) — may be null
    final maxPts = qd!.points.toDouble();
    final currentScore = _scores[answer.questionId] ?? 0.0;
    final isMC = qd.type == 'MULTIPLE_CHOICE' || qd.type == 'TRUE_FALSE';

    // Determine auto-correct indicator
    final isCorrect = answer.isCorrect;
    final borderColor = isCorrect == true
        ? Colors.green.withValues(alpha: 0.35)
        : isCorrect == false
        ? Colors.red.withValues(alpha: 0.35)
        : AppTheme.getBorder(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceVariant(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Question header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Q${qd.order}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Question text + type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichContent(qd.text),
                      const SizedBox(height: 2),
                      Text(
                        '${_typeLabel(qd!.type)} · ${qd.points.toInt()} pts'
                        '${qd.isRequired ? ' · required' : ''}',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Score badge
                _ScoreBadge(
                  score: currentScore.round(),
                  max: qd.points.toInt(),
                  isCorrect: isCorrect,
                ),
              ],
            ),
          ),

          const Divider(height: 1, indent: 14, endIndent: 14),

          // ── Student answer ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: isMC
                ? _buildMCAnswer(context, answer, fullQ)
                : _buildTextAnswer(context, answer),
          ),

          // ── Grading slider + feedback ─────────────────────────────────
          if (canEdit)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: _buildGradingPanel(context, answer, currentScore, maxPts),
            )
          else
            const SizedBox(height: 14),
        ],
      ),
    );
  }

  // ── Multiple-choice answer display ────────────────────────────────────────

  Widget _buildMCAnswer(
    BuildContext context,
    SubmissionAnswer answer,
    Question? fullQ,
  ) {
    // Try to get option text from the full question (which has options list)
    Option? picked;
    Option? correct;
    if (fullQ != null) {
      picked = fullQ.options.firstWhereOrNull(
        (o) => o.id == answer.selectedOptionId,
      );
      correct = fullQ.options.firstWhereOrNull((o) => o.isCorrect);
    }

    // Fallback: use selectedAnswer string if option not found
    final answerText =
        picked?.text ??
        answer.selectedAnswer ??
        (answer.selectedOptionId != null
            ? 'Option ID: ${answer.selectedOptionId}'
            : '— No answer selected —');

    final isRight = picked?.isCorrect ?? answer.isCorrect;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _answerLabel(context, 'Student selected:'),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isRight == true
                  ? Colors.green.withValues(alpha: 0.4)
                  : isRight == false
                  ? Colors.red.withValues(alpha: 0.4)
                  : AppTheme.getBorder(context),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isRight == true ? Icons.check_circle : Icons.cancel,
                size: 16,
                color: isRight == true ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  answerText,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isRight == true
                        ? Colors.green[700]
                        : Colors.red[700],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Show correct answer if student was wrong
        if (isRight == false && correct != null) ...[
          const SizedBox(height: 8),
          _answerLabel(context, 'Correct answer:'),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Text(
              correct.text,
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Essay / short-answer display ──────────────────────────────────────────

  Widget _buildTextAnswer(BuildContext context, SubmissionAnswer answer) {
    final text = answer.textAnswer;
    final empty = text == null || text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _answerLabel(context, 'Student\'s answer:'),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.getBorder(context)),
          ),
          child: Text(
            empty ? '— No answer provided —' : text!,
            style: TextStyle(
              color: empty
                  ? AppTheme.getTextSecondary(context)
                  : AppTheme.getTextPrimary(context),
              fontStyle: empty ? FontStyle.italic : FontStyle.normal,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  // ── Grading slider + feedback ─────────────────────────────────────────────

  Widget _buildGradingPanel(
    BuildContext context,
    SubmissionAnswer answer,
    double currentScore,
    double maxPts,
  ) {
    final divisions = maxPts.toInt().clamp(1, 100);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score row
          Row(
            children: [
              Icon(
                Icons.star_rate_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Points:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${currentScore.round()} / ${maxPts.toInt()}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              // Quick-set buttons
              _QuickBtn(
                label: '0',
                onTap: () => _setScore(answer.questionId, 0),
              ),
              const SizedBox(width: 4),
              _QuickBtn(
                label: '½',
                onTap: () => _setScore(answer.questionId, maxPts / 2),
              ),
              const SizedBox(width: 4),
              _QuickBtn(
                label: 'Full',
                onTap: () => _setScore(answer.questionId, maxPts),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Theme.of(context).colorScheme.primary,
              inactiveTrackColor: Theme.of(context).colorScheme.surfaceVariant,
              thumbColor: Theme.of(context).colorScheme.primary,
              overlayColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.15),
              valueIndicatorColor: Theme.of(context).colorScheme.primary,
              valueIndicatorTextStyle: const TextStyle(color: Colors.white),
              trackHeight: 4,
            ),
            child: Slider(
              value: currentScore.clamp(0, maxPts),
              min: 0,
              max: maxPts,
              divisions: divisions,
              label: currentScore.round().toString(),
              onChanged: (v) => _setScore(answer.questionId, v),
            ),
          ),

          // Feedback
          const SizedBox(height: 6),
          TextField(
            controller: _feedbackControllers[answer.questionId],
            decoration: InputDecoration(
              hintText: 'Add feedback for this answer (optional)…',
              hintStyle: TextStyle(
                fontSize: 12,
                color: AppTheme.getTextSecondary(context).withValues(alpha: 0.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.getBorder(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.getBorder(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
              ),
            ),
            maxLines: 2,
            style: const TextStyle(fontSize: 13),
            onChanged: (v) {
              setState(() {
                _feedback[answer.questionId] = v;
                _hasChanges = true;
              });
            },
          ),
        ],
      ),
    );
  }

  void _setScore(String questionId, double value) {
    setState(() {
      _scores[questionId] = value;
      _hasChanges = true;
    });
  }

  // ── Bottom save bar ───────────────────────────────────────────────────────

  Widget _buildSaveBar(ColorScheme cs) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
            top: BorderSide(color: AppTheme.getBorder(context), width: 0.5),
          ),
        ),
        child: FilledButton.icon(
          onPressed: (_isSaving || !_hasChanges) ? null : _saveGrade,
          icon: _isSaving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onPrimary,
                  ),
                )
              : const Icon(Icons.save_rounded),
          label: Text(
            _isSaving ? 'Saving Grade…' : 'Save Final Grade',
            style: const TextStyle(fontSize: 15),
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            backgroundColor: _hasChanges ? Colors.orange : null,
          ),
        ),
      ),
    );
  }

  // ── Small helpers ─────────────────────────────────────────────────────────

  Widget _answerLabel(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 11,
      color: AppTheme.getTextSecondary(context),
    ),
  );

  String _typeLabel(String type) {
    switch (type) {
      case 'MULTIPLE_CHOICE':
        return 'Multiple choice';
      case 'TRUE_FALSE':
        return 'True / False';
      case 'SHORT_ANSWER':
        return 'Short answer';
      case 'ESSAY':
        return 'Essay';
      default:
        return type;
    }
  }

  String _fmt(DateTime d) =>
      '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ScoreBadge extends StatelessWidget {
  final int score;
  final int max;
  final bool? isCorrect;

  const _ScoreBadge({required this.score, required this.max, this.isCorrect});

  @override
  Widget build(BuildContext context) {
    final color = isCorrect == true
        ? Colors.green
        : isCorrect == false
        ? Colors.red
        : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$score / $max',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.getSurfaceVariant(context).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.getBorder(context).withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: AppTheme.getTextSecondary(context)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      color: AppTheme.getTextSecondary(context),
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
