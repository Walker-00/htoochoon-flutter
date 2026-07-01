import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/organisation_provider.dart';
import 'package:htoochoon_flutter/Screens/AdminScreens/advanced_student_search_screen.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/course_detail_screen.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/member_detail_screen.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/student_overview_screen.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/shared_member_enrollment_widgets.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';
import 'package:htoochoon_flutter/Widgets/responsive.dart';
import 'package:htoochoon_flutter/core/userorgrole_manager.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:htoochoon_flutter/models/api_models/organization_model.dart';
import 'package:htoochoon_flutter/models/auth/auth_model.dart';
import 'package:provider/provider.dart';

class MembersScreen extends StatefulWidget {
  final String organisationId;
  final bool isInShell;

  const MembersScreen({
    super.key,
    required this.organisationId,
    this.isInShell = false,
  });

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen>
    with SingleTickerProviderStateMixin {
  // 5 tabs: All, Admin, Teacher, Student, Staff
  late TabController _tabController;

  static const _roleFilters = <Role?>[
    null,
    Role.ORG_ADMIN,
    Role.TEACHER,
    Role.STUDENT,
    Role.STAFF,
  ];

  String _search = '';

  String _roleLabel(Role? role) {
    switch (role) {
      case null:
        return 'All';
      case Role.ORG_ADMIN:
        return 'Admin';
      case Role.TEACHER:
        return 'Teacher';
      case Role.STUDENT:
        return 'Student';
      case Role.STAFF:
        return 'Staff';
      default:
        return 'Unknown';
    }
  }

  @override
  void initState() {
    super.initState();
    // ✅ length matches _roleFilters.length (5)
    _tabController = TabController(length: _roleFilters.length, vsync: this);
    _tabController.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final orgProv = context.read<OrganizationProvider>();
      await orgProv.fetchMembers(widget.organisationId, null);
      await orgProv.preloadMembers(orgProv.members);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Consumer<OrganizationProvider>(
        builder: (_, prov, __) {
          final all = prov.members;
          final roleFilter = _roleFilters[_tabController.index];

          // ✅ Search by cached name + email, fallback to userId
          final filtered = all.where((m) {
            final roleMatch = roleFilter == null || m.role == roleFilter;
            if (!roleMatch) return false;
            if (_search.isEmpty) return true;
            final q = _search.toLowerCase();
            final cached = prov.userCache[m.userId];
            final name = cached?.name.toLowerCase() ?? '';
            final email = cached?.email.toLowerCase() ?? '';
            final uid = m.userId.toLowerCase();
            return name.contains(q) || email.contains(q) || uid.contains(q);
          }).toList();

          final orgName = prov.selected?.name ?? '';

          return NestedScrollView(
            headerSliverBuilder: (ctx, _) => [
              SliverAppBar(
                automaticallyImplyLeading: !widget.isInShell,
                backgroundColor: cs.surface,
                foregroundColor: cs.onSurface,
                surfaceTintColor: Colors.transparent,
                pinned: true,
                title: Text(
                  '${all.length} Members',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: cs.onSurface,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.person_search_rounded, color: cs.primary),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdvancedStudentSearchScreen(
                          organizationId: widget.organisationId,
                        ),
                      ),
                    ),
                    tooltip: 'Advanced student search',
                  ),
                  IconButton(
                    icon: Icon(Icons.person_add_rounded, color: cs.primary),
                    onPressed: () => _showInviteDialog(context, prov),
                    tooltip: 'Add member',
                  ),
                  const SizedBox(width: 8),
                ],
                bottom: TabBar(
                  controller: _tabController,
                  labelColor: cs.primary,
                  unselectedLabelColor: cs.onSurfaceVariant,
                  indicatorColor: cs.primary,
                  indicatorWeight: 3,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: _roleFilters
                      .map((r) => Tab(text: _roleLabel(r)))
                      .toList(),
                ),
              ),
            ],
            body: MaxWidthBox(
              maxWidth: 860,
              child: Column(
              children: [
                // ── Search bar ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search by name or email…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),

                if (prov.isLoading)
                  const LinearProgressIndicator()
                else
                  const SizedBox(height: 2),

                // ── Member count for current filter ─────────
                if (!prov.isLoading && filtered.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${filtered.length} ${_roleLabel(roleFilter).toLowerCase()} ${filtered.length == 1 ? 'member' : 'members'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.getTextSecondary(context),
                        ),
                      ),
                    ),
                  ),

                // ── List ────────────────────────────────────
                Expanded(
                  child: filtered.isEmpty && !prov.isLoading
                      ? _EmptyState(
                          onAdd: () => _showInviteDialog(context, prov),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _OrgMemberTile(
                            member: filtered[i],
                            orgProv: prov,
                            orgName: orgName,
                            organisationId: widget.organisationId,
                            onRemove: () =>
                                _confirmRemove(context, prov, filtered[i]),
                          ),
                        ),
                ),
              ],
            ),
            ),
          );
        },
      ),
    );
  }

  // ── Invite dialog ──────────────────────────────────────
  Future<void> _showInviteDialog(
    BuildContext context,
    OrganizationProvider prov,
  ) async {
    String selectedRole = 'STUDENT';
    User? selectedUser;
    List<User> users = [];

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setInner) {
            return AlertDialog(
              title: const Text('Add Member'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Autocomplete<User>(
                    displayStringForOption: (u) => "${u.name} (${u.email})",
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty)
                        return const Iterable<User>.empty();
                      return users.where(
                        (u) =>
                            u.name.toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            ) ||
                            u.email.toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            ),
                      );
                    },
                    onSelected: (user) {
                      logD(
                        "✅ AUTOCOMPLETE SELECTED: ${user.id} | ${user.name}",
                      );
                      setInner(() => selectedUser = user);
                    },
                    fieldViewBuilder:
                        (context, textController, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: textController,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Search user (name/email)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) async {
                              if (value.isEmpty) {
                                setInner(() => users = []);
                                return;
                              }
                              final result = await prov.getUsers(value);
                              setInner(() => users = result);
                              logD("📡 FETCHED ${result.length} USERS");
                            },
                          );
                        },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    items: ['ORG_ADMIN', 'TEACHER', 'STUDENT', 'STAFF']
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) => setInner(() => selectedRole = v!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  // 🔍 ALWAYS ENABLED FOR DEBUGGING
                  onPressed: () async {
                    logD("🔘 ADD BUTTON CLICKED");
                    logD("selectedUser = $selectedUser");

                    if (selectedUser == null) {
                      logD("⚠️ EXITING: No user selected!");
                      ScaffoldMessenger.of(dialogCtx).showSnackBar(
                        const SnackBar(
                          content: Text('Please tap a user from the dropdown'),
                        ),
                      );
                      return;
                    }

                    logD("✅ PROCEEDING TO ADD MEMBER...");
                    Navigator.pop(dialogCtx);

                    try {
                      await prov.addMember(
                        widget.organisationId,
                        OrganisationMemberRequest(
                          userId: selectedUser!.id,
                          role: selectedRole,
                        ),
                      );
                      logD("✅ SUCCESS: Member added");
                    } catch (e) {
                      logD("❌ ERROR ADDING MEMBER: $e");
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Remove confirmation ────────────────────────────────
  Future<void> _confirmRemove(
    BuildContext context,
    OrganizationProvider prov,
    OrganisationMember member,
  ) async {
    final cachedName = prov.userCache[member.userId]?.name ?? member.userId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove $cachedName from organisation?'),
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await prov.removeMember(widget.organisationId, member.userId);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Org Member Tile — taps into MemberDetailScreen
// ─────────────────────────────────────────────────────────────────────────────
class _OrgMemberTile extends StatelessWidget {
  final OrganisationMember member;
  final OrganizationProvider orgProv;
  final String orgName;
  final String organisationId;
  final VoidCallback onRemove;

  const _OrgMemberTile({
    required this.member,
    required this.orgProv,
    required this.orgName,
    required this.organisationId,
    required this.onRemove,
  });

  Color _roleColor(ColorScheme cs) {
    return switch (member.role) {
      Role.ORG_ADMIN => Colors.deepOrange,
      Role.TEACHER => const Color(0xFF0F7B6C),
      Role.STUDENT => Colors.teal,
      Role.STAFF => Colors.purple,
      _ => cs.tertiary,
    };
  }

  String _roleLabel() {
    return switch (member.role) {
      Role.ORG_ADMIN => 'ADMIN',
      Role.TEACHER => 'TEACHER',
      Role.STUDENT => 'STUDENT',
      Role.STAFF => 'STAFF',
      _ => 'USER',
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final roleColor = _roleColor(cs);
    final cached = orgProv.userCache[member.userId];
    final displayName = cached?.name ?? member.userId;
    final email = cached?.email ?? '';
    final avatar = cached?.avatar;
    final String? absoluteAvatarUrl = (avatar != null && avatar.isNotEmpty)
        ? (avatar.startsWith('http')
              ? avatar
              : "https://backend.htoochoon.com$avatar")
        : null;
    final currentUser = UserSessionManager.user;
    bool isMe = (currentUser!.id.toString() == member.userId);

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MemberDetailScreen(
              userId: member.userId,
              roleInOrg: member.role,
              orgName: orgName,
              orgId: organisationId,
            ),
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: roleColor.withValues(alpha: 0.15),
          backgroundImage: absoluteAvatarUrl != null
              ? NetworkImage(absoluteAvatarUrl)
              : null,
          child: absoluteAvatarUrl == null
              ? Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: roleColor,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
        ),
        title: Text(
          isMe ? '$displayName (You)' : displayName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: email.isNotEmpty
            ? Text(
                email,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.getTextSecondary(context),
                ),
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _roleLabel(),
                style: TextStyle(
                  color: roleColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 18),
              onSelected: (v) {
                if (v == 'view') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MemberDetailScreen(
                        userId: member.userId,
                        roleInOrg: member.role,
                        orgName: orgName,
                        orgId: organisationId,
                      ),
                    ),
                  );
                }
                if (v == 'analytics') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudentOverviewScreen(
                        organizationId: organisationId,
                        studentId: member.userId,
                        studentName: orgProv.userCache[member.userId]?.name,
                      ),
                    ),
                  );
                }
                if (v == 'remove') onRemove();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('View Profile'),
                    ],
                  ),
                ),
                if (member.role == Role.STUDENT)
                  const PopupMenuItem(
                    value: 'analytics',
                    child: Row(
                      children: [
                        Icon(Icons.insights_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('View analytics'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_remove_outlined,
                        size: 16,
                        color: Colors.red,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Remove from org',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline_rounded, size: 56, color: cs.outline),
          const SizedBox(height: 12),
          const Text(
            'No members found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Add your first team member',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Add Member'),
          ),
        ],
      ),
    );
  }
}
