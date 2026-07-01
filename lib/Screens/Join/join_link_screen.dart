import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:htoochoon_flutter/api/api_service.dart';

/// Landing screen when a user opens a `…/join/<token>` deep link. Shows a
/// preview of what they're joining, then redeems on confirmation.
class JoinLinkScreen extends StatefulWidget {
  final String token;
  const JoinLinkScreen({super.key, required this.token});

  @override
  State<JoinLinkScreen> createState() => _JoinLinkScreenState();
}

class _JoinLinkScreenState extends State<JoinLinkScreen> {
  Map<String, dynamic>? _preview;
  bool _loading = true;
  bool _joining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res =
          await context.read<ApiService>().getJoinLinkPreview(widget.token);
      if (!mounted) return;
      setState(() {
        _preview = Map<String, dynamic>.from(res as Map);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load this invite.';
        _loading = false;
      });
    }
  }

  Future<void> _join() async {
    setState(() => _joining = true);
    try {
      final res =
          await context.read<ApiService>().redeemJoinLink(widget.token);
      final map = Map<String, dynamic>.from(res as Map);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(map['message']?.toString() ?? 'Done')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not join: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Invitation')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildPreview(cs),
    );
  }

  Widget _buildPreview(ColorScheme cs) {
    final p = _preview!;
    final valid = p['valid'] == true;
    final requiresApproval = p['requiresApproval'] == true;
    final type = (p['type'] ?? '').toString();
    final targetName = (p['targetName'] ?? 'this').toString();
    final orgName = (p['organizationName'] ?? '').toString();

    final typeLabel = switch (type) {
      'ORG' => 'organization',
      'PROGRAM' => 'program',
      'LIVE_SESSION' => 'live session',
      _ => 'resource',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_add_outlined, size: 64, color: cs.primary),
            const SizedBox(height: 20),
            Text(
              'Join $typeLabel',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              targetName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            if (orgName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(orgName, style: TextStyle(color: cs.onSurfaceVariant)),
            ],
            const SizedBox(height: 16),
            if (!valid)
              Text(
                p['revoked'] == true
                    ? 'This invite has been revoked.'
                    : p['expired'] == true
                        ? 'This invite has expired.'
                        : 'This invite has reached its limit.',
                style: TextStyle(color: cs.error),
              )
            else if (requiresApproval)
              Text(
                'Your request will be sent for approval.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (!valid || _joining) ? null : _join,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _joining
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(requiresApproval ? 'Request to join' : 'Join'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
