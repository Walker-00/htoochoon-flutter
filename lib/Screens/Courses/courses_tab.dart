import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Constants/app_colors.dart';
import 'package:htoochoon_flutter/Live-Session/models/class_model.dart';
import 'package:htoochoon_flutter/api/api_service.dart';
import 'package:htoochoon_flutter/models/api_models/organization_model.dart';
import 'package:htoochoon_flutter/Screens/Payment/fake_payment_sheet.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/courses_provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/organisation_provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/programs_provider.dart';
import 'package:htoochoon_flutter/Providers/auth_provider.dart';
import 'package:htoochoon_flutter/Providers/class_provider.dart';
import 'package:htoochoon_flutter/Providers/enrollment_provider.dart';
import 'package:htoochoon_flutter/Providers/structure_provider.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';
import 'package:htoochoon_flutter/Widgets/empty_state_widget.dart';
import 'package:htoochoon_flutter/Widgets/user_appbar.dart';
import 'package:htoochoon_flutter/core/userorgrole_manager.dart';
import 'package:htoochoon_flutter/models/api_models/class_model.dart';
import 'package:htoochoon_flutter/models/api_models/course_model.dart';
import 'package:htoochoon_flutter/models/api_models/enrollment_model.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:htoochoon_flutter/models/api_models/program_model.dart';
import 'package:provider/provider.dart';

// courses_tab.dart
// Refactored to match ClassesTab patterns:
//  - AppTheme helpers for dark/light theming (no hardcoded colors)
//  - colorScheme.primary replaces all hardcoded #007A8B greens
//  - InkWell hover/ripple on interactive cards
//  - Consistent border, radius, spacing tokens
//  - SegmentedButton and ChoiceChip use theme colors
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CoursesTab extends StatefulWidget {
  final VoidCallback onProfileTap;

  const CoursesTab({super.key, required this.onProfileTap});

  @override
  State<CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends State<CoursesTab> {
  String _selectedSegment = 'Skill Courses';
  int _selectedTopicIndex = 0;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  static const List<String> _topics = [
    'All Topics',
    'Data Science',
    'Design Thinking',
    'Marketing',
    'Development',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CoursesProvider>().fetchAllCourses();
      context.read<ProgramsProvider>().fetchAllPrograms();

      // Make sure our baseline enrollment maps remain freshly synchronized
      final userId = UserSessionManager.userId;
      if (userId != null) {
        final enrollProv = context.read<EnrollmentProvider>();
        enrollProv.fetchCurrentUserEnrollments(userId);
        // Pull open access requests so "Enrollment requested" persists.
        enrollProv.fetchMyAccessRequests();
      }
    });

    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final coursesProv = context.watch<CoursesProvider>();
    final programsProv = context.watch<ProgramsProvider>();

    // 🎯 Use our new search provider logic pipeline
    final skillCourses = coursesProv.searchAndFilterCourses(
      _searchQuery,
      CourseType.SKILL,
    );
    final filteredPrograms = programsProv.searchPrograms(_searchQuery);

    final isLoading = coursesProv.isLoading || programsProv.isLoading;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: UserAppBar(
        title: 'HtooChoon',
        showSearchIcon: true,
        leadIcon: Icons.dashboard,
        onProfileTap: widget.onProfileTap,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMd,
            vertical: AppTheme.spaceMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Working Search Input ───────────────────────────────────
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search courses or programs...',
                  hintStyle: TextStyle(
                    color: AppTheme.getTextTertiary(context),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppTheme.getTextTertiary(context),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppTheme.getTextTertiary(context),
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.getSurfaceVariant(context),
                  border: OutlineInputBorder(
                    borderRadius: AppTheme.borderRadiusMd,
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppTheme.borderRadiusMd,
                    borderSide: BorderSide(
                      color: AppTheme.getBorder(context),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppTheme.borderRadiusMd,
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spaceMd,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceLg),

              // ── 2. Segmented Navigation Controllers ────────────────────────
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Programs', label: Text('Programs')),
                  ButtonSegment(
                    value: 'Skill Courses',
                    label: Text('Skill Courses'),
                  ),
                ],
                selected: {_selectedSegment},
                onSelectionChanged: (Set<String> next) =>
                    setState(() => _selectedSegment = next.first),
                style: SegmentedButton.styleFrom(
                  backgroundColor: AppTheme.getSurfaceVariant(context),
                  selectedBackgroundColor: colorScheme.primary,
                  selectedForegroundColor: colorScheme.onPrimary,
                  foregroundColor: AppTheme.getTextSecondary(context),
                  side: BorderSide(color: AppTheme.getBorder(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.borderRadiusMd,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceLg),

              // ── 3. Topic Filters ─────────────────────────────────────────
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _topics.length,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedTopicIndex == index;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppTheme.spaceSm),
                      child: ChoiceChip(
                        label: Text(_topics[index]),
                        selected: isSelected,
                        onSelected: (_) =>
                            setState(() => _selectedTopicIndex = index),
                        selectedColor: colorScheme.primary,
                        backgroundColor: AppTheme.getSurfaceVariant(context),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? colorScheme.onPrimary
                              : AppTheme.getTextSecondary(context),
                        ),
                        showCheckmark: false,
                        side: BorderSide(
                          color: isSelected
                              ? colorScheme.primary
                              : AppTheme.getBorder(context),
                        ),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceSm,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppTheme.space2xl),

              // ── 4. Rendering View Selection Tree ───────────────────────────
              if (isLoading) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: AppTheme.spaceLg),
              ] else if (_selectedSegment == 'Skill Courses') ...[
                _SectionHeader(
                  onAction: () {},
                  eyebrow: 'SELECTED FOR YOU',
                  title: 'Featured Skill Courses',
                  actionLabel: "View All",
                ),
                const SizedBox(height: AppTheme.spaceMd),

                if (skillCourses.isEmpty)
                  const _EmptyState(
                    message: 'No courses match your search filter criteria',
                  )
                else if (MediaQuery.of(context).size.width > 700)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width > 1000 ? 4 : 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: skillCourses.length,
                    itemBuilder: (context, index) =>
                        _RealCourseCard(course: skillCourses[index]),
                  )
                else
                  SizedBox(
                    height: 260,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: skillCourses.length,
                      itemBuilder: (context, index) =>
                          _RealCourseCard(course: skillCourses[index]),
                    ),
                  ),
              ] else ...[
                _SectionHeader(
                  onAction: () {},

                  eyebrow: 'AVAILABLE PROGRAMS',
                  actionLabel: "View All",
                  title: 'Programs',
                ),
                const SizedBox(height: AppTheme.spaceMd),

                if (filteredPrograms.isEmpty)
                  const _EmptyState(
                    message: 'No learning programs match your filter criteria',
                    isProgram: true,
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredPrograms.length,
                    itemBuilder: (context, index) =>
                        _RealProgramTile(program: filteredPrograms[index]),
                  ),
              ],
              const SizedBox(height: AppTheme.spaceLg),
            ],
          ),
        ),
      ),
          ),
        ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final bool isProgram;
  const _EmptyState({required this.message, this.isProgram = false});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      type: isProgram ? EmptyStateType.noPrograms : EmptyStateType.noCourses,
      message: message,
      illustrationSize: 120,
    );
  }
}

