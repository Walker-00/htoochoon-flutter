import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';
import 'package:htoochoon_flutter/api/api_service.dart';
import 'package:htoochoon_flutter/Screens/MainLayout/main_scaffold.dart';

/// 🎯 Gamified first-run data collection: interests → where-you-heard → role →
/// (student/teacher: find & request an org · founder: create or request admin).
/// Saves answers to `PATCH /users/me/onboarding` then enters the app.
class GamifiedOnboardingScreen extends StatefulWidget {
  const GamifiedOnboardingScreen({super.key});

  @override
  State<GamifiedOnboardingScreen> createState() =>
      _GamifiedOnboardingScreenState();
}

class _GamifiedOnboardingScreenState extends State<GamifiedOnboardingScreen> {
  int _step = 0;
  bool _saving = false;

  // Answers
  final Set<String> _interests = {};
  String? _heardFrom;
  String? _role; // STUDENT | TEACHER | ORG_ADMIN
  bool _founderHasOrg = false;

  static const _presetInterests = [
    'IELTS', 'TOEFL', 'SAT', 'GED', 'IGCSE', 'A-Level', 'O-Level',
    'GRE', 'Coding', 'Mathematics', 'Science', 'Business', 'Language',
    'Music', 'Art & Design',
  ];
  static const _heardOptions = [
    'Facebook', 'YouTube', 'TikTok', 'Instagram', 'Friend', 'Online Search',
    'School / Org',
  ];

  int get _lastStep => 3;

  bool get _canAdvance {
    switch (_step) {
      case 0:
        return _interests.isNotEmpty;
      case 1:
        return _heardFrom != null && _heardFrom!.trim().isNotEmpty;
      case 2:
        return _role != null;
      default:
        return true;
    }
  }

