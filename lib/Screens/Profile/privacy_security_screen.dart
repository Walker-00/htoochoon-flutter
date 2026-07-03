import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/auth_provider.dart';
import 'package:htoochoon_flutter/Providers/locale_provider.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';
import 'package:provider/provider.dart';

/// Dedicated screen for account security & privacy:
///   • Change password (wired to AuthProvider.changePassword)
///   • Language (LocaleProvider)
///   • Two-factor authentication status
class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locale = context.watch<LocaleProvider>();
    final user = context.watch<AuthProvider>().user;
    final twoFaOn = user?.isTwoFactorEnabled ?? false;

    final currentLangCode = locale.locale?.languageCode;
    final currentLangLabel = currentLangCode == null
        ? 'System default'
        : LocaleProvider.labelFor(currentLangCode);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('Privacy & security')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel(cs, 'ACCOUNT'),
                const SizedBox(height: 10),
                _Tile(
                  icon: Icons.lock_outline,
                  title: 'Change password',
                  subtitle: 'Update your account password',
                  onTap: () => _showChangePassword(context),
                ),
                const SizedBox(height: 12),
                _Tile(
                  icon: Icons.translate,
                  title: 'Language',
                  subtitle: currentLangLabel,
                  onTap: () => _showLanguagePicker(context),
                ),
                const SizedBox(height: 24),

                _sectionLabel(cs, 'SECURITY'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.verified_user_outlined,
                              size: 18, color: cs.onSurface),
                          const SizedBox(width: 8),
                          Text(
                            'Two-factor authentication',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: twoFaOn ? AppTheme.success : cs.outline,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              twoFaOn ? 'Enabled' : 'Disabled',
                              style: const TextStyle(
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
                        'Two-factor authentication adds an extra layer of '
                        'security to your account.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(ColorScheme cs, String text) => Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: cs.tertiary,
        ),
      );

  // ── Change password (wired to AuthProvider.changePassword) ─────────────────
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
              final friendly = (msg.contains('incorrect') ||
                      msg.contains('invalid') ||
                      msg.contains('wrong') ||
                      msg.contains('400') ||
                      msg.contains('401'))
                  ? 'Current password is incorrect.'
                  : 'Could not update password. Please try again.';
              ScaffoldMessenger.of(rootContext).showSnackBar(
                SnackBar(content: Text(friendly), backgroundColor: Colors.red),
              );
            }
          }

          return AlertDialog(
            title: const Text('Change password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentCtrl,
                  obscureText: true,
                  enabled: !isSubmitting,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                    labelText: 'Current password',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newCtrl,
                  obscureText: true,
                  enabled: !isSubmitting,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                    labelText: 'New password',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed:
                    isSubmitting ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 11),
                ),
                onPressed: isSubmitting ? null : submit,
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Update',
                        style: TextStyle(color: Colors.white, fontSize: 14)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Language picker (System default / English / Burmese / Thai) ────────────
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
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Tile({
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
            Icon(icon, size: 19, color: cs.onSurface.withValues(alpha: 0.7)),
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
