import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:htoochoon_flutter/Constants/text_constants.dart';
import 'package:htoochoon_flutter/Live-Session/core/services/socket_service.dart';
import 'package:htoochoon_flutter/Live-Session/features/meeting/meeting_page.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/live_sessions_provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/organisation_provider.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/assignment_screens.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/course_analytics_screen.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/course_chat_screen.dart';
import 'package:htoochoon_flutter/Screens/Analytics/at_risk_screen.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/submission_detail_screen.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/submission_feedback_screen.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/take_assignment_screen.dart';
import 'package:htoochoon_flutter/api/api_service.dart';
import 'package:htoochoon_flutter/core/token_manager.dart';
import 'package:htoochoon_flutter/core/userorgrole_manager.dart';
import 'package:htoochoon_flutter/models/api_models/live_session_model.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/schedule_session_wizard.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/session_actions_menu.dart';
import 'package:htoochoon_flutter/models/api_models/organization_model.dart';
import 'package:htoochoon_flutter/models/auth/auth_model.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';
import 'package:htoochoon_flutter/Providers/assignment_provider.dart';
import 'package:htoochoon_flutter/Providers/material_provider.dart';
import 'package:htoochoon_flutter/models/api_models/material_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:htoochoon_flutter/Providers/class_provider.dart';
import 'package:htoochoon_flutter/Providers/auth_provider.dart';
import 'package:htoochoon_flutter/models/api_models/assignment_model.dart';
import 'package:htoochoon_flutter/models/api_models/submission_model.dart';
import 'package:htoochoon_flutter/models/api_models/class_model.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Entry point enum ──────────────────────────────────────
enum ClassEntryPoint { direct, fromProgram }

// ── Args ──────────────────────────────────────────────────
class ClassroomArgs {
  final String courseId;
  final String classId;
  final String courseName;
  final String courseCode;

  final String description;
  final ClassEntryPoint entryPoint;
  final String? programName;
  final String className;
  final String orgId;
  // A template (academic) course: no live sessions or people management — only
  // materials + draft assignments/exams.
  final bool isTemplate;

  const ClassroomArgs({
    required this.courseId,
    required this.classId,
    required this.courseName,
    required this.courseCode,
    required this.description,
    required this.entryPoint,
    required this.className,
    this.programName,
    required this.orgId,
    this.isTemplate = false,
  });
}

// ── Screen ────────────────────────────────────────────────

class ClassroomScreen extends StatefulWidget {
  final ClassroomArgs args;

  const ClassroomScreen({super.key, required this.args});

  @override
  State<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends State<ClassroomScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isAdminOrTeacher = false;

