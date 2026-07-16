import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Screens/Library/library_screen.dart';
import 'package:htoochoon_flutter/Providers/auth_provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/organisation_provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/subscription_provider.dart';
import 'package:htoochoon_flutter/Providers/theme_provider.dart';
import 'package:htoochoon_flutter/Screens/AdminScreens/admin_shell.dart';
import 'package:htoochoon_flutter/Screens/Onboarding/org_loader_screen.dart';
import 'package:htoochoon_flutter/Screens/Profile/personal_info_screen.dart';
import 'package:htoochoon_flutter/Screens/Profile/payment_account_screen.dart';
import 'package:htoochoon_flutter/Screens/Profile/privacy_security_screen.dart';
import 'package:htoochoon_flutter/Screens/TeacherScreens/teacher_shell.dart';
import 'package:htoochoon_flutter/utils/avatar_util.dart';
import 'package:htoochoon_flutter/Widgets/user_appbar.dart';
import 'package:htoochoon_flutter/core/userorgrole_manager.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:htoochoon_flutter/models/api_models/organization_model.dart';
import 'package:htoochoon_flutter/models/api_models/subscription_model.dart';
import 'package:htoochoon_flutter/models/auth/auth_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:htoochoon_flutter/Providers/locale_provider.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';

// ─── Breakpoints ─────────────────────────────────────────────────────────────

class _BP {
  static bool mobile(BuildContext c) => MediaQuery.of(c).size.width < 600;
  static bool desktop(BuildContext c) => MediaQuery.of(c).size.width >= 1024;
}

// ═════════════════════════════════════════════════════════════════════════════
// SETTINGS SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class SettingsScreen extends StatefulWidget {
  final VoidCallback onProfileTap;
  const SettingsScreen({super.key, required this.onProfileTap});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _language = 'English (US)';
  bool _notifyMaterials = true;
  bool _notifyInsights = true;

  Future<void> _bootstrap() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final auth = context.read<AuthProvider>();
      final orgs = context.read<OrganizationProvider>();

      if (!auth.initialized) {
        Future.delayed(const Duration(milliseconds: 50), _bootstrap);
        return;
      }

      // user is already loaded by MainScaffold — just load orgs
      if (auth.user != null) {
        await orgs.loadOrganisations();
        if (mounted) setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isMobile = _BP.mobile(context);

    if (auth.isLoading && user == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to load profile',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // @override
    // void initState() {
    //   super.initState();
    //
    //   WidgetsBinding.instance.addPostFrameCallback((_) async {
    //     await _bootstrap();
    //
    //     if (mounted) {
    //       setState(() {});
    //     }
    //   });
    // }

    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: UserAppBar(
        title: 'HtooChoon',
        showSearchIcon: true,
        leadIcon: Icons.dashboard,
        onProfileTap: widget.onProfileTap,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _bootstrap,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: 20,
                ),
                child: _BP.desktop(context)
                    ? Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: _DesktopLayout(
                            darkMode: themeProvider.isDarkMode,
                            language: _language,
                            notifyMaterials: _notifyMaterials,
                            notifyInsights: _notifyInsights,
                            onDarkMode: (v) => themeProvider.toggleTheme(),
                            onLanguage: (v) =>
                                setState(() => _language = v ?? _language),
                            onMaterials: (v) =>
                                setState(() => _notifyMaterials = v ?? false),
                            onInsights: (v) =>
                                setState(() => _notifyInsights = v ?? false),
                          ),
                        ),
                      )
                    : _MobileLayout(
                        darkMode: themeProvider.isDarkMode,
                        language: _language,
                        notifyMaterials: _notifyMaterials,
                        notifyInsights: _notifyInsights,
                        onDarkMode: (v) => themeProvider.toggleTheme(),
                        onLanguage: (v) =>
                            setState(() => _language = v ?? _language),
                        onMaterials: (v) =>
                            setState(() => _notifyMaterials = v ?? false),
                        onInsights: (v) =>
                            setState(() => _notifyInsights = v ?? false),
                      ),
              ),
            ),
            _Footer(isMobile: isMobile),
          ],
        ),
      ),
    );
  }
}