// ── Real Course Card ──────────────────────────────────────
class _RealCourseCard extends StatelessWidget {
  final CourseResponse course;
  const _RealCourseCard({required this.course});

  static const _icons = [
    Icons.design_services,
    Icons.analytics,
    Icons.campaign,
    Icons.phone_android,
    Icons.science,
    Icons.psychology,
  ];

  static const _gradients = [
    [Color(0xFF667eea), Color(0xFF764ba2)],
    [Color(0xFF0b8793), Color(0xFF360033)],
    [Color(0xFFf093fb), Color(0xFFf5576c)],
    [Color(0xFF4facfe), Color(0xFF00f2fe)],
    [Color(0xFF43e97b), Color(0xFF38f9d7)],
    [Color(0xFFfa709a), Color(0xFFfee140)],
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconIndex = course.name.length % _icons.length;
    final gradIndex = course.name.length % _gradients.length;
    final isGrid = MediaQuery.of(context).size.width > 700;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: AppTheme.borderRadiusLg,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CourseIntroScreen(course: course)),
        ),
        borderRadius: AppTheme.borderRadiusLg,
        child: Container(
          width: isGrid ? null : 220,
          margin: isGrid ? null : const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.getBorder(context), width: 1),
            borderRadius: AppTheme.borderRadiusLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: isGrid ? 100 : 110,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _gradients[gradIndex].map((c) => c.withValues(alpha: 0.15)).toList(),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(_icons[iconIndex], size: 36, color: _gradients[gradIndex][0]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.type.name.toUpperCase(),
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (course.organization?.name != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.school_outlined, size: 13, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              course.organization!.name ?? '',
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Real Program Tile ─────────────────────────────────────
class _RealProgramTile extends StatefulWidget {
  final ProgramResponse program;
  const _RealProgramTile({required this.program});

  @override
  State<_RealProgramTile> createState() => _RealProgramTileState();
}

class _RealProgramTileState extends State<_RealProgramTile> {
  bool _enrolling = false;

  ProgramResponse get program => widget.program;

  void _openProgram() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProgramIntroScreen(program: program),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _enroll(EnrollmentProvider enrollProv) async {
    final userId = UserSessionManager.userId;
    if (userId == null) {
      _snack('Please sign in to enroll');
      return;
    }
    final orgId = program.organizationId;

    // Org staff (owner / admin / teacher / staff) run the program — they must
    // not be able to self-enrol as a student in it.
    if (orgId != null && UserSessionManager.isOrgStaff(orgId)) {
      _snack("You manage this program, so you can't enrol as a student.");
      return;
    }

    // Not yet a member of the host org → enrolment needs admin approval first.
    // Send an access request tagged with this program so the admin sees exactly
    // what the user wants to join.
    if (orgId != null && !UserSessionManager.isMemberOf(orgId)) {
      await _requestAccess(orgId);
      return;
    }

    // 💳 Paid program → fake payment first (real gateway TODO).
    if (program.isPaid) {
      final paid = await showFakePaymentSheet(context, program: program);
      if (paid != true) return;
      if (!mounted) return;
    }

    setState(() => _enrolling = true);
    // Member student self-enrolment defaults to PENDING; an admin approves it.
    final result = await enrollProv.enrollProgram(
      ProgramEnrollmentRequest(
        userId: userId,
        programId: program.id,
        status: EnrollmentStatus.PENDING,
      ),
    );
    if (!mounted) return;
    setState(() => _enrolling = false);

    if (result != null) {
      // enrollProgram appends to myProgramEnrollments, so the watching
      // build() below flips this card to the "enrolled" state automatically.
      _snack('Enrolled — pending approval');
    } else {
      final err = (enrollProv.error ?? '').toLowerCase();
      if (err.contains('409') || err.contains('already')) {
        _snack("You're already enrolled");
      } else if (err.contains('staff') || err.contains('owner')) {
        _snack("You manage this program, so you can't enrol as a student.");
      } else {
        _snack('Could not enroll. Please try again.');
      }
    }
  }

  /// Non-members can't enrol directly — ask the org admin/owner for access,
  /// carrying the target program so the request list shows what they want.
  Future<void> _requestAccess(String orgId) async {
    setState(() => _enrolling = true);
    try {
      await context.read<ApiService>().createAccessRequest({
        'organizationId': orgId,
        'requestedRole': 'STUDENT',
        'programId': program.id,
        'message': 'Requesting to enrol in ${program.name}',
      });
      if (!mounted) return;
      setState(() => _enrolling = false);
      // Persist the "requested" state via the provider so it survives rebuilds
      // and app restarts (not a lost local bool).
      context
          .read<EnrollmentProvider>()
          .markRequested(programId: program.id, orgId: orgId);
      _snack('Request sent — an admin will review your enrollment.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _enrolling = false);
      if (e.toString().toLowerCase().contains('already')) {
        context
            .read<EnrollmentProvider>()
            .markRequested(programId: program.id, orgId: orgId);
        _snack('You have already requested to join.');
      } else {
        _snack('Could not send request. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Cross-verify matching program status strings
    final enrollProv = context.watch<EnrollmentProvider>();
    final matchedEnrollment = enrollProv.myProgramEnrollments.firstWhere(
      (element) => element.programId == program.id,
      orElse: () => enrollmentNullFallback(),
    );

    final isEnrolled = matchedEnrollment.id != "NONE";
    final enrolledCount = program.count?.enrollments ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: InkWell(
        onTap: _openProgram,
        borderRadius: AppTheme.borderRadiusLg,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: AppTheme.borderRadiusMd,
                    ),
                    child:
                        Icon(Icons.school_rounded, color: colorScheme.primary),
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          program.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // 🏢 Real Organization Detail row injection
                        Text(
                          'Hosted by: ${program.organization?.name ?? "Brainy Buds Hub"}',
                          style: TextStyle(
                            color: colorScheme.tertiary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Courses / type + REAL enrolled count
                        Row(
                          children: [
                            Text(
                              '${program.programCourses.length} Courses • ${program.type.name}',
                              style: TextStyle(
                                color: AppTheme.getTextSecondary(context),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.groups_rounded,
                              size: 13,
                              color: AppTheme.getTextTertiary(context),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$enrolledCount enrolled',
                              style: TextStyle(
                                color: AppTheme.getTextSecondary(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 🎨 Render dynamic badge when already enrolled
                  if (isEnrolled)
                    _StatusBadge(status: matchedEnrollment.status.name),
                ],
              ),
              const SizedBox(height: AppTheme.spaceSm),
              // ── Primary action: Enroll vs Go-to-program ──
              _buildAction(context, colorScheme, isEnrolled, enrollProv),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAction(
    BuildContext context,
    ColorScheme colorScheme,
    bool isEnrolled,
    EnrollmentProvider enrollProv,
  ) {
    const padding = EdgeInsets.symmetric(vertical: 11, horizontal: 18);
    const textStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);

    if (isEnrolled) {
      return Row(
        children: [
          Icon(Icons.check_circle_rounded,
              size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            'Already enrolled',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _openProgram,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('Go to program', style: textStyle),
            style: OutlinedButton.styleFrom(
              padding: padding,
              foregroundColor: colorScheme.primary,
              side: BorderSide(color: colorScheme.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      );
    }

    final orgId = program.organizationId;
    final isStaff = orgId != null && UserSessionManager.isOrgStaff(orgId);
    final isMember = orgId == null || UserSessionManager.isMemberOf(orgId);

    // Org staff can't self-enrol — show a clear non-actionable state.
    if (isStaff) {
      return Row(
        children: [
          Icon(Icons.verified_user_rounded,
              size: 16, color: colorScheme.tertiary),
          const SizedBox(width: 6),
          Text(
            'You manage this program',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.tertiary,
            ),
          ),
        ],
      );
    }

    // Non-member who already fired off an access request (provider-backed so it
    // survives rebuilds / restarts).
    final requested = enrollProv.hasPendingProgramRequest(program.id) ||
        (orgId != null && enrollProv.hasPendingOrgRequest(orgId));
    if (requested) {
      return Row(
        children: [
          Icon(Icons.hourglass_top_rounded,
              size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            'Enrollment requested',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ],
      );
    }

    final label = isMember ? 'Enroll' : 'Request to enroll';
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton(
        onPressed: _enrolling ? null : () => _enroll(enrollProv),
        style: ElevatedButton.styleFrom(
          padding: padding,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: _enrolling
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label, style: textStyle),
      ),
    );
  }
}

// ── Course Intro Screen ───────────────────────────────────
class CourseIntroScreen extends StatefulWidget {
  final CourseResponse course;
  const CourseIntroScreen({super.key, required this.course});

  static const _icons = [
    Icons.design_services,
    Icons.analytics,
    Icons.campaign,
    Icons.phone_android,
    Icons.science,
    Icons.psychology,
  ];

  @override
  State<CourseIntroScreen> createState() => _CourseIntroScreenState();
}

class _ClassPickerSheet extends StatefulWidget {
  final List<ClassModel> classes; // shallow list from CourseResponse
  const _ClassPickerSheet({required this.classes});

  @override
  State<_ClassPickerSheet> createState() => _ClassPickerSheetState();
}

class _ClassPickerSheetState extends State<_ClassPickerSheet> {
  ClassModel? _selected;

  // ✅ Map of classId → fully loaded ClassModel (with members + maxStudents)
  final Map<String, ClassModel> _detailCache = {};
  bool _loadingDetails = true;

  @override
  void initState() {
    super.initState();
    _loadAllClassDetails();
  }

  Future<void> _loadAllClassDetails() async {
    final api = context.read<ClassProvider>();
    // Fetch all classes in parallel
    final futures = widget.classes
        .where((c) => c.id != null)
        .map((c) => api.getClassById(c.id!));

    final results = await Future.wait(futures);

    if (!mounted) return;
    setState(() {
      for (final result in results) {
        if (result != null && result.id != null) {
          _detailCache[result.id!] = result;
        }
      }
      _loadingDetails = false;
    });
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.getBorder(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choose a Class',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${widget.classes.length} available',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Select the class schedule that works for you.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),

            // ✅ Loading state while fetching class details
            if (_loadingDetails)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: widget.classes.length,
                  itemBuilder: (_, i) {
                    final shallow = widget.classes[i];
                    // ✅ Use full detail if loaded, fall back to shallow
                    final c = _detailCache[shallow.id] ?? shallow;

                    final isSelected = _selected?.id == c.id;
                    final now = DateTime.now();

                    // ✅ Prefer isActive from API, fall back to date calc
                    final isActive =
                        c.isActive ??
                        ((c.startDate?.isBefore(now) ?? false) &&
                            (c.endDate?.isAfter(now) ?? false));
                    final isUpcoming =
                        !(c.isActive ?? false) &&
                        (c.startDate?.isAfter(now) ?? false);

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

                    // ✅ Real spots calculation
                    final taken = c.members.length;
                    final max = c.maxStudents;
                    final spotsLeft = max != null ? max - taken : null;
                    final isFull = spotsLeft != null && spotsLeft <= 0;

                    return GestureDetector(
                      onTap: isFull
                          ? null // ✅ Can't select a full class
                          : () => setState(() => _selected = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isFull
                              ? AppTheme.getSurfaceVariant(context)
                              : isSelected
                              ? cs.primary.withValues(alpha: 0.07)
                              : Theme.of(context).cardColor,
                          borderRadius: AppTheme.borderRadiusLg,
                          border: Border.all(
                            color: isSelected
                                ? cs.primary
                                : AppTheme.getBorder(context),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Radio
                            Container(
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.only(top: 2, right: 12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isFull
                                      ? AppTheme.getBorder(context)
                                      : isSelected
                                      ? cs.primary
                                      : AppTheme.getBorder(context),
                                  width: 2,
                                ),
                                color: isSelected
                                    ? cs.primary
                                    : Colors.transparent,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      size: 12,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),

                            Expanded(
                              child: Opacity(
                                opacity: isFull ? 0.45 : 1.0,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            c.name ?? 'Unnamed Class',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: isSelected
                                                      ? cs.primary
                                                      : null,
                                                ),
                                          ),
                                        ),
                                        // Status badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            statusLabel,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: statusColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),

                                    // Date range
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_outlined,
                                          size: 12,
                                          color: AppTheme.getTextSecondary(
                                            context,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${_fmt(c.startDate)} → ${_fmt(c.endDate)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color:
                                                    AppTheme.getTextSecondary(
                                                      context,
                                                    ),
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),

                                    // ✅ Spots row with real data
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.people_outline,
                                          size: 12,
                                          color: isFull
                                              ? Colors.red
                                              : AppTheme.getTextSecondary(
                                                  context,
                                                ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          max == null
                                              ? '$taken enrolled'
                                              : isFull
                                              ? 'Class full ($taken/$max)'
                                              : '$taken/$max enrolled · $spotsLeft spots left',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: isFull
                                                    ? Colors.red
                                                    : AppTheme.getTextSecondary(
                                                        context,
                                                      ),
                                                fontWeight: isFull
                                                    ? FontWeight.w600
                                                    : null,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Confirm button
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected == null
                      ? null
                      : () => Navigator.pop(context, _selected),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    disabledBackgroundColor: AppTheme.getBorder(context),
                  ),
                  child: Text(
                    _selected == null
                        ? 'Select a class to continue'
                        : 'Enroll in ${_selected!.name ?? 'this class'}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseIntroScreenState extends State<CourseIntroScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<StructureProvider>().getCourseDetailById(widget.course.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final authProv = context.read<AuthProvider>();
    final enrollProv = context.read<EnrollmentProvider>();
    final iconIndex =
        widget.course.name.length % CourseIntroScreen._icons.length;
    final structProv = context.watch<StructureProvider>();
    final courseDetail = structProv.courseDetail ?? widget.course;
    Future<ClassModel?> _showClassPickerDialog(
      BuildContext context,
      List<ClassModel> classes,
    ) async {
      return showModalBottomSheet<ClassModel>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _ClassPickerSheet(classes: classes),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.tertiary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(
                    CourseIntroScreen._icons[iconIndex],
                    size: 72,
                    color: cs.onPrimary.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: AppTheme.borderRadiusSm,
                    ),
                    child: Text(
                      widget.course.type.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),

                  // Name
                  Align(
                    alignment: AlignmentGeometry.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          textAlign: TextAlign.left,
                          "${widget.course.name}  ",

                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        if (widget.course.organization?.name != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: cs.tertiary.withValues(alpha: 0.1),
                              borderRadius: AppTheme.borderRadiusSm,
                              border: Border.all(
                                color: cs.tertiary.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.school_outlined,
                                  size: 13,
                                  color: cs.tertiary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Hosted by ${widget.course.organization!.name}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: cs.tertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),

                  // Description
                  if (widget.course.description != null) ...[
                    Text(
                      'About this course',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    Text(
                      widget.course.description!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.getTextSecondary(context),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLg),
                  ],

                  // Details card
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceMd),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: AppTheme.borderRadiusLg,
                      border: Border.all(color: AppTheme.getBorder(context)),
                    ),
                    child: Column(
                      children: [
                        _DetailRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Created',
                          value: widget.course.createdAt.toString().split(
                            ' ',
                          )[0],
                        ),
                        const Divider(height: AppTheme.spaceLg),
                        _DetailRow(
                          icon: Icons.update_outlined,
                          label: 'Last Updated',
                          value: widget.course.updatedAt.toString().split(
                            ' ',
                          )[0],
                        ),
                        const Divider(height: AppTheme.spaceLg),
                        _DetailRow(
                          icon: Icons.category_outlined,
                          label: 'Type',
                          value: widget.course.type.name,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.space2xl),

                  // Enroll button
                  SizedBox(
                    width: double.infinity,
                    child: Consumer<EnrollmentProvider>(
                      builder: (context, enrollProv, _) => FilledButton(
                        onPressed: enrollProv.isLoading
                            ? null
                            : () async {
                                debugPrint(
                                  "🚀 [Enroll Button] Pressed for Course: ${widget.course.name}",
                                );

                                // 1. Check Authenticated User
                                final userId = UserSessionManager.userId;
                                debugPrint(
                                  "👤 [Enroll Button] User ID: $userId",
                                );
                                if (userId == null) {
                                  debugPrint(
                                    "🛑 [Enroll Button] Stopped: User ID is NULL.",
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please log in to enroll.'),
                                    ),
                                  );
                                  return;
                                }

                                // 2. Check Organization & Roles
                                final orgProv = context
                                    .read<OrganizationProvider>();
                                final orgId = widget.course.organization?.id;
                                debugPrint(
                                  "🏢 [Enroll Button] Organization ID: $orgId",
                                );

                                if (orgId == null) {
                                  debugPrint(
                                    "🛑 [Enroll Button] Stopped: course.organization.id is NULL.",
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Invalid course organization',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                final role = orgProv.getOrgRole(orgId);
                                debugPrint(
                                  "🔑 [Enroll Button] User Organization Role: $role",
                                );
                                if (role == Role.ORG_ADMIN) {
                                  debugPrint(
                                    "🛑 [Enroll Button] Stopped: User is ORG_ADMIN.",
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'You are already an admin for this course.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                // 3. Check if classes exist inside the course object directly
                                final courseClasses =
                                    courseDetail.classes ?? [];
                                debugPrint(
                                  "📚 [Enroll Button] Total classes inside this course object: ${courseClasses.length}",
                                );

                                if (courseClasses.isEmpty) {
                                  debugPrint(
                                    "🛑 [Enroll Button] Stopped: course.classes is empty.",
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No classes available for this course yet.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                // Safely grab the first class instance from the course
                                final targetedClass = courseClasses.first;
                                debugPrint(
                                  "🔍 [Enroll Button] Target Class Selected: ${targetedClass.id}",
                                );

                                // 4. Fire Request
                                debugPrint(
                                  "📡 [Enroll Button] All guards passed! Sending payload to provider...",
                                );
                                final result = await enrollProv.enrollCourse(
                                  CourseEnrollmentRequest(
                                    userId: userId,
                                    courseId: widget.course.id,
                                    classId: targetedClass.id.toString(),
                                    status: "PENDING",
                                  ),
                                );

                                debugPrint(
                                  "🏁 [Enroll Button] Execution returned. Server response result: $result",
                                );

                                if (!context.mounted) return;

                                // 5. Handle Toast/SnackBar UX Response
                                String snackBarMessage;
                                Color snackBarColor = Colors.black;

                                if (result != null) {
                                  snackBarMessage =
                                      'Enrolled in ${widget.course.name} successfully!';
                                  snackBarColor = Colors.green;
                                } else if (enrollProv.error != null) {
                                  final errorMsg = enrollProv.error!;

                                  // 🎯 FIX: Check for the 403 Backend Organization context rejection message
                                  if (errorMsg.contains("403") ||
                                      errorMsg.toLowerCase().contains(
                                        "missing target organization",
                                      ) ||
                                      errorMsg.toLowerCase().contains(
                                        "forbidden",
                                      )) {
                                    snackBarMessage =
                                        "You need to be in this organization first to enroll this program/course";
                                    snackBarColor = Colors.red;
                                  } else if (errorMsg.contains(
                                        "User already enrolled in this course",
                                      ) ||
                                      errorMsg.contains(
                                        "User already enrolled in this program",
                                      ) ||
                                      errorMsg.contains("409")) {
                                    snackBarMessage =
                                        'You are already enrolled in this course.';
                                    snackBarColor = Colors.orange;
                                  } else {
                                    snackBarMessage = errorMsg;
                                    snackBarColor = Colors.red;
                                  }
                                } else {
                                  snackBarMessage =
                                      'Enrollment failed. Please try again.';
                                  snackBarColor = Colors.red;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(snackBarMessage),
                                    backgroundColor: snackBarColor,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                        // onPressed: enrollProv.isLoading
                        //     ? null
                        //     : () async {
                        //         final userId = UserSessionManager.userId;
                        //         if (userId == null) {
                        //           ScaffoldMessenger.of(context).showSnackBar(
                        //             const SnackBar(
                        //               content: Text('Please log in to enroll.'),
                        //             ),
                        //           );
                        //           return;
                        //         }
                        //
                        //         final orgId = widget.course.organization?.id;
                        //         if (orgId == null) {
                        //           ScaffoldMessenger.of(context).showSnackBar(
                        //             const SnackBar(
                        //               content: Text(
                        //                 'Invalid course organization.',
                        //               ),
                        //             ),
                        //           );
                        //           return;
                        //         }
                        //
                        //         final role = context
                        //             .read<OrganizationProvider>()
                        //             .getOrgRole(orgId);
                        //         if (role == Role.ORG_ADMIN) {
                        //           ScaffoldMessenger.of(context).showSnackBar(
                        //             const SnackBar(
                        //               content: Text(
                        //                 'You are already an admin for this course.',
                        //               ),
                        //             ),
                        //           );
                        //           return;
                        //         }
                        //
                        //         final courseClasses =
                        //             structProv.courseDetail?.classes ?? [];
                        //         if (courseClasses.isEmpty) {
                        //           ScaffoldMessenger.of(context).showSnackBar(
                        //             const SnackBar(
                        //               content: Text(
                        //                 'No classes available for this course yet.',
                        //               ),
                        //             ),
                        //           );
                        //           return;
                        //         }
                        //
                        //         // ✅ Show class picker — student picks which class to join
                        //         final chosenClass =
                        //             await _showClassPickerDialog(
                        //               context,
                        //               courseClasses,
                        //             );
                        //         if (chosenClass == null)
                        //           return; // user dismissed
                        //
                        //         final result = await enrollProv.enrollCourse(
                        //           CourseEnrollmentRequest(
                        //             userId: userId,
                        //             courseId: widget.course.id,
                        //             classId: chosenClass.id.toString(),
                        //             status: "PENDING",
                        //           ),
                        //         );
                        //
                        //         if (!context.mounted) return;
                        //
                        //         String message;
                        //         Color color;
                        //
                        //         if (result != null) {
                        //           message =
                        //               'Enrolled in ${widget.course.name} successfully!';
                        //           color = Colors.green;
                        //         } else if (enrollProv.error != null) {
                        //           final err = enrollProv.error!;
                        //           if (err.contains("already enrolled") ||
                        //               err.contains("409")) {
                        //             message =
                        //                 'You are already enrolled in this course.';
                        //             color = Colors.orange;
                        //           } else {
                        //             message = err;
                        //             color = Colors.red;
                        //           }
                        //         } else {
                        //           message =
                        //               'Enrollment failed. Please try again.';
                        //           color = Colors.red;
                        //         }
                        //
                        //         ScaffoldMessenger.of(context).showSnackBar(
                        //           SnackBar(
                        //             content: Text(message),
                        //             backgroundColor: color,
                        //             behavior: SnackBarBehavior.floating,
                        //           ),
                        //         );
                        //       },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spaceMd,
                          ),
                        ),
                        child: enrollProv.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Enroll Now',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
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

// ── Program Intro Screen ──────────────────────────────────
class ProgramIntroScreen extends StatefulWidget {
  final ProgramResponse program;
  const ProgramIntroScreen({super.key, required this.program});

  @override
  State<ProgramIntroScreen> createState() => _ProgramIntroScreenState();
}

class _ProgramIntroScreenState extends State<ProgramIntroScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<StructureProvider>().getProgramDetailById(widget.program.id);
      final enrollProv = context.read<EnrollmentProvider>();
      final userId = UserSessionManager.userId;
      if (userId != null) {
        enrollProv.fetchCurrentUserEnrollments(userId);
      }
      // So the button can render "Enrollment requested" if one is already open.
      enrollProv.fetchMyAccessRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final structProv = context.watch<StructureProvider>();
    final authProv = context.read<AuthProvider>();

    final program = structProv.programDetail ?? widget.program;
    final courses = program.programCourses.map((pc) => pc.course).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.primary.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.school_rounded,
                    size: 72,
                    color: cs.onPrimary.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: AppTheme.borderRadiusSm,
                    ),
                    child: Text(
                      program.type.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),

                  // Name
                  Text(
                    program.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.school, size: 15),

                      Text(
                        " ${program.organization?.name}",
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceSm),

                  // Stats row
                  Row(
                    children: [
                      Icon(
                        Icons.book_outlined,
                        size: 16,
                        color: AppTheme.getTextSecondary(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${courses.length} Courses',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.getTextSecondary(context),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceMd),
                      Icon(
                        Icons.people_outline,
                        size: 16,
                        color: AppTheme.getTextSecondary(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${program.count?.enrollments ?? 0} Enrolled',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceMd),

                  // 💳 Pricing
                  _PricingPill(program: program),
                  const SizedBox(height: AppTheme.spaceMd),

                  // 🏢 Organization info
                  if (program.organization != null)
                    _OrgInfoCard(org: program.organization!),
                  const SizedBox(height: AppTheme.spaceMd),

                  // 📊 Program analysis / counts
                  _ProgramAnalysisRow(program: program, courses: courses),
                  const SizedBox(height: AppTheme.spaceLg),

                  // Description — guard empty and the literal "null" string a
                  // backend sometimes serialises for a missing value.
                  if (program.description != null &&
                      program.description!.trim().isNotEmpty &&
                      program.description!.trim().toLowerCase() != 'null') ...[
                    Text(
                      'About this program',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    Text(
                      program.description!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.getTextSecondary(context),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLg),
                  ],

                  // Courses in this program
                  if (structProv.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (courses.isNotEmpty) ...[
                    Text(
                      'Courses in this Program',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    ...courses.map(
                      (course) => _ProgramCourseListTile(course: course),
                    ),
                    const SizedBox(height: AppTheme.spaceLg),
                  ],

                  // Enroll button
                  SizedBox(
                    width: double.infinity,
                    child: Consumer<EnrollmentProvider>(
                      builder: (context, enrollProv, _) {
                        // 💡 Determine if the context object is a Program or a Course
                        // (Adjust this check based on how your 'program' or 'course' model is named/typed)
                        final isProgramType = program.programCourses != null;

                        // Already enrolled, or already sent an access request?
                        // Show a non-actionable status chip instead of the button
                        // so it doesn't keep saying "Enroll Now" after a request.
                        final orgIdChip = program.organization?.id;
                        final alreadyEnrolled = enrollProv.myProgramEnrollments
                            .any((e) =>
                                e.programId == program.id && e.id != 'NONE');
                        final alreadyRequested =
                            enrollProv.hasPendingProgramRequest(program.id) ||
                                (orgIdChip != null &&
                                    enrollProv.hasPendingOrgRequest(orgIdChip));
                        if (alreadyEnrolled || alreadyRequested) {
                          final cs2 = Theme.of(context).colorScheme;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppTheme.spaceMd),
                            decoration: BoxDecoration(
                              color: cs2.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  alreadyEnrolled
                                      ? Icons.check_circle_rounded
                                      : Icons.hourglass_top_rounded,
                                  size: 18,
                                  color: cs2.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  alreadyEnrolled
                                      ? 'Enrolled'
                                      : 'Enrollment requested',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: cs2.primary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return FilledButton(
                          onPressed: enrollProv.isLoading
                              ? null
                              : () async {
                                  debugPrint(
                                    "🚀 [Enroll Button] Pressed. Type: ${isProgramType ? 'PROGRAM' : 'COURSE'}",
                                  );

                                  // 1. Check Authenticated User
                                  final userId = UserSessionManager.userId;
                                  debugPrint(
                                    "👤 [Enroll Button] User ID: $userId",
                                  );
                                  if (userId == null) {
                                    debugPrint(
                                      "🛑 [Enroll Button] Stopped: User ID is NULL.",
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please log in to enroll.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  // 2. Check Organization & Roles
                                  final orgProv = context
                                      .read<OrganizationProvider>();
                                  final orgId = program.organization?.id;
                                  debugPrint(
                                    "🏢 [Enroll Button] Organization ID: $orgId",
                                  );

                                  if (orgId == null) {
                                    debugPrint(
                                      "🛑 [Enroll Button] Stopped: organization.id is NULL.",
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Invalid organization'),
                                      ),
                                    );
                                    return;
                                  }

                                  final role = orgProv.getOrgRole(orgId);
                                  debugPrint(
                                    "🔑 [Enroll Button] User Organization Role: $role",
                                  );
                                  // Org staff (owner/admin/teacher/staff) run
                                  // this — they can't self-enrol as a student.
                                  if (UserSessionManager.isOrgStaff(orgId)) {
                                    debugPrint(
                                      "🛑 [Enroll Button] Stopped: user is org staff.",
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "You manage this ${isProgramType ? 'program' : 'course'}, so you can't enrol as a student.",
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  // Not a member of the host org yet → enrolment
                                  // needs admin approval. Send an access request
                                  // tagged with the program instead of enrolling.
                                  if (!UserSessionManager.isMemberOf(orgId)) {
                                    try {
                                      await context
                                          .read<ApiService>()
                                          .createAccessRequest({
                                        'organizationId': orgId,
                                        'requestedRole': 'STUDENT',
                                        if (isProgramType)
                                          'programId': program.id,
                                        'message': isProgramType
                                            ? 'Requesting to enrol in ${program.name}'
                                            : 'Requesting access to enrol',
                                      });
                                      if (!context.mounted) return;
                                      // Persist so the button flips to
                                      // "Enrollment requested" and stays that way.
                                      enrollProv.markRequested(
                                        programId:
                                            isProgramType ? program.id : null,
                                        orgId: orgId,
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Request sent — an admin will review your enrollment.',
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      final already = e
                                          .toString()
                                          .toLowerCase()
                                          .contains('already');
                                      if (already) {
                                        enrollProv.markRequested(
                                          programId:
                                              isProgramType ? program.id : null,
                                          orgId: orgId,
                                        );
                                      }
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(already
                                              ? 'You have already requested to join.'
                                              : 'Could not send request. Please try again.'),
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  // 💳 Paid program → fake payment first.
                                  if (isProgramType && program.isPaid) {
                                    final paid = await showFakePaymentSheet(
                                      context,
                                      program: program,
                                    );
                                    if (paid != true) return;
                                    if (!context.mounted) return;
                                  }

                                  // 3. Conditional Content & Target Verification
                                  dynamic result;

                                  if (isProgramType) {
                                    // ── PROGRAM VALIDATION RULE ──
                                    // Check if the program has courses attached
                                    final coursesList =
                                        program.programCourses ?? [];
                                    debugPrint(
                                      "📋 [Enroll Button] Total courses in Program: ${coursesList.length}",
                                    );

                                    if (coursesList.isEmpty) {
                                      debugPrint(
                                        "🛑 [Enroll Button] Stopped: Program has no courses.",
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'This program does not have any courses yet.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    debugPrint(
                                      "📡 [Enroll Button] Sending Program enrollment payload...",
                                    );
                                    result = await enrollProv.enrollProgram(
                                      ProgramEnrollmentRequest(
                                        userId: userId,
                                        programId: program.id,
                                        status: EnrollmentStatus.PENDING,
                                      ),
                                    );
                                  } else {
                                    // ── COURSE VALIDATION RULE ──
                                    // Check if the course contains local classes or check via ClassProvider
                                    final classProv = context
                                        .read<ClassProvider>();

                                    final matchingClass = classProv.classes
                                        .where((c) => c.courseId == program.id)
                                        .firstOrNull;

                                    debugPrint(
                                      "🔍 [Enroll Button] Matching Class Found: $matchingClass",
                                    );

                                    if (matchingClass == null) {
                                      debugPrint(
                                        "🛑 [Enroll Button] Stopped: No classes available match course ID ${program.id}.",
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'No classes available for this course yet.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    debugPrint(
                                      "📡 [Enroll Button] Sending Course enrollment payload...",
                                    );
                                    result = await enrollProv.enrollCourse(
                                      CourseEnrollmentRequest(
                                        userId: userId,
                                        courseId: program.id,
                                        classId: matchingClass.id.toString(),
                                        status: "PENDING",
                                      ),
                                    );
                                  }

                                  debugPrint(
                                    "🏁 [Enroll Button] Execution returned. Result: $result",
                                  );

                                  if (!context.mounted) return;

                                  // 4. Handle Toast/SnackBar UX Response
                                  String snackBarMessage;
                                  Color snackBarColor = Colors.black;

                                  if (result != null) {
                                    snackBarMessage =
                                        'Enrolled in ${program.name} successfully!';
                                    snackBarColor = Colors.green;
                                  } else if (enrollProv.error != null) {
                                    final errorMsg = enrollProv.error!;

                                    // 🎯 FIX: Catch organization isolation level restriction errors on the program stream
                                    if (errorMsg.contains("403") ||
                                        errorMsg.toLowerCase().contains(
                                          "missing target organization",
                                        ) ||
                                        errorMsg.toLowerCase().contains(
                                          "forbidden",
                                        )) {
                                      snackBarMessage =
                                          "You need to be in this organization first to enroll this program/course";
                                      snackBarColor = Colors.red;
                                    } else if (errorMsg.contains(
                                          "User already enrolled",
                                        ) ||
                                        errorMsg.contains("409")) {
                                      snackBarMessage =
                                          'You are already enrolled in this program.';
                                      snackBarColor = Colors.orange;
                                    } else {
                                      snackBarMessage = errorMsg;
                                      snackBarColor = Colors.red;
                                    }
                                  } else {
                                    snackBarMessage =
                                        'Enrollment failed. Please try again.';
                                    snackBarColor = Colors.red;
                                  }

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(snackBarMessage),
                                      backgroundColor: snackBarColor,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spaceMd,
                            ),
                          ),
                          child: enrollProv.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Enroll Now',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceLg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Program Course List Tile ──────────────────────────────
class _ProgramCourseListTile extends StatelessWidget {
  final CourseResponseForProgram course;
  const _ProgramCourseListTile({required this.course});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final secondary = AppTheme.getTextSecondary(context);
    final teacher = course.teacher;
    final hasMeta = (course.category != null &&
            course.category!.trim().isNotEmpty) ||
        course.topics.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusMd,
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: AppTheme.borderRadiusSm,
                ),
                child: Icon(Icons.book_rounded, size: 18, color: cs.primary),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    // 👨‍🏫 Teacher line
                    Row(
                      children: [
                        Icon(Icons.person_rounded, size: 13, color: secondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            teacher?.name != null &&
                                    teacher!.name!.trim().isNotEmpty
                                ? teacher.name!
                                : 'Teacher to be assigned',
                            style: TextStyle(fontSize: 12, color: secondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (course.type != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: AppTheme.borderRadiusSm,
                  ),
                  child: Text(
                    course.type!.name,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
            ],
          ),
          // 🏷️ Category + topics chips
          if (hasMeta) ...[
            const SizedBox(height: AppTheme.spaceSm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (course.category != null &&
                    course.category!.trim().isNotEmpty)
                  _chip(context, course.category!, cs.tertiary, filled: true),
                ...course.topics.map((t) => _chip(context, t, secondary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, Color color,
      {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled
            ? color.withValues(alpha: 0.14)
            : Theme.of(context).colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
          color: filled ? color : AppTheme.getTextSecondary(context),
        ),
      ),
    );
  }
}

// ── 💳 Pricing pill (program detail) ──────────────────────
class _PricingPill extends StatelessWidget {
  final ProgramResponse program;
  const _PricingPill({required this.program});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final paid = program.isPaid;
    final color = paid ? cs.tertiary : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            paid
                ? (program.pricingType == ProgramPricingType.MONTHLY
                    ? Icons.autorenew_rounded
                    : Icons.payments_rounded)
                : Icons.volunteer_activism_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            program.priceLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (paid && program.pricingType == ProgramPricingType.ONE_TIME) ...[
            const SizedBox(width: 6),
            Text('· one-time',
                style: TextStyle(
                    fontSize: 11, color: AppTheme.getTextSecondary(context))),
          ],
        ],
      ),
    );
  }
}

// ── 🏢 Organization info card (program detail) ─────────────
class _OrgInfoCard extends StatelessWidget {
  final OrgResForProgramResponse org;
  const _OrgInfoCard({required this.org});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final secondary = AppTheme.getTextSecondary(context);
    final logo = org.logoUrl;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusMd,
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: cs.primary.withValues(alpha: 0.12),
            foregroundImage: (logo != null && logo.startsWith('http'))
                ? NetworkImage(logo)
                : null,
            child: Icon(Icons.apartment_rounded, color: cs.primary, size: 22),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(org.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (org.category != null &&
                        org.category!.trim().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.tertiary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(org.category!,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: cs.tertiary)),
                      ),
                    ],
                  ],
                ),
                if (org.description != null &&
                    org.description!.trim().isNotEmpty &&
                    org.description!.trim().toLowerCase() != 'null') ...[
                  const SizedBox(height: 4),
                  Text(org.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: secondary)),
                ],
                if (org.phone != null && org.phone!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.phone_rounded, size: 12, color: secondary),
                    const SizedBox(width: 4),
                    Text(org.phone!,
                        style: TextStyle(fontSize: 12, color: secondary)),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 📊 Program analysis / counts (program detail) ──────────
class _ProgramAnalysisRow extends StatelessWidget {
  final ProgramResponse program;
  final List<CourseResponseForProgram> courses;
  const _ProgramAnalysisRow({required this.program, required this.courses});

  @override
  Widget build(BuildContext context) {
    final enrolled = program.count?.enrollments ?? 0;
    final materials = courses.fold<int>(
        0, (sum, c) => sum + (c.count?.materials ?? 0));
    final teachers = courses
        .map((c) => c.teacher?.id)
        .whereType<String>()
        .toSet()
        .length;
    return Row(
      children: [
        _stat(context, Icons.menu_book_rounded, '${courses.length}', 'Courses'),
        _stat(context, Icons.people_alt_rounded, '$enrolled', 'Enrolled'),
        _stat(context, Icons.badge_rounded, '$teachers', 'Teachers'),
        _stat(context, Icons.folder_rounded, '$materials', 'Materials'),
      ],
    );
  }

  Widget _stat(
      BuildContext context, IconData icon, String value, String label) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: AppTheme.borderRadiusMd,
          border: Border.all(color: AppTheme.getBorder(context)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800)),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.getTextSecondary(context))),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color baseColor = Colors.grey;
    if (status == 'ACTIVE') baseColor = Colors.green;
    if (status == 'PENDING') baseColor = Colors.orange;
    if (status == 'ENDED') baseColor = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: baseColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: baseColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// Global safety map instance handler targeting elements without matching backend identifiers
Enrollment enrollmentNullFallback() {
  return Enrollment(
    id: "NONE",
    status: EnrollmentStatus.COMPLETED, // default structural state token
    enrolledAt: DateTime.now(),
  );
}

// ── Detail Row ────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: AppTheme.spaceMd),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.getTextSecondary(context),
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    this.eyebrow,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
            padding: EdgeInsets.zero,
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

// Keep your existing _SectionHeader, CourseCard, OrgTile unchanged
