import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Constants/text_constants.dart';
import 'package:htoochoon_flutter/Providers/class_provider.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/classroom_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:htoochoon_flutter/Providers/structure_provider.dart';
import 'package:htoochoon_flutter/models/api_models/class_model.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';
// Navigate into classroom detail — adjust import to your actual screen path
// import 'package:htoochoon_flutter/Screens/ClassroomScreen/classroom_screen.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';

class TeacherClassesScreen extends StatefulWidget {
  final String teacherId;
  final String organisationId;
  final bool isInShell;
  const TeacherClassesScreen({
    super.key,
    required this.teacherId,
    required this.organisationId,
    this.isInShell = false,
  });

  @override
  State<TeacherClassesScreen> createState() => _TeacherClassesScreenState();
}

class _TeacherClassesScreenState extends State<TeacherClassesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      logD("TEACHER ID: ${widget.teacherId}");
      context.read<ClassProvider>().fetchTeacherIdClass(
        widget.teacherId,
        widget.organisationId,
      );
    });
  }

  List<ClassModel> _filterMyClasses(List<ClassModel> all) {
    return all.where((c) => c.teacherId == widget.teacherId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final classProv = context.watch<ClassProvider>();
    final myClasses = _filterMyClasses(classProv.classes);

    return Scaffold(
      backgroundColor: cs.surface,
      body: RefreshIndicator(
        onRefresh: () => context.read<ClassProvider>().fetchClasses(
          widget.organisationId,
          widget.teacherId,
          null,
        ),
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──────────────────────────────────────
            SliverAppBar(
              automaticallyImplyLeading: !widget.isInShell,
              backgroundColor: const Color(0xFF0F7B6C),
              foregroundColor: Colors.white,
              pinned: true,
              expandedHeight: 120,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'My Classes',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F7B6C), Color(0xFF13A896)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),

            if (classProv.isLoading)
              const SliverToBoxAdapter(child: LinearProgressIndicator()),

            if (classProv.error != null)
              SliverToBoxAdapter(
                child: _ErrorBanner(
                  message: classProv.error!,
                  onDismiss: classProv.clearError,
                ),
              ),

            // ── Count header ─────────────────────────────────
            if (!classProv.isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceLg,
                    AppTheme.spaceLg,
                    AppTheme.spaceLg,
                    AppTheme.spaceSm,
                  ),
                  child: Text(
                    '${myClasses.length} ${myClasses.length == 1 ? 'class' : 'classes'} assigned to you',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.getTextSecondary(context),
                    ),
                  ),
                ),
              ),

            // ── Empty state ──────────────────────────────────
            if (myClasses.isEmpty && !classProv.isLoading)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.class_outlined, size: 56, color: cs.outline),
                      const SizedBox(height: 12),
                      const Text(
                        'No classes assigned to you yet.',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ask your admin to assign you to a class.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Class list ───────────────────────────────────
            if (myClasses.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceLg,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: AppTypography.kMd),
                      child: _ClassCard(
                        classId: myClasses[index].id.toString(),
                        orgId: widget.organisationId,

                        classItem: myClasses[index],
                        courseName:
                            myClasses[index].course?.name ?? 'Unknown Course',
                      ),
                    ),
                    childCount: myClasses.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Class Card
// ─────────────────────────────────────────────────────
class _ClassCard extends StatelessWidget {
  final String classId;
  final String orgId;
  final ClassModel classItem;
  final String courseName;
  final String? programName;

  const _ClassCard({
    super.key,
    required this.classId,
    required this.orgId,
    required this.classItem,
    required this.courseName,
    this.programName,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final isActive =
        (classItem.startDate?.isBefore(now) ?? false) &&
        (classItem.endDate?.isAfter(now) ?? false);

    final isUpcoming = classItem.startDate?.isAfter(now) ?? false;
    final statusLabel = isActive
        ? 'Active'
        : isUpcoming
        ? 'Upcoming'
        : 'Ended';
    final statusColor = isActive
        ? Colors.green
        : isUpcoming
        ? Colors.orange
        : Colors.grey;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip
          Container(
            height: 6,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              color: const Color(0xFF0F7B6C),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        classItem.name.toString(),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Course name
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 14,
                      color: AppTheme.getTextSecondary(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      classItem.course?.name ?? 'Unknown Course',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceMd),
                // Date range + students row
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.calendar_today_rounded,
                      label:
                          '${_fmt(classItem.startDate ?? DateTime.now())} → ${_fmt(classItem.endDate ?? DateTime.now())}',
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.people_alt_rounded,
                      label: '${classItem.maxStudents} max',
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceMd),
                // Enter classroom button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F7B6C),
                    ),
                    onPressed: () {
                      // TODO: Navigate to ClassroomScreen when ready
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
                              description:
                                  'Class details for ${classItem.name}',
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Opening ${classItem.name}...')),
                      );
                    },
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text('Enter Classroom'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year.toString().substring(2)}';
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.getTextSecondary(context)),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.getTextSecondary(context),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
