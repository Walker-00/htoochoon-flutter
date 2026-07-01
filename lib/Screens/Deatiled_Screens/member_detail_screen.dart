import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';
import 'package:htoochoon_flutter/core/userorgrole_manager.dart';
import 'package:provider/provider.dart';
import 'package:htoochoon_flutter/Providers/auth_provider.dart';
import 'package:htoochoon_flutter/models/auth/auth_model.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';

import 'package:htoochoon_flutter/api/api_service.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/student_overview_screen.dart';

class MemberDetailScreen extends StatefulWidget {
  final String userId;
  final Role roleInOrg;
  final String orgName;
  final String? orgId; // needed to surface student analytics

  const MemberDetailScreen({
    super.key,
    required this.userId,
    required this.roleInOrg,
    required this.orgName,
    this.orgId,
  });

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  User? _user;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _overview; // student analytics headline (lazy)

  bool get _isStudent => widget.roleInOrg == Role.STUDENT && widget.orgId != null;

  @override
  void initState() {
    super.initState();
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final user = await api.getUser(widget.userId);
      if (mounted) {
        setState(() {
          _user = user;
          _loading = false;
        });
      }
      // Pull analytics headline in the background for student members.
      if (_isStudent) {
        try {
          final res = await api.getStudentOverview(widget.orgId!, widget.userId);
          if (mounted && res is Map) {
            setState(() => _overview = Map<String, dynamic>.from(res));
          }
        } catch (_) {
          /* analytics is best-effort — ignore failures */
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Color get _roleColor {
    return switch (widget.roleInOrg) {
      Role.ORG_ADMIN => Colors.deepOrange,
      Role.TEACHER => const Color(0xFF0F7B6C),
      Role.STUDENT => Colors.blue,
      Role.STAFF => Colors.purple,
      _ => Colors.grey,
    };
  }

  String get _roleLabel {
    return switch (widget.roleInOrg) {
      Role.ORG_ADMIN => 'ORG ADMIN',
      Role.TEACHER => 'TEACHER',
      Role.STUDENT => 'STUDENT',
      Role.STAFF => 'STAFF',
      _ => 'MEMBER',
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(error: _error!, onRetry: _fetchUser)
          : _buildProfile(context),
    );
  }

  Widget _buildProfile(BuildContext context) {
    final user = _user!;
    final initials = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';
    final joinedAt = user.createdAt;

    // 🎯 Identity Check Hook: Append text tag indicators if the ID matches the local session
    final bool isMe = user.id == UserSessionManager.userId;
    final String parsedDisplayName = isMe ? '${user.name} (You)' : user.name;

    // ✅ FIX: Use the model's unified domain-stitched getter for asset resolution
    final String? absoluteAvatar = user.absoluteAvatarUrl;
    String joinedAtText = '';

    if (joinedAt != null) {
      joinedAtText =
          '${joinedAt.day} ${_monthName(joinedAt.month)} ${joinedAt.year}';
    }
    return CustomScrollView(
      slivers: [
        // ── App Bar ──────────────────────────────────────
        SliverAppBar(
          backgroundColor: _roleColor,
          foregroundColor: Colors.white,
          pinned: true,
          expandedHeight: 220,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_roleColor, _roleColor.withValues(alpha: 0.7)],
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
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      // ✅ Swapped to use verified stitched remote asset path securely
                      backgroundImage: absoluteAvatar != null
                          ? NetworkImage(absoluteAvatar)
                          : null,
                      child: absoluteAvatar == null
                          ? Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      parsedDisplayName, // 🚀 Displays identity tracking indicator natively
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _roleLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Contact Info Card ──────────────────────
              _SectionCard(
                margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: user.email,
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Joined',
                      value: joinedAtText,
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.circle,
                      label: 'Status',
                      value: user.isActive ? 'Active' : 'Inactive',
                      valueColor: user.isActive
                          ? Colors.green[700]
                          : Colors.red,
                      iconColor: user.isActive ? Colors.green : Colors.red,
                    ),
                  ],
                ),
              ),

              // ── Org Card ───────────────────────────────
              if (widget.orgName.isNotEmpty)
                _SectionCard(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _roleColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.corporate_fare_rounded,
                          size: 18,
                          color: _roleColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Organisation',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: AppTheme.getTextSecondary(context),
                                    letterSpacing: 0.6,
                                  ),
                            ),
                            Text(
                              widget.orgName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
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
                          color: _roleColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _roleLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _roleColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── 📊 Performance & Analytics (students only) ──────────
              if (_isStudent) _analyticsCard(context),

              // ── Memberships across other orgs ──────────
              if (user.memberships != null && user.memberships!.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    'Other Memberships',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _SectionCard(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: user.memberships!.asMap().entries.map((entry) {
                      final i = entry.key;
                      final m = entry.value;
                      // Skip the current org
                      if (m.organization.name == widget.orgName) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        children: [
                          if (i > 0) const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.business_rounded,
                                  size: 16,
                                  color: AppTheme.getTextSecondary(context),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    m.organization.name.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                _SmallRoleBadge(role: m.role),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],

              // ── Account Security Info (read-only) ──────
              _SectionCard(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    _ReadOnlyRow(
                      icon: Icons.security_rounded,
                      label: 'Two-Factor Auth',
                      value: (user.isTwoFactorEnabled ?? false)
                          ? 'Enabled'
                          : 'Disabled',
                      valueColor: (user.isTwoFactorEnabled ?? false)
                          ? Colors.green[700]
                          : AppTheme.getTextSecondary(context),
                    ),
                    const Divider(height: 16),
                    _ReadOnlyRow(
                      icon: Icons.fingerprint_rounded,
                      label: 'User ID',
                      value: user.id,
                      mono: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  Widget _analyticsCard(BuildContext context) {
    final o = _overview;

    String pct(dynamic v) => v == null ? '—' : '$v%';
    final attendance = (o?['attendance'] as Map?)?['attendanceRate'];
    final avgGrade = o?['averageGrade'];
    final learnHrs = o?['totalLearningHours'];
    final riskBand = o?['riskBand'] as String?;
    final riskScore = o?['riskScore'];
    final engagement = o?['engagementScore'];

    final (riskColor, riskLabel) = switch (riskBand) {
      'HIGH' => (Colors.red, 'High risk'),
      'MEDIUM' => (Colors.orange, 'Medium risk'),
      'LOW' => (Colors.green, 'Low risk'),
      _ => (Colors.grey, '—'),
    };

    return _SectionCard(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 18, color: _roleColor),
              const SizedBox(width: 8),
              const Text(
                'Performance & Analytics',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const Spacer(),
              if (riskBand != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$riskLabel${riskScore != null ? ' · $riskScore' : ''}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: riskColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (o == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Loading analytics…', style: TextStyle(fontSize: 12)),
                ],
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MiniStat(label: 'Attendance', value: pct(attendance), icon: Icons.event_available_rounded, color: Colors.teal),
                _MiniStat(label: 'Avg grade', value: pct(avgGrade), icon: Icons.grade_rounded, color: Colors.indigo),
                _MiniStat(label: 'Engagement', value: pct(engagement), icon: Icons.local_fire_department_rounded, color: Colors.deepOrange),
                _MiniStat(label: 'Learning', value: learnHrs == null ? '—' : '${learnHrs}h', icon: Icons.schedule_rounded, color: Colors.blueGrey),
              ],
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudentOverviewScreen(
                      organizationId: widget.orgId!,
                      studentId: widget.userId,
                      studentName: _user?.name,
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: _roleColor,
                side: BorderSide(color: _roleColor.withValues(alpha: 0.4)),
              ),
              icon: const Icon(Icons.bar_chart_rounded, size: 18),
              label: const Text('View full report'),
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int m) => const [
    '',
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
  ][m];
}
// ─── Widgets ──────────────────────────────────────────────────────────────────

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

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.getTextSecondary(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Color? iconColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: iconColor ?? AppTheme.getTextSecondary(context),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.getTextSecondary(context),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool mono;

  const _ReadOnlyRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.getTextSecondary(context)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: valueColor,
                  fontFamily: mono ? 'monospace' : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SmallRoleBadge extends StatelessWidget {
  final Role role;

  const _SmallRoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      Role.ORG_ADMIN => ('ADMIN', Colors.deepOrange),
      Role.TEACHER => ('TEACHER', const Color(0xFF0F7B6C)),
      Role.STUDENT => ('STUDENT', Colors.blue),
      Role.STAFF => ('STAFF', Colors.purple),
      _ => ('USER', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
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

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            const Text(
              'Failed to load member',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
