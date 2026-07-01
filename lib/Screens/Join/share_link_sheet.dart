import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:htoochoon_flutter/api/api_service.dart';

/// Admin/teacher flow: configure + generate a shareable join link, then share
/// its URL. `type` is one of ORG / PROGRAM / LIVE_SESSION.
Future<void> showShareLinkSheet(
  BuildContext context, {
  required String type,
  required String targetId,
  required String organizationId,
  String targetName = '',
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ShareLinkSheet(
      type: type,
      targetId: targetId,
      organizationId: organizationId,
      targetName: targetName,
    ),
  );
}

class _ShareLinkSheet extends StatefulWidget {
  final String type;
  final String targetId;
  final String organizationId;
  final String targetName;
  const _ShareLinkSheet({
    required this.type,
    required this.targetId,
    required this.organizationId,
    required this.targetName,
  });

  @override
  State<_ShareLinkSheet> createState() => _ShareLinkSheetState();
}

class _ShareLinkSheetState extends State<_ShareLinkSheet> {
  bool _unlimited = true;
  bool _requireApproval = false;
  final _limitCtrl = TextEditingController(text: '10');
  bool _creating = false;

  @override
  void dispose() {
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      final body = <String, dynamic>{
        'type': widget.type,
        'targetId': widget.targetId,
        'organizationId': widget.organizationId,
        'approvalMode': _requireApproval ? 'APPROVAL' : 'IMMEDIATE',
        if (!_unlimited)
          'maxUses': int.tryParse(_limitCtrl.text.trim()) ?? 1,
      };
      final res = await context.read<ApiService>().createJoinLink(body);
      final map = Map<String, dynamic>.from(res as Map);
      final url = map['url']?.toString() ?? '';
      if (!mounted) return;
      Navigator.pop(context);
      await Share.share(
        'Join ${widget.targetName.isEmpty ? 'us' : widget.targetName} on HtooChoon:\n$url',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create link: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share invite link',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Anyone with the link can join.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Unlimited access'),
              subtitle: const Text('Off = cap the number of people'),
              value: _unlimited,
              onChanged: (v) => setState(() => _unlimited = v),
            ),
            if (!_unlimited)
              TextField(
                controller: _limitCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max people',
                  border: OutlineInputBorder(),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Require approval'),
              subtitle: const Text(
                  'On = requests land in the enrollment tab. Off = join instantly'),
              value: _requireApproval,
              onChanged: (v) => setState(() => _requireApproval = v),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _creating ? null : _create,
                icon: _creating
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.share),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('Create & share link'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
