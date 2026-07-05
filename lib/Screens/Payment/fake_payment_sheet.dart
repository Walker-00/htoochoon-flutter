import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';
import 'package:htoochoon_flutter/models/api_models/program_model.dart';

/// 💳 FAKE payment flow (no real gateway yet). Shows the org's receiving
/// mobile-money account and the amount, then a "Simulate payment" button.
///
/// Returns `true` when the user completes the (fake) payment, `false`/`null`
/// if they cancel. Free programs should skip this entirely.
Future<bool?> showFakePaymentSheet(
  BuildContext context, {
  required ProgramResponse program,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _FakePaymentSheet(program: program),
  );
}

class _FakePaymentSheet extends StatefulWidget {
  final ProgramResponse program;
  const _FakePaymentSheet({required this.program});

  @override
  State<_FakePaymentSheet> createState() => _FakePaymentSheetState();
}

class _FakePaymentSheetState extends State<_FakePaymentSheet> {
  bool _paying = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final secondary = AppTheme.getTextSecondary(context);
    final org = widget.program.organization;
    final provider = org?.paymentProvider;
    final phone = org?.paymentPhone;
    final payee = org?.paymentAccountName ?? org?.name;

    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.spaceLg,
        right: AppTheme.spaceLg,
        top: AppTheme.spaceMd,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spaceLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: secondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),
          Row(
            children: [
              Icon(Icons.payments_rounded, color: cs.primary),
              const SizedBox(width: 8),
              const Text('Complete payment',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Enrolling in ${widget.program.name}',
              style: TextStyle(fontSize: 13, color: secondary)),
          const SizedBox(height: AppTheme.spaceLg),

          // Amount
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: AppTheme.borderRadiusMd,
            ),
            child: Column(
              children: [
                Text('Amount due', style: TextStyle(color: secondary)),
                const SizedBox(height: 4),
                Text(
                  widget.program.priceLabel,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: cs.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),

          // Pay-to account
          Text('Pay to',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: secondary)),
          const SizedBox(height: 6),
          _row(Icons.account_balance_wallet_rounded,
              provider ?? 'Mobile money', secondary),
          if (phone != null && phone.isNotEmpty)
            _row(Icons.phone_rounded, phone, secondary),
          if (payee != null && payee.isNotEmpty)
            _row(Icons.badge_rounded, payee, secondary),
          if (provider == null && phone == null)
            Text(
              'The organization has not set a payment account yet. This is a demo checkout.',
              style: TextStyle(fontSize: 12, color: secondary),
            ),

          const SizedBox(height: AppTheme.spaceMd),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: AppTheme.borderRadiusSm,
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Demo payment — no real charge is made.',
                    style: TextStyle(fontSize: 11, color: secondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _paying
                  ? null
                  : () async {
                      setState(() => _paying = true);
                      // Simulate a gateway round-trip.
                      await Future.delayed(const Duration(milliseconds: 900));
                      if (!context.mounted) return;
                      Navigator.pop(context, true);
                    },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
              ),
              child: _paying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Pay ${widget.program.priceLabel}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed:
                  _paying ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text, Color secondary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
