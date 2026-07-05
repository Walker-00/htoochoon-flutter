import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/auth_provider.dart';
import 'package:provider/provider.dart';

/// 💳 Student payment account — the mobile-money number/provider they pay
/// enrollment fees FROM. Fake payment flow for now (no real gateway).
class PaymentAccountScreen extends StatefulWidget {
  const PaymentAccountScreen({super.key});

  @override
  State<PaymentAccountScreen> createState() => _PaymentAccountScreenState();
}

class _PaymentAccountScreenState extends State<PaymentAccountScreen> {
  final _phoneCtrl = TextEditingController();
  String? _provider;
  bool _saving = false;
  bool _seeded = false;

  static const _providers = ['KBZPay', 'WavePay', 'AYAPay', 'CBPay', 'Other'];

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await auth.updateUser(user.id, {
        'paymentPhone': _phoneCtrl.text.trim(),
        'paymentProvider': _provider ?? '',
      });
      if (!mounted) return;
      _snack('Payment account saved');
    } catch (_) {
      if (!mounted) return;
      _snack('Could not save. Please try again.', error: true);
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
      _phoneCtrl.text = user.paymentPhone ?? '';
      _provider = (user.paymentProvider != null &&
              _providers.contains(user.paymentProvider))
          ? user.paymentProvider
          : (user.paymentProvider != null && user.paymentProvider!.isNotEmpty
              ? 'Other'
              : null);
      _seeded = true;
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('Payment account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'The mobile-money account you use to pay for paid '
                          'programs. Used at checkout (demo payment for now).',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSurface.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _Label('PROVIDER'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _provider,
                  isExpanded: true,
                  decoration: _fieldDecoration(cs, hint: 'Choose provider'),
                  items: _providers
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setState(() => _provider = v),
                ),
                const SizedBox(height: 20),

                _Label('PAYMENT PHONE'),
                const SizedBox(height: 6),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 14),
                  decoration:
                      _fieldDecoration(cs, hint: 'e.g. 09xxxxxxxxx'),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      minimumSize: const Size.fromHeight(46),
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
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save changes',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
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
