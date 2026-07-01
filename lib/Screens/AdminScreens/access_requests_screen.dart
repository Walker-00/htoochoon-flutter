import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:htoochoon_flutter/api/api_service.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';

/// 🙋 Org owner/admin view: pending self-service join requests. Approve → the
/// user becomes a member with the requested role; decline → dismissed.
class AccessRequestsScreen extends StatefulWidget {
  const AccessRequestsScreen({super.key, required this.organisationId});
  final String organisationId;

  @override
  State<AccessRequestsScreen> createState() => _AccessRequestsScreenState();
}

class _AccessRequestsScreenState extends State<AccessRequestsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _err;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final res = await context
          .read<ApiService>()
          .listOrgAccessRequests(widget.organisationId, 'PENDING');
      final list = (res as List?) ?? [];
      _items =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      _err = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(Map<String, dynamic> req, bool approve) async {
    final id = req['id']?.toString();
    if (id == null) return;
    setState(() => _busy.add(id));
    try {
      await context.read<ApiService>().decideAccessRequest(id, {
        'approve': approve,
      });
      if (!mounted) return;
      setState(() => _items.removeWhere((r) => r['id']?.toString() == id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve ? 'Approved ✅' : 'Declined'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Access requests')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _err != null
                ? ListView(children: [
                    const SizedBox(height: 120),
                    Center(child: Text('Could not load: $_err')),
                  ])
                : _items.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 140),
                        Icon(Icons.inbox_outlined,
                            size: 48, color: cs.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Center(
                          child: Text('No pending requests',
                              style: TextStyle(color: cs.onSurfaceVariant)),
                        ),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppTheme.spaceMd),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppTheme.spaceXs),
                        itemBuilder: (_, i) => _tile(_items[i], cs),
                      ),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> req, ColorScheme cs) {
    final user = (req['user'] is Map)
        ? Map<String, dynamic>.from(req['user'])
        : <String, dynamic>{};
    final name = user['name']?.toString() ?? 'Someone';
    final email = user['email']?.toString() ?? '';
    final role = (req['requestedRole']?.toString() ?? 'STUDENT').toLowerCase();
    final id = req['id']?.toString() ?? '';
    final busy = _busy.contains(id);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: cs.primary.withValues(alpha: 0.12),
                child: Text(name.characters.first.toUpperCase(),
                    style: TextStyle(color: cs.primary)),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (email.isNotEmpty)
                      Text(email,
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.getTextSecondary(context))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceSm, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text('wants: $role',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.primary)),
              ),
            ],
          ),
          if (req['message'] != null &&
              req['message'].toString().trim().isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceXs),
            Text(req['message'].toString(),
                style: TextStyle(color: AppTheme.getTextSecondary(context))),
          ],
          const SizedBox(height: AppTheme.spaceSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: busy ? null : () => _decide(req, false),
                child: const Text('Decline'),
              ),
              const SizedBox(width: AppTheme.spaceXs),
              FilledButton(
                onPressed: busy ? null : () => _decide(req, true),
                child: busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Approve'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
