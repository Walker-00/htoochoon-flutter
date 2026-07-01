import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/organisation_provider.dart';
import 'package:htoochoon_flutter/Screens/Onboarding/org_loader_screen.dart';
import 'package:htoochoon_flutter/core/userorgrole_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:htoochoon_flutter/Providers/auth_provider.dart';
import 'package:htoochoon_flutter/models/auth/auth_model.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';

// ─── Local profile extras (stored in SharedPreferences) ──────────────────────
class _LocalProfile {
  final String title;
  final String bio;
  final List<String> subjects;
  final String department;
  final String staffId;

  const _LocalProfile({
    this.title = '',
    this.bio = '',
    this.subjects = const [],
    this.department = '',
    this.staffId = '',
  });

  static const _key = 'teacher_profile_extras';

  factory _LocalProfile.fromPrefs(Map<String, dynamic> json) => _LocalProfile(
    title: json['title'] ?? '',
    bio: json['bio'] ?? '',
    subjects: List<String>.from(json['subjects'] ?? []),
    department: json['department'] ?? '',
    staffId: json['staffId'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'bio': bio,
    'subjects': subjects,
    'department': department,
    'staffId': staffId,
  };

  static Future<_LocalProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const _LocalProfile();
    return _LocalProfile.fromPrefs(jsonDecode(raw));
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }

