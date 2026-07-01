import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';
// ── Models ────────────────────────────────────────────────────────────────────

enum ClassEntryPoint { direct, fromProgram }

class ClassroomArgs {
  final String courseId;
  final String courseName;
  final String courseCode;
  final String description;
  final ClassEntryPoint entryPoint;
  final String? programName; // only when entryPoint == fromProgram
  final String className; // the subject/class name (e.g. "Mathematics")

  const ClassroomArgs({
    required this.courseId,
    required this.courseName,
    required this.courseCode,
    required this.description,
    required this.entryPoint,
    required this.className,
    this.programName,
  });
}

class ExamItem {
  final String title;
  final String date;
  final String time;
  final bool isUpcoming;
  final String? grade;
  final String? completedDate;
  const ExamItem({
    required this.title,
    required this.date,
    required this.time,
    required this.isUpcoming,
    this.grade,
    this.completedDate,
  });
}

class MaterialItem {
  final String title;
  final String type; // PDF, Video, Slides, Link
  final String size;
  final String uploadedAt;
  const MaterialItem({
    required this.title,
    required this.type,
    required this.size,
    required this.uploadedAt,
  });
}

class SessionItem {
  final String title;
  final String date;
  final String time;
  final String duration;
  final bool isLive;
  final bool isPast;
  final String? recordingUrl;
  const SessionItem({
    required this.title,
    required this.date,
    required this.time,
    required this.duration,
    required this.isLive,
    required this.isPast,
    this.recordingUrl,
  });
}

class PersonItem {
  final String name;
  final String role; // Instructor, Student
  final String? email;
  final String initials;
  final Color avatarColor;
  const PersonItem({
    required this.name,
    required this.role,
    this.email,
    required this.initials,
    required this.avatarColor,
  });
}

// ── Demo Data ─────────────────────────────────────────────────────────────────

final _demoExams = [
  const ExamItem(
    title: 'Midterm: Deep Architecture Fundamentals',
    date: 'Oct 28, 2023',
    time: '10:00 AM – 12:00 PM',
    isUpcoming: true,
  ),
  const ExamItem(
    title: 'Quiz 1: GrPdie6лДекШё6л',
    date: 'Sep 15, 2023',
    time: '9:00 AM – 10:00 AM',
    isUpcoming: false,
    grade: 'A- (92%)',
    completedDate: 'COMPLETED SEP 15, 2023',
  ),
  const ExamItem(
    title: 'Mock Test: BPШкзгоз',
    date: 'Oct 02, 2023',
    time: '2:00 PM – 3:00 PM',
    isUpcoming: false,
    grade: 'B+ (88%)',
    completedDate: 'COMPLETED OCT 02, 2023',
  ),
];

final _demoMaterials = [
  const MaterialItem(
    title: 'Week 1 – Intro to Neural Networks',
    type: 'PDF',
    size: '2.4 MB',
    uploadedAt: 'Sep 1, 2023',
  ),
  const MaterialItem(
    title: 'Backpropagation Explained',
    type: 'Video',
    size: '145 MB',
    uploadedAt: 'Sep 8, 2023',
  ),
  const MaterialItem(
    title: 'Transformer Architecture Slides',
    type: 'Slides',
    size: '8.1 MB',
    uploadedAt: 'Sep 15, 2023',
  ),
  const MaterialItem(
    title: 'PyTorch Cheatsheet',
    type: 'PDF',
    size: '1.2 MB',
    uploadedAt: 'Sep 22, 2023',
  ),
  const MaterialItem(
    title: 'Assignment 1 – CNN Design',
    type: 'PDF',
    size: '540 KB',
    uploadedAt: 'Oct 1, 2023',
  ),
  const MaterialItem(
    title: 'Lecture 6 Recording',
    type: 'Video',
    size: '310 MB',
    uploadedAt: 'Oct 10, 2023',
  ),
  const MaterialItem(
    title: 'Reading List & References',
    type: 'Link',
    size: '—',
    uploadedAt: 'Sep 1, 2023',
  ),
];

