import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/organisation_provider.dart';
import 'package:htoochoon_flutter/Providers/class_provider.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/classroom_detail_screen.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/course_detail_screen.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';
import 'package:htoochoon_flutter/core/userorgrole_manager.dart';
import 'package:htoochoon_flutter/models/api_models/class_model.dart';
import 'package:htoochoon_flutter/models/api_models/course_model.dart';

import 'package:htoochoon_flutter/models/api_models/enrollment_model.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:htoochoon_flutter/models/api_models/program_model.dart';
import 'package:htoochoon_flutter/models/auth/auth_model.dart';
import 'package:provider/provider.dart';

// ── Shared Data Class ─────────────────────────────────────
class MemberEnrollment {
  final Enrollment enrollment;
  final User? user;
  MemberEnrollment({required this.enrollment, this.user});
}

// ── Shared Member Tile ────────────────────────────────────
class MemberTile extends StatelessWidget {
  final MemberEnrollment memberEnrollment;
  final bool isPending;
  final VoidCallback? onApprove;
  final VoidCallback? onDrop;

  const MemberTile({
    super.key,
    required this.memberEnrollment,
    required this.isPending,
    this.onApprove,
    this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = memberEnrollment.user;
    final name = user?.name ?? 'Unknown User';
    final email = user?.email ?? memberEnrollment.enrollment.userId;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.borderRadiusLg,
        side: BorderSide(color: AppTheme.getBorder(context)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd,
          vertical: AppTheme.spaceXs,
        ),
        leading: CircleAvatar(
          backgroundColor: cs.primary.withValues(alpha: 0.1),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          name,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          email.toString(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.getTextSecondary(context),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPending && onApprove != null)
              IconButton(
                icon: Icon(
                  Icons.check_circle_outline,
                  color: Colors.green[600],
                ),
                tooltip: 'Approve',
                onPressed: onApprove,
              ),
            IconButton(
              icon: Icon(
                isPending ? Icons.cancel_outlined : Icons.remove_circle_outline,
                color: Colors.red[400],
              ),
              tooltip: isPending ? 'Reject' : 'Remove',
              onPressed: () => _confirmDrop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDrop(BuildContext context) {
    final label = isPending ? 'Reject' : 'Remove';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label Member'),
        content: Text(
          '$label ${memberEnrollment.user?.name ?? 'this member'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onDrop?.call();
            },
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

// ── Course Card (used in ProgramDetailScreen) ─────────────
class CourseCard extends StatelessWidget {
  final CourseResponseForProgram course;
  final String? programName;
  final ProgramResponse program;
  final String organizationId;

  const CourseCard({
    super.key,
    required this.course,
    this.programName,
    required this.program,
    required this.organizationId,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    logD("COURSE CARD IS WORKING");
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: InkWell(
        onTap: () {
          final role = UserSessionManager.orgRole(organizationId);

          logD("ROLE CHECK INSIDE TAP: $role");
          logD("USING ORG ID: $organizationId");
          final isAdmin = role == Role.ORG_ADMIN;
          final isTeacher = role == Role.TEACHER;
          if (role == Role.ORG_ADMIN || role == Role.TEACHER) {
            Navigator.push(
              context,

              MaterialPageRoute(
                builder: (_) => CourseDetailScreen(
                  courseId: course.id,

                  courseName: course.name,

                  orgId: organizationId,
                ),
              ),
            );
          } else {
            Navigator.push(
              context,

              MaterialPageRoute(
                builder: (_) => StudentCourseDetailScreen(
                  orgId: organizationId,

                  courseId: course.id,

                  courseName: course.name,
                ),
              ),
            );
          }
        },
        borderRadius: AppTheme.borderRadiusLg,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: AppTheme.borderRadiusMd,
                ),
                child: Icon(Icons.book_rounded, color: cs.primary),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // if (course.description != null) ...[
                    //   const SizedBox(height: AppTheme.spaceXs),
                    //   Text(
                    //     course.description!,
                    //     maxLines: 2,
                    //     overflow: TextOverflow.ellipsis,
                    //     style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    //       color: AppTheme.getTextSecondary(context),
                    //     ),
                    //   ),
                    // ] else ...[
                    const SizedBox(height: AppTheme.spaceXs),
                    Text(
                      'No description',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                  // ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppTheme.getTextTertiary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Class Card (used in CourseDetailScreen) ───────────────
class ClassCard extends StatelessWidget {
  final ClassModel classItem;
  final String courseName;
  final String? programName;
  final String orgId;
  final bool isEditable; // Added protection parameter

  const ClassCard({
    super.key,
    required this.classItem,
    required this.courseName,
    this.programName,
    required this.orgId,
    required this.isEditable,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final classProv = context.read<ClassProvider>();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.borderRadiusLg,
        side: BorderSide(color: AppTheme.getBorder(context)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppTheme.spaceMd),
        leading: CircleAvatar(
          backgroundColor: cs.primary.withValues(alpha: 0.1),
          child: Icon(Icons.class_, color: cs.primary),
        ),
        title: Text(
          classItem.name.toString(),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppTheme.spaceXs),
            Text(
              'Teacher: ${classItem.teacher?.name ?? 'Unknown Teacher'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: AppTheme.getTextTertiary(context),
                ),
                const SizedBox(width: 4),
                Text(
                  'Starts: ${classItem.startDate.toString().split(' ')[0]}',
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),

        trailing: isEditable
            ? PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: AppTheme.getTextTertiary(context),
                ),
                onSelected: (action) {
                  if (action == 'edit') {
                    _showEditClassDialog(context, classProv);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Edit Class Info'),
                      ],
                    ),
                  ),
                ],
              )
            : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClassroomScreen(
                args: ClassroomArgs(
                  orgId: orgId,
                  courseId: classItem.courseId.toString(),
                  courseName: courseName,
                  courseCode: classItem.id
                      .toString()
                      .substring(0, 4)
                      .toUpperCase(),
                  description: 'Class details for ${classItem.name}',
                  entryPoint: programName != null
                      ? ClassEntryPoint.fromProgram
                      : ClassEntryPoint.direct,
                  programName: programName,
                  classId: classItem.id.toString(),
                  className: classItem.name.toString(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 📝 Stateful Update Dialog Box Frame
  void _showEditClassDialog(BuildContext context, dynamic provider) async {
    final nameCtrl = TextEditingController(text: classItem.name);
    final maxStudentsCtrl = TextEditingController(
      text: (classItem.maxStudents ?? 30).toString(),
    );
    DateTime selectedStart = classItem.startDate ?? DateTime.now();

    DateTime selectedEnd =
        classItem.endDate ?? selectedStart.add(const Duration(days: 90));
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setInnerState) => AlertDialog(
          title: const Text('Edit Class Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Batch/Class Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxStudentsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max Student Seat Limit',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Date Picking Group Setup
                ListTile(
                  title: const Text(
                    'Start Date',
                    style: TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(selectedStart.toString().split(' ')[0]),
                  trailing: const Icon(Icons.date_range),
                  dense: true,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedStart,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null)
                      setInnerState(() => selectedStart = picked);
                  },
                ),
                ListTile(
                  title: const Text(
                    'Expected End Date',
                    style: TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(selectedEnd.toString().split(' ')[0]),
                  trailing: const Icon(Icons.date_range),
                  dense: true,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedEnd,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null)
                      setInnerState(() => selectedEnd = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;

                final request = ClassRequest(
                  name: nameCtrl.text,
                  courseId: classItem.courseId.toString(),
                  startDate: selectedStart,
                  endDate: selectedEnd,
                  maxStudents: int.tryParse(maxStudentsCtrl.text) ?? 30,
                  teacherId: classItem.teacherId ?? classItem.teacher?.id ?? '',
                  organizationId: orgId,
                );

                Navigator.pop(ctx);

                final success = await provider.updateClass(
                  classItem.id,
                  request,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Class details modified successfully.'
                            : 'Failed to update class details.',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
