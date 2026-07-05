import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/courses_provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/organisation_provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/programs_provider.dart';
import 'package:htoochoon_flutter/Providers/enrollment_provider.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/program_detail_screen.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/course_detail_screen.dart';
import 'package:htoochoon_flutter/Screens/Subsciption/subscription_screen.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';
import 'package:htoochoon_flutter/Widgets/empty_state_widget.dart';
import 'package:htoochoon_flutter/Widgets/responsive.dart';
import 'package:htoochoon_flutter/models/api_models/course_model.dart';
import 'package:htoochoon_flutter/models/api_models/program_model.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:htoochoon_flutter/models/api_models/organization_model.dart';
import 'package:provider/provider.dart';
import 'package:htoochoon_flutter/Providers/structure_provider.dart';

class _UpgradePlanSheet extends StatelessWidget {
  const _UpgradePlanSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.upgrade_rounded, size: 50, color: Colors.orange),
          const SizedBox(height: 12),

          const Text(
            "Limit Reached",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            "You've reached your program limit. Upgrade your subscription to continue creating more programs.",
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
          ),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);

              // navigate to plans page
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SubscriptionScreen()),
              );
            },
            child: const Text("Upgrade Plan"),
          ),
        ],
      ),
    );
  }
}

class CoursesScreen extends StatefulWidget {
  final String organisationId;
  final String accessedFrom;
  final bool isInShell;

  const CoursesScreen({
    super.key,
    required this.organisationId,
    required this.accessedFrom,
    this.isInShell = false,
  });

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  String _selected = 'Programs';
  // Sub-filter state for courses tab: 'ALL', 'SKILL', 'ACADEMIC'
  String _courseFilter = 'ALL';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final coursesProv = context.read<CoursesProvider>();
      final programsProv = context.read<ProgramsProvider>();
      final enrollProv = context.read<EnrollmentProvider>();
      final orgProv = context.read<OrganizationProvider>();

      await coursesProv.fetchCoursesInOrg(widget.organisationId, null);
      final role = orgProv.getOrgRole(widget.organisationId);

      if (role == Role.ORG_ADMIN || role == Role.TEACHER) {
        await programsProv.fetchProgramsInOrgId(widget.organisationId);
      } else {
        final userId = orgProv.currentUserId;
        if (userId != null) {
          await enrollProv.fetchCurrentUserEnrollments(userId);
        }
      }

      programsProv.onLimitReached = () {
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _UpgradePlanSheet(),
        );
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final coursesProv = context.watch<CoursesProvider>();
    final programsProv = context.watch<ProgramsProvider>();
    final programs = programsProv.programs;
    final isLoading = coursesProv.isLoading || programsProv.isLoading;
    final orgProv = context.watch<OrganizationProvider>();
    // Filter logic handling all variations across the broader base array
    final filteredCourses = coursesProv.courses.where((c) {
      if (_courseFilter == 'SKILL') return c.type == CourseType.SKILL;
      if (_courseFilter == 'ACADEMIC') return c.type == CourseType.ACADEMIC;
      return true; // 'ALL' configuration
    }).toList();
    final userRole = orgProv.getOrgRole(widget.organisationId);
    final isAllowedToEdit =
        (userRole == Role.ORG_ADMIN || userRole == Role.TEACHER);
    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              final coursesProv = context.read<CoursesProvider>();
              final programsProv = context.read<ProgramsProvider>();
              final enrollProv = context.read<EnrollmentProvider>();
              final orgProv = context.read<OrganizationProvider>();

              await coursesProv.fetchCoursesInOrg(widget.organisationId, null);
              final role = orgProv.getOrgRole(widget.organisationId);