final _demoSessions = [
  const SessionItem(
    title: 'Live Q&A – Transformers Deep Dive',
    date: 'Today',
    time: '3:00 PM',
    duration: '90 min',
    isLive: true,
    isPast: false,
  ),
  const SessionItem(
    title: 'Lecture 8 – Attention Mechanism',
    date: 'Oct 30, 2023',
    time: '10:00 AM',
    duration: '60 min',
    isLive: false,
    isPast: false,
  ),
  const SessionItem(
    title: 'Lecture 7 – Recurrent Networks',
    date: 'Oct 23, 2023',
    time: '10:00 AM',
    duration: '60 min',
    isLive: false,
    isPast: true,
    recordingUrl: 'https://example.com',
  ),
  const SessionItem(
    title: 'Lecture 6 – Optimization Methods',
    date: 'Oct 16, 2023',
    time: '10:00 AM',
    duration: '60 min',
    isLive: false,
    isPast: true,
    recordingUrl: 'https://example.com',
  ),
  const SessionItem(
    title: 'Lecture 5 – Convolutional Networks',
    date: 'Oct 9, 2023',
    time: '10:00 AM',
    duration: '60 min',
    isLive: false,
    isPast: true,
    recordingUrl: 'https://example.com',
  ),
];

final _demoPeople = [
  const PersonItem(
    name: 'Dr. Ahmed Karimi',
    role: 'Instructor',
    email: 'a.karimi@school.edu',
    initials: 'AK',
    avatarColor: Color(0xFF185FA5),
  ),
  const PersonItem(
    name: 'Ms. Clara Ng',
    role: 'Teaching Assistant',
    email: 'c.ng@school.edu',
    initials: 'CN',
    avatarColor: Color(0xFF1D9E75),
  ),
  const PersonItem(
    name: 'HtooChoon',
    role: 'Student',
    initials: 'HC',
    avatarColor: Color(0xFFD4680A),
  ),
  const PersonItem(
    name: 'Aung Myat',
    role: 'Student',
    initials: 'AM',
    avatarColor: Color(0xFF534AB7),
  ),
  const PersonItem(
    name: 'Su Wai',
    role: 'Student',
    initials: 'SW',
    avatarColor: Color(0xFFD85A30),
  ),
  const PersonItem(
    name: 'Kyaw Zin',
    role: 'Student',
    initials: 'KZ',
    avatarColor: Color(0xFF3B6D11),
  ),
  const PersonItem(
    name: 'Thida Oo',
    role: 'Student',
    initials: 'TO',
    avatarColor: Color(0xFF993556),
  ),
  const PersonItem(
    name: 'Min Htet',
    role: 'Student',
    initials: 'MH',
    avatarColor: Color(0xFF854F0B),
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class ClassroomScreen extends StatefulWidget {
  final ClassroomArgs args;
  // Replace demo lists with API data later
  final List<ExamItem> exams;
  final List<MaterialItem> materials;
  final List<SessionItem> sessions;
  final List<PersonItem> people;

  const ClassroomScreen({
    super.key,
    required this.args,
    required this.exams,
    required this.materials,
    required this.sessions,
    required this.people,
  });

  @override
  State<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends State<ClassroomScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _examCodeController = TextEditingController();

  late List<ExamItem> _exams;
  late List<MaterialItem> _materials;
  late List<SessionItem> _sessions;
  late List<PersonItem> _people;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 2);
    _exams = widget.exams ?? _demoExams;
    _materials = widget.materials ?? _demoMaterials;
    _sessions = widget.sessions ?? _demoSessions;
    _people = widget.people ?? _demoPeople;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _examCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final args = widget.args;

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
            title: _Breadcrumb(args: args),
            actions: [
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
                    'HC',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
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

          // Hero info + Join Live
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${args.courseCode}: ${args.courseName}',
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
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.cast_connected_outlined, size: 16),
                    label: const Text('Join Live'),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
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
                tabs: const [
                  Tab(text: 'Materials'),
                  Tab(text: 'Sessions'),
                  Tab(text: 'Exams'),
                  Tab(text: 'People'),
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
                isScrollable: false,
              ),
              Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _MaterialsTab(materials: widget.materials),
            _SessionsTab(sessions: widget.sessions),
            _ExamsTab(
              exams: widget.exams,
              examCodeController: _examCodeController,
            ),
            _PeopleTab(people: widget.people),
          ],
        ),
      ),
    );
  }
}

// ── Breadcrumb ────────────────────────────────────────────────────────────────

class _Breadcrumb extends StatelessWidget {
  final ClassroomArgs args;
  const _Breadcrumb({required this.args});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = args.entryPoint == ClassEntryPoint.fromProgram
        ? ['Classes', args.programName!, args.className]
        : ['Classes', args.className];

    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 14,
              color: AppTheme.getTextTertiary(context),
            ),
            const SizedBox(width: 4),
          ],
          GestureDetector(
            onTap: i < items.length - 1 ? () => Navigator.pop(context) : null,
            child: Text(
              items[i],
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
    );
  }
}

// ── Sticky Tab Bar Delegate ───────────────────────────────────────────────────

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
  ) {
    return Container(color: bg, child: tabBar);
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate old) => false;
}