  _LocalProfile copyWith({
    String? title,
    String? bio,
    List<String>? subjects,
    String? department,
    String? staffId,
  }) => _LocalProfile(
    title: title ?? this.title,
    bio: bio ?? this.bio,
    subjects: subjects ?? this.subjects,
    department: department ?? this.department,
    staffId: staffId ?? this.staffId,
  );
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class TeacherProfileScreen extends StatefulWidget {
  final VoidCallback onQuitOrganisation;
  final bool isInShell;
  const TeacherProfileScreen({
    super.key,
    required this.onQuitOrganisation,
    this.isInShell = false,
  });

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  _LocalProfile _local = const _LocalProfile();
  bool _loadingLocal = true;

  static const _teacherGreen = Color(0xFF0F7B6C);
  static const _teacherGreenLight = Color(0xFF13A896);

  @override
  void initState() {
    super.initState();
    _loadLocal();
  }

  Future<void> _loadLocal() async {
    final p = await _LocalProfile.load();
    if (mounted)
      setState(() {
        _local = p;
        _loadingLocal = false;
      });
  }

  Future<void> _editProfile(User user) async {
    final titleCtrl = TextEditingController(text: _local.title);
    final bioCtrl = TextEditingController(text: _local.bio);
    final deptCtrl = TextEditingController(text: _local.department);
    final staffCtrl = TextEditingController(text: _local.staffId);
    final subjectsCtrl = TextEditingController(
      text: _local.subjects.join(', '),
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Edit Profile',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                _Field(
                  label: 'Title / Position',
                  ctrl: titleCtrl,
                  hint: 'e.g. Senior Faculty of Computer Science',
                ),
                const SizedBox(height: 12),
                _Field(
                  label: 'Department',
                  ctrl: deptCtrl,
                  hint: 'e.g. STEM Research Wing',
                ),
                const SizedBox(height: 12),
                _Field(
                  label: 'Staff ID',
                  ctrl: staffCtrl,
                  hint: 'e.g. #EDU-SJ-2024-0012',
                ),
                const SizedBox(height: 12),
                _Field(
                  label: 'Subjects (comma-separated)',
                  ctrl: subjectsCtrl,
                  hint: 'e.g. Physics, Mathematics, AI Ethics',
                ),
                const SizedBox(height: 12),
                _Field(
                  label: 'Teaching Bio',
                  ctrl: bioCtrl,
                  hint: 'Share your teaching philosophy...',
                  maxLines: 4,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _teacherGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final updated = _local.copyWith(
                        title: titleCtrl.text.trim(),
                        bio: bioCtrl.text.trim(),
                        department: deptCtrl.text.trim(),
                        staffId: staffCtrl.text.trim(),
                        subjects: subjectsCtrl.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList(),
                      );
                      await updated.save();
                      if (mounted) setState(() => _local = updated);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgProv = context.watch<OrganizationProvider>();
    final user = UserSessionManager.user;
    final avatar = user?.avatar;
    final String? absoluteAvatarUrl = (avatar != null && avatar.isNotEmpty)
        ? (avatar.startsWith('http')
              ? avatar
              : "https://backend.htoochoon.com$avatar")
        : null;
    final cs = Theme.of(context).colorScheme;
    final displayName = user?.name ?? 'Teacher';
    logD("USER:${user?.name ?? "idkbro"} ");
    logD("USER ID:${user?.id ?? "idkbro"} ");

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final orgName = orgProv.selected?.name ?? '';
    final orgId = orgProv.selected?.id ?? '';
    final memberRole = orgProv.selected != null
        ? orgProv.currentOrgRole
        : user.role;
    Future<void> _confirmQuit(BuildContext context) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Quit Organisation?'),
          content: const Text(
            'You will be returned to your user profile. You can re-enter the organisation later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Stay'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx, true);
                // Notice we removed the immediate extra raw pop here so we can control route flow smoothly
              },
              child: const Text('Quit'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // 1. Capture the structural navigator instance for safely bypassing async gaps
        final navigator = Navigator.of(context);

        // 2. Show the network loader animation screen explicitly
        await OrgLoaderScreen.show(
          context,
          action: () async {
            // Execute database cleanup processing or analytical state notifications safely inside here
            await Future.delayed(const Duration(milliseconds: 500));
            widget.onQuitOrganisation();
          },
        );

        // 3. 🚀 CRITICAL FIX: Pop the AdminShell route safely now that the loader has dismissed itself!
        // This guarantees we return back to the root profile dashboard
        if (navigator.canPop()) {
          navigator.pop();
        }
      }
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────
          SliverAppBar(
            automaticallyImplyLeading: !widget.isInShell,
            backgroundColor: _teacherGreen,
            foregroundColor: Colors.white,
            pinned: true,
            expandedHeight: 220,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                onPressed: () => _editProfile(user),
                tooltip: 'Edit profile',
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_teacherGreen, _teacherGreenLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),
                      // Avatar
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            backgroundImage: absoluteAvatarUrl != null
                                ? NetworkImage(absoluteAvatarUrl)
                                : null,
                            child: absoluteAvatarUrl == null
                                ? Text(
                                    displayName.isNotEmpty
                                        ? displayName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: _teacherGreenLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_local.title.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 2,
                          ),
                          child: Text(
                            _local.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: _loadingLocal
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 1. Subjects ────────────────────────────────
                      if (_local.subjects.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _local.subjects
                                .map(
                                  (s) => Chip(
                                    label: Text(
                                      s.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    backgroundColor: _teacherGreen.withValues(
                                      alpha: 0.08,
                                    ),
                                    side: BorderSide(
                                      color: _teacherGreen.withValues(alpha: 0.2),
                                    ),
                                    labelStyle: const TextStyle(
                                      color: _teacherGreen,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),

                      // ── 2. Org Info Card ───────────────────────────
                      if (orgName.isNotEmpty)
                        _SectionCard(
                          margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _teacherGreen.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.corporate_fare_rounded,
                                      size: 18,
                                      color: _teacherGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      orgName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  _RoleBadgeSmall(role: memberRole),
                                ],
                              ),
                              if (_local.department.isNotEmpty ||
                                  _local.staffId.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                const Divider(height: 1),
                                const SizedBox(height: 14),
                              ],
                              if (_local.department.isNotEmpty)
                                _InfoRow(
                                  label: 'DEPARTMENT',
                                  value: _local.department,
                                ),
                              if (_local.staffId.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _InfoRow(
                                  label: 'STAFF ID',
                                  value: _local.staffId,
                                  valueColor: _teacherGreen,
                                ),
                              ],
                            ],
                          ),
                        ),

                      // ── 3. System Settings ─────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Text(
                          'System Settings',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _SectionCard(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            _SettingsRow(
                              icon: Icons.person_outline_rounded,
                              label: 'Account Information',
                              onTap: () {},
                            ),
                            const Divider(height: 1, indent: 44),
                            _SettingsRow(
                              icon: Icons.shield_outlined,
                              label: 'Security & Credentials',
                              onTap: () {},
                            ),
                            const Divider(height: 1, indent: 44),
                            _SettingsRow(
                              icon: Icons.translate_rounded,
                              label: 'Language & Region',
                              onTap: () {},
                            ),
                          ],
                        ),
                      ),

                      // ── 4. Teacher Mode Toggle ─────────────────────
                      _SectionCard(
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CURRENT VIEW',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppTheme.getTextSecondary(
                                              context,
                                            ),
                                            letterSpacing: 0.8,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'TEACHER MODE',
                                      style: TextStyle(
                                        color: _teacherGreen,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Switch(
                                  value: true,
                                  activeColor: _teacherGreen,
                                  onChanged: (_) {},
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Switch to Student View to preview course material, assignments, and grades from a learner\'s perspective.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppTheme.getTextSecondary(context),
                                  ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 16,
                                ),
                                label: const Text('Switch to Student View'),
                                onPressed: () {},
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _teacherGreen,
                                  side: BorderSide(
                                    color: _teacherGreen.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── 5. Teaching Bio ────────────────────────────
                      if (_local.bio.isNotEmpty)
                        _SectionCard(
                          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Teaching Bio',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _local.bio,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppTheme.getTextSecondary(context),
                                      height: 1.5,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () => _editProfile(user),
                                child: const Text(
                                  'Update Profile Bio',
                                  style: TextStyle(
                                    color: _teacherGreen,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ── 6. FIXED Danger Zone (Brought out of the else block) ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: Colors.red.shade300,
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    "Danger Zone",
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Colors.red.shade300,
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.logout_rounded),
                              label: const Text('Exit Workspace View'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: BorderSide(
                                  color: Colors.red.withValues(alpha: 0.4),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () async {
                                // Confirm dialog before popping workspace view
                                final switchConfirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Exit Workspace?'),
                                    content: const Text(
                                      'You will change your view back to your standard personal profile dashboard.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Exit View'),
                                      ),
                                    ],
                                  ),
                                );

                                if (switchConfirmed == true &&
                                    context.mounted) {
                                  final navigator = Navigator.of(context);

                                  // Fire loader animation cleanly
                                  await OrgLoaderScreen.show(
                                    context,
                                    action: () async {
                                      // ✅ SAFE VIEW SWAP: Trigger workspace state closure without deleting records
                                      widget.onQuitOrganisation();
                                      await Future.delayed(
                                        const Duration(milliseconds: 400),
                                      );
                                    },
                                  );

                                  // Return to root home view layer safely
                                  if (navigator.canPop()) {
                                    navigator.pop();
                                  }
                                }
                              },
                            ),
                          ],
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

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;

  const _SectionCard({required this.child, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.getTextSecondary(context),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20, color: AppTheme.getTextSecondary(context)),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.getTextSecondary(context),
      ),
      onTap: onTap,
    );
  }
}

class _RoleBadgeSmall extends StatelessWidget {
  final Role role;

  const _RoleBadgeSmall({required this.role});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0F7B6C);
    final (label, color) = switch (role) {
      Role.ORG_ADMIN => ('ORG ADMIN', Colors.deepOrange),
      Role.TEACHER => ('TEACHER', green),
      Role.STUDENT => ('STUDENT', Colors.blue),
      Role.STAFF => ('STAFF', Colors.purple),
      _ => ('USER', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final int maxLines;

  const _Field({
    required this.label,
    required this.ctrl,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }
}