  @override
  void initState() {
    super.initState();
    // Templates drop the Sessions + People tabs (3 instead of 5).
    _tabController = TabController(
      length: widget.args.isTemplate ? 3 : 5,
      vsync: this,
      initialIndex: 0,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final role = UserSessionManager.orgRole(widget.args.orgId);

      debugPrint("🎭 Role in org ${widget.args.orgId}: $role");
      debugPrint("👤 Current user: ${UserSessionManager.user?.email}");

      final isAdminOrTeacher = role == Role.ORG_ADMIN || role == Role.TEACHER;
      setState(() {
        _isAdminOrTeacher = isAdminOrTeacher;
      });

      final assignProv = context.read<AssignmentProvider>();
      // Students only see published assessments; teachers/admins see drafts too.
      await Future.wait([
        assignProv.fetchAssignments(
          widget.args.classId,
          publishedOnly: isAdminOrTeacher ? null : true,
        ),
      ]);

      final classProv = context.read<ClassProvider>();
      if (classProv.classes.isEmpty) {
        await classProv.fetchClasses(
          widget.args.orgId,
          null,
          widget.args.courseId,
        );
      }

      final orgProvider = context.read<OrganizationProvider>();
      if (orgProvider.userCache.isEmpty && orgProvider.members.isNotEmpty) {
        await orgProvider.preloadMembers(orgProvider.members);
      }

      // Pre-fetch live sessions so the Hero widget knows instantly if someone is live
      if (mounted) {
        context.read<LiveSessionProvider>().fetchSessionsByStatus(
          orgId: widget.args.orgId,
          classId: widget.args.classId,
          targetStatus: "LIVE",
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Inside Class ClassroomScreenState...
  // ✅ FIX: Accept context parameter explicitly from call site
  Future<void> _handleStudentDirectJoin(
    BuildContext executionContext,
    dynamic activeLiveSession,
  ) async {
    if (activeLiveSession == null) return;

    // Capture states safely using the passing context reference
    final navigator = Navigator.of(executionContext);
    final scaffoldMessenger = ScaffoldMessenger.of(executionContext);

    final nameCtrl = TextEditingController(
      text: UserSessionManager.user?.name ?? 'Student',
    );
    final roomCtrl = TextEditingController(
      text: activeLiveSession?.roomId ?? '',
    );
    final formKey = GlobalKey<FormState>();

    final dialogResult = await showDialog<Map<String, String>>(
      context: executionContext, // 👈 Use execution context
      barrierDismissible: false,
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.blur_on, color: cs.primary),
              const SizedBox(width: 8),
              const Text('Join Live Session'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Display Name ✏️',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: roomCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Room ID / Code 🔑',
                    border: OutlineInputBorder(),
                    helperText: "Enter the code shared by your teacher",
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Room ID / Code is required'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, {
                    'name': nameCtrl.text.trim(),
                    'roomId': roomCtrl.text.trim(),
                  });
                }
              },
              child: const Text('Enter Room ✨'),
            ),
          ],
        );
      },
    );

    if (dialogResult == null) return;

    if (!executionContext.mounted) return;
    final sessionProv = executionContext.read<LiveSessionProvider>();

    final success = await sessionProv.studentJoinSession(
      sessionId: activeLiveSession.id,
      name: dialogResult['name']!,
    );
    logD("join called");

    if (success && executionContext.mounted) {
      final tokenManager = TokenManager();
      final String accessToken =
          (sessionProv.accessToken != null &&
              sessionProv.accessToken!.isNotEmpty)
          ? sessionProv.accessToken!
          : await tokenManager.getToken() ?? '';
      final String refreshToken =
          (sessionProv.refreshToken != null &&
              sessionProv.refreshToken!.isNotEmpty)
          ? sessionProv.refreshToken!
          : await tokenManager.getRefreshToken() ?? '';

      final socketService = SocketService();
      socketService.connect(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      // ✅ Use pre-captured context-safe navigator
      navigator.push(
        MaterialPageRoute(
          builder: (_) => MeetingPage(
            sessionId: activeLiveSession.id,
            isLocal: false,
            roomId: dialogResult['roomId']!,
            role: 'student',
            userName: dialogResult['name']!,
            socketService: socketService,
            accessToken: accessToken,
            refreshToken: refreshToken,
          ),
        ),
      );
    } else if (!success && executionContext.mounted) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Failed to join live session.')),
      );
    }
  }
  // Future<void> _handleStudentDirectJoin(dynamic activeLiveSession) async {
  //   if (activeLiveSession == null) return;
  //
  //   final nameCtrl = TextEditingController(
  //     text: UserSessionManager.user?.name ?? 'Student',
  //   );
  //   final roomCtrl = TextEditingController(
  //     text: activeLiveSession?.roomId ?? '',
  //   );
  //   final formKey = GlobalKey<FormState>();
  //
  //   final dialogResult = await showDialog<Map<String, String>>(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (context) {
  //       final cs = Theme.of(context).colorScheme;
  //       return AlertDialog(
  //         title: Row(
  //           children: [
  //             Icon(Icons.blur_on, color: cs.primary),
  //             const SizedBox(width: 8),
  //             const Text('Join Live Session'),
  //           ],
  //         ),
  //         content: Form(
  //           key: formKey,
  //           child: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               TextFormField(
  //                 controller: nameCtrl,
  //                 decoration: const InputDecoration(
  //                   labelText: 'Display Name ✏️',
  //                   border: OutlineInputBorder(),
  //                 ),
  //                 validator: (v) => (v == null || v.trim().isEmpty)
  //                     ? 'Name is required'
  //                     : null,
  //               ),
  //               const SizedBox(height: 16),
  //               TextFormField(
  //                 controller: roomCtrl,
  //                 decoration: const InputDecoration(
  //                   labelText: 'Room ID / Code 🔑',
  //                   border: OutlineInputBorder(),
  //                   helperText: "Enter the code shared by your teacher",
  //                 ),
  //                 validator: (v) => (v == null || v.trim().isEmpty)
  //                     ? 'Room ID / Code is required'
  //                     : null,
  //               ),
  //             ],
  //           ),
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(context, null),
  //             child: const Text('Cancel'),
  //           ),
  //           FilledButton(
  //             onPressed: () {
  //               if (formKey.currentState?.validate() ?? false) {
  //                 Navigator.pop(context, {
  //                   'name': nameCtrl.text.trim(),
  //                   'roomId': roomCtrl.text.trim(),
  //                 });
  //               }
  //             },
  //             child: const Text('Enter Room ✨'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  //
  //   if (dialogResult == null) return;
  //
  //   // 🔥 Navigate and connect directly from the parent context level
  //   if (!mounted) return;
  //   final sessionProv = context.read<LiveSessionProvider>();
  //
  //   final success = await sessionProv.studentJoinSession(
  //     sessionId: activeLiveSession.id,
  //     name: dialogResult['name']!,
  //   );
  //
  //   if (success && mounted) {
  //     final tokenManager = TokenManager();
  //     final String accessToken =
  //         (sessionProv.accessToken != null &&
  //             sessionProv.accessToken!.isNotEmpty)
  //         ? sessionProv.accessToken!
  //         : await tokenManager.getToken() ?? '';
  //     final String refreshToken =
  //         (sessionProv.refreshToken != null &&
  //             sessionProv.refreshToken!.isNotEmpty)
  //         ? sessionProv.refreshToken!
  //         : await tokenManager.getRefreshToken() ?? '';
  //
  //     final socketService = SocketService();
  //     socketService.connect(
  //       accessToken: accessToken,
  //       refreshToken: refreshToken,
  //     );
  //
  //     Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (_) => MeetingPage(
  //           sessionId: activeLiveSession.id,
  //           isLocal: false,
  //           roomId: dialogResult['roomId']!,
  //           role: 'student',
  //           userName: dialogResult['name']!,
  //           socketService: socketService,
  //           accessToken: accessToken,
  //           refreshToken: refreshToken,
  //         ),
  //       ),
  //     );
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final args = widget.args;
    final currentUserOrgRole =
        UserSessionManager.user?.role.toString() ?? "TEACHER";

    // 💡 Declared here at the top of build() so the entire widget layout tree can safely evaluate it
    final sessionProv = context.watch<LiveSessionProvider>();
    final activeLiveSession = sessionProv.liveSessions.firstWhereOrNull(
      (s) => s.courseId == args.courseId && s.status == LiveSessionStatus.live,
    );

    final userName = UserSessionManager.user?.name ?? 'User';
    final initials = userName.length >= 2
        ? userName.substring(0, 2).toUpperCase()
        : userName.toUpperCase();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            floating: false,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: cs.onSurface,
            elevation: 0,
            scrolledUnderElevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Expanded(child: _Breadcrumb(args: args))],
            ),
            actions: [
              if (_isAdminOrTeacher && !args.isTemplate)
                IconButton(
                  tooltip: 'Course analytics',
                  icon: const Icon(Icons.bar_chart_rounded),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourseAnalyticsScreen(
                        courseId: args.courseId,
                        courseName: args.courseName,
                      ),
                    ),
                  ),
                ),
              if (_isAdminOrTeacher && !args.isTemplate)
                IconButton(
                  tooltip: 'At-risk students',
                  icon: const Icon(Icons.warning_amber_rounded),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AtRiskScreen(
                        courseId: args.courseId,
                        courseName: args.courseName,
                      ),
                    ),
                  ),
                ),
              if (!args.isTemplate)
                IconButton(
                  tooltip: 'Course chat',
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourseChatScreen(
                        courseId: args.courseId,
                        courseName: args.courseName,
                      ),
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: cs.primary.withValues(alpha: 0.15),
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 10,
                      overflow: TextOverflow.fade,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.inversePrimary,
                    ),
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0),
              child: Divider(
                height: 0.5,
                thickness: 0.5,
                color: AppTheme.getBorder(context),
              ),
            ),
          ),

          // Hero info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    args.isTemplate
                        ? 'Template for ${args.courseName}'
                        : (args.programName != null &&
                                args.programName!.trim().isNotEmpty)
                            ? '${args.programName}: ${args.courseName}'
                            : args.courseName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    args.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.getTextSecondary(context),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _isAdminOrTeacher
                      ? Column(
                          children: [
                            // Templates have no live sessions — hide the button.
                            if (!args.isTemplate)
                            OutlinedButton.icon(
                              onPressed: () {
                                final role =
                                    UserSessionManager.user?.role ?? "ADMIN";
                                if (role == Role.ORG_ADMIN) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Only teachers can schedule sessions. Admins do not have host permission. 💢',
                                      ),
                                      backgroundColor: Colors.orange,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                ScheduleSessionWizard.show(
                                  context,
                                  classId: widget.args.classId,
                                  orgId: widget.args.orgId,
                                  hostId: UserSessionManager.userId ?? '',
                                  className: widget.args.className,
                                );
                              },
                              icon: const Icon(
                                Icons.videocam_outlined,
                                size: 16,
                              ),
                              label: const Text('Schedule a Live Session'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppTheme.borderRadiusMd,
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            // OutlinedButton.icon(
                            //   onPressed: () =>
                            //       _showCreateScheduleSessionDialog(context),
                            //   icon: const Icon(
                            //     Icons.videocam_outlined,
                            //     size: 16,
                            //   ),
                            //   label: const Text('Start Live Session'),
                            //   style: OutlinedButton.styleFrom(
                            //     shape: RoundedRectangleBorder(
                            //       borderRadius: AppTheme.borderRadiusMd,
                            //     ),
                            //   ),
                            // ),
                          ],
                        )
                      : FilledButton.icon(
                          onPressed: () => _handleStudentDirectJoin(
                            context,
                            activeLiveSession,
                          ),
                          icon: Icon(
                            activeLiveSession != null
                                ? Icons.sensors
                                : Icons.cast_connected_outlined,
                            size: 16,
                          ),
                          label: Text(
                            activeLiveSession != null
                                ? 'Join Live Now 🎉'
                                : 'Join with Code 🔑',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: activeLiveSession != null
                                ? Colors.red
                                : cs.primary,
                            foregroundColor: cs.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppTheme.borderRadiusMd,
                            ),
                          ),
                        ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Tab bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              TabBar(
                controller: _tabController,
                tabs: [
                  const Tab(text: 'Assignments'),
                  const Tab(text: 'Exams'),
                  // Templates have no live sessions or people.
                  if (!args.isTemplate) const Tab(text: 'Sessions'),
                  const Tab(text: 'Materials'),
                  if (!args.isTemplate) const Tab(text: 'People'),
                ],
                labelColor: cs.primary,
                unselectedLabelColor: AppTheme.getTextSecondary(context),
                indicatorColor: cs.primary,
                indicatorWeight: 2,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                dividerColor: AppTheme.getBorder(context),
                isScrollable: true,
                tabAlignment: TabAlignment.start,
              ),
              Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _AssignmentsTab(
              classId: args.classId,
              isAdminOrTeacher: _isAdminOrTeacher,
              isTemplate: args.isTemplate,
            ),
            _ExamsTab(
              classId: args.classId,
              isAdminOrTeacher: _isAdminOrTeacher,
              isTemplate: args.isTemplate,
            ),
            if (!args.isTemplate)
              _SessionsTab(
                organizationId: args.orgId,
                classId: args.classId,
                isAdminOrTeacher: _isAdminOrTeacher,
                onStudentJoinRequested: (session) =>
                    _handleStudentDirectJoin(context, session),
              ),
            _MaterialsTab(
              classId: args.classId,
              isAdminOrTeacher: _isAdminOrTeacher,
            ),
            if (!args.isTemplate)
              _PeopleTab(
                classId: args.classId,
                isAdminOrTeacher: _isAdminOrTeacher,
                organizationId: args.orgId,
              ),
          ],
        ),
      ),
    );
  }

  // Leave your existing showDateTimePicker and _showCreateSessionDialog intact below...
  Future<DateTime?> showDateTimePicker(
    BuildContext context,
    DateTime initial,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _showCreateScheduleSessionDialog(BuildContext context) {
    final liveSessionProv = context.read<LiveSessionProvider>();
    final orgProv = context.read<OrganizationProvider>();
    final titleCtrl = TextEditingController();
    DateTime? startTime;
    DateTime? endTime;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Start Live Session'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Session Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // Start time picker
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showDateTimePicker(
                      ctx,
                      // ✅ Default to 15 min from now, not DateTime.now()
                      DateTime.now().add(const Duration(minutes: 15)),
                    );
                    if (picked != null) setState(() => startTime = picked);
                  },
                  child: Text(
                    startTime == null
                        ? 'Pick Start Time'
                        : startTime.toString(),
                  ),
                ),

                // End time picker
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showDateTimePicker(
                      ctx,
                      //  Default to 1hr after start (or now+1hr if start not picked)
                      (startTime ?? DateTime.now()).add(
                        const Duration(hours: 1),
                      ),
                    );
                    if (picked != null) setState(() => endTime = picked);
                  },
                  child: Text(
                    endTime == null ? 'Pick End Time' : endTime.toString(),
                  ),
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
                  final messenger = ScaffoldMessenger.of(context);

                  // 1. Empty field guard
                  if (titleCtrl.text.isEmpty ||
                      startTime == null ||
                      endTime == null) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Please fill in all fields.'),
                      ),
                    );
                    return;
                  }

                  final now = DateTime.now();

                  final tomorrow = DateTime(now.year, now.month, now.day + 1);

                  if (startTime!.isBefore(tomorrow)) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Sessions must be scheduled for a future date, not today.',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  // // 2. Start time must be in the future
                  // if (!startTime!.isAfter(
                  //   now.add(const Duration(minutes: 1)),
                  // )) {
                  //   messenger.showSnackBar(
                  //     const SnackBar(
                  //       content: Text(
                  //         'Start time must be at least 1 minute in the future.',
                  //       ),
                  //       backgroundColor: Colors.red,
                  //     ),
                  //   );
                  //   return;
                  // }

                  // 3. End time must be after start time
                  if (!endTime!.isAfter(startTime!)) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('End time must be after start time.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final request = LiveSessionRequest(
                    topic: titleCtrl.text.trim(),
                    courseId: widget.args.courseId,
                    hostId: UserSessionManager.userId ?? orgProv.currentUserId!,
                    startTime: startTime!.toUtc().toIso8601String(),
                    endTime: endTime!.toUtc().toIso8601String(),
                    status: LiveSessionStatus.scheduled,
                  );

                  final result = await liveSessionProv.createSession(request);

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (result == null) {
                    final error = liveSessionProv.error ?? '';
                    final String message;

                    if (error.contains('403') ||
                        error.contains('Forbidden') ||
                        error.contains('does not have permission')) {
                      message =
                          'The designated host does not have permission to host sessions in this organization. 💢';
                    } else if (error.isNotEmpty) {
                      message = error;
                    } else {
                      message = 'Failed to schedule session. Please try again.';
                    }

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(message),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return; // ← keep dialog open
                  }

                  // 5. Success
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Session scheduled successfully! 🎉'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('Schedule'),
              ),
            ],
          );
        },
      ),
    );
  }

  // void _showLiveNowSessionDialog(BuildContext context) {
  //   final liveSessionProv = context.read<LiveSessionProvider>();
  //   final orgProv = context.read<OrganizationProvider>();
  //   final titleCtrl = TextEditingController();
  //   DateTime? startTime;
  //   DateTime? endTime;
  //
  //   showDialog(
  //     context: context,
  //     builder: (ctx) => StatefulBuilder(
  //       builder: (ctx, setState) {
  //         return AlertDialog(
  //           title: const Text('Start Live Session'),
  //           content: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               TextField(
  //                 controller: titleCtrl,
  //                 decoration: const InputDecoration(
  //                   labelText: 'Session Title',
  //                   border: OutlineInputBorder(),
  //                 ),
  //               ),
  //               const SizedBox(height: 12),
  //               ElevatedButton(
  //                 onPressed: () async {
  //                   final picked = await showDateTimePicker(
  //                     ctx,
  //                     DateTime.now(),
  //                   );
  //                   if (picked != null) setState(() => startTime = picked);
  //                 },
  //                 child: Text(
  //                   startTime == null
  //                       ? 'Pick Start Time'
  //                       : startTime.toString(),
  //                 ),
  //               ),
  //               const SizedBox(height: 8),
  //               ElevatedButton(
  //                 onPressed: () async {
  //                   final picked = await showDateTimePicker(
  //                     ctx,
  //                     DateTime.now(),
  //                   );
  //                   if (picked != null) setState(() => endTime = picked);
  //                 },
  //                 child: Text(
  //                   endTime == null ? 'Pick End Time' : endTime.toString(),
  //                 ),
  //               ),
  //             ],
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.pop(ctx),
  //               child: const Text('Cancel'),
  //             ),
  //             ElevatedButton(
  //               onPressed: () async {
  //                 if (titleCtrl.text.isEmpty ||
  //                     startTime == null ||
  //                     endTime == null)
  //                   return;
  //                 Navigator.pop(ctx);
  //                 final request = LiveSessionRequest(
  //                   topic: titleCtrl.text.trim(),
  //                   classId: widget.args.classId,
  //                   hostId: UserSessionManager.userId ?? orgProv.currentUserId!,
  //                   startTime: startTime!.toUtc().toIso8601String(),
  //                   endTime: endTime!.toUtc().toIso8601String(),
  //                   status: LiveSessionStatus.live,
  //                 );
  //                 await liveSessionProv.createSession(request);
  //               },
  //               child: const Text('Start'),
  //             ),
  //           ],
  //         );
  //       },
  //     ),
  //   );
  // }
}

