// grade_submissions_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/widgets/rich_content.dart';
import 'package:htoochoon_flutter/Providers/assignment_provider.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/assignment_screens.dart';
import 'package:htoochoon_flutter/models/api_models/assignment_model.dart';
import 'package:provider/provider.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';

const _kBaseUrl = 'https://backend.htoochoon.com';

// ─────────────────────────────────────────────────────────────────────────────
// GRADE SUBMISSIONS SCREEN  (admin / teacher)
// ─────────────────────────────────────────────────────────────────────────────

class GradeSubmissionsScreen extends StatefulWidget {
  final Assignment assignment;
  final String classId;

  const GradeSubmissionsScreen({
    super.key,
    required this.assignment,
    required this.classId,
  });

  @override
  State<GradeSubmissionsScreen> createState() => _GradeSubmissionsScreenState();
}

class _GradeSubmissionsScreenState extends State<GradeSubmissionsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Submission> _submissions = [];
  Assignment? _full;

  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prov = context.read<AssignmentProvider>();

    // Load full assignment (with questions) + submissions in parallel
    await Future.wait([
      prov.fetchAssignmentDetail(widget.assignment.id).then((d) {
        if (mounted) setState(() => _full = d ?? widget.assignment);
      }),
      prov
          .fetchSubmissions(
            classId: widget.classId,
            type: widget.assignment.type == AssignmentType.TEST
                ? 'test'
                : 'assignment',
            itemId: widget.assignment.id,
          )
          .then((_) {
            if (mounted) {
              setState(() => _submissions = List.from(prov.submissions));
            }
          }),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  int get _totalPoints => (_full ?? widget.assignment).questions.fold<int>(
    0,
    (s, q) => s + q.points,
  );

  int get _gradedCount =>
      _submissions.where((s) => s.status.toUpperCase() == "GRADED").length;

  double get _avgScore {
    final graded = _submissions
        .where((s) => s.status.toUpperCase() == "GRADED")
        .toList();

    if (graded.isEmpty) return 0.0;

    // Filter out null scores and calculate average
    final validScores = graded
        .map((s) => s.score)
        .whereType<num>() // Removes null values
        .toList();

    if (validScores.isEmpty) return 0.0;

    final total = validScores.reduce((a, b) => a + b);
    return total / validScores.length; // ✅ Both are non-null now
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = _full ?? widget.assignment;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              a.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            Text(
              'Submissions',
              style: TextStyle(
                fontSize: 11,
                color: cs.onPrimary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: cs.onPrimary,
          labelColor: cs.onPrimary,
          unselectedLabelColor: cs.onPrimary.withValues(alpha: 0.6),
          tabs: const [
            Tab(text: 'Submissions'),
            Tab(text: 'Questions'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Stats banner ───────────────────────────
                _StatsBanner(
                  total: _submissions.length,
                  graded: _gradedCount,
                  avgScore: _avgScore,
                  totalPts: _totalPoints,
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      // Tab 1: Submissions list
                      _submissions.isEmpty
                          ? const Center(child: Text('No submissions yet'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(AppTheme.spaceLg),
                              itemCount: _submissions.length,
                              itemBuilder: (context, i) => _SubmissionTile(
                                submission: _submissions[i],
                                assignment: a,
                                totalPoints: _totalPoints,
                                onGraded: (updated) =>
                                    setState(() => _submissions[i] = updated),
                              ),
                            ),

                      // Tab 2: Questions overview
                      ListView.builder(
                        padding: const EdgeInsets.all(AppTheme.spaceLg),
                        itemCount: a.questions.length,
                        itemBuilder: (context, i) => _QuestionStatsCard(
                          question: a.questions[i],
                          submissions: _submissions,
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

// ─────────────────────────────────────────────────────────────────────────────
// STATS BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _StatsBanner extends StatelessWidget {
  final int total, graded, totalPts;
  final double avgScore;

  const _StatsBanner({
    required this.total,
    required this.graded,
    required this.avgScore,
    required this.totalPts,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.primary.withValues(alpha: 0.05),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Stat(label: 'Total', value: '$total', icon: Icons.people_outline),
          _divider(),
          _Stat(label: 'Graded', value: '$graded', icon: Icons.grading),
          _divider(),
          _Stat(
            label: 'Avg Score',
            value: totalPts == 0
                ? '-'
                : '${avgScore.toStringAsFixed(1)} / $totalPts',
            icon: Icons.bar_chart,
          ),
          _divider(),
          _Stat(
            label: 'Pending',
            value: '${total - graded}',
            icon: Icons.pending_outlined,
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 36, color: Colors.grey.withValues(alpha: 0.3));
}

class _Stat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _Stat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.getTextSecondary(context),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBMISSION TILE  (expandable)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// SUBMISSION TILE  (expandable)
// ─────────────────────────────────────────────────────────────────────────────

class _SubmissionTile extends StatelessWidget {
  final Submission submission;
  final Assignment assignment;
  final int totalPoints;
  final void Function(Submission) onGraded;
  final VoidCallback? onRefresh;

  const _SubmissionTile({
    required this.submission,
    required this.assignment,
    required this.totalPoints,
    required this.onGraded,
    this.onRefresh,
  });

  // ✅ NEW: Helper method to calculate the objective score automatically
  double _calculateAutoScore() {
    double calculatedScore = 0.0;

    // 1. Parse answers map from content JSON
    Map<String, String> lookup = {};
    try {
      final decoded = jsonDecode(submission.content.toString());
      if (decoded is Map) {
        lookup = decoded.cast<String, dynamic>().map((k, v) {
          if (v is Map) {
            return MapEntry(
              k,
              v['selectedOptionId']?.toString() ??
                  v['textAnswer']?.toString() ??
                  '',
            );
          }
          return MapEntry(k, v.toString());
        });
      } else if (decoded is List) {
        for (final a in decoded) {
          if (a is Map) {
            final qId = a['questionId']?.toString() ?? '';
            lookup[qId] =
                a['selectedOptionId']?.toString() ??
                a['textAnswer']?.toString() ??
                '';
          }
        }
      }
    } catch (_) {
      // If parsing fails, return 0 for auto-grade
      return 0.0;
    }

    // 2. Loop through questions and grade MC / True-False automatically
    for (final q in assignment.questions) {
      final isMC =
          q.type == QuestionType.MULTIPLE_CHOICE ||
          q.type == QuestionType.TRUE_FALSE;

      if (isMC) {
        final studentAnswer = lookup[q.id];
        if (studentAnswer != null) {
          final pickedOption = q.options
              .where((o) => o.id == studentAnswer)
              .firstOrNull;
          if (pickedOption != null && pickedOption.isCorrect) {
            calculatedScore += q.points; // Add points for correct answer
          }
        }
      }
    }

    return calculatedScore;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isGraded = submission.status == SubmissionStatus.GRADED;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(
          color: isGraded
              ? Colors.green.withValues(alpha: 0.4)
              : AppTheme.getBorder(context),
          width: isGraded ? 1.5 : 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMd,
            vertical: 4,
          ),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: cs.primary.withValues(alpha: 0.12),
            child: Text(
              (submission.student?.name ?? '').isNotEmpty
                  ? submission.student!.name![0].toUpperCase()
                  : '?',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          title: Text(
            submission.student?.name ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            isGraded ? 'Graded' : 'Pending review',
            style: TextStyle(
              fontSize: 11,
              color: isGraded
                  ? Colors.green[600]
                  : AppTheme.getTextSecondary(context),
            ),
          ),
          trailing: isGraded
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${submission.score?.toStringAsFixed(0) ?? 67} / $totalPoints',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.green,
                      fontSize: 13,
                    ),
                  ),
                )
              : OutlinedButton(
                  onPressed: () => _showGradeDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Grade'),
                ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceMd,
                0,
                AppTheme.spaceMd,
                AppTheme.spaceMd,
              ),
              child: _AnswerReview(
                submission: submission,
                assignment: assignment,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGradeDialog(BuildContext context) {
    final provider = context.read<AssignmentProvider>();

    // ✅ Calculate auto-score instead of defaulting to totalPoints
    double score = _calculateAutoScore();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setInner) => AlertDialog(
          title: Text('Grade — ${submission.student?.name ?? ''}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${score.toStringAsFixed(0)} / $totalPoints',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                totalPoints > 0
                    ? '${(score / totalPoints * 100).toStringAsFixed(0)}%'
                    : '0%',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              if (totalPoints > 0)
                Slider(
                  value: score,
                  min: 0,
                  max: totalPoints.toDouble(),
                  divisions: totalPoints,
                  label: score.toStringAsFixed(0),
                  onChanged: (v) => setInner(() => score = v),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updated = await provider.gradeSubmission(
                  submissionId: submission.id,
                  request: GradeRequest(
                    questionGrades: [],
                    score: score,
                    status: SubmissionStatus.GRADED,
                  ),
                );

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }

                if (updated != null) {
                  onGraded(updated);
                }
              },
              child: const Text('Save Grade'),
            ),
          ],
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// ANSWER REVIEW  (expanded inside submission tile)
// ─────────────────────────────────────────────────────────────────────────────

class _AnswerReview extends StatelessWidget {
  final Submission submission;
  final Assignment assignment;

  const _AnswerReview({required this.submission, required this.assignment});

  @override
  Widget build(BuildContext context) {
    // Parse answers map from content JSON
    Map<String, dynamic> answersMap = {};
    List<dynamic> answersList = [];
    try {
      final decoded = jsonDecode(submission.content.toString());
      if (decoded is Map) {
        answersMap = decoded.cast<String, dynamic>();
      } else if (decoded is List) {
        answersList = decoded;
      }
    } catch (_) {
      // plain text
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: AppTheme.getSurfaceVariant(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(submission.content.toString()),
      );
    }

    // Build a lookup: questionId → selectedOptionId or textAnswer
    Map<String, String> lookup = {};
    if (answersMap.isNotEmpty) {
      lookup = answersMap.map((k, v) {
        if (v is Map) {
          return MapEntry(
            k,
            v['selectedOptionId']?.toString() ??
                v['textAnswer']?.toString() ??
                '',
          );
        }
        return MapEntry(k, v.toString());
      });
    } else if (answersList.isNotEmpty) {
      for (final a in answersList) {
        if (a is Map) {
          final qId = a['questionId']?.toString() ?? '';
          lookup[qId] =
              a['selectedOptionId']?.toString() ??
              a['textAnswer']?.toString() ??
              '';
        }
      }
    }

    if (assignment.questions.isEmpty) {
      return const Text('No questions available for review.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: assignment.questions.map((q) {
        final studentAnswer = lookup[q.id];
        return _QuestionReviewCard(question: q, studentAnswer: studentAnswer);
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUESTION REVIEW CARD  (per-question in submission review)
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionReviewCard extends StatelessWidget {
  final Question question;
  final String? studentAnswer; // optionId or text

  const _QuestionReviewCard({required this.question, this.studentAnswer});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Resolve for MC / TRUE_FALSE
    final pickedOption = question.options
        .where((o) => o.id == studentAnswer)
        .firstOrNull;
    final correctOption = question.options
        .where((o) => o.isCorrect)
        .firstOrNull;
    final isCorrect = pickedOption?.isCorrect ?? false;
    final isMC =
        question.type == QuestionType.MULTIPLE_CHOICE ||
        question.type == QuestionType.TRUE_FALSE;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: studentAnswer == null
            ? Colors.orange.withValues(alpha: 0.05)
            : isMC
            ? (isCorrect
                  ? Colors.green.withValues(alpha: 0.05)
                  : Colors.red.withValues(alpha: 0.05))
            : AppTheme.getSurfaceVariant(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: studentAnswer == null
              ? Colors.orange.withValues(alpha: 0.3)
              : isMC
              ? (isCorrect
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.red.withValues(alpha: 0.3))
              : AppTheme.getBorder(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Q${question.order}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${question.points} pts',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
              const Spacer(),
              if (studentAnswer == null)
                _badge('Not answered', Colors.orange)
              else if (isMC)
                _badge(
                  isCorrect ? 'Correct' : 'Wrong',
                  isCorrect ? Colors.green : Colors.red,
                )
              else
                _badge('Essay / Text', Colors.blue),
            ],
          ),

          const SizedBox(height: 6),
          RichContent(question.text),

          // Student answer
          const SizedBox(height: 4),
          if (studentAnswer == null)
            Text(
              '— not answered —',
              style: TextStyle(
                color: Colors.orange[700],
                fontStyle: FontStyle.italic,
              ),
            )
          else if (isMC) ...[
            Text(
              'Student: ${pickedOption?.text ?? studentAnswer}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isCorrect ? Colors.green[700] : Colors.red[700],
              ),
            ),
            if (!isCorrect && correctOption != null)
              Text(
                'Correct: ${correctOption.text}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.getSurfaceVariant(context),
                borderRadius: BorderRadius.circular(6),
              ),
              child: SmartAnswerText(raw: studentAnswer!, context: context),
            ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// QUESTION STATS CARD  (Questions tab — how many got it right)
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionStatsCard extends StatelessWidget {
  final Question question;
  final List<Submission> submissions;

  const _QuestionStatsCard({required this.question, required this.submissions});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Count how many students picked each option
    Map<String, int> optionCounts = {for (final o in question.options) o.id: 0};

    int unanswered = 0;
    for (final sub in submissions) {
      try {
        final decoded = jsonDecode(sub.content.toString());
        String? answer;
        if (decoded is Map) {
          final v = decoded[question.id];
          if (v is Map) {
            answer = v['selectedOptionId']?.toString();
          } else {
            answer = v?.toString();
          }
        } else if (decoded is List) {
          final match = (decoded as List<dynamic>).firstWhere(
            (a) => a['questionId'] == question.id,
            orElse: () => null,
          );
          answer = match?['selectedOptionId']?.toString();
        }
        if (answer != null && optionCounts.containsKey(answer)) {
          optionCounts[answer] = (optionCounts[answer] ?? 0) + 1;
        } else {
          unanswered++;
        }
      } catch (_) {
        unanswered++;
      }
    }

    final total = submissions.length;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Q${question.order}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${question.points} pts',
                style: TextStyle(color: AppTheme.getTextSecondary(context)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          RichContent(question.text),

          if (question.options.isNotEmpty) ...[
            const Divider(height: 16),
            ...question.options.map((opt) {
              final count = optionCounts[opt.id] ?? 0;
              final pct = total == 0 ? 0.0 : count / total;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: opt.isCorrect
                                ? Colors.green
                                : cs.outline.withValues(alpha: 0.15),
                          ),
                          child: Center(
                            child: Text(
                              opt.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: opt.isCorrect
                                    ? Colors.white
                                    : cs.onSurface,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            opt.text,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          '$count (${(pct * 100).toInt()}%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: opt.isCorrect
                                ? Colors.green[700]
                                : AppTheme.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 4,
                        backgroundColor: cs.primary.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation(
                          opt.isCorrect ? Colors.green : cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          if (unanswered > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '$unanswered not answered',
                style: TextStyle(fontSize: 11, color: Colors.orange[700]),
              ),
            ),
        ],
      ),
    );
  }
}
