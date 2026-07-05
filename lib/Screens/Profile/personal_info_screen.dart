import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/auth_provider.dart';
import 'package:htoochoon_flutter/utils/avatar_util.dart';
import 'package:provider/provider.dart';

/// Dedicated screen for editing personal information: avatar, full name
/// (editable) and email (read-only display).
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;
  bool _seeded = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Please enter your name.', error: true);
      return;
    }
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await auth.updateUser(user.id, {'name': name});
      if (!mounted) return;
      _snack('Profile updated');
    } catch (_) {
      if (!mounted) return;
      _snack('Could not update profile. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = context.watch<AuthProvider>().user;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }
    if (!_seeded) {
      _nameCtrl.text = user.name;
      _seeded = true;
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('Personal information')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Center(
                  child: Column(
                    children: [
                      const EditableAvatar(size: 96),
                      const SizedBox(height: 10),
                      Text(
                        'Tap the photo to change it',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                _Label('FULL NAME'),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(fontSize: 14),
                  decoration: _fieldDecoration(cs, hint: 'Your full name'),
                ),
                const SizedBox(height: 20),

                _Label('EMAIL ADDRESS'),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outline),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.email_outlined,
                          size: 18, color: cs.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          user.email,
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurface.withValues(alpha: 0.8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.lock_outline,
                          size: 15, color: cs.onSurface.withValues(alpha: 0.4)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Email cannot be changed here.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      minimumSize: const Size.fromHeight(46),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save changes',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(ColorScheme cs, {String? hint}) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      filled: true,
      fillColor: cs.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: cs.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: cs.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Theme.of(context).colorScheme.tertiary,
      ),
    );
  }
}
