import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/organisation_provider.dart';
import 'package:htoochoon_flutter/Screens/AdminScreens/resource_usage_section.dart';
import 'package:htoochoon_flutter/Screens/Onboarding/org_loader_screen.dart';
import 'package:htoochoon_flutter/Widgets/responsive.dart';
import 'package:htoochoon_flutter/models/api_models/organization_model.dart';
import 'package:htoochoon_flutter/models/api_models/subscription_model.dart';
import 'package:provider/provider.dart';

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class SettingsScreen extends StatefulWidget {
  final String organisationId;
  final VoidCallback onQuitOrganisation;
  final bool isInShell;

  const SettingsScreen({
    super.key,
    required this.organisationId,
    required this.onQuitOrganisation,
    this.isInShell = false,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _edited = false;
  File? _pickedImage; // 🖼️ Tracks local picked image state
  String? _currentLogoUrl; // Tracks the background cached image path string

  // 🎯 1. Inside your _SettingsScreenState lifecycle hooks, parse the full domain asset target string:
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prov = context.read<OrganizationProvider>();
      await prov.fetchOrganisation(widget.organisationId);
      final org = prov.organisation;
      if (org != null) {
        _nameCtrl.text = org.name;
        _emailCtrl.text = org.email;
        _descCtrl.text = org.description ?? '';

        // 🛠️ COMBINE BASE DOMAIN + LOGO PATH URL
        if (org.logoUrl != null && org.logoUrl!.isNotEmpty) {
          _currentLogoUrl = "https://backend.htoochoon.com${org.logoUrl}";
        }
        setState(() {});
      }
    });
  }

  // 🎯 2. Update your picker action frame to execute the network upload instantly on item selection:
  Future<void> _pickLogo(OrganizationProvider prov) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      setState(() => _pickedImage = file);

      // 🚀 EXECUTE THE BACKEND MUTATION INSTANTLY
      final success = await prov.uploadLogo(widget.organisationId, file);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Logo updated successfully!' : 'Failed to save logo.',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );

        // Sync local display paths back to database states after completion frames finish
        if (success && prov.organisation?.logoUrl != null) {
          setState(() {
            _currentLogoUrl =
                "https://backend.htoochoon.com${prov.organisation!.logoUrl}";
            _pickedImage =
                null; // Clear local picker view fallback once server is synced
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Consumer<OrganizationProvider>(
        builder: (_, prov, __) => CustomScrollView(
          slivers: [
            SliverAppBar(
              automaticallyImplyLeading: !widget.isInShell,
              backgroundColor: cs.surface,
              foregroundColor: cs.onSurface,
              surfaceTintColor: Colors.transparent,
              pinned: true,
              title: Text(
                'Settings',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
            if (prov.isLoading)
              const SliverToBoxAdapter(child: LinearProgressIndicator()),

            SliverPadding(
              padding: centeredPagePadding(context, max: kFormMaxWidth),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Organisation info section ─────────
                  _SectionHeader(label: 'Organisation Details'),
                  const SizedBox(height: 12),

                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: prov.isUploadingLogo
                              ? const Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : _pickedImage != null
                              ? Image.file(_pickedImage!, fit: BoxFit.cover)
                              : (_currentLogoUrl != null &&
                                    _currentLogoUrl!.isNotEmpty)
                              ? Image.network(
                                  _currentLogoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.business_rounded,
                                    size: 40,
                                    color: cs.primary,
                                  ),
                                )
                              : Icon(
                                  Icons.business_rounded,
                                  size: 40,
                                  color: cs.primary,
                                ),
                        ),
                        if (!prov.isUploadingLogo)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _pickLogo(
                                prov,
                              ), // Passes provider instance cleanly
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: cs.primary,
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  _SettingsCard(
                    child: Column(
                      children: [
                        _Field(
                          controller: _nameCtrl,
                          label: 'Name',
                          icon: Icons.business_rounded,
                          onChanged: (_) => setState(() => _edited = true),
                        ),
                        const Divider(height: 1),
                        _Field(
                          controller: _emailCtrl,
                          label: 'Email',
                          icon: Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) => setState(() => _edited = true),
                        ),
                        const Divider(height: 1),
                        _Field(
                          controller: _descCtrl,
                          label: 'Description',
                          icon: Icons.notes_rounded,
                          maxLines: 3,
                          onChanged: (_) => setState(() => _edited = true),
                        ),
                      ],
                    ),
                  ),

                  if (_edited) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: prov.isLoading
                            ? null
                            : () => _saveChanges(context, prov),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: prov.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save Changes'),
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // ── Resource usage (moved here from the home Overview) ──
                  _SectionHeader(label: 'Resource Usage'),
                  const SizedBox(height: 12),
                  ResourceUsageSection(orgId: widget.organisationId),

                  const SizedBox(height: 28),

                  // ── Account ────────────────────────
                  _SectionHeader(label: 'Account'),
                  const SizedBox(height: 12),

                  _SettingsCard(
                    child: ListTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.swap_horiz_rounded,
                          color: cs.primary,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Switch Organisation',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Go back to your profile to switch',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _confirmQuit(context),
                    ),
                  ),

                  const SizedBox(height: 12),

                  _SectionHeader(label: 'Danger Zone', isDanger: true),
                  const SizedBox(height: 12),

                  _SettingsCard(
                    child: ListTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.exit_to_app_rounded,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Quit Organisation',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Return to user profile view',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.red,
                      ),
                      onTap: () => _confirmQuit(context),
                    ),
                  ),

                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveChanges(
    BuildContext context,
    OrganizationProvider prov,
  ) async {
    // Note: If you want to upload the multi-part file logo image, you can pass `_pickedImage`
    // to your provider handling method layer here.
    await prov.updateOrganisation(
      widget.organisationId,
      OrganizationRequest(
        name: _nameCtrl.text,
        email: _emailCtrl.text,
        description: _descCtrl.text.isNotEmpty ? _descCtrl.text : null,
        // logoFile: _pickedImage, // Pass down to handle MultiPart API calls if supported
      ),
    );

    setState(() => _edited = false);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Organisation updated')));
    }
  }

  // _confirmQuit content goes here...
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
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quit'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final navigator = Navigator.of(context);
      await OrgLoaderScreen.show(
        context,
        action: () async {
          await Future.delayed(const Duration(milliseconds: 500));
          widget.onQuitOrganisation();
        },
      );
      if (navigator.canPop()) {
        navigator.pop();
      }
    }
  }
}
// ── Widgets ──────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool isDanger;

  const _SectionHeader({required this.label, this.isDanger = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: isDanger
            ? Colors.red
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Icon(icon, size: 18, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              onChanged: onChanged,
              decoration: InputDecoration(
                labelText: label,
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageStatCard extends StatelessWidget {
  final UsageCheckResponse usage;

  const _UsageStatCard({required this.usage});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = usage.max > 0 ? usage.current / usage.max : 0.0;

    return _SettingsCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  usage.reason,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${usage.current} / ${usage.max}',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: cs.outline.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(
                  pct > 0.85 ? Colors.red : cs.primary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              usage.allowed ? 'Within limit' : 'Limit reached',
              style: TextStyle(
                fontSize: 12,
                color: usage.allowed ? Colors.green : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
