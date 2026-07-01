import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../Providers/submission_notes_provider.dart';
import '../../Widgets/state/async_view.dart';
import '../../core/haptics.dart';
import '../../core/userorgrole_manager.dart';
import '../../models/api_models/enums.dart';

/// Notes & feedback on a submission (Google-Classroom style):
/// - "Private comments" — shared between teacher and the student.
/// - "Teacher notes" — only visible to teachers/admins/staff.
/// Teachers also get a "Return work" action here.
class SubmissionNotesScreen extends StatefulWidget {
  final String submissionId;
  final String? studentName;
  final String? currentStatus;
  const SubmissionNotesScreen({
    super.key,
    required this.submissionId,
    this.studentName,
    this.currentStatus,
  });

  @override
  State<SubmissionNotesScreen> createState() => _SubmissionNotesScreenState();
}

class _SubmissionNotesScreenState extends State<SubmissionNotesScreen> {
  final _composer = TextEditingController();
  bool _teacherOnly = false;

  bool get _isStaff {
    final r = UserSessionManager.globalRole;
    return r == Role.TEACHER || r == Role.ORG_ADMIN || r == Role.STAFF;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubmissionNotesProvider>().load(widget.submissionId);
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _composer.text;
    if (body.trim().isEmpty) return;
    final ok = await context.read<SubmissionNotesProvider>().add(
          widget.submissionId,
          body: body,
          isTeacherOnly: _teacherOnly && _isStaff,
        );
    if (ok) {
      Haptics.light();
      _composer.clear();
    }
  }

  Future<void> _return() async {
    Haptics.success();
    final ok = await context
        .read<SubmissionNotesProvider>()
        .returnSubmission(widget.submissionId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Work returned to student' : 'Failed to return')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SubmissionNotesProvider>();
    final me = UserSessionManager.userId;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.studentName == null
            ? 'Feedback'
            : '${widget.studentName} · Feedback'),
        actions: [
          if (_isStaff)
            TextButton.icon(
              onPressed: _return,
              icon: const Icon(Icons.assignment_turned_in, size: 18),
              label: const Text('Return'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  context.read<SubmissionNotesProvider>().load(widget.submissionId),
              child: AsyncView<List<dynamic>>(
                loading: p.loading,
                error: p.error,
                data: p.notes,
                isEmpty: (n) => n.isEmpty,
                onRetry: () =>
                    context.read<SubmissionNotesProvider>().load(widget.submissionId),
                emptyIcon: Icons.comment_outlined,
                emptyTitle: 'No feedback yet',
                emptyMessage: _isStaff
                    ? 'Add a private comment or a teacher-only note below.'
                    : 'Your teacher hasn\'t left feedback yet.',
                builder: (_) {
                  final notes = p.notes!;
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: notes.length,
                    itemBuilder: (_, i) {
                      final n = notes[i];
                      final mine = n.authorId == me;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: n.isTeacherOnly
                              ? cs.tertiaryContainer.withValues(alpha: 0.5)
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: n.isTeacherOnly
                              ? Border.all(color: cs.tertiary, width: 1)
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  mine ? 'You' : (n.authorName ?? 'Someone'),
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 8),
                                if (n.isTeacherOnly)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cs.tertiary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('Teacher only',
                                        style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: cs.onTertiary)),
                                  ),
                                const Spacer(),
                                Text(DateFormat('MMM d, h:mm a').format(n.createdAt),
                                    style: TextStyle(
                                        fontSize: 10, color: cs.onSurfaceVariant)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(n.body),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(top: BorderSide(color: cs.outlineVariant)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isStaff)
                    Row(
                      children: [
                        Switch(
                          value: _teacherOnly,
                          onChanged: (v) => setState(() => _teacherOnly = v),
                        ),
                        Text('Teacher-only note',
                            style: TextStyle(
                                fontSize: 13, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _composer,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: _teacherOnly
                                ? 'Private note (teachers only)…'
                                : 'Add a comment…',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton.filled(
                        onPressed: p.posting ? null : _send,
                        icon: p.posting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