// ── Tab: Exams ────────────────────────────────────────────────────────────────

class _ExamsTab extends StatelessWidget {
  final List<ExamItem> exams;
  final TextEditingController examCodeController;
  const _ExamsTab({required this.exams, required this.examCodeController});

  @override
  Widget build(BuildContext context) {
    final upcoming = exams.where((e) => e.isUpcoming).toList();
    final past = exams.where((e) => !e.isUpcoming).toList();

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      children: [
        // Upcoming header
        _SectionHeader(
          icon: Icons.calendar_month_outlined,
          label: 'Upcoming Exams',
          badge: 'NEXT 7 DAYS',
        ),
        const SizedBox(height: AppTheme.spaceMd),

        // Upcoming list
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: upcoming.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spaceMd),
          itemBuilder: (context, i) => _UpcomingExamCard(
            exam: upcoming[i],
            controller: examCodeController,
          ),
        ),

        const SizedBox(height: AppTheme.space2xl),

        // Previous header
        _SectionHeader(icon: Icons.history, label: 'Previous Exams'),
        const SizedBox(height: AppTheme.spaceMd),

        // Past list
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: past.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            thickness: 0.5,
            color: AppTheme.getBorder(context),
          ),
          itemBuilder: (context, i) => _PastExamRow(exam: past[i]),
        ),
      ],
    );
  }
}