class _AssignmentsTab extends StatefulWidget {
  final String classId;
  final bool isAdminOrTeacher;
  // Template courses are draft-only (no publish). Real program courses publish.
  final bool isTemplate;

  const _AssignmentsTab({
    required this.classId,
    required this.isAdminOrTeacher,
    this.isTemplate = false,
  });

  @override
  State<_AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends State<_AssignmentsTab> {
  // studentId → submissionMap (assessmentId → Submission)
  Map<String, Submission> _submittedMap = {};
  Assignment? _detailedAssignment;
  @override
  void initState() {
    super.initState();
    if (!widget.isAdminOrTeacher) _loadMySubmissions();
  }

  Future<void> _loadMySubmissions() async {
    final authProv = context.read<AuthProvider>();
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getString("user_id") ?? '';
    if (studentId.isEmpty) return;
    try {
      final subs = await context
          .read<AssignmentProvider>()
          .fetchStudentSubmissionsRaw(studentId: studentId);
      if (!mounted) return;
      setState(() {
        for (final s in subs) {
          logD('📦 Submission Debug:');
          logD('   - s.id: ${s.id}');
          logD('   - s.assessmentId: ${s.assessmentId}');
          logD('   - s.effectiveAssessmentId: ${s.effectiveAssessmentId}');
          logD(
            '   - Expected key (assignment.id): 9e72ee74-0515-4fdf-b681-cd6eec0b01d3',
          );
          logD(
            '   - Match assessmentId? ${s.assessmentId == "9e72ee74-0515-4fdf-b681-cd6eec0b01d3"}',
          );
          logD(
            '   - Match effectiveAssessmentId? ${s.effectiveAssessmentId == "9e72ee74-0515-4fdf-b681-cd6eec0b01d3"}',
          );
        }

        _submittedMap = {for (final s in subs) s.effectiveAssessmentId: s};
      });
      setState(() {});
    } catch (e, stack) {
      logD('❌ Error loading submissions: $e');
      logD('Stack: $stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final assignProv = context.watch<AssignmentProvider>();
    final authProv = context.read<AuthProvider>();

    final assignments = assignProv.assignments
        .where((a) => a.type == AssignmentType.ASSIGNMENT)
        .toList();

    // final prefs = await SharedPreferences.getInstance();
    // final studentId = prefs.getString("user_id") ?? '';
    return Stack(
      children: [
        assignProv.isLoading
            ? const Center(child: CircularProgressIndicator())
            : assignments.isEmpty
            ? _EmptyTab(
                icon: Icons.assignment_outlined,
                message: 'No assignments yet',
                subtitle: widget.isAdminOrTeacher
                    ? 'Create the first assignment for this class'
                    : 'No assignments have been posted yet',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppTheme.spaceLg),
                itemCount: assignments.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppTheme.getBorder(context),
                ),
                itemBuilder: (context, i) {
                  logD(
                    "printing assignment length from admin classroom view  ${assignments.length} ",
                  );

                  final a = assignments[i];
                  final isOverdue =
                      a.dueDate != null && a.dueDate!.isBefore(DateTime.now());
                  final submission = _submittedMap[a.id];
                  logD(
                    '🔍 Lookup: assignment.id=${a.id}, found submission: ${submission != null}, status: ${submission?.status}',
                  );
                  final isSubmitted = submission != null;
                  final isGraded = submission?.status.toUpperCase() == "GRADED";
                  logD(
                    "isgraded: ${submission?.status}, ${SubmissionStatus.GRADED.name.toString()}",
                  );
                  return InkWell(
                    onTap: () async {
                      final navigator = Navigator.of(context);
                      final provider = context.read<AssignmentProvider>();

                      final fullAssignment = await provider
                          .fetchAssignmentDetail(a.id);

                      if (!mounted || fullAssignment == null) return;

                      final submission = _submittedMap[a.id];
                      final isSubmitted = submission != null;
                      final isGraded =
                          submission?.status.toUpperCase() == "GRADED";
                      if (!widget.isAdminOrTeacher && isSubmitted) {
                        if (isGraded) {
                          await navigator.push(
                            MaterialPageRoute(
                              builder: (_) => SubmissionFeedbackScreen(
                                assignment: fullAssignment,
                                submission: submission!,
                                classId: widget.classId,
                                studentId: UserSessionManager.user?.id ?? '',
                              ),
                            ),
                          );
                        } else {
                          await navigator.push(
                            MaterialPageRoute(
                              builder: (_) => AssignmentDetailScreen(
                                isAssignment: true,
                                assignment: fullAssignment,
                                classId: widget.classId,
                                isAdminOrTeacher: widget.isAdminOrTeacher,
                                studentId: UserSessionManager.user?.id ?? '',

                                existingSubmission: submission,
                              ),
                            ),
                          );
                        }
                      } else {
                        await navigator.push(
                          MaterialPageRoute(
                            builder: (_) => AssignmentDetailScreen(
                              isAssignment: true,
                              assignment: fullAssignment,
                              classId: widget.classId,
                              isAdminOrTeacher: widget.isAdminOrTeacher,
                              studentId: UserSessionManager.user?.id ?? '',
                              existingSubmission: submission,
                            ),
                          ),
                        );
                      }

                      if (!mounted) return;
                      if (!widget.isAdminOrTeacher) _loadMySubmissions();
                    },
                    borderRadius: AppTheme.borderRadiusMd,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spaceMd,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSubmitted
                                  ? (isGraded
                                        ? Colors.green.withValues(alpha: 0.12)
                                        : Colors.blue.withValues(alpha: 0.10))
                                  : cs.primary.withValues(alpha: 0.08),
                              borderRadius: AppTheme.borderRadiusMd,
                            ),
                            child: Icon(
                              isSubmitted
                                  ? Icons.assignment_turned_in_outlined
                                  : Icons.assignment_outlined,
                              color: isSubmitted
                                  ? (isGraded ? Colors.green : Colors.blue)
                                  : cs.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.title,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 11,
                                      color: isOverdue
                                          ? Colors.red
                                          : AppTheme.getTextTertiary(context),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Due ${_formatDate(a.dueDate)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: isOverdue
                                                ? Colors.red
                                                : AppTheme.getTextSecondary(
                                                    context,
                                                  ),
                                          ),
                                    ),
                                    if (widget.isAdminOrTeacher)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        tooltip: 'Delete Assignment',
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text(
                                                'Delete Assignment',
                                              ),
                                              content: Text(
                                                'Are you sure you want to delete "${a.title}"?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: const Text(
                                                    'Delete',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm != true) return;

                                          try {
                                            await context
                                                .read<AssignmentProvider>()
                                                .deleteAssignment(a.id);

                                            if (!mounted) return;

                                            ScaffoldMessenger.maybeOf(context)
                                                ?.showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Assignment deleted successfully',
                                                ),
                                              ),
                                            );

                                            // optional if provider notifyListeners already updates UI
                                            // _loadAssignments();
                                          } catch (e) {
                                            if (!mounted) return;

                                            ScaffoldMessenger.maybeOf(context)
                                                ?.showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Failed to delete assignment: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      )
                                    else
                                      Icon(
                                        Icons.chevron_right,
                                        size: 18,
                                        color: AppTheme.getTextTertiary(
                                          context,
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    if (!a.published)
                                      _TypeBadge(
                                        label: 'DRAFT',
                                        color: Colors.orange,
                                      ),
                                    // Publish action — program courses only;
                                    // template courses stay draft-only.
                                    if (widget.isAdminOrTeacher &&
                                        !widget.isTemplate &&
                                        !a.published) ...[
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () async {
                                          // Capture the messenger BEFORE the
                                          // await — using context.of after an
                                          // async gap crashes if the tree moved.
                                          final messenger =
                                              ScaffoldMessenger.maybeOf(context);
                                          final ok = await context
                                              .read<AssignmentProvider>()
                                              .updateAssignment(
                                                a.id,
                                                {'published': true},
                                              );
                                          if (!mounted) return;
                                          messenger?.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                ok != null
                                                    ? 'Published'
                                                    : 'Publish failed',
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: const Text(
                                            'Publish',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],

                                    // ── Submission status badge ──────────
                                    if (!widget.isAdminOrTeacher &&
                                        isSubmitted) ...[
                                      const SizedBox(width: 4),
                                      _TypeBadge(
                                        label: isGraded
                                            ? 'GRADED'
                                            : 'SUBMITTED',
                                        color: isGraded
                                            ? Colors.green
                                            : Colors.blue,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Show score chip if graded
                          if (!widget.isAdminOrTeacher && isGraded)
                            GestureDetector(
                              onTap: () async {
                                final provider = context
                                    .read<AssignmentProvider>();

                                final fullAssignment = await provider
                                    .fetchAssignmentDetail(a.id);

                                if (!mounted) return;
                                if (fullAssignment == null) return;

                                final isStudent = !widget.isAdminOrTeacher;
                                final submission = _submittedMap[a.id];

                                final isGraded =
                                    submission?.status ==
                                    SubmissionStatus.GRADED.name;

                                if (isStudent &&
                                    submission != null &&
                                    isGraded) {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SubmissionFeedbackScreen(
                                        assignment: fullAssignment,
                                        submission: submission!,
                                        classId: widget.classId,
                                        studentId:
                                            UserSessionManager.user?.id ?? '',
                                      ),
                                    ),
                                  );
                                } else {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AssignmentDetailScreen(
                                        isAssignment: true,
                                        assignment: fullAssignment,
                                        classId: widget.classId,
                                        isAdminOrTeacher:
                                            widget.isAdminOrTeacher,
                                        studentId:
                                            UserSessionManager.user?.id ?? '',
                                        existingSubmission: submission,
                                      ),
                                    ),
                                  );
                                }

                                if (!mounted) return;

                                if (isStudent) {
                                  _loadMySubmissions();
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  '${submission!.score?.toStringAsFixed(0) ?? '-'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: AppTheme.getTextTertiary(context),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

        if (widget.isAdminOrTeacher)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'assignment_fab',
              onPressed: () => _showCreateAssignment(context),
              icon: const Icon(Icons.add),
              label: const Text('Assignment'),
            ),
          ),
      ],
    );
  }

  void _showCreateAssignment(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateAssignmentScreen(
          classId: widget.classId,
          isTemplate: widget.isTemplate,
        ),
      ),
    );
  }
}

class _ExamsTab extends StatefulWidget {
  final String classId;
  final bool isAdminOrTeacher;
  // Template courses are draft-only (no publish). Real program courses publish.
  final bool isTemplate;

  const _ExamsTab({
    required this.classId,
    required this.isAdminOrTeacher,
    this.isTemplate = false,
  });

  @override
  State<_ExamsTab> createState() => _ExamsTabState();
}

class _ExamsTabState extends State<_ExamsTab> {
  Map<String, Submission> _submittedMap = {};

  @override
  void initState() {
    super.initState();
    if (!widget.isAdminOrTeacher) _loadMySubmissions();
  }