              if (role == Role.ORG_ADMIN || role == Role.TEACHER) {
                await programsProv.fetchProgramsInOrgId(widget.organisationId);
              } else {
                final userId = orgProv.currentUserId;
                if (userId != null) {
                  await enrollProv.fetchCurrentUserEnrollments(userId);
                }
              }
            },
          ),
          SliverAppBar(
            automaticallyImplyLeading: !widget.isInShell,
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            title: Text(
              'Learning Paths',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.add_rounded, color: cs.primary),
                onPressed: () {
                  if (_selected == 'Programs') {
                    _showCreateProgramDialog(
                      context,
                      programsProv,
                      widget.organisationId,
                    );
                  } else {
                    _showCreateCourseDialog(
                      context,
                      coursesProv,
                      widget.organisationId,
                    );
                  }
                },
                tooltip: _selected == 'Programs'
                    ? 'Create Program'
                    : 'Create Course',
              ),
            ],
          ),

          if (isLoading)
            const SliverToBoxAdapter(child: LinearProgressIndicator()),

          if (coursesProv.error?.isNotEmpty == true)
            SliverToBoxAdapter(
              child: _ErrorBanner(
                message: coursesProv.error!,
                onDismiss: coursesProv.clearError,
              ),
            ),
          if (programsProv.error?.isNotEmpty == true)
            SliverToBoxAdapter(
              child: _ErrorBanner(
                message: programsProv.error!,
                onDismiss: programsProv.clearError,
              ),
            ),

          // Main Tabs Segment Header
          SliverToBoxAdapter(
            child: Padding(
              padding: centeredPagePadding(context, top: AppTheme.spaceLg, bottom: 0),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Programs', label: Text('Programs')),
                  ButtonSegment(
                    value: 'Courses',
                    label: Text('Courses'),
                  ), // Changed title label here
                ],
                selected: {_selected},
                onSelectionChanged: (v) => setState(() => _selected = v.first),
                style: SegmentedButton.styleFrom(
                  backgroundColor: AppTheme.getSurfaceVariant(context),
                  selectedBackgroundColor: cs.primary,
                  selectedForegroundColor: cs.onPrimary,
                  foregroundColor: AppTheme.getTextSecondary(context),
                  side: BorderSide(color: AppTheme.getBorder(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.borderRadiusMd,
                  ),
                ),
              ),
            ),
          ),

          // Inline Sub-filter controls rendered safely for Courses Tab context
          if (_selected == 'Courses')
            SliverToBoxAdapter(
              child: Padding(
                padding: centeredPagePadding(
                  context,
                  top: AppTheme.spaceMd,
                  bottom: AppTheme.spaceMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(context, 'ALL', 'All Courses'),
                          const SizedBox(width: 8),
                          _buildFilterChip(context, 'SKILL', 'Skill Courses'),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            context,
                            'ACADEMIC',
                            'Academic Courses',
                          ),
                        ],
                      ),
                    ),
                    // Information Context banner dynamically triggered on relevant filters
                    if (_courseFilter == 'ACADEMIC' ||
                        _courseFilter == 'ALL') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer.withValues(alpha: 0.4),
                          borderRadius: AppTheme.borderRadiusMd,
                          border: Border.all(color: cs.secondaryContainer),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: cs.onSecondaryContainer,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Academic courses need to be added into a program layout framework to be accessible.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: cs.onSecondaryContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          if (_selected == 'Programs') ...[
            if (programs.isEmpty && !isLoading)
              SliverFillRemaining(
                child: _EmptyState(
                  message: 'No programs yet',
                  buttonText: 'Create Program',
                  onAdd: () => _showCreateProgramDialog(
                    context,
                    programsProv,
                    widget.organisationId,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: centeredPagePadding(
                  context,
                  top: AppTheme.spaceLg,
                  bottom: AppTheme.spaceLg,
                ),
                sliver: MediaQuery.of(context).size.width > 700
                    ? SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: MediaQuery.of(context).size.width > 1000 ? 3 : 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 185,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return _ProgramCard(
                            isEditable: isAllowedToEdit,
                            onEdit: () => _showEditProgramDialog(context, programsProv, programs[index]),
                            program: programs[index],
                            onDelete: () => _confirmDeleteProgram(context, programsProv, programs[index]),
                            onAddCourse: () {
                              _showAddCourseToProgramDialog(
                                context, context.read<StructureProvider>(), coursesProv, programs[index],
                              );
                            },
                          );
                        }, childCount: programs.length),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ProgramCard(
                              isEditable: isAllowedToEdit,
                              onEdit: () => _showEditProgramDialog(context, programsProv, programs[index]),
                              program: programs[index],
                              onDelete: () => _confirmDeleteProgram(context, programsProv, programs[index]),
                              onAddCourse: () {
                                _showAddCourseToProgramDialog(
                                  context, context.read<StructureProvider>(), coursesProv, programs[index],
                                );
                              },
                            ),
                          );
                        }, childCount: programs.length),
                      ),
              ),
          ] else ...[
            if (filteredCourses.isEmpty && !isLoading)
              SliverFillRemaining(
                child: _EmptyState(
                  message: 'No courses match this filter',
                  buttonText: 'Create Course',
                  onAdd: () => _showCreateCourseDialog(
                    context,
                    coursesProv,
                    widget.organisationId,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: centeredPagePadding(
                  context,
                  top: AppTheme.spaceMd,
                  bottom: AppTheme.spaceLg,
                ),
                sliver: MediaQuery.of(context).size.width > 700
                    ? SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              MediaQuery.of(context).size.width > 1000 ? 3 : 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 300,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return _SkillCourseCard(
                            onEdit: () => _showEditCourseDialog(
                              context,
                              coursesProv,
                              filteredCourses[index],
                            ),
                            course: filteredCourses[index],
                            onDelete: () => _confirmDeleteCourse(
                              context,
                              coursesProv,
                              filteredCourses[index],
                            ),
                          );
                        }, childCount: filteredCourses.length),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppTheme.spaceMd),
                            child: _SkillCourseCard(
                              onEdit: () => _showEditCourseDialog(
                                context,
                                coursesProv,
                                filteredCourses[index],
                              ),
                              course: filteredCourses[index],
                              onDelete: () => _confirmDeleteCourse(
                                context,
                                coursesProv,
                                filteredCourses[index],
                              ),
                            ),
                          );
                        }, childCount: filteredCourses.length),
                      ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _showEditProgramDialog(
    BuildContext context,
    ProgramsProvider prov,
    ProgramResponse program,
  ) async {
    final nameCtrl = TextEditingController(text: program.name);
    final descCtrl = TextEditingController(text: program.description ?? '');
    final priceCtrl = TextEditingController(
        text: program.price > 0 ? program.price.toString() : '');
    ProgramType selectedType = program.type;
    ProgramPricingType pricingType = program.pricingType;
    DateTime? startDate = program.startDate;
    DateTime? endDate = program.endDate;

    String label(DateTime? d) => d == null
        ? 'Pick date'
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> pick(bool isStart) async {
            final base = isStart
                ? (startDate ?? DateTime.now())
                : (endDate ??
                    (startDate ?? DateTime.now()).add(const Duration(days: 30)));
            final d = await showDatePicker(
              context: ctx,
              initialDate: base,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d != null) {
              setS(() => isStart ? startDate = d : endDate = d);
            }
          }

          return AlertDialog(
            title: const Text('Edit Program'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ProgramType>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: ProgramType.values
                        .map((t) =>
                            DropdownMenuItem(value: t, child: Text(t.name)))
                        .toList(),
                    onChanged: (v) => setS(() => selectedType = v!),
                  ),
                  const SizedBox(height: 12),
                  // ── 💳 Pricing ──
                  DropdownButtonFormField<ProgramPricingType>(
                    value: pricingType,
                    decoration: const InputDecoration(
                      labelText: 'Pricing',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: ProgramPricingType.FREE,
                        child: Text('Free'),
                      ),
                      DropdownMenuItem(
                        value: ProgramPricingType.MONTHLY,
                        child: Text('Monthly subscription'),
                      ),
                      DropdownMenuItem(
                        value: ProgramPricingType.ONE_TIME,
                        child: Text('One-time payment'),
                      ),
                    ],
                    onChanged: (v) => setS(() => pricingType = v!),
                  ),
                  if (pricingType != ProgramPricingType.FREE) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: pricingType == ProgramPricingType.MONTHLY
                            ? 'Price per month'
                            : 'One-time price',
                        prefixIcon: const Icon(Icons.attach_money_rounded),
                        suffixText: 'MMK',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.play_arrow, size: 16),
                          label: Text('Start: ${label(startDate)}',
                              overflow: TextOverflow.ellipsis),
                          onPressed: () => pick(true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.flag_outlined, size: 16),
                          label: Text('End: ${label(endDate)}',
                              overflow: TextOverflow.ellipsis),
                          onPressed: () => pick(false),
                        ),
                      ),
                    ],
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
                  // Name + both dates are REQUIRED — block submission otherwise.
                  if (nameCtrl.text.trim().isEmpty ||
                      startDate == null ||
                      endDate == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content:
                          Text('Name, start date and end date are required.'),
                    ));
                    return;
                  }
                  if (!endDate!.isAfter(startDate!)) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('End date must be after start date.'),
                    ));
                    return;
                  }
                  final int price = pricingType == ProgramPricingType.FREE
                      ? 0
                      : (int.tryParse(priceCtrl.text.trim()) ?? 0);
                  if (pricingType != ProgramPricingType.FREE && price <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Enter a price for a paid program.'),
                    ));
                    return;
                  }
                  Navigator.pop(ctx);
                  await prov.updateProgram(
                    program.id,
                    ProgramRequest(
                      name: nameCtrl.text.trim(),
                      description: descCtrl.text,
                      organizationId: widget.organisationId,
                      type: selectedType,
                      startDate: startDate!,
                      endDate: endDate!,
                      pricingType: pricingType,
                      price: price,
                      currency: 'MMK',
                    ),
                  );
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Mini Builder implementation for the Horizontal Course Filter FilterChips
  Widget _buildFilterChip(BuildContext context, String value, String label) {
    final isSelected = _courseFilter == value;
    final cs = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? cs.onPrimaryContainer
              : AppTheme.getTextSecondary(context),
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _courseFilter = value);
        }
      },
      selectedColor: cs.primary,

      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusSm),
      side: BorderSide(
        color: isSelected ? cs.primary : AppTheme.getBorder(context),
      ),
    );
  }

  // ── Existing Dialog Logic & Helper Implementations Left Intact ──
  Future<void> _showAddCourseToProgramDialog(
    BuildContext context,
    StructureProvider structProv,
    CoursesProvider coursesProv,
    ProgramResponse program,
  ) async {
    final academicCourses = coursesProv.courses
        .where((c) => c.type == CourseType.ACADEMIC)
        .toList();

    if (academicCourses.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No existing academic courses available. Create one first.',
          ),
        ),
      );
      return;
    }

    CourseResponse? selectedCourse;

    // Teachers/admins of this org — the teacher is assigned to this course copy
    // inside this program only (the template stays untouched).
    final orgProv = context.read<OrganizationProvider>();
    final staff = orgProv.members
        .where((m) => m.role == Role.TEACHER || m.role == Role.ORG_ADMIN)
        .toList();
    OrganisationMember? selectedTeacher;
    String teacherName(OrganisationMember m) =>
        orgProv.userCache[m.userId]?.name ?? m.userId;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Existing Academic Course'),
        content: StatefulBuilder(
          builder: (_, setInner) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<CourseResponse>(
                value: selectedCourse,
                isExpanded: true,
                hint: const Text('Select a course to add'),
                decoration: const InputDecoration(
                  labelText: 'Template course',
                  border: OutlineInputBorder(),
                ),
                items: academicCourses
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.name, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setInner(() => selectedCourse = v),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<OrganisationMember>(
                value: selectedTeacher,
                isExpanded: true,
                hint: const Text('Assign a teacher (optional)'),
                decoration: const InputDecoration(
                  labelText: 'Teacher for this program',
                  border: OutlineInputBorder(),
                ),
                items: staff
                    .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(teacherName(m),
                            overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setInner(() => selectedTeacher = v),
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
              if (selectedCourse == null) return;
              Navigator.pop(ctx);
              final success = await structProv.addCourseToProgram(
                program.id,
                ProgramCourseRequest(
                  courseId: selectedCourse!.id,
                  teacherId: selectedTeacher?.userId,
                ),
              );
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${selectedCourse!.name} added to program'),
                  ),
                );
              }
            },
            child: const Text('Add Course'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateProgramDialog(
    BuildContext context,
    ProgramsProvider prov,
    String orgId,
  ) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    ProgramType selectedType = ProgramType.CERTIFICATION;
    ProgramPricingType pricingType = ProgramPricingType.FREE;
    DateTime? startDate;
    DateTime? endDate;

    String label(DateTime? d) => d == null
        ? 'Pick date'
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> pick(bool isStart) async {
            final base = isStart
                ? (startDate ?? DateTime.now())
                : (endDate ??
                    (startDate ?? DateTime.now()).add(const Duration(days: 30)));
            final d = await showDatePicker(
              context: ctx,
              initialDate: base,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d != null) {
              setS(() => isStart ? startDate = d : endDate = d);
            }
          }

          return AlertDialog(
            title: const Text('New Program'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ProgramType>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: ProgramType.values
                        .map((t) =>
                            DropdownMenuItem(value: t, child: Text(t.name)))
                        .toList(),
                    onChanged: (v) => setS(() => selectedType = v!),
                  ),
                  const SizedBox(height: 12),
                  // ── 💳 Pricing ──
                  DropdownButtonFormField<ProgramPricingType>(
                    value: pricingType,
                    decoration: const InputDecoration(
                      labelText: 'Pricing',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: ProgramPricingType.FREE,
                        child: Text('Free'),
                      ),
                      DropdownMenuItem(
                        value: ProgramPricingType.MONTHLY,
                        child: Text('Monthly subscription'),
                      ),
                      DropdownMenuItem(
                        value: ProgramPricingType.ONE_TIME,
                        child: Text('One-time payment'),
                      ),
                    ],
                    onChanged: (v) => setS(() => pricingType = v!),
                  ),
                  if (pricingType != ProgramPricingType.FREE) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: pricingType == ProgramPricingType.MONTHLY
                            ? 'Price per month'
                            : 'One-time price',
                        prefixIcon: const Icon(Icons.attach_money_rounded),
                        suffixText: 'MMK',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.play_arrow, size: 16),
                          label: Text('Start: ${label(startDate)}',
                              overflow: TextOverflow.ellipsis),
                          onPressed: () => pick(true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.flag_outlined, size: 16),
                          label: Text('End: ${label(endDate)}',
                              overflow: TextOverflow.ellipsis),
                          onPressed: () => pick(false),
                        ),
                      ),
                    ],
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
                  // Name + both dates are REQUIRED — block submission otherwise.
                  if (nameCtrl.text.trim().isEmpty ||
                      startDate == null ||
                      endDate == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content:
                          Text('Name, start date and end date are required.'),
                    ));
                    return;
                  }
                  if (!endDate!.isAfter(startDate!)) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('End date must be after start date.'),
                    ));
                    return;
                  }
                  final int price = pricingType == ProgramPricingType.FREE
                      ? 0
                      : (int.tryParse(priceCtrl.text.trim()) ?? 0);
                  if (pricingType != ProgramPricingType.FREE && price <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Enter a price for a paid program.'),
                    ));
                    return;
                  }
                  Navigator.pop(ctx);
                  await prov.createProgram(
                    ProgramRequest(
                      name: nameCtrl.text.trim(),
                      description:
                          descCtrl.text.isNotEmpty ? descCtrl.text : null,
                      organizationId: orgId,
                      type: selectedType,
                      startDate: startDate!,
                      endDate: endDate!,
                      pricingType: pricingType,
                      price: price,
                      currency: 'MMK',
                    ),
                  );
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCreateCourseDialog(
    BuildContext context,
    CoursesProvider prov,
    String orgId,
  ) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final categoryOtherCtrl = TextEditingController();
    final topicsCtrl = TextEditingController();
    CourseType selectedType = CourseType.SKILL;
    String? categoryValue;
    const categoryPresets = [
      'English',
      'Math',
      'Science',
      'GED',
      'IELTS',
      'TOEFL',
      'SAT',
      'Programming',
      'Business',
      'Other',
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setInner) => AlertDialog(
          title: const Text('New Course'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CourseType>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Course Type',
                  border: OutlineInputBorder(),
                ),
                items: CourseType.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Row(
                          children: [
                            Icon(
                              _courseTypeIcon(t),
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(_courseTypeLabel(t)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setInner(() => selectedType = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: categoryValue,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Category (optional)',
                  border: OutlineInputBorder(),
                ),
                items: categoryPresets
                    .map(
                      (c) => DropdownMenuItem(value: c, child: Text(c)),
                    )
                    .toList(),
                onChanged: (v) => setInner(() => categoryValue = v),
              ),
              if (categoryValue == 'Other') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: categoryOtherCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Custom category',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: topicsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Topics (comma-separated)',
                  helperText: 'e.g. Grammar, Essay Writing, Reading',
                  border: OutlineInputBorder(),
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
                if (nameCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                final cat = categoryValue == 'Other'
                    ? (categoryOtherCtrl.text.trim().isNotEmpty
                          ? categoryOtherCtrl.text.trim()
                          : null)
                    : categoryValue;
                final topics = topicsCtrl.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                await prov.createCourse(
                  CourseRequest(
                    name: nameCtrl.text,
                    description: descCtrl.text.isNotEmpty
                        ? descCtrl.text
                        : null,
                    organizationId: orgId,
                    type: selectedType,
                    category: cat,
                    topics: topics,
                  ),
                );
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditCourseDialog(
    BuildContext context,
    CoursesProvider prov,
    CourseResponse course,
  ) async {
    final nameCtrl = TextEditingController(text: course.name);
    final descCtrl = TextEditingController(text: course.description ?? '');
    final topicsCtrl = TextEditingController(text: course.topics.join(', '));
    CourseType selectedType = course.type;
    const categoryPresets = [
      'English',
      'Math',
      'Science',
      'GED',
      'IELTS',
      'TOEFL',
      'SAT',
      'Programming',
      'Business',
      'Other',
    ];
    final existingCategory = course.category ?? '';
    String? categoryValue = existingCategory.isEmpty
        ? null
        : (categoryPresets.contains(existingCategory)
              ? existingCategory
              : 'Other');
    final categoryOtherCtrl = TextEditingController(
      text: categoryValue == 'Other' ? existingCategory : '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setInner) => AlertDialog(
          title: const Text('Edit Course'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CourseType>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Course Type',
                  border: OutlineInputBorder(),
                ),
                items: CourseType.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Row(
                          children: [
                            Icon(
                              _courseTypeIcon(t),
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(_courseTypeLabel(t)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setInner(() => selectedType = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: categoryValue,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Category (optional)',
                  border: OutlineInputBorder(),
                ),
                items: categoryPresets
                    .map(
                      (c) => DropdownMenuItem(value: c, child: Text(c)),
                    )
                    .toList(),
                onChanged: (v) => setInner(() => categoryValue = v),
              ),
              if (categoryValue == 'Other') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: categoryOtherCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Custom category',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: topicsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Topics (comma-separated)',
                  helperText: 'e.g. Grammar, Essay Writing, Reading',
                  border: OutlineInputBorder(),
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
                if (nameCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                final cat = categoryValue == 'Other'
                    ? (categoryOtherCtrl.text.trim().isNotEmpty
                          ? categoryOtherCtrl.text.trim()
                          : null)
                    : categoryValue;
                final topics = topicsCtrl.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                final success = await prov.updateCourse(
                  course.id,
                  CourseRequest(
                    name: nameCtrl.text,
                    description: descCtrl.text.isNotEmpty
                        ? descCtrl.text
                        : null,
                    organizationId: course.organizationId.toString(),
                    type: selectedType,
                    category: cat,
                    topics: topics,
                  ),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? '${nameCtrl.text} updated.'
                            : prov.error ?? 'Update failed.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _courseTypeLabel(CourseType t) {
    switch (t) {
      case CourseType.SKILL:
        return 'Standalone Skill';
      case CourseType.ACADEMIC:
        return 'Academic Course';
      case CourseType.TEST_PREP:
        return 'Test Prep';
    }
  }

  IconData _courseTypeIcon(CourseType t) {
    switch (t) {
      case CourseType.SKILL:
        return Icons.bolt_rounded;
      case CourseType.ACADEMIC:
        return Icons.school_rounded;
      case CourseType.TEST_PREP:
        return Icons.quiz_rounded;
    }
  }

  Future<void> _confirmDeleteProgram(
    BuildContext context,
    ProgramsProvider prov,
    ProgramResponse program,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Program'),
        content: Text('Delete "${program.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await prov.deleteProgram(program.id);
  }

  Future<void> _confirmDeleteCourse(
    BuildContext context,
    CoursesProvider prov,
    CourseResponse course,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Course'),
        content: Text('Delete "${course.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await prov.deleteCourse(course.id);
  }
}

//Program helpers
List<Color> _programThumbColors(String programId) {
  const List<List<Color>> palettes = [
    [Color(0xFF0F9D58), Color(0xFF42B773)],
    [Color(0xFFDB4437), Color(0xFFE57373)],
    // [Color(0xFFF4B400), Color(0xFFFFD54F)],
    [Color(0xFF1A73E8), Color(0xFF66A2FF)],
    [Color(0xFF00ACC1), Color(0xFF4DD0E1)],
    [Color(0xFFE91E63), Color(0xFFF06292)],
    [Color(0xFF8E24AA), Color(0xFFBA68C8)],
    [Color(0xFF37474F), Color(0xFF78909C)],
    [Color(0xFF11998E), Color(0xFF38EF7D)],
    [Color(0xFF795548), Color(0xFFA1887F)],
  ];

  // Hash the ID string to get a deterministic index
  final int index = programId.hashCode.abs() % palettes.length;
  return palettes[index];
}

class _ProgramCard extends StatelessWidget {
  final ProgramResponse program;
  final bool isEditable;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddCourse;

  const _ProgramCard({
    required this.program,
    required this.isEditable,
    required this.onEdit,
    required this.onDelete,
    required this.onAddCourse,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final thumbColors = _programThumbColors(program.id.toString());

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: AppTheme.borderRadiusLg,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProgramDetailScreen(program: program)),
        ),
        borderRadius: AppTheme.borderRadiusLg,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.getBorder(context)),
            borderRadius: AppTheme.borderRadiusLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  gradient: LinearGradient(colors: thumbColors),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            program.type.name,
                            style: TextStyle(
                              color: cs.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (isEditable)
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant, size: 20),
                            onSelected: (value) {
                              if (value == 'edit') onEdit();
                              if (value == 'delete') onDelete();
                              if (value == 'add_course') onAddCourse();
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'add_course', child: Text('Add Academic Course')),
                              const PopupMenuItem(value: 'edit', child: Text('Edit Settings')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete Program')),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      program.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    if (program.description != null && program.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        program.description!,
                        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.arrow_forward_rounded, size: 16, color: cs.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Open Program',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.primary),
                        ),
                      ],
                    ),
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

class _SkillCourseCard extends StatelessWidget {
  final CourseResponse course;
  final VoidCallback onDelete;
  final VoidCallback onEdit; // ← add

  const _SkillCourseCard({
    required this.course,
    required this.onDelete,
    required this.onEdit, // ← add
  });

  @override
  Widget build(BuildContext context) {
    final thumbColors = _courseThumbColors(course.type);
    final typeLabel = _courseTypeBadgeLabel(course.type);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  gradient: LinearGradient(
                    colors: thumbColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: AppTheme.borderRadiusSm,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    typeLabel,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  onSelected: (v) {
                    if (v == 'edit') onEdit(); // ← add
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: AppTheme.borderRadiusSm,
                  ),
                  child: Text(
                    course.type.name,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXs),
                Text(
                  course.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppTheme.space2xs),
                if (course.description != null)
                  Text(
                    course.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.getTextSecondary(context),
                    ),
                  ),
                const SizedBox(height: AppTheme.spaceMd),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CourseDetailScreen(
                            courseId: course.id,
                            courseName: course.name,
                            orgId: course.organizationId.toString(),
                            isTemplate: course.isTemplate,
                          ),
                        ),
                      );
                    },
                    child: Text(
                        course.isTemplate ? 'Build template' : 'Enter Course'),
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

// ── Color helpers ─────────────────────────────────────────
List<Color> _courseThumbColors(CourseType type) {
  switch (type) {
    case CourseType.SKILL:
      return const [Color(0xFFC75D30), Color(0xFFE8935A)];
    case CourseType.ACADEMIC:
      return const [Color(0xFF1565C0), Color(0xFF42A5F5)];
    case CourseType.TEST_PREP:
      return const [Color(0xFF6A1B9A), Color(0xFFAB47BC)];
  }
}

String _courseTypeBadgeLabel(CourseType type) {
  switch (type) {
    case CourseType.SKILL:
      return 'STANDALONE SKILL';
    case CourseType.ACADEMIC:
      return 'ACADEMIC';
    case CourseType.TEST_PREP:
      return 'TEST PREP';
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

class _EmptyState extends StatelessWidget {
  final String message;
  final String buttonText;
  final VoidCallback onAdd;

  const _EmptyState({
    required this.message,
    required this.buttonText,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      type: EmptyStateType.noCourses,
      message: message,
      actionLabel: buttonText,
      onAction: onAdd,
      illustrationSize: 120,
    );
  }
}