class _UpcomingExamCard extends StatelessWidget {
  final ExamItem exam;
  final TextEditingController controller;
  const _UpcomingExamCard({required this.exam, required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          Text(
            exam.title,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 13,
                color: AppTheme.getTextTertiary(context),
              ),
              const SizedBox(width: 6),
              Text(exam.date, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 12),
              Icon(
                Icons.access_time,
                size: 13,
                color: AppTheme.getTextTertiary(context),
              ),
              const SizedBox(width: 6),
              Text(exam.time, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.link, size: 16),
              label: const Text('Join via Link'),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.borderRadiusMd,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Exam Code',
                    hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.getTextTertiary(context),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppTheme.borderRadiusMd,
                      borderSide: BorderSide(
                        color: AppTheme.getBorder(context),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppTheme.borderRadiusMd,
                      borderSide: BorderSide(
                        color: AppTheme.getBorder(context),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppTheme.borderRadiusMd,
                      borderSide: BorderSide(color: cs.primary),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.getBorder(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.borderRadiusMd,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: const Text('Enter'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PastExamRow extends StatelessWidget {
  final ExamItem exam;
  const _PastExamRow({required this.exam});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isGood = exam.grade?.startsWith('A') ?? false;
    return InkWell(
      onTap: () {},
      borderRadius: AppTheme.borderRadiusMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exam.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    exam.completedDate ?? '',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.getTextTertiary(context),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {},
                    child: Row(
                      children: [
                        Icon(
                          Icons.remove_red_eye_outlined,
                          size: 14,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'View Review',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (isGood ? cs.primary : AppTheme.warning).withValues(
                  alpha: 0.08,
                ),
                borderRadius: AppTheme.borderRadiusMd,
              ),
              child: Column(
                children: [
                  Text(
                    'GRADE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.getTextTertiary(context),
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    exam.grade ?? '—',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isGood ? cs.primary : AppTheme.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: AppTheme.getTextTertiary(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab: Materials ────────────────────────────────────────────────────────────

class _MaterialsTab extends StatelessWidget {
  final List<MaterialItem> materials;
  const _MaterialsTab({required this.materials});

  IconData _iconFor(String type) {
    switch (type) {
      case 'Video':
        return Icons.play_circle_outline;
      case 'Slides':
        return Icons.slideshow_outlined;
      case 'Link':
        return Icons.link;
      default:
        return Icons.picture_as_pdf_outlined;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'Video':
        return const Color(0xFFD85A30);
      case 'Slides':
        return const Color(0xFF185FA5);
      case 'Link':
        return const Color(0xFF1D9E75);
      default:
        return const Color(0xFF993556);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      itemCount: materials.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 0.5,
        color: AppTheme.getBorder(context),
      ),
      itemBuilder: (context, i) {
        final m = materials[i];
        final color = _colorFor(m.type);
        return InkWell(
          onTap: () {},
          borderRadius: AppTheme.borderRadiusMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: AppTheme.borderRadiusMd,
                  ),
                  child: Icon(_iconFor(m.type), color: color, size: 20),
                ),
                const SizedBox(width: AppTheme.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          _TypeBadge(label: m.type, color: color),
                          const SizedBox(width: 8),
                          Text(
                            m.size,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppTheme.getTextTertiary(context),
                                ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '· ${m.uploadedAt}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppTheme.getTextTertiary(context),
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.download_outlined,
                  size: 20,
                  color: AppTheme.getTextTertiary(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
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

// ── Tab: Sessions ─────────────────────────────────────────────────────────────

class _SessionsTab extends StatelessWidget {
  final List<SessionItem> sessions;
  const _SessionsTab({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final upcoming = sessions.where((s) => !s.isPast).toList();
    final past = sessions.where((s) => s.isPast).toList();
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      children: [
        _SectionHeader(
          icon: Icons.videocam_outlined,
          label: 'Upcoming Sessions',
        ),
        const SizedBox(height: AppTheme.spaceMd),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: upcoming.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spaceMd),
          itemBuilder: (context, i) {
            final s = upcoming[i];
            return Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppTheme.borderRadiusLg,
                border: Border.all(
                  color: s.isLive
                      ? cs.primary.withValues(alpha: 0.4)
                      : AppTheme.getBorder(context),
                  width: s.isLive ? 1.5 : 0.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: s.isLive
                          ? cs.primary.withValues(alpha: 0.1)
                          : AppTheme.getSurfaceVariant(context),
                      borderRadius: AppTheme.borderRadiusMd,
                    ),
                    child: Icon(
                      s.isLive ? Icons.sensors : Icons.videocam_outlined,
                      color: s.isLive
                          ? cs.primary
                          : AppTheme.getTextSecondary(context),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (s.isLive) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: AppTheme.borderRadiusSm,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'LIVE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                s.title,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 11,
                              color: AppTheme.getTextTertiary(context),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${s.date} · ${s.time}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppTheme.getTextSecondary(context),
                                  ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.timer_outlined,
                              size: 11,
                              color: AppTheme.getTextTertiary(context),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              s.duration,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppTheme.getTextSecondary(context),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (s.isLive)
                    FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.borderRadiusMd,
                        ),
                      ),
                      child: const Text('Join', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: AppTheme.space2xl),
        _SectionHeader(icon: Icons.history, label: 'Past Sessions'),
        const SizedBox(height: AppTheme.spaceMd),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: past.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            thickness: 0.5,
            color: AppTheme.getBorder(context),
          ),
          itemBuilder: (context, i) {
            final s = past[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.getSurfaceVariant(context),
                      borderRadius: AppTheme.borderRadiusMd,
                    ),
                    child: Icon(
                      Icons.play_circle_outline,
                      color: AppTheme.getTextSecondary(context),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${s.date} · ${s.duration}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.getTextSecondary(context),
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (s.recordingUrl != null)
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: cs.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                      ),
                      child: const Text(
                        'Recording',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Tab: People ───────────────────────────────────────────────────────────────

class _PeopleTab extends StatelessWidget {
  final List<PersonItem> people;
  const _PeopleTab({required this.people});

  @override
  Widget build(BuildContext context) {
    final instructors = people.where((p) => p.role != 'Student').toList();
    final students = people.where((p) => p.role == 'Student').toList();

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      children: [
        _SectionHeader(icon: Icons.school_outlined, label: 'Instructors & TAs'),
        const SizedBox(height: AppTheme.spaceMd),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: instructors.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spaceSm),
          itemBuilder: (context, i) => _PersonCard(person: instructors[i]),
        ),

        const SizedBox(height: AppTheme.space2xl),
        _SectionHeader(
          icon: Icons.people_outline,
          label: 'Students',
          badge: '${students.length}',
        ),
        const SizedBox(height: AppTheme.spaceMd),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: students.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            thickness: 0.5,
            color: AppTheme.getBorder(context),
          ),
          itemBuilder: (context, i) => _PersonRow(person: students[i]),
        ),
      ],
    );
  }
}

class _PersonCard extends StatelessWidget {
  final PersonItem person;
  const _PersonCard({required this.person});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
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
            backgroundColor: person.avatarColor.withValues(alpha: 0.15),
            child: Text(
              person.initials,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: person.avatarColor,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  person.role,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (person.email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    person.email!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.getTextTertiary(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.mail_outline,
              color: AppTheme.getTextSecondary(context),
              size: 20,
            ),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final PersonItem person;
  const _PersonRow({required this.person});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: person.avatarColor.withValues(alpha: 0.15),
            child: Text(
              person.initials,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: person.avatarColor,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Text(
              person.name,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            person.role,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.getTextTertiary(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared Section Header ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;

  const _SectionHeader({required this.icon, required this.label, this.badge});

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
      ],
    );
  }
}