// ─── Layouts ─────────────────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  final bool darkMode;
  final String language;
  final bool notifyMaterials, notifyInsights;
  final ValueChanged<bool> onDarkMode;
  final ValueChanged<String?> onLanguage;
  final ValueChanged<bool?> onMaterials, onInsights;

  const _DesktopLayout({
    required this.darkMode,
    required this.language,
    required this.notifyMaterials,
    required this.notifyInsights,
    required this.onDarkMode,
    required this.onLanguage,
    required this.onMaterials,
    required this.onInsights,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              const _AccountLinksCard(),
              const SizedBox(height: 20),
              const _ProfileCard(),
              const SizedBox(height: 20),
              const _OrganisationsCard(),
            ],
          ),
        ),
        const SizedBox(width: 20),
        SizedBox(
          width: 320,
          child: Column(
            children: [
              _PreferencesCard(
                darkMode: darkMode,
                language: language,
                notifyMaterials: notifyMaterials,
                notifyInsights: notifyInsights,
                onDarkMode: onDarkMode,
                onLanguage: onLanguage,
                onMaterials: onMaterials,
                onInsights: onInsights,
              ),
              const SizedBox(height: 20),
              const _SecurityCard(),
              const SizedBox(height: 20),
              // const _SubscriptionCard(),
              // const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileLayout extends StatelessWidget {
  final bool darkMode;
  final String language;
  final bool notifyMaterials, notifyInsights;
  final ValueChanged<bool> onDarkMode;
  final ValueChanged<String?> onLanguage;
  final ValueChanged<bool?> onMaterials, onInsights;

  const _MobileLayout({
    required this.darkMode,
    required this.language,
    required this.notifyMaterials,
    required this.notifyInsights,
    required this.onDarkMode,
    required this.onLanguage,
    required this.onMaterials,
    required this.onInsights,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _AccountLinksCard(),
        const SizedBox(height: 16),
        const _ProfileCard(),
        const SizedBox(height: 16),
        _PreferencesCard(
          darkMode: darkMode,
          language: language,
          notifyMaterials: notifyMaterials,
          notifyInsights: notifyInsights,
          onDarkMode: onDarkMode,
          onLanguage: onLanguage,
          onMaterials: onMaterials,
          onInsights: onInsights,
        ),
        const SizedBox(height: 16),
        const _OrganisationsCard(),
        const SizedBox(height: 16),
        // const _SubscriptionCard(),
        // const SizedBox(height: 16),
        const _SecurityCard(),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─── Account Links Card ───────────────────────────────────────────────────────

class _AccountLinksCard extends StatelessWidget {
  const _AccountLinksCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          _AccountLinkTile(
            icon: Icons.person_outline,
            title: 'Personal information',
            subtitle: 'Photo, name and email',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          _AccountLinkTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Payment account',
            subtitle: 'Phone number you pay from',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PaymentAccountScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AccountLinkTile(
            icon: Icons.shield_outlined,
            title: 'Privacy & security',
            subtitle: 'Password, language and 2FA',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountLinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AccountLinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 20, color: cs.onSurface.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ─── Profile Card ─────────────────────────────────────────────────────────────

class _ProfileCard extends StatefulWidget {
  const _ProfileCard({super.key});

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user; // ✅
    if (user == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Update your personal details and how others see you on the platform.',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.65),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => _showUpdateDialog(context, user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Update\nProfile',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Avatar (upload / generated / reset flow)
                const EditableAvatar(),

                const SizedBox(width: 16),
                Expanded(
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      final useRow = constraints.maxWidth > 320;
                      final nameField = _LabeledField(
                        label: 'FULL NAME',
                        value: user.name,
                      );
                      final emailField = _LabeledField(
                        label: 'EMAIL ADDRESS',
                        value: user.email,
                      );
                      if (useRow) {
                        return Row(
                          children: [
                            Expanded(child: nameField),
                            const SizedBox(width: 12),
                            Expanded(child: emailField),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          nameField,
                          const SizedBox(height: 10),
                          emailField,
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUpdateDialog(BuildContext context, User user) {
    final nameCtrl = TextEditingController(text: user.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update Profile'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Full Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AuthProvider>().updateUser(user.id, {
                'name': nameCtrl.text.trim(),
              });
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label, value;
  const _LabeledField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: cs.tertiary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outline),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Organisations Card ───────────────────────────────────────────────────────

class _OrganisationsCard extends StatelessWidget {
  const _OrganisationsCard();

  @override
  Widget build(BuildContext context) {
    final orgProv = context.watch<OrganizationProvider>();
    final subProv = context.watch<SubscriptionProvider>();
    final authProv = context.watch<AuthProvider>();
    final isMobile = _BP.mobile(context);
    final cs = Theme.of(context).colorScheme;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Organisations',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage your institutional roles and associations.',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _CreateOrgButton(subProv: subProv, orgProv: orgProv),
            ],
          ),
          const SizedBox(height: 20),

          if (orgProv.isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: CircularProgressIndicator(color: cs.primary),
              ),
            )
          else if (orgProv.organisations.isEmpty)
            _EmptyOrgs(
              onTap: () => _startOrgFlow(context, subProv, orgProv, authProv),
            )
          else
            isMobile
                ? ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: orgProv.organisations.length,
                    itemBuilder: (context, index) {
                      final o = orgProv.organisations[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _OrgTile(
                          org: o,
                          subProv: subProv,
                          onSelect: () {
                            // await Future.delayed(const Duration(milliseconds: 20));
                            _openAdminShell(context, o, orgProv);
                          },
                          onDelete: () => _confirmDelete(context, o, orgProv),
                        ),
                      );
                    },
                  )
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: orgProv.organisations
                        .map(
                          (o) => SizedBox(
                            width: 260,
                            child: _OrgTile(
                              org: o,
                              subProv: subProv,
                              onSelect: () {
                                _openAdminShell(context, o, orgProv);
                              },
                              onDelete: () =>
                                  _confirmDelete(context, o, orgProv),
                            ),
                          ),
                        )
                        .toList(),
                  ),

          if (orgProv.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: cs.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Couldn't load your organisations",
                            style: TextStyle(
                              color: cs.error,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Please check your connection and try again. If this keeps happening, report it to your admin.',
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => orgProv.loadOrganisations(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(0, 32),
                            ),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                          ),
                        ],
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

  // ── Navigate into AdminShell ─────────────────────
  //
  // We await selectOrganisation so the provider has the org + members loaded
  // before AdminShell.initState fires. Without this, DashboardScreen's
  // initState runs before `selected` is set and shows stale/empty data.
  // Future<void> _openAdminShell(
  //   BuildContext context,
  //   OrganizationResponse org,
  //   OrganizationProvider orgProv,
  // ) async {
  //   logD("opened admin shell: ${org.id}");
  //
  //   // Select org (fetches members + marks justSwitched)
  //   orgProv.setSelected(org);
  //   await Future.delayed(const Duration(milliseconds: 50));
  //
  //   if (!context.mounted) return;
  //   if (orgProv.error != null) {
  //     logD("Navigation blocked due to error: ${orgProv.error}");
  //     return;
  //   }
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (_) => AdminShell(
  //           organisationId: org.id,
  //           onQuitOrganisation: () {
  //             orgProv.leaveOrganisation();
  //             Navigator.of(context).pop();
  //           },
  //         ),
  //       ),
  //     );
  //   });
  // }

  Future<void> _openAdminShell(
    BuildContext context,
    OrganizationResponse org,
    OrganizationProvider orgProv,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    orgProv.setSelected(org);

    final role = orgProv.getOrgRole(org.id);
    logD("User role in org ${org.id}: $role");

    // ✅ Block students immediately — no loader, no navigation
    if (role == Role.STUDENT ||
        role == Role.STAFF ||
        role == Role.USER ||
        role == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('You are already in a student view.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Only admins and teachers get past this point
    await OrgLoaderScreen.show(
      context,
      action: () async {
        await Future.delayed(const Duration(milliseconds: 400));
      },
    );

    final onQuit = () => navigator.pop();

    final Widget shell;
    switch (role) {
      case Role.TEACHER:
        shell = TeacherShell(
          organisationId: org.id,
          onQuitOrganisation: onQuit,
        );
        break;
      case Role.ORG_ADMIN:
        shell = AdminShell(organisationId: org.id, onQuitOrganisation: onQuit);
        break;
      default:
        return;
    }

    navigator.push(MaterialPageRoute(builder: (_) => shell));
  }
}

void _startOrgFlow(
  BuildContext context,
  SubscriptionProvider subProv,
  OrganizationProvider orgProv,
  AuthProvider authProv,
) async {
  final selectedId = orgProv.selected?.id;
  if (selectedId != null) {
    _showCreateOrgDialog(context, orgProv);
  }
}

/// Default organisation categories offered in the create form. The user must
/// pick one (category is required).
const List<String> kOrgCategories = [
  'School',
  'University / College',
  'Bootcamp',
  'Tutoring Center',
  'Training / Corporate',
  'Online Academy',
  'Non-profit',
  'Other',
];

void _showCreateOrgDialog(BuildContext context, OrganizationProvider orgProv) {
  showDialog(
    context: context,
    builder: (_) => _CreateOrgDialog(orgProv: orgProv),
  );
}

class _CreateOrgDialog extends StatefulWidget {
  final OrganizationProvider orgProv;
  const _CreateOrgDialog({required this.orgProv});

  @override
  State<_CreateOrgDialog> createState() => _CreateOrgDialogState();
}

class _CreateOrgDialogState extends State<_CreateOrgDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _emailCtrl = TextEditingController(
    text: UserSessionManager.user?.email ?? '',
  );
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();

  String? _category;
  File? _logoFile;
  bool _submitting = false;

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _descCtrl,
      _emailCtrl,
      _phoneCtrl,
      _addressCtrl,
      _websiteCtrl,
      _facebookCtrl,
      _instagramCtrl,
      _linkedinCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() => _logoFile = File(image.path));
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim().isNotEmpty
        ? _emailCtrl.text.trim()
        : (UserSessionManager.user?.email ?? '');

    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and Email are required')),
      );
      return;
    }
    if (_category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a category')),
      );
      return;
    }

    final social = <String, String>{
      if (_facebookCtrl.text.trim().isNotEmpty)
        'facebook': _facebookCtrl.text.trim(),
      if (_instagramCtrl.text.trim().isNotEmpty)
        'instagram': _instagramCtrl.text.trim(),
      if (_linkedinCtrl.text.trim().isNotEmpty)
        'linkedin': _linkedinCtrl.text.trim(),
    };

    setState(() => _submitting = true);
    try {
      final created = await widget.orgProv.createOrganisation(
        OrganizationRequest(
          name: name,
          email: email,
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          category: _category,
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim().isEmpty
              ? null
              : _addressCtrl.text.trim(),
          website: _websiteCtrl.text.trim().isEmpty
              ? null
              : _websiteCtrl.text.trim(),
          socialLinks: social.isEmpty ? null : social,
        ),
        email,
      );

      // Logo is uploaded after creation (separate multipart endpoint that
      // needs the new org id).
      if (created != null && _logoFile != null) {
        await widget.orgProv.uploadLogo(created.id, _logoFile!);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _showLimitDialog(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Start an Organisation'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo upload
              Center(
                child: GestureDetector(
                  onTap: _pickLogo,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cs.outline.withValues(alpha: 0.5),
                      ),
                      image: _logoFile != null
                          ? DecorationImage(
                              image: FileImage(_logoFile!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _logoFile == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined,
                                  color: cs.primary, size: 24),
                              const SizedBox(height: 4),
                              Text(
                                'Logo',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: _pickLogo,
                  child: Text(_logoFile == null ? 'Upload logo' : 'Change logo'),
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Organisation Name *',
                ),
              ),
              const SizedBox(height: 12),

              // Category (REQUIRED)
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category *'),
                hint: const Text('Select a category'),
                items: kOrgCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email *'),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration:
                    const InputDecoration(labelText: 'Phone (optional)'),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _addressCtrl,
                decoration:
                    const InputDecoration(labelText: 'Address (optional)'),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _websiteCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Website (optional)',
                  hintText: 'https://example.com',
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Social media (optional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _facebookCtrl,
                decoration: const InputDecoration(
                  labelText: 'Facebook',
                  prefixIcon: Icon(Icons.facebook),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _instagramCtrl,
                decoration: const InputDecoration(
                  labelText: 'Instagram',
                  prefixIcon: Icon(Icons.camera_alt_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _linkedinCtrl,
                decoration: const InputDecoration(
                  labelText: 'LinkedIn',
                  prefixIcon: Icon(Icons.work_outline),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: cs.primary),
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Create', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

void _confirmDelete(
  BuildContext context,
  OrganizationResponse org,
  OrganizationProvider orgProv,
) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete Organisation'),
      content: Text('Delete "${org.name}"? This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () async {
            Navigator.pop(context);
            await orgProv.deleteOrganisation(org.id);
          },
          child: const Text('Delete', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

/// Pulls the human-readable `message` out of a backend error payload, falling
/// back to the raw text when the error isn't a NestJS-shaped response.
String _errorMessage(Object e) {
  final raw = e.toString();
  final match = RegExp(r'"message"\s*:\s*("(?:[^"\\]|\\.)*"|\[[^\]]*\])')
      .firstMatch(raw);
  if (match == null) return raw;
  try {
    final decoded = jsonDecode(match.group(1)!);
    if (decoded is List) return decoded.join('\n');
    return decoded.toString();
  } catch (_) {
    return raw;
  }
}

void _showLimitDialog(BuildContext context, Object e) {
  final message = _errorMessage(e);
  // Only the subscription cap gets the upgrade pitch; validation/duplicate/
  // network failures are plain errors and must not be mislabelled.
  final isLimit = message.toLowerCase().contains('limit reached');

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(isLimit ? 'Plan Limit Reached' : "Couldn't create organisation"),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Dismiss'),
        ),
        if (isLimit)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Contact our Team to Upgrade',
              style: TextStyle(color: Colors.white),
            ),
          ),
      ],
    ),
  );
}

class _CreateOrgButton extends StatelessWidget {
  final SubscriptionProvider subProv;
  final OrganizationProvider orgProv;

  const _CreateOrgButton({required this.subProv, required this.orgProv});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => _handleCreate(context),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('New'),
    );
  }

  void _handleCreate(BuildContext context) {
    // If a plan is loaded, check limits before proceeding
    // if (subProv.currentPlan != null) {
    //   // Each org is one "program-level" entity; reuse canCreateProgram as a
    //   // proxy, or add a dedicated canCreateOrg() if your API supports it.
    //   // For now we just show a warning and still allow — adjust as needed.
    //   if (subProv.isApproachingLimit(threshold: 100)) {
    //     _showLimitWarning(
    //       context,
    //       'You have reached the limit for your current plan. '
    //       'Upgrade to create more organisations.',
    //     );
    //     return;
    //   }
    // }

    _showCreateOrgDialog(context, orgProv);

    // _startOrgFlow(context, subProv, orgProv, authProv);
  }

  void _showLimitWarning(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Plan limit reached'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: navigate to upgrade / plan screen
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }
}

// ── Shared limit-dialog helper used by any screen ──────────────────────────
//
// Call this wherever you have a create action and want to gate on subscription.
// Example:
//   final result = subProv.canCreateCourse();
//   if (!result.allowed) {
//     showSubscriptionLimitDialog(context, result);
//     return;
//   }

void showSubscriptionLimitDialog(
  BuildContext context,
  LimitCheckResult result,
) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('${result.resourceName} limit reached'),
      content: Text(
        result.reason ??
            'You have used ${result.current} of ${result.max} '
                '${result.resourceName.toLowerCase()} on your current plan.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            // TODO: navigate to upgrade / plan screen
          },
          child: const Text('Upgrade plan'),
        ),
      ],
    ),
  );
}

class _EmptyOrgs extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyOrgs({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(
            color: cs.outline,
            style: BorderStyle.solid,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.business_outlined, color: cs.tertiary, size: 36),
            const SizedBox(height: 8),
            Text(
              'No organisations yet',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to create your first organisation',
              style: TextStyle(color: cs.tertiary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrgTile extends StatelessWidget {
  final OrganizationResponse org;
  final SubscriptionProvider subProv;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  const _OrgTile({
    required this.org,
    required this.subProv,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final orgProv = context.watch<OrganizationProvider>();
    final cs = Theme.of(context).colorScheme;

    final isSelected = orgProv.selected?.id == org.id;

    final studentPercent = subProv.usagePercent('student');
    final studentUsed = orgProv.usageStats?.current ?? 0;
    final studentMax = orgProv.usageStats?.max ?? 0;

    final role = orgProv.getOrgRole(org.id);

    // admin → primary colour, other roles → tertiary colour
    final badgeColor = role == Role.ORG_ADMIN ? cs.primary : cs.tertiary;

    return GestureDetector(
      onTap: onSelect,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outline,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left accent bar
              SizedBox(
                width: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isSelected ? cs.primary : badgeColor,
                  ),
                ),
              ),

              // Main content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: role == Role.ORG_ADMIN
                                  ? cs.primary.withValues(alpha: 0.12)
                                  : cs.tertiary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              role == Role.ORG_ADMIN
                                  ? Icons.school
                                  : Icons.code,
                              color: role == Role.ORG_ADMIN
                                  ? cs.primary
                                  : cs.tertiary,
                              size: 20,
                            ),
                          ),

                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  role.toString(),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.background,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),

                              if (role == Role.ORG_ADMIN) ...[
                                const SizedBox(width: 6),

                                GestureDetector(
                                  onTap: onDelete,
                                  child: Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: cs.tertiary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Text(
                        org.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        '2 active students',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),

                      if (isSelected &&
                          studentMax > 0 &&
                          studentPercent != null) ...[
                        const SizedBox(height: 10),

                        _UsageBar(
                          label: 'Students',
                          used: studentUsed,
                          max: studentMax,
                          percent: studentPercent / 100.0,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
//─── Usage Bar ────────────────────────────────────────────────────────────────

class _UsageBar extends StatelessWidget {
  final String label;
  final int used, max;
  final double percent;

  const _UsageBar({
    required this.label,
    required this.used,
    required this.max,
    required this.percent,
  });

  Color _barColor(ColorScheme cs) {
    if (percent >= 1.0) return cs.error;
    if (percent >= 0.8) return AppTheme.warning;
    return cs.primary;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _barColor(cs);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            Text(
              '$used / $max',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 6,
            backgroundColor: cs.outline,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

// ─── Preferences Card ─────────────────────────────────────────────────────────

class _PreferencesCard extends StatelessWidget {
  final bool darkMode, notifyMaterials, notifyInsights;
  final String language;
  final ValueChanged<bool> onDarkMode;
  final ValueChanged<String?> onLanguage;
  final ValueChanged<bool?> onMaterials, onInsights;

  const _PreferencesCard({
    required this.darkMode,
    required this.language,
    required this.notifyMaterials,
    required this.notifyInsights,
    required this.onDarkMode,
    required this.onLanguage,
    required this.onMaterials,
    required this.onInsights,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Preferences',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dark Mode',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Switch to dark interface',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: darkMode,
                  onChanged: onDarkMode,
                  activeColor: cs.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Language',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final locale = context.watch<LocaleProvider>();
              final current = locale.locale?.languageCode; // null = system
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outline),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: current,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down,
                        color: cs.onSurface.withValues(alpha: 0.6)),
                    style: TextStyle(fontSize: 14, color: cs.onSurface),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('System default'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'en',
                        child: Text(LocaleProvider.labelFor('en')),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'my',
                        child: Text(LocaleProvider.labelFor('my')),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'th',
                        child: Text(LocaleProvider.labelFor('th')),
                      ),
                    ],
                    onChanged: (code) => locale
                        .setLocale(code == null ? null : Locale(code)),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Notify me about',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          _CheckRow(
            label: 'New course materials',
            value: notifyMaterials,
            onChanged: onMaterials,
          ),
          const SizedBox(height: 6),
          _CheckRow(
            label: 'AI performance insights',
            value: notifyInsights,
            onChanged: onInsights,
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;
  const _CheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: cs.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 14, color: cs.onSurface)),
      ],
    );
  }
}

// // ─── Subscription Card ────────────────────────────────────────────────────────
//
// class _SubscriptionCard extends StatelessWidget {
//   const _SubscriptionCard();
//
//   @override
//   Widget build(BuildContext context) {
//     final subProv = context.watch<SubscriptionProvider>();
//     final orgProv = context.watch<OrganizationProvider>();
//     final cs = Theme.of(context).colorScheme;
//     final plan = subProv.currentPlan;
//     final usage = subProv.usage;
//     final orgId = orgProv.selected?.id;
//
//     return _Card(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Row(
//                 children: [
//                   Icon(Icons.workspace_premium, color: cs.primary, size: 20),
//                   const SizedBox(width: 8),
//                   Text(
//                     'Subscription',
//                     style: TextStyle(
//                       fontSize: 17,
//                       fontWeight: FontWeight.w700,
//                       color: cs.onSurface,
//                     ),
//                   ),
//                 ],
//               ),
//               if (plan != null)
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 10,
//                     vertical: 4,
//                   ),
//                   decoration: BoxDecoration(
//                     color: plan.status == 'active'
//                         ? AppTheme.success
//                         : Colors.blueGrey,
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                   child: Text(
//                     plan.planType.toUpperCase(),
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 11,
//                       fontWeight: FontWeight.w700,
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//           const SizedBox(height: 14),
//
//           if (subProv.isLoading)
//             Center(
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: CircularProgressIndicator(color: cs.primary),
//               ),
//             )
//           else if (plan == null)
//             Text('No active plan', style: TextStyle(color: cs.inversePrimary))
//           else ...[
//             if (usage != null) ...[
//               _UsageBar(
//                 label: 'Students',
//                 used: usage.usagePercentage.students,
//                 max: usage.usagePercentage.students + usage.remaining.students,
//                 percent: usage.usagePercentage.students / 100,
//               ),
//               const SizedBox(height: 10),
//               _UsageBar(
//                 label: 'Courses',
//                 used: usage.usagePercentage.courses,
//                 max: usage.usagePercentage.courses + usage.remaining.courses,
//                 percent: usage.usagePercentage.courses / 100,
//               ),
//               const SizedBox(height: 10),
//               _UsageBar(
//                 label: 'Live Sessions',
//                 used: usage.usagePercentage.classes,
//                 max: usage.usagePercentage.classes + usage.remaining.classes,
//                 percent: usage.usagePercentage.classes / 100,
//               ),
//               const SizedBox(height: 14),
//             ],
//
//             if (subProv.availablePlans.isNotEmpty) ...[
//               Text(
//                 'Available Plans',
//                 style: TextStyle(
//                   fontSize: 13,
//                   fontWeight: FontWeight.w500,
//                   color: cs.onSurface.withValues(alpha: 0.6),
//                 ),
//               ),
//               const SizedBox(height: 10),
//               ...subProv.availablePlans.map(
//                 (tier) => Padding(
//                   padding: const EdgeInsets.only(bottom: 8),
//                   child: _PlanTierRow(
//                     tier: tier,
//                     isCurrent: tier.isCurrent,
//                     onUpgrade: orgId == null
//                         ? null
//                         : () async {
//                             final ok = await subProv.upgradePlan(
//                               orgId,
//                               tier.name,
//                             );
//                             if (ok && context.mounted) {
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 SnackBar(
//                                   content: Text('Switched to ${tier.name}'),
//                                 ),
//                               );
//                             }
//                           },
//                   ),
//                 ),
//               ),
//             ],
//           ],
//
//           if (subProv.error != null)
//             Padding(
//               padding: const EdgeInsets.only(top: 8),
//               child: Text(
//                 subProv.error!,
//                 style: TextStyle(color: cs.error, fontSize: 12),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }

class _PlanTierRow extends StatelessWidget {
  final PlanTier tier;
  final bool isCurrent;
  final VoidCallback? onUpgrade;

  const _PlanTierRow({
    required this.tier,
    required this.isCurrent,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrent
            ? cs.secondary.withValues(alpha: 0.06)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrent ? cs.primary : cs.outline,
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.planType,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                if (tier.price != null)
                  Text(
                    tier.price.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          if (isCurrent)
            Text(
              'Current',
              style: TextStyle(
                fontSize: 12,
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            TextButton(
              onPressed: onUpgrade,
              style: TextButton.styleFrom(
                foregroundColor: cs.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
              child: const Text('Switch', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

// ─── Security Card ────────────────────────────────────────────────────────────

class _SecurityCard extends StatelessWidget {
  const _SecurityCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: cs.onSurface, size: 20),
              const SizedBox(width: 8),
              Text(
                'Security',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => _showChangePassword(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outline),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    color: cs.onSurface.withValues(alpha: 0.6),
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Change Password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: cs.onSurface.withValues(alpha: 0.6),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 🌐 Language picker (English / Burmese / Thai).
          InkWell(
            onTap: () => _showLanguagePicker(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outline),
              ),
              child: Row(
                children: [
                  Icon(Icons.translate,
                      color: cs.onSurface.withValues(alpha: 0.6), size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Language',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: cs.onSurface.withValues(alpha: 0.6), size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 🎞️ Local recordings + exported notes library.
          InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LibraryScreen()),
            ),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outline),
              ),
              child: Row(
                children: [
                  Icon(Icons.video_library_outlined,
                      color: cs.onSurface.withValues(alpha: 0.6), size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'My Recordings & Notes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: cs.onSurface.withValues(alpha: 0.6), size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '2FA Authentication',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.success,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Enabled',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Two-factor authentication adds an extra layer of security to your account.',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.6),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePassword(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final rootContext = context;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> submit() async {
            final current = currentCtrl.text.trim();
            final next = newCtrl.text;
            if (current.isEmpty || next.isEmpty) {
              ScaffoldMessenger.of(rootContext).showSnackBar(
                const SnackBar(
                  content: Text('Please fill in both fields.'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            if (next.length < 6) {
              ScaffoldMessenger.of(rootContext).showSnackBar(
                const SnackBar(
                  content: Text('New password must be at least 6 characters.'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            setDialogState(() => isSubmitting = true);
            try {
              await rootContext
                  .read<AuthProvider>()
                  .changePassword(current, next);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (!rootContext.mounted) return;
              ScaffoldMessenger.of(rootContext).showSnackBar(
                const SnackBar(
                  content: Text('Password updated'),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (e) {
              if (!rootContext.mounted) return;
              setDialogState(() => isSubmitting = false);
              final msg = e.toString().toLowerCase();
              final friendly =
                  (msg.contains('incorrect') ||
                      msg.contains('invalid') ||
                      msg.contains('wrong') ||
                      msg.contains('400') ||
                      msg.contains('401'))
                  ? 'Current password is incorrect.'
                  : 'Could not update password. Please try again.';
              ScaffoldMessenger.of(rootContext).showSnackBar(
                SnackBar(
                  content: Text(friendly),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }

          return AlertDialog(
            title: const Text('Change Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentCtrl,
                  obscureText: true,
                  enabled: !isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newCtrl,
                  obscureText: true,
                  enabled: !isSubmitting,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
                onPressed: isSubmitting ? null : submit,
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Update',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// // ─── AI Insight Card ──────────────────────────────────────────────────────────
//
// class _AIInsightCard extends StatelessWidget {
//   const _AIInsightCard();
//
//   @override
//   Widget build(BuildContext context) {
//     final subProv = context.watch<SubscriptionProvider>();
//     final cs = Theme.of(context).colorScheme;
//     final studentPct = (subProv.usagePercent('student') * 100).toStringAsFixed(
//       0,
//     );
//     const secureScore = 85;
//
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         // secondary = _lightPrimary = Color(0xFF007291) — deep teal, good for a dark banner
//         color: cs.secondary,
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Stack(
//         children: [
//           Positioned(
//             right: -8,
//             bottom: -8,
//             child: Icon(
//               Icons.auto_awesome,
//               size: 64,
//               color: Colors.white.withValues(alpha: 0.08),
//             ),
//           ),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   const Icon(
//                     Icons.auto_awesome,
//                     color: Colors.white70,
//                     size: 16,
//                   ),
//                   const SizedBox(width: 8),
//                   Text(
//                     'AI SECURITY INSIGHT',
//                     style: TextStyle(
//                       color: Colors.white.withValues(alpha: 0.85),
//                       fontSize: 11,
//                       fontWeight: FontWeight.w700,
//                       letterSpacing: 1.2,
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 12),
//               Text(
//                 'Your profile is $secureScore% secure. '
//                 'Student capacity at $studentPct%. '
//                 'Complete your bio and verification to reach 100%.',
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 15,
//                   fontWeight: FontWeight.w500,
//                   height: 1.5,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

// ─── Shared Card Wrapper ──────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline),
      ),
      child: child,
    );
  }
}

// ─── Footer ───────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final bool isMobile;
  const _Footer({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: isMobile
          ? Column(
              children: const [
                _Copyright(),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _FooterLink(label: 'PRIVACY POLICY'),
                    SizedBox(width: 16),
                    _FooterLink(label: 'TERMS OF SERVICE'),
                  ],
                ),
              ],
            )
          : const Row(
              children: [
                _Copyright(),
                Spacer(),
                _FooterLink(label: 'PRIVACY POLICY'),
                SizedBox(width: 24),
                _FooterLink(label: 'TERMS OF SERVICE'),
              ],
            ),
    );
  }
}

class _Copyright extends StatelessWidget {
  const _Copyright();
  @override
  Widget build(BuildContext context) => Text(
    '© 2024 HTOOCHOON LMS. ALL RIGHTS RESERVED.',
    style: TextStyle(
      fontSize: 11,
      color: Theme.of(context).colorScheme.tertiary,
      letterSpacing: 0.5,
    ),
  );
}

class _FooterLink extends StatelessWidget {
  final String label;
  const _FooterLink({required this.label});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {},
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: Theme.of(context).colorScheme.tertiary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
  );
} //

/// Language picker: System default / English / Burmese / Thai.
void _showLanguagePicker(BuildContext context) {
  final provider = context.read<LocaleProvider>();
  final current = provider.locale?.languageCode;
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) {
      Widget tile(String? code, String label) => RadioListTile<String?>(
            value: code,
            groupValue: current,
            title: Text(label),
            onChanged: (v) {
              provider.setLocale(v == null ? null : Locale(v));
              Navigator.pop(sheetCtx);
            },
          );
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            tile(null, 'System default'),
            tile('en', LocaleProvider.labelFor('en')),
            tile('my', LocaleProvider.labelFor('my')),
            tile('th', LocaleProvider.labelFor('th')),
          ],
        ),
      );
    },
  );
}