  void _next() {
    if (_step < _lastStep) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await context.read<ApiService>().saveOnboarding({
        'interests': _interests.toList(),
        'heardFrom': _heardFrom,
        'intendedRole': _role,
      });
    } catch (_) {
      // Non-fatal — the user can still enter the app; answers just weren't saved.
    }
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainScaffold()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceLg, AppTheme.spaceLg, AppTheme.spaceLg, 0),
              child: Row(
                children: List.generate(_lastStep + 1, (i) {
                  final active = i <= _step;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 6,
                      decoration: BoxDecoration(
                        color: active
                            ? cs.primary
                            : AppTheme.getBorder(context),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: SingleChildScrollView(
                  key: ValueKey(_step),
                  padding: const EdgeInsets.all(AppTheme.spaceLg),
                  child: _buildStep(context),
                ),
              ),
            ),
            _bottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _interestsStep(context);
      case 1:
        return _heardStep(context);
      case 2:
        return _roleStep(context);
      default:
        return _roleActionStep(context);
    }
  }

  // ---- Step 0: interests ---------------------------------------------------
  Widget _interestsStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('What are you here to learn? 🎯',
            'Pick anything that fits — you can add your own too.'),
        const SizedBox(height: AppTheme.spaceLg),
        Wrap(
          spacing: AppTheme.spaceXs,
          runSpacing: AppTheme.spaceXs,
          children: [
            for (final tag in {..._presetInterests, ..._interests})
              _chip(
                label: tag,
                selected: _interests.contains(tag),
                onTap: () => setState(() {
                  _interests.contains(tag)
                      ? _interests.remove(tag)
                      : _interests.add(tag);
                }),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceMd),
        _AddCustomField(
          hint: 'Add your own (e.g. Cambridge, PTE)…',
          onAdd: (v) => setState(() => _interests.add(v)),
        ),
      ],
    );
  }

  // ---- Step 1: heard from --------------------------------------------------
  Widget _heardStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('How did you hear about us? 📣',
            'Helps us reach more learners like you.'),
        const SizedBox(height: AppTheme.spaceLg),
        Wrap(
          spacing: AppTheme.spaceXs,
          runSpacing: AppTheme.spaceXs,
          children: [
            for (final opt in {
              ..._heardOptions,
              if (_heardFrom != null && !_heardOptions.contains(_heardFrom))
                _heardFrom!,
            })
              _chip(
                label: opt,
                selected: _heardFrom == opt,
                onTap: () => setState(() => _heardFrom = opt),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceMd),
        _AddCustomField(
          hint: 'Somewhere else? Type it…',
          onAdd: (v) => setState(() => _heardFrom = v),
        ),
      ],
    );
  }

  // ---- Step 2: role --------------------------------------------------------
  Widget _roleStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('Which one is you? 🙋',
            'We\'ll tailor your first steps.'),
        const SizedBox(height: AppTheme.spaceLg),
        _roleCard(
          value: 'STUDENT',
          icon: Icons.school_outlined,
          title: 'Student',
          desc: 'Learn, join classes, take exams.',
        ),
        _roleCard(
          value: 'TEACHER',
          icon: Icons.cast_for_education_outlined,
          title: 'Teacher',
          desc: 'Teach classes, grade, run live sessions.',
        ),
        _roleCard(
          value: 'ORG_ADMIN',
          icon: Icons.apartment_outlined,
          title: 'Founder / Admin',
          desc: 'Run an organization on HtooChoon.',
        ),
      ],
    );
  }

  // ---- Step 3: role-specific action ---------------------------------------
  Widget _roleActionStep(BuildContext context) {
    if (_role == 'ORG_ADMIN') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Set up your organization 🏛️',
              'Create a new one, or join an existing org\'s admin team.'),
          const SizedBox(height: AppTheme.spaceLg),
          Row(
            children: [
              Expanded(
                child: _toggleCard(
                  selected: !_founderHasOrg,
                  title: 'Create new',
                  desc: 'Start a fresh org.',
                  onTap: () => setState(() => _founderHasOrg = false),
                ),
              ),
              const SizedBox(width: AppTheme.spaceXs),
              Expanded(
                child: _toggleCard(
                  selected: _founderHasOrg,
                  title: 'Already exists',
                  desc: 'Ask the owner for admin access.',
                  onTap: () => setState(() => _founderHasOrg = true),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLg),
          if (_founderHasOrg)
            _OrgSearchRequest(requestedRole: 'ORG_ADMIN')
          else
            _infoCard(
              'Tap “Enter HtooChoon” below, then use “+ New” on your Profile to '
              'create your organization. You\'ll be its owner & admin.',
            ),
        ],
      );
    }

    // Student / teacher: find and request to join an org.
    final roleLabel = _role == 'TEACHER' ? 'teach at' : 'study at';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('Find your organization 🔎',
            'Search the org you want to $roleLabel by name or email, then send a '
            'join request. An admin approves you.'),
        const SizedBox(height: AppTheme.spaceLg),
        _OrgSearchRequest(requestedRole: _role ?? 'STUDENT'),
      ],
    );
  }

  // ---- shared bits ---------------------------------------------------------
  Widget _bottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.getBorder(context))),
      ),
      child: Row(
        children: [
          if (_step > 0)
            TextButton(
              onPressed: _saving ? null : () => setState(() => _step--),
              child: const Text('Back'),
            ),
          const Spacer(),
          if (_step == _lastStep)
            TextButton(
              onPressed: _saving ? null : _finish,
              child: const Text('Skip'),
            ),
          const SizedBox(width: AppTheme.spaceXs),
          FilledButton(
            onPressed: (_canAdvance && !_saving) ? _next : null,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_step == _lastStep ? 'Enter HtooChoon' : 'Continue'),
          ),
        ],
      ),
    );
  }

  Widget _title(String t, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.getTextPrimary(context))),
        const SizedBox(height: AppTheme.spaceXs),
        Text(sub,
            style: TextStyle(
                fontSize: 14, color: AppTheme.getTextSecondary(context))),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
        decoration: BoxDecoration(
          color: selected ? cs.primary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: selected ? cs.primary : AppTheme.getBorder(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? cs.onPrimary : AppTheme.getTextPrimary(context),
          ),
        ),
      ),
    );
  }

  Widget _roleCard({
    required String value,
    required IconData icon,
    required String title,
    required String desc,
  }) {
    final cs = Theme.of(context).colorScheme;
    final selected = _role == value;
    return GestureDetector(
      onTap: () => setState(() => _role = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.08)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(
            color: selected ? cs.primary : AppTheme.getBorder(context),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: cs.primary, size: 28),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.getTextPrimary(context))),
                  Text(desc,
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.getTextSecondary(context))),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: cs.primary),
          ],
        ),
      ),
    );
  }

  Widget _toggleCard({
    required bool selected,
    required String title,
    required String desc,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.08)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: selected ? cs.primary : AppTheme.getBorder(context),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.getTextPrimary(context))),
            const SizedBox(height: 2),
            Text(desc,
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.getTextSecondary(context))),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String text) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Text(text,
          style: TextStyle(color: AppTheme.getTextSecondary(context))),
    );
  }
}