  Future<void> _loadMySubmissions() async {
    final studentId = UserSessionManager.user?.id ?? '';
    if (studentId.isEmpty) return;
    try {
      final subs = await context
          .read<AssignmentProvider>()
          .fetchStudentSubmissionsRaw(studentId: studentId);
      if (!mounted) return;
      setState(() {
        _submittedMap = {for (final s in subs) s.effectiveAssessmentId: s};
      });
      setState(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final assignProv = context.watch<AssignmentProvider>();

    // Exam tab covers every assessed type except plain assignments, so TEST,
    // QUIZ and EXAM (the latter two are creatable via API/Swagger) are all
    // reachable instead of being silently filtered out.
    final exams = assignProv.assignments
        .where((a) => a.type != AssignmentType.ASSIGNMENT)
        .toList();

    return Stack(
      children: [
        assignProv.isLoading
            ? const Center(child: CircularProgressIndicator())
            : exams.isEmpty
            ? _EmptyTab(
                icon: Icons.quiz_outlined,
                message: 'No exams yet',
                subtitle: widget.isAdminOrTeacher
                    ? 'Create the first exam for this class'
                    : 'No exams have been posted yet',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppTheme.spaceLg),
                itemCount: exams.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppTheme.getBorder(context),
                ),
                itemBuilder: (context, i) {
                  final a = exams[i];
                  final isOverdue =
                      a.dueDate != null && a.dueDate!.isBefore(DateTime.now());
                  final submission = _submittedMap[a.id];
                  final isSubmitted = submission != null;
                  final isGraded = submission?.status.toUpperCase() == "GRADED";
                  return InkWell(
                    onTap: () async {
                      final navigator = Navigator.of(context);
                      final provider = context.read<AssignmentProvider>();

                      final fullExam = await provider.fetchAssignmentDetail(
                        a.id,
                      );
                      if (!mounted || fullExam == null) return;

                      final submission = _submittedMap[a.id];
                      final isSubmitted = submission != null;
                      final isGraded =
                          submission?.status?.toUpperCase() == "GRADED";
                      if (!widget.isAdminOrTeacher && isSubmitted) {
                        if (isGraded) {
                          await navigator.push(
                            MaterialPageRoute(
                              builder: (_) => SubmissionFeedbackScreen(
                                assignment: fullExam,
                                submission: submission!,
                                classId: widget.classId,
                                studentId: UserSessionManager.user?.id ?? '',
                              ),
                            ),
                          );
                        } else {
                          // Submitted but pending grade — read-only view, no retake possible
                          await navigator.push(
                            MaterialPageRoute(
                              builder: (_) => AssignmentDetailScreen(
                                isAssignment: false,
                                assignment: fullExam,
                                classId: widget.classId,
                                isAdminOrTeacher: widget.isAdminOrTeacher,
                                studentId: UserSessionManager.user?.id ?? '',
                                existingSubmission:
                                    submission, // locks out resubmission
                              ),
                            ),
                          );
                        }
                      } else {
                        // Not submitted (student) OR admin/teacher
                        await navigator.push(
                          MaterialPageRoute(
                            builder: (_) => AssignmentDetailScreen(
                              isAssignment: false,
                              assignment: fullExam,
                              classId: widget.classId,
                              isAdminOrTeacher: widget.isAdminOrTeacher,
                              studentId: UserSessionManager.user?.id ?? '',
                              existingSubmission: submission,
                            ),
                          ),
                        );
                      }

                      if (!mounted) return;
                      if (!widget.isAdminOrTeacher) _loadMySubmissions();
                    },
                    borderRadius: AppTheme.borderRadiusMd,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spaceMd,
                      ),
                      child: Row(
                        children: [
                          // Leading icon
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSubmitted
                                  ? (isGraded
                                        ? Colors.green.withValues(alpha: 0.12)
                                        : Colors.blue.withValues(alpha: 0.10))
                                  : cs.primary.withValues(alpha: 0.08),
                              borderRadius: AppTheme.borderRadiusMd,
                            ),
                            child: Icon(
                              isSubmitted
                                  ? Icons.assignment_turned_in_outlined
                                  : Icons.quiz_outlined,
                              color: isSubmitted
                                  ? (isGraded ? Colors.green : Colors.blue)
                                  : cs.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.title,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 11,
                                      color: isOverdue
                                          ? Colors.red
                                          : AppTheme.getTextTertiary(context),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Due ${_formatDate(a.dueDate)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: isOverdue
                                                ? Colors.red
                                                : AppTheme.getTextSecondary(
                                                    context,
                                                  ),
                                          ),
                                    ),
                                    // Delete button for admin/teacher
                                    if (widget.isAdminOrTeacher)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        tooltip: 'Delete Exam',
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Delete Exam'),
                                              content: Text(
                                                'Are you sure you want to delete "${a.title}"?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: const Text(
                                                    'Delete',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm != true) return;
                                          try {
                                            await context
                                                .read<AssignmentProvider>()
                                                .deleteAssignment(a.id);
                                            if (!mounted) return;
                                            ScaffoldMessenger.maybeOf(context)
                                                ?.showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Exam deleted successfully',
                                                ),
                                              ),
                                            );
                                          } catch (e) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.maybeOf(context)
                                                ?.showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Failed to delete exam: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      )
                                    else
                                      Icon(
                                        Icons.chevron_right,
                                        size: 18,
                                        color: AppTheme.getTextTertiary(
                                          context,
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    if (!a.published)
                                      _TypeBadge(
                                        label: 'DRAFT',
                                        color: Colors.orange,
                                      ),
                                    // Publish action — program courses only;
                                    // template courses stay draft-only.
                                    if (widget.isAdminOrTeacher &&
                                        !widget.isTemplate &&
                                        !a.published) ...[
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () async {
                                          // Capture the messenger BEFORE the
                                          // await — using context.of after an
                                          // async gap crashes if the tree moved.
                                          final messenger =
                                              ScaffoldMessenger.maybeOf(context);
                                          final ok = await context
                                              .read<AssignmentProvider>()
                                              .updateAssignment(
                                                a.id,
                                                {'published': true},
                                              );
                                          if (!mounted) return;
                                          messenger?.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                ok != null
                                                    ? 'Published'
                                                    : 'Publish failed',
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: const Text(
                                            'Publish',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    // Submission status badge
                                    if (!widget.isAdminOrTeacher &&
                                        isSubmitted) ...[
                                      const SizedBox(width: 4),
                                      _TypeBadge(
                                        label: isGraded
                                            ? 'GRADED'
                                            : 'SUBMITTED',
                                        color: isGraded
                                            ? Colors.green
                                            : Colors.blue,
                                      ),
                                    ],
                                    // Overdue + not submitted badge for students
                                    if (!widget.isAdminOrTeacher &&
                                        !isSubmitted &&
                                        isOverdue) ...[
                                      const SizedBox(width: 4),
                                      _TypeBadge(
                                        label: 'MISSED',
                                        color: Colors.red,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Score chip if graded
                          if (!widget.isAdminOrTeacher && isGraded)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                '${submission!.score?.toStringAsFixed(0) ?? '-'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: AppTheme.getTextTertiary(context),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

        if (widget.isAdminOrTeacher)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'exam_fab',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateAssignmentScreen(
                    classId: widget.classId,
                    isTest: true,
                    isTemplate: widget.isTemplate,
                  ),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Exam'),
            ),
          ),
      ],
    );
  }
}

// A single "Starts / Ends" line. The value is Flexible + ellipsis so a long
// localized date can never overflow under the menu/Start button.
Widget _scheduleRow(BuildContext context, String label, String value) {
  return Row(
    children: [
      SizedBox(
        width: 48,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      Flexible(
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

// ── Sessions Tab ──────────────────────────────────────────
class _SessionsTab extends StatefulWidget {
  final String classId;
  final String organizationId;
  final bool isAdminOrTeacher;
  final Function(dynamic session) onStudentJoinRequested;

  const _SessionsTab({
    required this.classId,
    required this.organizationId,
    required this.isAdminOrTeacher,
    required this.onStudentJoinRequested,
  });

  @override
  State<_SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends State<_SessionsTab> {
  bool _actionLoading = false;
  int _pastCurrentPage = 1;
  final int _pastPageLimit = 10;
  bool _hasMorePastSessions = true;
  bool _loadingMorePast = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    Future.microtask(() {
      if (mounted) {
        setState(() {
          _pastCurrentPage = 1;
          _hasMorePastSessions = true;
        });

        final prov = context.read<LiveSessionProvider>();

        // 🎯 1. Fetch live classes explicitly (Always Page 1)
        prov.fetchSessionsByStatus(
          orgId: widget.organizationId,
          classId: widget.classId,
          targetStatus: 'LIVE',
        );

        // 🎯 2. Fetch upcoming schedule classes explicitly (Always Page 1)
        prov.fetchSessionsByStatus(
          orgId: widget.organizationId,
          classId: widget.classId,
          targetStatus: 'SCHEDULED',
        );

        // 🎯 3. Fetch past session history explicitly with pagination settings
        prov.fetchSessionsByStatus(
          orgId: widget.organizationId,
          classId: widget.classId,
          targetStatus: 'ENDED',
          page: 1,
          limit: _pastPageLimit,
        );
      }
    });
  }

  Future<void> _loadMorePastSessions() async {
    if (_loadingMorePast || !_hasMorePastSessions) return;

    setState(() => _loadingMorePast = true);

    try {
      final nextPage = _pastCurrentPage + 1;
      final sessionProv = context.read<LiveSessionProvider>();
      final previousLength = sessionProv.pastSessions.length;

      await sessionProv.fetchSessionsByStatus(
        orgId: widget.organizationId,
        classId: widget.classId,
        targetStatus: 'ENDED',
        page: nextPage,
        limit: _pastPageLimit,
      );

      if (mounted) {
        final currentLength = sessionProv.pastSessions.length;
        setState(() {
          _pastCurrentPage = nextPage;
          if (currentLength == previousLength ||
              (currentLength - previousLength) < _pastPageLimit) {
            _hasMorePastSessions = false;
          }
        });
      }
    } catch (e) {
      debugPrint("Past pagination failed: $e");
    } finally {
      if (mounted) setState(() => _loadingMorePast = false);
    }
  }

  Future<Map<String, String>?> _showJoinDetailsDialog({
    required String initialName,
    required String initialRoomId,
    required bool isTeacher,
  }) async {
    final nameCtrl = TextEditingController(text: initialName);
    final roomCtrl = TextEditingController(text: initialRoomId);
    final formKey = GlobalKey<FormState>();

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                isTeacher ? Icons.video_call : Icons.blur_on,
                color: cs.primary,
              ),
              const SizedBox(width: 8),
              Text(isTeacher ? 'Launch Session' : 'Join Live Session'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Display Name ✏️',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: roomCtrl,
                  enabled: !isTeacher,
                  decoration: InputDecoration(
                    labelText: 'Room ID 🔑',
                    border: const OutlineInputBorder(),
                    helperText: isTeacher
                        ? "Generated by system"
                        : "Confirm session room match",
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Room ID is required'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(context, {
                    'name': nameCtrl.text.trim(),
                    'roomId': roomCtrl.text.trim(),
                  });
                }
              },
              child: Text(isTeacher ? 'Go Live 🚀' : 'Enter Room ✨'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigateToMeeting({
    required String sessionId,
    required String roomId,
    required String userName,
    required String role,
    String? backendToken,
    String? backendRefreshToken,
  }) async {
    // ✅ FIX 1: Capture context states before entering async gaps
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final tokenManager = TokenManager();
    final String accessToken =
        backendToken ?? await tokenManager.getToken() ?? '';
    final String refreshToken =
        backendRefreshToken ?? await tokenManager.getRefreshToken() ?? '';

    final socketService = SocketService();

    // Show a loading indicator so the UI doesn't look frozen while handshaking
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 16),
            Text('Establishing real-time connection stream... 📡'),
          ],
        ),
        duration: Duration(seconds: 4),
      ),
    );

    // ✅ FIX 2: Await the socket connection setup process
    final isConnected = await socketService.connect(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    // Clear the loading snackbar
    scaffoldMessenger.hideCurrentSnackBar();

    if (!isConnected) {
      // ✅ FIX 3: Fail gracefully if connection handshakes fail or time out
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Connection failed. Please check your network and try again. ❌',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return; // Halt navigation right here
    }

    // ✅ FIX 4: Use the pre-captured context-safe navigator instance to push the screen
    navigator.push(
      MaterialPageRoute(
        builder: (_) => MeetingPage(
          sessionId: sessionId,
          isLocal: false,
          roomId: roomId,
          role: role,
          userName: userName,
          socketService: socketService,
          accessToken: accessToken,
          refreshToken: refreshToken,
        ),
      ),
    );
  }

  void _handleAction(Future<void> Function() action) async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      await action();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sessionProv = context.watch<LiveSessionProvider>();

    // final classSessions = sessionProv.sessions
    //     .where((s) => s.classId == widget.classId)
    //     .toList();

    final live = sessionProv.liveSessions;
    final upcoming = sessionProv.upcomingSessions;
    final past = sessionProv.pastSessions;
    final dateFormat = DateFormat('EEE, MMM d • h:mma');

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      children: [
        // ── 1. LIVE NOW SECTION ──
        if (live.isNotEmpty) ...[
          _SectionHeader(icon: Icons.sensors, label: 'Live Now'),
          const SizedBox(height: AppTheme.spaceMd),
          ...live.map(
            (s) => Container(
              margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppTheme.borderRadiusLg,
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: AppTheme.borderRadiusMd,
                        ),
                        child: Icon(Icons.sensors, color: cs.primary, size: 22),
                      ),
                      const SizedBox(width: AppTheme.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: AppTheme.borderRadiusSm,
                                  ),
                                  child: const Text(
                                    'LIVE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    s.topic,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  if (widget.isAdminOrTeacher)
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _actionLoading
                                ? null
                                : () {
                                    // ✅ FIX 1: Capture navigator state before opening any closures
                                    final navigator = Navigator.of(context);

                                    _handleAction(() async {
                                      final dialogResult =
                                          await _showJoinDetailsDialog(
                                            initialName:
                                                UserSessionManager.user?.name ??
                                                'Teacher',
                                            initialRoomId: s.roomId ?? '',
                                            isTeacher: true,
                                          );
                                      if (dialogResult == null) return;

                                      final success = await sessionProv
                                          .teacherJoinSession(
                                            sessionId: s.id,
                                            name: dialogResult['name']!,
                                          );
                                      if (success) {
                                        final tokenManager = TokenManager();
                                        final String accessToken =
                                            (sessionProv.accessToken != null &&
                                                sessionProv
                                                    .accessToken!
                                                    .isNotEmpty)
                                            ? sessionProv.accessToken!
                                            : await tokenManager.getToken() ??
                                                  '';
                                        final String refreshToken =
                                            (sessionProv.refreshToken != null &&
                                                sessionProv
                                                    .refreshToken!
                                                    .isNotEmpty)
                                            ? sessionProv.refreshToken!
                                            : await tokenManager
                                                      .getRefreshToken() ??
                                                  '';

                                        // ✅ FIX 2: Pass explicit parameters into your method cleanly
                                        await _navigateToMeeting(
                                          sessionId: s.id,
                                          roomId: dialogResult['roomId']!,
                                          userName: dialogResult['name']!,
                                          role: 'teacher',
                                          backendToken: accessToken,
                                          backendRefreshToken: refreshToken,
                                        );
                                      }
                                    });
                                  },
                            child: const Text('Join'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _actionLoading
                                ? null
                                : () => _handleAction(
                                    () => sessionProv.endSession(s.id),
                                  ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('End'),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _actionLoading
                            ? null
                            : () {
                                // ✅ FIX 3: Capture student navigator branch reference
                                final navigator = Navigator.of(context);

                                _handleAction(() async {
                                  final dialogResult =
                                      await _showJoinDetailsDialog(
                                        initialName:
                                            UserSessionManager.user?.name ??
                                            'Student',
                                        initialRoomId: s.roomId ?? '',
                                        isTeacher: false,
                                      );
                                  if (dialogResult == null) return;

                                  final success = await sessionProv
                                      .studentJoinSession(
                                        sessionId: s.id,
                                        name: dialogResult['name']!,
                                      );
                                  logD("called from elevated button");
                                  logD("success ${success}");
                                  if (success) {
                                    final tokenManager = TokenManager();
                                    final String accessToken =
                                        (sessionProv.accessToken != null &&
                                            sessionProv.accessToken!.isNotEmpty)
                                        ? sessionProv.accessToken!
                                        : await tokenManager.getToken() ?? '';
                                    final String refreshToken =
                                        (sessionProv.refreshToken != null &&
                                            sessionProv
                                                .refreshToken!
                                                .isNotEmpty)
                                        ? sessionProv.refreshToken!
                                        : await tokenManager
                                                  .getRefreshToken() ??
                                              '';
                                    logD("trying to navigate");
                                    await _navigateToMeeting(
                                      sessionId: s.id,
                                      roomId: dialogResult['roomId']!,
                                      userName: dialogResult['name']!,
                                      role: 'student',
                                      backendToken: accessToken,
                                      backendRefreshToken: refreshToken,
                                    );
                                  }
                                });
                              },
                        child: const Text('Join'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],

        // ── 2. UPCOMING SECTION ──
        const SizedBox(height: AppTheme.spaceLg),
        _SectionHeader(
          icon: Icons.videocam_outlined,
          label: 'Upcoming Sessions',
        ),
        const SizedBox(height: AppTheme.spaceMd),
        if (upcoming.isEmpty)
          const _EmptyTab(
            icon: Icons.videocam_off_outlined,
            message: 'No upcoming sessions',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: upcoming.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppTheme.spaceMd),
            itemBuilder: (context, i) {
              final s = upcoming[i];
              return Container(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: AppTheme.borderRadiusLg,
                  border: Border.all(color: AppTheme.getBorder(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title row (icon + topic + overflow menu) ──
                    Row(
                      children: [
                        Icon(
                          Icons.videocam_outlined,
                          color: AppTheme.getTextSecondary(context),
                        ),
                        const SizedBox(width: AppTheme.spaceMd),
                        Expanded(
                          child: Text(
                            s.topic,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (widget.isAdminOrTeacher)
                          SessionActionsMenu(
                            session: s,
                            orgId: widget.organizationId,
                            classId: widget.classId,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // ── Schedule block (full width → no overlap) ──
                    Container(
                      padding: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _scheduleRow(
                            context,
                            'Starts',
                            dateFormat.format(s.startTime.toLocal()),
                          ),
                          const SizedBox(height: 2),
                          _scheduleRow(
                            context,
                            'Ends',
                            '${dateFormat.format(s.endTime.toLocal())} MMT',
                          ),
                        ],
                      ),
                    ),
                    // ── Start action (right-aligned, full row) ──
                    if (widget.isAdminOrTeacher) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          onPressed: _actionLoading
                              ? null
                              : () => _handleAction(() async {
                                  final dialogResult =
                                      await _showJoinDetailsDialog(
                                        initialName:
                                            UserSessionManager.user?.name ??
                                            'Teacher',
                                        initialRoomId: s.roomId ?? '',
                                        isTeacher: true,
                                      );
                                  if (dialogResult == null) return;

                                  await sessionProv.startSession(s.id);
                                  final activeRoomId =
                                      sessionProv.currentSession?.roomId ??
                                      s.roomId ??
                                      '';
                                  await _navigateToMeeting(
                                    sessionId: s.id,
                                    roomId: activeRoomId,
                                    userName: dialogResult['name']!,
                                    role: 'teacher',
                                  );
                                }),
                          label: const Text('Start'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

        // ── 3. PAST/ENDED SECTION ──
        const SizedBox(height: AppTheme.space2xl),
        _SectionHeader(icon: Icons.history, label: 'Past Sessions'),
        const SizedBox(height: AppTheme.spaceMd),
        if (past.isEmpty)
          const _EmptyTab(
            icon: Icons.history_toggle_off,
            message: 'No record of past sessions found',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: past.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppTheme.spaceMd),
            itemBuilder: (context, i) {
              final s = past[i];
              return Opacity(
                opacity:
                    0.65, // Gives historical items a distinctive muted style
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).disabledColor.withValues(alpha: 0.04),
                    borderRadius: AppTheme.borderRadiusLg,
                    border: Border.all(
                      color: AppTheme.getBorder(context).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: AppTheme.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.topic,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                decoration: TextDecoration
                                    .lineThrough, // Striking visual distinction
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Ended on: ${dateFormat.format(s.endTime.toLocal())}",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: AppTheme.borderRadiusSm,
                        ),
                        child: const Text(
                          'ENDED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
// // ── Sessions Tab ──────────────────────────────────────────
// class _SessionsTab extends StatefulWidget {
//   final String classId;
//   final String organizationId;
//   final bool isAdminOrTeacher;
//
//   const _SessionsTab({
//     required this.classId,
//     required this.organizationId,
//     required this.isAdminOrTeacher,
//   });
//
//   @override
//   State<_SessionsTab> createState() => _SessionsTabState();
// }
//
// class _SessionsTabState extends State<_SessionsTab> {
//   @override
//   void initState() {
//     final sessionProv = context.read<LiveSessionProvider>();
//     super.initState();
//
//     Future.microtask(() {
//       sessionProv.fetchSessions(classId: widget.classId);
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final sessionProv = context.watch<LiveSessionProvider>();
//     final sessions = sessionProv.sessions
//         .where((s) => s.classId == widget.classId)
//         .toList();
//     logD("Sessions length : ${sessions.length}");
//     final upcoming = sessions
//         .where((s) => s.status == LiveSessionStatus.scheduled)
//         .toList();
//     final live = sessions
//         .where((s) => s.status == LiveSessionStatus.live)
//         .toList();
//     final past = sessions
//         .where((s) => s.status == LiveSessionStatus.ended)
//         .toList();
//
//     return ListView(
//       padding: const EdgeInsets.all(AppTheme.spaceLg),
//       children: [
//         if (live.isNotEmpty) ...[
//           _SectionHeader(icon: Icons.sensors, label: 'Live Now'),
//           const SizedBox(height: AppTheme.spaceMd),
//           ...live.map(
//             (s) => Container(
//               margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
//               padding: const EdgeInsets.all(AppTheme.spaceMd),
//               decoration: BoxDecoration(
//                 color: Theme.of(context).cardColor,
//                 borderRadius: AppTheme.borderRadiusLg,
//                 border: Border.all(
//                   color: cs.primary.withValues(alpha: 0.4),
//                   width: 1.5,
//                 ),
//               ),
//               child: Row(
//                 children: [
//                   Container(
//                     width: 44,
//                     height: 44,
//                     decoration: BoxDecoration(
//                       color: cs.primary.withValues(alpha: 0.1),
//                       borderRadius: AppTheme.borderRadiusMd,
//                     ),
//                     child: Icon(Icons.sensors, color: cs.primary, size: 22),
//                   ),
//                   const SizedBox(width: AppTheme.spaceMd),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           children: [
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 6,
//                                 vertical: 2,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: Colors.red.withValues(alpha: 0.1),
//                                 borderRadius: AppTheme.borderRadiusSm,
//                               ),
//                               child: Row(
//                                 children: [
//                                   Container(
//                                     width: 6,
//                                     height: 6,
//                                     decoration: const BoxDecoration(
//                                       color: Colors.red,
//                                       shape: BoxShape.circle,
//                                     ),
//                                   ),
//                                   const SizedBox(width: 4),
//                                   const Text(
//                                     'LIVE',
//                                     style: TextStyle(
//                                       fontSize: 9,
//                                       fontWeight: FontWeight.w800,
//                                       color: Colors.red,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             const SizedBox(width: 6),
//                             Expanded(
//                               child: Text(
//                                 s.topic,
//                                 style: Theme.of(context).textTheme.bodyMedium
//                                     ?.copyWith(fontWeight: FontWeight.w600),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                   FilledButton(
//                     onPressed: () {},
//                     style: FilledButton.styleFrom(
//                       backgroundColor: cs.primary,
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 8,
//                       ),
//                       minimumSize: Size.zero,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: AppTheme.borderRadiusMd,
//                       ),
//                     ),
//                     child: Text(
//                       widget.isAdminOrTeacher ? 'Manage' : 'Join',
//                       style: const TextStyle(fontSize: 12),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           const SizedBox(height: AppTheme.space2xl),
//         ],
//
//         _SectionHeader(
//           icon: Icons.videocam_outlined,
//           label: 'Upcoming Sessions',
//         ),
//         const SizedBox(height: AppTheme.spaceMd),
//         if (upcoming.isEmpty)
//           _EmptyTab(
//             icon: Icons.videocam_off_outlined,
//             message: 'No upcoming sessions',
//           )
//         else
//           ListView.separated(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             itemCount: upcoming.length,
//             separatorBuilder: (_, __) =>
//                 const SizedBox(height: AppTheme.spaceMd),
//             itemBuilder: (context, i) {
//               final s = upcoming[i];
//               return Container(
//                 padding: const EdgeInsets.all(AppTheme.spaceMd),
//                 decoration: BoxDecoration(
//                   color: Theme.of(context).cardColor,
//                   borderRadius: AppTheme.borderRadiusLg,
//                   border: Border.all(color: AppTheme.getBorder(context)),
//                 ),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 44,
//                       height: 44,
//                       decoration: BoxDecoration(
//                         color: AppTheme.getSurfaceVariant(context),
//                         borderRadius: AppTheme.borderRadiusMd,
//                       ),
//                       child: Icon(
//                         Icons.videocam_outlined,
//                         color: AppTheme.getTextSecondary(context),
//                         size: 22,
//                       ),
//                     ),
//                     const SizedBox(width: AppTheme.spaceMd),
//                     Expanded(
//                       child: Text(
//                         s.topic,
//                         style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             },
//           ),
//
//         const SizedBox(height: AppTheme.space2xl),
//         _SectionHeader(icon: Icons.history, label: 'Past Sessions'),
//         const SizedBox(height: AppTheme.spaceMd),
//         if (past.isEmpty)
//           _EmptyTab(icon: Icons.history_outlined, message: 'No past sessions')
//         else
//           ListView.separated(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             itemCount: past.length,
//             separatorBuilder: (_, __) => Divider(
//               height: 1,
//               thickness: 0.5,
//               color: AppTheme.getBorder(context),
//             ),
//             itemBuilder: (context, i) {
//               final s = past[i];
//               return Padding(
//                 padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 40,
//                       height: 40,
//                       decoration: BoxDecoration(
//                         color: AppTheme.getSurfaceVariant(context),
//                         borderRadius: AppTheme.borderRadiusMd,
//                       ),
//                       child: Icon(
//                         Icons.play_circle_outline,
//                         color: AppTheme.getTextSecondary(context),
//                         size: 20,
//                       ),
//                     ),
//                     const SizedBox(width: AppTheme.spaceMd),
//                     Expanded(
//                       child: Text(
//                         s.topic,
//                         style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ),
//
//                     //TODO ADD LIVE RECORDING URL
//                     // if (s.recordingUrl != null)
//                     //   TextButton(
//                     //     onPressed: () {},
//                     //     style: TextButton.styleFrom(
//                     //       foregroundColor: cs.primary,
//                     //       padding: const EdgeInsets.symmetric(horizontal: 8),
//                     //       minimumSize: Size.zero,
//                     //     ),
//                     //     child: const Text(
//                     //       'Recording',
//                     //       style: TextStyle(fontSize: 12),
//                     //     ),
//                     //   ),
//                   ],
//                 ),
//               );
//             },
//           ),
//       ],
//     );
//   }
// }

// ── Materials Tab (kept as demo until file upload API exists) ─
class _MaterialsTab extends StatefulWidget {
  final String classId;
  final bool isAdminOrTeacher;
  const _MaterialsTab({required this.classId, required this.isAdminOrTeacher});

  @override
  State<_MaterialsTab> createState() => _MaterialsTabState();
}

class _MaterialsTabState extends State<_MaterialsTab> {
  // Same hardcoded host used elsewhere for static /uploads files.
  static const String _baseUrl = 'https://backend.htoochoon.com';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MaterialProvider>().fetchMaterials(
        widget.classId,
        refresh: true,
      );
    });
  }

  Future<void> _pickAndUpload() async {
    // withData so web/Waydroid get bytes; mobile still exposes a path.
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;

    final prov = context.read<MaterialProvider>();
    final created = await prov.uploadMaterial(
      classId: widget.classId,
      file: result.files.first,
    );
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          created != null
              ? 'Uploaded “${created.displayName}”'
              : (prov.error(widget.classId) ?? 'Upload failed'),
        ),
        backgroundColor: created != null ? null : cs.error,
      ),
    );
  }

  Future<void> _open(CourseMaterial m) async {
    final url = '$_baseUrl${m.fileUrl}';

    // Engagement tracking: record that this user opened the material (lets
    // teachers/admins see "did they view it?"). Fire-and-forget — never block
    // opening the file on it.
    try {
      // ignore: unawaited_futures
      context.read<ApiService>().markMaterialViewed(m.id);
    } catch (_) {}

    // Images preview in-app (consistent with attachment viewers elsewhere).
    if (m.isImage) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: url,
                placeholder: (_, __) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
              ),
            ),
          ),
        ),
      );
      return;
    }

    // Everything else opens in the platform handler / browser for download.
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open this file')));
    }
  }

  Future<void> _confirmDelete(CourseMaterial m) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete material?'),
        content: Text('“${m.displayName}” will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    final prov = context.read<MaterialProvider>();
    final ok = await prov.deleteMaterial(widget.classId, m.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(prov.error(widget.classId) ?? 'Delete failed')),
      );
    }
  }

  IconData _iconFor(CourseMaterial m) {
    if (m.isImage) return Icons.image_outlined;
    if (m.isVideo) return Icons.movie_outlined;
    if (m.isAudio) return Icons.audiotrack_outlined;
    if (m.isPdf) return Icons.picture_as_pdf_outlined;
    final n = m.fileName.toLowerCase();
    if (n.endsWith('.doc') || n.endsWith('.docx')) {
      return Icons.description_outlined;
    }
    if (n.endsWith('.ppt') || n.endsWith('.pptx'))
      return Icons.slideshow_outlined;
    if (n.endsWith('.xls') || n.endsWith('.xlsx') || n.endsWith('.csv')) {
      return Icons.table_chart_outlined;
    }
    if (n.endsWith('.zip')) return Icons.folder_zip_outlined;
    return Icons.insert_drive_file_outlined;
  }

  /// A membership/permission rejection from the materials endpoint isn't a real
  /// error to surface — it just means there's nothing here for this user, so we
  /// render the normal "No materials yet" empty state instead.
  bool _isAccessError(String err) {
    final lower = err.toLowerCase();
    return lower.contains('member') ||
        lower.contains('permission') ||
        lower.contains('access');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final prov = context.watch<MaterialProvider>();
    final items = prov.materials(widget.classId);
    final loading = prov.isLoading(widget.classId);
    final err = prov.error(widget.classId);

    Widget body;
    if (loading && items.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (err != null && items.isEmpty && !_isAccessError(err)) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: cs.error, size: 40),
            const SizedBox(height: 8),
            Text(err, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  prov.fetchMaterials(widget.classId, refresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (items.isEmpty) {
      body = const Center(
        child: _EmptyTab(
          icon: Icons.folder_outlined,
          message: 'No materials yet',
          subtitle: 'Materials will appear here once uploaded',
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => prov.fetchMaterials(widget.classId, refresh: true),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final m = items[i];
            return Card(
              elevation: 0,
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                onTap: () => _open(m),
                leading: CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Icon(_iconFor(m), color: cs.onPrimaryContainer),
                ),
                title: Text(
                  m.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    if (m.readableSize.isNotEmpty) m.readableSize,
                    if (m.uploadedBy?.name.isNotEmpty ?? false)
                      m.uploadedBy!.name,
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: widget.isAdminOrTeacher
                    ? IconButton(
                        icon: Icon(Icons.delete_outline, color: cs.error),
                        onPressed: () => _confirmDelete(m),
                      )
                    : const Icon(Icons.download_outlined),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: widget.isAdminOrTeacher
          ? FloatingActionButton.extended(
              onPressed: prov.isUploading ? null : _pickAndUpload,
              icon: prov.isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(prov.isUploading ? 'Uploading…' : 'Upload'),
            )
          : null,
      body: body,
    );
  }
}

// ── People Tab ────────────────────────────────────────────
class _PeopleTab extends StatefulWidget {
  final String classId;
  final bool isAdminOrTeacher;
  final String organizationId;

  const _PeopleTab({
    required this.classId,
    required this.isAdminOrTeacher,
    required this.organizationId,
  });

  @override
  State<_PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<_PeopleTab> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClassProvider>().fetchStudents(
        widget.classId,
        refresh: true,
      );
    });
    logD("FFEYCHED FORM ON INIT");
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final prov = context.read<ClassProvider>();

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (prov.hasMoreStudents(widget.classId) &&
          !prov.isStudentsLoading(widget.classId)) {
        prov.fetchStudents(widget.classId);
        logD("FFEYCHED FORM ON SCROLL");
      }
    }
  }

  @override
  void dispose() {
    final prov = context.read<ClassProvider>();

    _scrollController.dispose();
    prov.clearStudents(widget.classId);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final classProv = context.watch<ClassProvider>();
    final orgProv = context.watch<OrganizationProvider>();

    final students = classProv.getStudents(widget.classId);
    final currentUserId = UserSessionManager.userId;
    final isLoading = classProv.isStudentsLoading(widget.classId);

    final classModel = classProv.classes
        .where((c) => c.id == widget.classId)
        .firstOrNull;

    if (classModel == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isLoading && students.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // ─── Resolve Teacher Data ──────────────────────────────────────
    final teacher = classModel.teacher;
    final teacherUser = teacher == null ? null : orgProv.userCache[teacher.id];

    // ✅ FIX: Resolve Teacher's actual avatar URL straight from your userCache metadata
    final String? teacherAvatar = teacherUser?.avatar;
    final String? absoluteTeacherAvatarUrl =
        (teacherAvatar != null && teacherAvatar.isNotEmpty)
        ? (teacherAvatar.startsWith('http')
              ? teacherAvatar
              : "https://backend.htoochoon.com$teacherAvatar")
        : null;

    final String teacherName = teacher?.name ?? 'Unknown Teacher';
    final bool isTeacherMe = teacher?.id == currentUserId;

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      children: [
        // ── Teacher / Instructor ────────────────────────────────────
        _SectionHeader(icon: Icons.school_outlined, label: 'Instructor'),

        const SizedBox(height: AppTheme.spaceMd),

        Container(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: AppTheme.borderRadiusLg,
            border: Border.all(color: AppTheme.getBorder(context)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: cs.primary.withValues(alpha: 0.15),
                backgroundImage: absoluteTeacherAvatarUrl != null
                    ? NetworkImage(absoluteTeacherAvatarUrl)
                    : null,
                child: absoluteTeacherAvatarUrl == null
                    ? Text(
                        teacherName.isNotEmpty
                            ? teacherName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color:
                              cs.primary, // Fixed undefined roleColor variable
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),

              const SizedBox(width: AppTheme.spaceMd),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTeacherMe ? '$teacherName (You)' : teacherName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    Text(
                      teacherUser?.email ?? 'Teacher',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.getTextTertiary(context),
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: AppTheme.borderRadiusSm,
                ),
                child: Text(
                  'TEACHER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.space2xl),

        // ── Students Roster (inherited from program enrollment) ──────
        // Students are enrolled at the PROGRAM level and inherit access to
        // every class under it, so there is no class-level "add student".
        // Admin/teacher can still remove (exclude) an individual student below.
        _SectionHeader(
          icon: Icons.people_outline,
          label: 'Students',
          badge: '${students.length}',
          trailing: null,
        ),

        const SizedBox(height: AppTheme.spaceMd),

        if (students.isEmpty)
          _EmptyTab(
            icon: Icons.people_outline,
            message: 'No students yet',
            subtitle:
                'Students inherit access by being enrolled in the program',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: students.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              thickness: 0.5,
              color: AppTheme.getBorder(context),
            ),
            itemBuilder: (context, i) {
              final user = students[i];
              final bool isStudentMe = user.id == currentUserId;

              // ✅ FIX: Kept raw name clean so initials fallbacks use actual letters instead of 'Y'
              final rawName = user.name.trim();
              final displayName = isStudentMe ? '$rawName (You)' : rawName;

              final cached = orgProv.userCache[user.id];
              final avatar = cached?.avatar;

              final String? absoluteStudentAvatarUrl =
                  (avatar != null && avatar.isNotEmpty)
                  ? (avatar.startsWith('http')
                        ? avatar
                        : "https://backend.htoochoon.com$avatar")
                  : null;

              final colors = [
                const Color(0xFF185FA5),
                const Color(0xFF1D9E75),
                const Color(0xFFD4680A),
                const Color(0xFF534AB7),
                const Color(0xFFD85A30),
              ];
              final color = colors[i % colors.length];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: color.withValues(alpha: 0.15),
                      backgroundImage: absoluteStudentAvatarUrl != null
                          ? NetworkImage(absoluteStudentAvatarUrl.toString())
                          : null,
                      child: absoluteStudentAvatarUrl == null
                          ? Text(
                              rawName.isNotEmpty
                                  ? rawName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color:
                                    color, // Uses matching list color for clean styling contrast
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),

                    const SizedBox(width: AppTheme.spaceMd),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: isStudentMe
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                          ),
                          if (user.email.isNotEmpty)
                            Text(
                              user.email,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppTheme.getTextTertiary(context),
                                  ),
                            ),
                        ],
                      ),
                    ),

                    if (widget.isAdminOrTeacher)
                      IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: Colors.red[400],
                          size: 18,
                        ),
                        onPressed: () => _confirmRemoveStudent(
                          context,
                          user.id,
                          displayName,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

        if (isLoading && students.isNotEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  void _confirmRemoveStudent(BuildContext context, String userId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from this class'),
        content: Text(
          'Exclude $name from this class only? They stay enrolled in the '
          'program and keep access to its other classes.',
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
            onPressed: () async {
              Navigator.pop(ctx);

              final success = await context
                  .read<ClassProvider>()
                  .removeStudentFromClass(widget.classId, userId);

              if (!context.mounted) {
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? '$name excluded from this class'
                        : 'Failed to remove student',
                  ),
                ),
              );
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
// ── Assignment Detail Screen ──────────────────────────────
// class AssignmentDetailScreen extends StatefulWidget {
//   final Assignment assignment;
//   final String classId;
//   final bool isAdminOrTeacher;
//   final String studentId;
//
//   const AssignmentDetailScreen({
//     super.key,
//     required this.assignment,
//     required this.classId,
//     required this.isAdminOrTeacher,
//     required this.studentId,
//   });
//
//   @override
//   State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
// }
//
// class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
//   List<Submission> _submissions = [];
//   bool _isLoading = false;
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       if (widget.isAdminOrTeacher) {
//         setState(() => _isLoading = true);
//         _submissions = await context
//             .read<AssignmentProvider>()
//             .fetchStudentSubmissions(widget.assignment.id);
//         setState(() => _isLoading = false);
//       }
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final a = widget.assignment;
//     final isOverdue = a.dueDate.isBefore(DateTime.now());
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(a.title),
//         backgroundColor: cs.primary,
//         foregroundColor: cs.onPrimary,
//       ),
//       body: ListView(
//         padding: const EdgeInsets.all(AppTheme.spaceLg),
//         children: [
//           // Due date banner
//           Container(
//             padding: const EdgeInsets.all(AppTheme.spaceMd),
//             decoration: BoxDecoration(
//               color: isOverdue
//                   ? Colors.red.withValues(alpha: 0.06)
//                   : cs.primary.withValues(alpha: 0.06),
//               borderRadius: AppTheme.borderRadiusMd,
//               border: Border.all(
//                 color: isOverdue
//                     ? Colors.red.withValues(alpha: 0.2)
//                     : cs.primary.withValues(alpha: 0.2),
//               ),
//             ),
//             child: Row(
//               children: [
//                 Icon(
//                   Icons.calendar_today,
//                   size: 16,
//                   color: isOverdue ? Colors.red : cs.primary,
//                 ),
//                 const SizedBox(width: 8),
//                 Text(
//                   isOverdue
//                       ? 'Overdue · ${_formatDate(a.dueDate)}'
//                       : 'Due ${_formatDate(a.dueDate)}',
//                   style: TextStyle(
//                     fontWeight: FontWeight.w600,
//                     color: isOverdue ? Colors.red : cs.primary,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: AppTheme.spaceLg),
//
//           // Content
//           Text(
//             'Instructions',
//             style: Theme.of(
//               context,
//             ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
//           ),
//           const SizedBox(height: AppTheme.spaceSm),
//           Text(
//             a.content,
//             style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//               color: AppTheme.getTextSecondary(context),
//               height: 1.6,
//             ),
//           ),
//           const SizedBox(height: AppTheme.space2xl),
//
//           // Admin: submissions list | Student: submit button
//           if (widget.isAdminOrTeacher) ...[
//             Text(
//               'Submissions',
//               style: Theme.of(
//                 context,
//               ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
//             ),
//             const SizedBox(height: AppTheme.spaceMd),
//             if (_isLoading)
//               const Center(child: CircularProgressIndicator())
//             else if (_submissions.isEmpty)
//               const Text('No submissions yet')
//             else
//               ..._submissions.map(
//                 (s) => _SubmissionTile(
//                   submission: s,
//                   onGrade: (score) async {
//                     await context.read<AssignmentProvider>().gradeSubmission(
//                       s.id,
//                       GradeRequest(
//                         score: score,
//                         status: SubmissionStatus.GRADED,
//                       ),
//                     );
//                   },
//                 ),
//               ),
//           ] else ...[
//             SizedBox(
//               width: double.infinity,
//               child: FilledButton.icon(
//                 onPressed: () => Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => TakeAssignmentScreen(
//                       assignment: a,
//
//                       studentId: widget.studentId,
//                     ),
//                   ),
//                 ),
//                 icon: const Icon(Icons.edit_outlined),
//                 label: const Text('Submit Assignment'),
//                 style: FilledButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(
//                     vertical: AppTheme.spaceMd,
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }

// class SubmitWorkScreen extends StatefulWidget {
//   final String title;
//   final String? assignmentId;
//   final String? testId;
//   final String classId;
//   final String studentId;
//
//   const SubmitWorkScreen({
//     super.key,
//     required this.title,
//     this.assignmentId,
//     this.testId,
//     required this.classId,
//     required this.studentId,
//   });
//
//   @override
//   State<SubmitWorkScreen> createState() => _SubmitWorkScreenState();
// }
//
// class _SubmitWorkScreenState extends State<SubmitWorkScreen> {
//   late QuillController _controller;
//   final FocusNode _focusNode = FocusNode();
//   final ScrollController _scrollController = ScrollController();
//   bool _submitted = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = QuillController.basic();
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     _focusNode.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }
//
//   String _getPlainText() {
//     return _controller.document.toPlainText().trim();
//   }
//
//   String _getRichText() {
//     // Store as JSON string for backend
//     return jsonEncode(_controller.document.toDelta().toJson());
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//
//     return Scaffold(
//       backgroundColor: Theme.of(context).scaffoldBackgroundColor,
//       appBar: AppBar(
//         title: Text(widget.title),
//         backgroundColor: cs.primary,
//         foregroundColor: cs.onPrimary,
//         actions: [
//           Consumer<AssignmentProvider>(
//             builder: (context, assignProv, _) => TextButton(
//               onPressed: _submitted || assignProv.isLoading ? null : _submit,
//               child: assignProv.isLoading
//                   ? const SizedBox(
//                       width: 16,
//                       height: 16,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2,
//                         color: Colors.white,
//                       ),
//                     )
//                   : Text(
//                       _submitted ? 'Submitted ✓' : 'Submit',
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//             ),
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // ── Quill Toolbar ─────────────────────────────
//           Container(
//             decoration: BoxDecoration(
//               color: Theme.of(context).cardColor,
//               border: Border(
//                 bottom: BorderSide(color: AppTheme.getBorder(context)),
//               ),
//             ),
//             child: QuillSimpleToolbar(
//               controller: _controller,
//               config: QuillSimpleToolbarConfig(
//                 showFontFamily: false,
//                 showFontSize: false,
//                 showBackgroundColorButton: false,
//                 showClearFormat: true,
//                 showColorButton: true,
//                 showBoldButton: true,
//                 showItalicButton: true,
//                 showUnderLineButton: true,
//                 showStrikeThrough: false,
//                 showListBullets: true,
//                 showListNumbers: true,
//                 showQuote: false,
//                 showLink: false,
//                 showSearchButton: false,
//                 showSubscript: false,
//                 showSuperscript: false,
//                 showAlignmentButtons: true,
//                 showHeaderStyle: true,
//                 showIndent: true,
//                 showDividers: true,
//                 // multiRowsToolbar: false,
//                 toolbarSize: 42,
//                 buttonOptions: QuillSimpleToolbarButtonOptions(
//                   base: QuillToolbarBaseButtonOptions(
//                     iconTheme: QuillIconTheme(
//                       // iconButtonSelectedData: IconButtonTheme(
//                       //   style: ButtonStyle(
//                       //     backgroundColor: WidgetStateProperty.all(
//                       //       cs.primary.withValues(alpha: 0.12),
//                       //     ),
//                       //   ),
//                       // ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//
//           // ── Word count bar ────────────────────────────
//           StreamBuilder(
//             stream: _controller.document.changes,
//             builder: (context, snapshot) {
//               final text = _controller.document.toPlainText();
//               final wordCount = text
//                   .trim()
//                   .split(RegExp(r'\s+'))
//                   .where((w) => w.isNotEmpty)
//                   .length;
//
//               return Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 16,
//                   vertical: 4,
//                 ),
//                 child: Text('$wordCount words'),
//               );
//             },
//           ),
//
//           // ── Editor ────────────────────────────────────
//           Expanded(
//             child: Container(
//               margin: const EdgeInsets.all(AppTheme.spaceLg),
//               decoration: BoxDecoration(
//                 color: Theme.of(context).cardColor,
//                 borderRadius: AppTheme.borderRadiusLg,
//                 border: Border.all(color: AppTheme.getBorder(context)),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withValues(alpha: 0.04),
//                     blurRadius: 8,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               clipBehavior: Clip.antiAlias,
//               child: QuillEditor(
//                 controller: _controller,
//                 focusNode: _focusNode,
//                 scrollController: _scrollController,
//                 config: QuillEditorConfig(
//                   placeholder: 'Start writing your answer here...',
//                   padding: const EdgeInsets.all(AppTheme.spaceLg),
//                   autoFocus: false,
//                   expands: true,
//                   scrollable: true,
//                   customStyles: DefaultStyles(
//                     paragraph: DefaultTextBlockStyle(
//                       Theme.of(context).textTheme.bodyMedium!.copyWith(
//                         height: 1.7,
//                         color: Theme.of(context).textTheme.bodyMedium?.color,
//                       ),
//                       const HorizontalSpacing(0, 0),
//                       const VerticalSpacing(2, 2),
//                       const VerticalSpacing(0, 0),
//                       null,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Future<void> _submit() async {
//     final plainText = _getPlainText();
//     if (plainText.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Please write something before submitting'),
//         ),
//       );
//       return;
//     }
//
//     // Send rich text JSON as content so it can be rendered back later
//     final result = await context.read<AssignmentProvider>().submitAssignment(
//       SubmissionRequest(
//         studentId: widget.studentId,
//         assignmentId: widget.assignmentId,
//         testId: widget.testId,
//         content: _getRichText(), // ← sends Delta JSON
//       ),
//     );
//
//     if (!mounted) return;
//     if (result != null) {
//       setState(() => _submitted = true);
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('Submitted successfully!')));
//       Navigator.pop(context);
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             context.read<AssignmentProvider>().error ?? 'Submission failed',
//           ),
//         ),
//       );
//     }
//   }
// }

//── Test Submissions Screen (Admin view) ──────────────────
class TestSubmissionsScreen extends StatefulWidget {
  final Assignment test;
  final String classId;

  const TestSubmissionsScreen({
    super.key,
    required this.test,
    required this.classId,
  });

  @override
  State<TestSubmissionsScreen> createState() => _TestSubmissionsScreenState();
}

class _TestSubmissionsScreenState extends State<TestSubmissionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AssignmentProvider>().fetchSubmissions(
        classId: widget.classId,
        type: 'test',
        itemId: widget.test.id,
      );
    });
  }

  int get _totalPoints =>
      widget.test.questions.fold<int>(0, (sum, q) => sum + q.points);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final assignProv = context.watch<AssignmentProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.test.title),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: assignProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : assignProv.submissions.isEmpty
          ? const Center(child: Text('No submissions yet'))
          : ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              itemCount: assignProv.submissions.length,
              itemBuilder: (context, i) {
                final s = assignProv.submissions[i];
                return _SubmissionTile(
                  submission: s,
                  assignment: widget.test,
                  totalPoints: _totalPoints,
                  onGrade: (score) async {
                    // This is for the inline grade dialog (if you keep it)
                    await assignProv.gradeSubmission(
                      submissionId: s.id,
                      request: GradeRequest(
                        // questionGrade: [],
                        score: score,
                        status: SubmissionStatus.GRADED,
                      ),
                    );
                  },
                  onRefresh: () {
                    // ✅ Refresh the submissions list after grading
                    context.read<AssignmentProvider>().fetchSubmissions(
                      classId: widget.classId,
                      type: 'test',
                      itemId: widget.test.id,
                    );
                  },
                );
              },
            ),
    );
  }
}

// ── Submission Tile ───────────────────────────────────────
class _SubmissionTile extends StatelessWidget {
  final Submission submission;
  final Assignment assignment;
  final int totalPoints;
  final Future<void> Function(double score) onGrade;
  final VoidCallback? onRefresh;
  const _SubmissionTile({
    required this.submission,
    required this.assignment,
    required this.totalPoints,
    required this.onGrade,
    this.onRefresh,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isGraded = submission.status == "GRADED";
    final name = submission.student?.name ?? '';
    final avatar = submission.student?.avatar;
    final String? absoluteAvatarUrl = (avatar != null && avatar.isNotEmpty)
        ? (avatar.startsWith('http')
              ? avatar
              : "https://backend.htoochoon.com$avatar")
        : null;
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
              CircleAvatar(
                radius: 16,
                backgroundColor: cs.primary.withValues(alpha: 0.1),
                backgroundImage: absoluteAvatarUrl != null
                    ? NetworkImage(absoluteAvatarUrl)
                    : null,
                child: absoluteAvatarUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  submission.student?.name ?? '',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isGraded)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.08),
                            borderRadius: AppTheme.borderRadiusSm,
                          ),
                          child: Text(
                            '${submission.score?.toStringAsFixed(0) ?? 67}%',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: cs.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentSubmissionDetailScreen(
                                  submission: submission,
                                  assignment: assignment,
                                  isEditMode: true,
                                  onGradeComplete: () {
                                    onRefresh?.call();
                                  },
                                ),
                              ),
                            );
                          },
                          child: const Text('Edit Grade'),
                        ),
                      ],
                    )
                  else
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentSubmissionDetailScreen(
                              submission: submission,
                              assignment: assignment,
                              onGradeComplete: () {
                                onRefresh?.call();
                              },
                            ),
                          ),
                        );
                      },
                      child: const Text('Grade'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          // Replace the content Text widget in _SubmissionTile with:
          Builder(
            builder: (context) {
              // Try to parse as Quill Delta JSON, fall back to plain text
              try {
                final delta = Delta.fromJson(
                  jsonDecode(submission.content.toString()) as List,
                );
                final doc = Document.fromDelta(delta);
                final readOnlyController = QuillController(
                  document: doc,
                  selection: const TextSelection.collapsed(offset: 0),
                  readOnly: true,
                );
                return SizedBox(
                  height: 80,
                  child: QuillEditor(
                    controller: readOnlyController,
                    focusNode: FocusNode(),
                    scrollController: ScrollController(),
                    config: const QuillEditorConfig(
                      padding: EdgeInsets.zero,
                      expands: false,
                      scrollable: true,
                      showCursor: false,
                    ),
                  ),
                );
              } catch (_) {
                // Plain text fallback
                return Text(
                  submission.content.toString(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.getTextSecondary(context),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showGradeDialog(BuildContext context) {
    double score = 100;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setInner) => AlertDialog(
          title: Text('Grade ${submission.student?.name ?? ''}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${score.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Slider(
                value: score,
                min: 0,
                max: 100,
                divisions: 20,
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
                Navigator.pop(ctx);
                await onGrade(score);
              },
              child: const Text('Save Grade'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Toolbar Button ────────────────────────────────────────
class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ToolbarBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      onPressed: onTap,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusSm),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────
String _formatDate(DateTime? dt) {
  if (dt == null) return 'No due date';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;

  const _EmptyTab({required this.icon, required this.message, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space2xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.getTextTertiary(context)),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTheme.spaceXs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Breadcrumb, StickyTabBar, TypeBadge, SectionHeader (unchanged) ──
class _Breadcrumb extends StatelessWidget {
  final ClassroomArgs args;
  const _Breadcrumb({required this.args});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = args.entryPoint == ClassEntryPoint.fromProgram
        ? [args.programName!, args.courseName, args.className]
        : [args.courseName, args.className];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 14,
                color: AppTheme.getTextTertiary(context),
              ),
              const SizedBox(width: 1),
            ],
            GestureDetector(
              onTap: i < items.length - 1 ? () => Navigator.pop(context) : null,
              child: Text(
                items[i],
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: i == items.length - 1
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: i == items.length - 1
                      ? cs.primary
                      : AppTheme.getTextSecondary(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color bg;
  const _StickyTabBarDelegate(this.tabBar, this.bg);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Container(color: bg, child: tabBar);

  @override
  bool shouldRebuild(_StickyTabBarDelegate old) => false;
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppTheme.borderRadiusSm,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final Widget? trailing;

  const _SectionHeader({
    required this.icon,
    required this.label,
    this.badge,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (badge != null) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.getSurfaceVariant(context),
              borderRadius: AppTheme.borderRadiusSm,
            ),
            child: Text(
              badge!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppTheme.getTextSecondary(context),
              ),
            ),
          ),
        ],
        if (trailing != null) ...[
          if (badge == null) const Spacer(),
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}
