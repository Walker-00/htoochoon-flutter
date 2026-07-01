import 'package:htoochoon_flutter/core/log/app_logger.dart';
// ─────────────────────────────────────────────────────────────────────────────
// SUBMISSION FEEDBACK SCREEN  (Student view: graded assignment review)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:htoochoon_flutter/widgets/rich_content.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/assignment_screens.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/submission_notes_screen.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';
import 'package:collection/collection.dart';
import 'package:htoochoon_flutter/models/api_models/assignment_model.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';

class SubmissionFeedbackScreen extends StatelessWidget {
  final Assignment assignment;
  final Submission submission;
  final String classId;
  final String studentId;

  const SubmissionFeedbackScreen({
    super.key,
    required this.assignment,
    required this.submission,
    required this.classId,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = assignment;

    int calculateTotalPoints() {
      logD(a.questions.length);

      for (var q in a.questions) {
        logD("Question: ${q.text}");
        logD("Points: ${q.points}");
      }
      return a.questions.fold(0, (sum, question) => sum + question.points);
    }

    // final totalPoints = a.questions.fold<int>(0, (sum, q) => sum + q.points);
    //
    final totalPoints = calculateTotalPoints();
    final earnedPoints = submission.score?.toDouble() ?? 0.0;
    final percentage = totalPoints > 0
        ? (earnedPoints / totalPoints * 100)
        : 0.0;

    // ✅ Determine grade badge color/text based on percentage
    final (gradeColor, gradeLabel) = _getGradeBadge(percentage);

    return Scaffold(
      appBar: AppBar(
        title: Text(a.title),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        actions: [
          IconButton(
            tooltip: 'Feedback & notes',
            icon: const Icon(Icons.comment_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SubmissionNotesScreen(
                  submissionId: submission.id,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        children: [
          // ── Header: Score + Status Banner ──────────────────
          _buildScoreBanner(
            context,
            totalPoints,
            earnedPoints,
            gradeColor,
            gradeLabel,
          ),

          const SizedBox(height: AppTheme.spaceLg),

          // ── Overall Feedback (if provided by teacher) ─────
          if (submission.content?.isNotEmpty == true ||
              submission.content?.isNotEmpty == true)
            _buildOverallFeedback(context),

          if (submission.content?.isNotEmpty == true ||
              submission.content?.isNotEmpty == true)
            const SizedBox(height: AppTheme.spaceLg),

          // ── Questions Breakdown ───────────────────────────
          Text(
            'Question Breakdown',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppTheme.spaceMd),

          if (a.questions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              decoration: BoxDecoration(
                color: AppTheme.getSurfaceVariant(context),
                borderRadius: AppTheme.borderRadiusLg,
                border: Border.all(color: AppTheme.getBorder(context)),
              ),
              child: Column(
                children: [
                  Icon(Icons.assignment_outlined,
                      size: 40, color: AppTheme.getTextSecondary(context)),
                  const SizedBox(height: 8),
                  Text(
                    'No question details available for this submission.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.getTextSecondary(context)),
                  ),
                ],
              ),
            )
          else
            ...a.questions.map((fullQuestion) {
              final studentAnswer = submission.answers?.firstWhereOrNull(
                (ans) => ans.questionId == fullQuestion.id,
              );

              return _QuestionFeedbackCard(
                question: fullQuestion,
                studentAnswer: studentAnswer,

                isGraded: true,
              );
            }),
          const SizedBox(height: AppTheme.space2xl),

          // ── Action Buttons ────────────────────────────────
          _buildActionButtons(context, a),

          const SizedBox(height: AppTheme.spaceLg),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Helper: Score Banner Widget
  // ─────────────────────────────────────────────────────────
  Widget _buildScoreBanner(
    BuildContext context,
    int totalPoints,
    double earnedPoints,
    Color gradeColor,
    String gradeLabel,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isPerfect = earnedPoints == totalPoints;
    final isPassing = earnedPoints >= totalPoints * 0.6; // 60% threshold

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradeColor.withValues(alpha: 0.15), gradeColor.withValues(alpha: 0.05)],
        ),
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: gradeColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          // Score display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                earnedPoints.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: gradeColor,
                  height: 1,
                ),
              ),
              Text(
                ' / $totalPoints',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Grade badge + status
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: gradeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: gradeColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  gradeLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: gradeColor,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isPerfect
                    ? 'Perfect score! 🎉'
                    : isPassing
                    ? 'Well done! ✓'
                    : 'Keep practicing 💪',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalPoints > 0 ? earnedPoints / totalPoints : 0,
              backgroundColor: cs.primary.withValues(alpha: 0.1),
              color: gradeColor,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Helper: Overall Feedback Widget
  // ─────────────────────────────────────────────────────────
  Widget _buildOverallFeedback(BuildContext context) {
    // final feedbackText = submission?.isNotEmpty == true
    //     ? submission.content
    //     : submission.content; // Fallback to content if feedback is null

    // if (feedbackText?.isEmpty != false) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.comment_outlined, color: Colors.blue[700], size: 18),
              const SizedBox(width: 6),
              Text(
                'Teacher Feedback',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.blue[800],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Text(
          //   feedbackText!,
          //   style: TextStyle(
          //     color: Colors.blue[900],
          //     fontSize: 13,
          //     height: 1.4,
          //   ),
          // ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Helper: Action Buttons
  // ─────────────────────────────────────────────────────────
  Widget _buildActionButtons(BuildContext context, Assignment a) {
    final isOverdue =
        a.dueDate != null && a.dueDate!.isBefore(DateTime.now());

    return Column(
      children: [
        // Primary: Back to Assignments
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Assignments'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
            ),
          ),
        ),

        const SizedBox(height: AppTheme.spaceSm),

        // Secondary: View Assignment Details (optional)
        TextButton.icon(
          onPressed: () {
            Navigator.pop(context); // Close feedback first
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AssignmentDetailScreen(
                  isAssignment: false,
                  assignment: a,
                  classId: classId,
                  isAdminOrTeacher: false,
                  studentId: studentId,
                  existingSubmission: submission,
                ),
              ),
            );
          },
          icon: const Icon(Icons.info_outline),
          label: const Text('View Assignment Details'),
        ),

        // Optional: Retake button (if assignment allows & not overdue)
        // if (a.allowRetake && !isOverdue) ...[
        //   const SizedBox(height: AppTheme.spaceSm),
        //   SizedBox(
        //     width: double.infinity,
        //     child: FilledButton.icon(
        //       onPressed: () => _showRetakeConfirmation(context),
        //       icon: const Icon(Icons.refresh),
        //       label: const Text('Retry Assignment'),
        //     ),
        //   ),
        // ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // Helper: Grade Badge Logic
  // ─────────────────────────────────────────────────────────
  (Color, String) _getGradeBadge(double percentage) {
    if (percentage >= 90) return (Colors.green, 'Excellent');
    if (percentage >= 75) return (Colors.blue, 'Good');
    if (percentage >= 60) return (Colors.orange, 'Pass');
    return (Colors.red, 'Needs Improvement');
  }

  // ─────────────────────────────────────────────────────────
  // Optional: Retake Confirmation Dialog
  // ─────────────────────────────────────────────────────────
  // void _showRetakeConfirmation(BuildContext context) {
  //   showDialog(
  //     context: context,
  //     builder: (ctx) => AlertDialog(
  //       title: const Text('Retry Assignment?'),
  //       content: const Text(
  //         'Your previous submission will be kept for reference. '
  //         'Are you sure you want to start a new attempt?',
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(ctx),
  //           child: const Text('Cancel'),
  //         ),
  //         FilledButton(
  //           onPressed: () {
  //             Navigator.pop(ctx);
  //             Navigator.pushReplacement(
  //               context,
  //               MaterialPageRoute(
  //                 builder: (_) => TakeAssignmentScreen(
  //                   assignment: assignment,
  //                   studentId: studentId,
  //                   isRetake: true,
  //                 ),
  //               ),
  //             );
  //           },
  //           child: const Text('Start New Attempt'),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}

class _QuestionFeedbackCard extends StatelessWidget {
  final Question question;
  final SubmissionAnswer? studentAnswer; // ✅ Student's answer for this question
  final bool isGraded; // ✅ Show correctness indicators?

  const _QuestionFeedbackCard({
    required this.question,
    this.studentAnswer,
    this.isGraded = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseUrl = 'https://backend.htoochoon.com';

    // ── Per-question result state (Peacock palette) ──────────────
    //  correct → emerald · incorrect → coral · pending → gold
    final isCorrect = studentAnswer?.isCorrect;
    final isManualType = question.type == QuestionType.SHORT_ANSWER ||
        question.type == QuestionType.ESSAY;
    // Awaiting a human grade: graded view, an answer exists, but no verdict yet
    // (essay/short-answer before the teacher scores it).
    final isPending =
        isGraded && studentAnswer != null && isCorrect == null && isManualType;
    final Color stateColor = isCorrect == true
        ? AppTheme.success
        : isCorrect == false
            ? cs.error
            : isPending
                ? AppTheme.warning
                : AppTheme.getBorder(context);

    // ✅ Determine border color based on grading status
    final borderColor = isGraded && (isCorrect != null || isPending)
        ? stateColor.withValues(alpha: 0.5)
        : AppTheme.getBorder(context);

    // ✅ Find student's selected option for MCQ display
    final selectedOption = question.type == QuestionType.MULTIPLE_CHOICE
        ? question.options.firstWhereOrNull(
            (opt) => opt.id == studentAnswer?.selectedOptionId,
          )
        : null;

    // ✅ Find correct option for reference
    final correctOption = question.options.firstWhereOrNull(
      (opt) => opt.isCorrect == true,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(
          color: borderColor,
          width: isGraded ? 2 : 1,
        ), // ✅ Thicker border if graded
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header (unchanged) ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceMd,
              AppTheme.spaceMd,
              AppTheme.spaceMd,
              0,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.getSurfaceVariant(context),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    question.type.name.replaceAll('_', ' '),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      '${question.points} pts',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                        fontSize: 13,
                      ),
                    ),
                    // Points earned for this question, coloured by result state
                    // (emerald correct · coral incorrect · gold pending).
                    if (isGraded && studentAnswer != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        isPending
                            ? '— / ${question.points} pts'
                            : '${studentAnswer!.pointsEarned?.toInt() ?? 0}/${question.points} pts',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: stateColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // ── Question text (HTML) ──────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXs),
            child: RichContent(question.text),
          ),

          // ── Attachments (unchanged) ───────────────────
          if (question.attachments.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceMd,
                0,
                AppTheme.spaceMd,
                AppTheme.spaceSm,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: question.attachments.map((att) {
                  final isImage = att.fileType.startsWith('image/');
                  final url = '$baseUrl${att.fileUrl}';
                  return Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                    ),
                    child: isImage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.network(url, fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.insert_drive_file,
                                color: cs.primary,
                                size: 28,
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  att.fileName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 9),
                                ),
                              ),
                            ],
                          ),
                  );
                }).toList(),
              ),
            ),
          ],

          // ── ✅ NEW: Student's Answer Section ──────────
          // ── ✅ NEW: Student's Answer Section ──────────
          if (studentAnswer != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Your Answer:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.getTextPrimary(context),
                        ),
                      ),
                      // ✅ Correctness badge — correct / incorrect / pending
                      if (isGraded && (isCorrect != null || isPending)) ...[
                        const SizedBox(width: 8),
                        Builder(builder: (_) {
                          final label = isCorrect == true
                              ? 'Correct'
                              : isCorrect == false
                                  ? 'Incorrect'
                                  : 'Pending manual grading';
                          final icon = isCorrect == true
                              ? Icons.check_circle
                              : isCorrect == false
                                  ? Icons.cancel
                                  : Icons.hourglass_top;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: stateColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: stateColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, color: stateColor, size: 12),
                                const SizedBox(width: 2),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: stateColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),

                  // ✅ Display answer text properly based on type
                  if (question.type == QuestionType.MULTIPLE_CHOICE)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.spaceSm),
                      decoration: BoxDecoration(
                        color: AppTheme.getSurfaceVariant(context),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        selectedOption?.text ?? 'No answer selected',
                        style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.spaceSm),
                      decoration: BoxDecoration(
                        color: AppTheme.getSurfaceVariant(context),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        // Checks textAnswer fallback if essay/short essay
                        studentAnswer!.textAnswer?.isNotEmpty == true
                            ? studentAnswer!.textAnswer!
                            : 'No response text provided.',
                        style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                        ),
                      ),
                    ),

                  // ✅ Reveal the correct option when the MCQ answer was wrong
                  if (isGraded &&
                      isCorrect == false &&
                      question.type == QuestionType.MULTIPLE_CHOICE &&
                      correctOption != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Correct Answer:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.success,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.spaceSm),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppTheme.success.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        correctOption.text,
                        style: TextStyle(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],

                  // ✅ Show teacher feedback if available (FIXED CONDITIONAL)
                  if (isGraded &&
                      studentAnswer!.feedback?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.comment_outlined,
                          size: 14,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Teacher Feedback:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.spaceSm),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        // FIX: Changed from studentAnswer!.textAnswer to studentAnswer!.feedback
                        studentAnswer!.feedback!,
                        style: TextStyle(color: Colors.blue[800], fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          // if (studentAnswer != null) ...[
          //   const Divider(height: 1),
          //   Padding(
          //     padding: const EdgeInsets.all(AppTheme.spaceMd),
          //     child: Column(
          //       crossAxisAlignment: CrossAxisAlignment.start,
          //       children: [
          //         Row(
          //           children: [
          //             Text(
          //               'Your Answer:',
          //               style: TextStyle(
          //                 fontWeight: FontWeight.w600,
          //                 color: AppTheme.getTextPrimary(context),
          //               ),
          //             ),
          //             // ✅ Correctness badge
          //             if (isGraded && studentAnswer!.isCorrect != null) ...[
          //               const SizedBox(width: 8),
          //               Container(
          //                 padding: const EdgeInsets.symmetric(
          //                   horizontal: 6,
          //                   vertical: 2,
          //                 ),
          //                 decoration: BoxDecoration(
          //                   color: studentAnswer!.isCorrect!
          //                       ? Colors.green.withValues(alpha: 0.1)
          //                       : Colors.red.withValues(alpha: 0.1),
          //                   borderRadius: BorderRadius.circular(4),
          //                   border: Border.all(
          //                     color: studentAnswer!.isCorrect!
          //                         ? Colors.green.withValues(alpha: 0.4)
          //                         : Colors.red.withValues(alpha: 0.4),
          //                   ),
          //                 ),
          //                 child: Row(
          //                   mainAxisSize: MainAxisSize.min,
          //                   children: [
          //                     Icon(
          //                       studentAnswer!.isCorrect!
          //                           ? Icons.check_circle
          //                           : Icons.cancel,
          //                       color: studentAnswer!.isCorrect!
          //                           ? Colors.green
          //                           : Colors.red,
          //                       size: 12,
          //                     ),
          //                     const SizedBox(width: 2),
          //                     Text(
          //                       (studentAnswer!.isCorrect! ||
          //                               studentAnswer!.selectedAnswer ==
          //                                   question.correctAnswer ||
          //                               studentAnswer!.selectedOptionId ==
          //                                   question.correctOptionId)
          //                           ? 'Correct'
          //                           : 'Incorrect',
          //                       style: TextStyle(
          //                         fontSize: 10,
          //                         fontWeight: FontWeight.w600,
          //                         color: studentAnswer!.isCorrect!
          //                             ? Colors.green
          //                             : Colors.red,
          //                       ),
          //                     ),
          //                   ],
          //                 ),
          //               ),
          //             ],
          //           ],
          //         ),
          //         const SizedBox(height: 6),
          //
          //         // ✅ Display answer based on question type
          //         if (question.type == QuestionType.MULTIPLE_CHOICE)
          //           Container(
          //             padding: const EdgeInsets.all(AppTheme.spaceSm),
          //             decoration: BoxDecoration(
          //               color: AppTheme.getSurfaceVariant(context),
          //               borderRadius: BorderRadius.circular(6),
          //             ),
          //             child: Text(
          //               selectedOption?.text ?? 'No answer selected',
          //               style: TextStyle(
          //                 color: AppTheme.getTextPrimary(context),
          //                 fontWeight: FontWeight.w500,
          //               ),
          //             ),
          //           )
          //         else
          //           Container(
          //             padding: const EdgeInsets.all(AppTheme.spaceSm),
          //             decoration: BoxDecoration(
          //               color: AppTheme.getSurfaceVariant(context),
          //               borderRadius: BorderRadius.circular(6),
          //             ),
          //             child: Text(
          //               studentAnswer!.textAnswer ?? 'No text answer',
          //               style: TextStyle(
          //                 color: AppTheme.getTextPrimary(context),
          //               ),
          //             ),
          //           ),
          //
          //         // ✅ Show correct answer if student was wrong (for learning)
          //         if (isGraded &&
          //             studentAnswer!.isCorrect == false &&
          //             correctOption != null) ...[
          //           const SizedBox(height: 12),
          //           Text(
          //             'Correct Answer:',
          //             style: TextStyle(
          //               fontWeight: FontWeight.w600,
          //               color: Colors.green[700],
          //               fontSize: 12,
          //             ),
          //           ),
          //           const SizedBox(height: 4),
          //           Container(
          //             padding: const EdgeInsets.all(AppTheme.spaceSm),
          //             decoration: BoxDecoration(
          //               color: Colors.green.withValues(alpha: 0.08),
          //               borderRadius: BorderRadius.circular(6),
          //               border: Border.all(
          //                 color: Colors.green.withValues(alpha: 0.3),
          //               ),
          //             ),
          //             child: Text(
          //               correctOption.text,
          //               style: TextStyle(
          //                 color: Colors.green[800],
          //                 fontWeight: FontWeight.w500,
          //               ),
          //             ),
          //           ),
          //         ],
          //
          //         // ✅ Show teacher feedback if available
          //         if (isGraded &&
          //             (studentAnswer!.textAnswer?.isNotEmpty == true ||
          //                 studentAnswer!.textAnswer != null)) ...[
          //           const SizedBox(height: 12),
          //           Row(
          //             children: [
          //               Icon(
          //                 Icons.comment_outlined,
          //                 size: 14,
          //                 color: Colors.blue[700],
          //               ),
          //               const SizedBox(width: 4),
          //               Text(
          //                 'Feedback:',
          //                 style: TextStyle(
          //                   fontWeight: FontWeight.w600,
          //                   color: Colors.blue[700],
          //                   fontSize: 12,
          //                 ),
          //               ),
          //               Text(
          //                 studentAnswer?.feedback.toString() ?? '',
          //                 style: TextStyle(
          //                   fontWeight: FontWeight.w600,
          //                   color: Colors.blue[700],
          //                   fontSize: 12,
          //                 ),
          //               ),
          //             ],
          //           ),
          //           const SizedBox(height: 4),
          //           Container(
          //             padding: const EdgeInsets.all(AppTheme.spaceSm),
          //             decoration: BoxDecoration(
          //               color: Colors.blue.withValues(alpha: 0.08),
          //               borderRadius: BorderRadius.circular(6),
          //               border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          //             ),
          //             child: Text(
          //               studentAnswer!.textAnswer ?? '',
          //               style: TextStyle(color: Colors.blue[800], fontSize: 12),
          //             ),
          //           ),
          //         ],
          //       ],
          //     ),
          //   ),
          // ],

          // ── Options (for reference, unchanged styling) ─
          if (question.options.isNotEmpty &&
              question.type == QuestionType.MULTIPLE_CHOICE) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              child: Column(
                children: question.options.map((opt) {
                  final isStudentChoice =
                      opt.id == studentAnswer?.selectedOptionId;
                  final isCorrect = opt.isCorrect == true;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? AppTheme.success.withValues(alpha: 0.08)
                          : isStudentChoice && !isCorrect
                          ? cs.error.withValues(alpha: 0.08)
                          : AppTheme.getSurfaceVariant(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCorrect
                            ? AppTheme.success.withValues(alpha: 0.4)
                            : isStudentChoice && !isCorrect
                            ? cs.error.withValues(alpha: 0.4)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCorrect
                                ? AppTheme.success
                                : isStudentChoice
                                ? cs.error
                                : cs.outline.withValues(alpha: 0.2),
                          ),
                          child: Center(
                            child: Text(
                              opt.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isCorrect || isStudentChoice
                                    ? Colors.white
                                    : cs.onSurface,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(opt.text)),
                        if (isCorrect)
                          const Icon(
                            Icons.check_circle,
                            color: AppTheme.success,
                            size: 16,
                          ),
                        if (isStudentChoice && !isCorrect)
                          Icon(Icons.close, color: cs.error, size: 16),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