/// Small "type + Add" field used for custom interests / heard-from entries.
class _AddCustomField extends StatefulWidget {
  const _AddCustomField({required this.hint, required this.onAdd});
  final String hint;
  final ValueChanged<String> onAdd;

  @override
  State<_AddCustomField> createState() => _AddCustomFieldState();
}

class _AddCustomFieldState extends State<_AddCustomField> {
  final _ctrl = TextEditingController();

  void _submit() {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    widget.onAdd(v);
    _ctrl.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: widget.hint,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spaceXs),
        IconButton.filledTonal(
          onPressed: _submit,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

/// Search organizations by name/email and send a join (access) request.
class _OrgSearchRequest extends StatefulWidget {
  const _OrgSearchRequest({required this.requestedRole});
  final String requestedRole;

  @override
  State<_OrgSearchRequest> createState() => _OrgSearchRequestState();
}

class _OrgSearchRequestState extends State<_OrgSearchRequest> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _requestedOrgId;
  String? _requestedOrgName;

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    setState(() => _loading = true);
    try {
      final res = await context.read<ApiService>().searchOrganizations(q);
      final list = (res as List?) ?? [];
      _results = list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      _results = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _request(Map<String, dynamic> org) async {
    final id = org['id']?.toString();
    if (id == null) return;
    try {
      await context.read<ApiService>().createAccessRequest({
        'organizationId': id,
        'requestedRole': widget.requestedRole,
      });
      if (!mounted) return;
      setState(() {
        _requestedOrgId = id;
        _requestedOrgName = org['name']?.toString();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send request: $e')),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_requestedOrgId != null) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: cs.primary),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: cs.primary),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: Text(
                'Request sent to ${_requestedOrgName ?? 'the org'} — '
                'you\'ll get a notification once an admin approves you.',
                style: TextStyle(color: AppTheme.getTextPrimary(context)),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'Org name or email…',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spaceXs),
            FilledButton(onPressed: _search, child: const Text('Search')),
          ],
        ),
        const SizedBox(height: AppTheme.spaceMd),
        if (_loading)
          const Center(child: Padding(
            padding: EdgeInsets.all(AppTheme.spaceMd),
            child: CircularProgressIndicator(),
          ))
        else if (_results.isEmpty)
          Text('Search for your organization above.',
              style: TextStyle(color: AppTheme.getTextTertiary(context)))
        else
          ..._results.map((org) => Container(
                margin: const EdgeInsets.only(bottom: AppTheme.spaceXs),
                padding: const EdgeInsets.all(AppTheme.spaceSm),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.getBorder(context)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: cs.primary.withValues(alpha: 0.12),
                      child: Text(
                        (org['name']?.toString() ?? '?')
                            .characters
                            .first
                            .toUpperCase(),
                        style: TextStyle(color: cs.primary),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(org['name']?.toString() ?? '—',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          if (org['email'] != null)
                            Text(org['email'].toString(),
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        AppTheme.getTextSecondary(context))),
                        ],
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () => _request(org),
                      child: const Text('Request'),
                    ),
                  ],
                ),
              )),
      ],
    );
  }
}
