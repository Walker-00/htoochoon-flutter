import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/live_sessions_provider.dart';
import 'package:htoochoon_flutter/models/api_models/live_session_model.dart';
import 'package:htoochoon_flutter/models/api_models/session_schedule_model.dart';

/// Ask which occurrences an edit/delete applies to. Returns null on cancel.
Future<EditScope?> showEditScopeSheet(BuildContext context,
    {required String verb}) {
  return showModalBottomSheet<EditScope>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.event),
            title: Text('$verb this session'),
            onTap: () => Navigator.pop(ctx, EditScope.single),
          ),
          ListTile(
            leading: const Icon(Icons.event_repeat),
            title: Text('$verb this and following'),
            onTap: () => Navigator.pop(ctx, EditScope.future),
          ),
          ListTile(
            leading: const Icon(Icons.all_inclusive),
            title: Text('$verb all in series'),
            onTap: () => Navigator.pop(ctx, EditScope.all),
          ),
        ],
      ),
    ),
  );
}

class SessionActionsMenu extends StatelessWidget {
  final LiveSession session;
  final String orgId;
  final String classId;
  const SessionActionsMenu({
    super.key,
    required this.session,
    required this.orgId,
    required this.classId,
  });

  Future<void> _refresh(LiveSessionProvider prov) => prov.fetchSessionsByStatus(
      orgId: orgId, classId: classId, targetStatus: 'SCHEDULED');

  @override
  Widget build(BuildContext context) {
    final prov = context.read<LiveSessionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (v) async {
        if (v == 'delete') {
          final scope = await showEditScopeSheet(context, verb: 'Delete');
          if (scope == null) return;
          final ok = await prov.deleteSessionScoped(session.id, scope);
          if (ok) await _refresh(prov);
          messenger.showSnackBar(SnackBar(
            content: Text(ok ? 'Deleted.' : (prov.error ?? 'Delete failed')),
          ));
        } else if (v == 'reschedule') {
          final picked = await showDatePicker(
            context: context,
            initialDate: session.startTime.toLocal(),
            firstDate: DateTime.now(),
            lastDate: DateTime(2100),
          );
          if (picked == null) return;
          if (!context.mounted) return;
          final t = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(session.startTime.toLocal()),
          );
          if (t == null) return;
          final newStart =
              DateTime(picked.year, picked.month, picked.day, t.hour, t.minute);
          if (!context.mounted) return;
          final scope = await showEditScopeSheet(context, verb: 'Reschedule');
          if (scope == null) return;
          final ok = await prov.updateSession(session.id, scope,
              startTimeIso: newStart.toUtc().toIso8601String());
          if (ok) await _refresh(prov);
          messenger.showSnackBar(SnackBar(
            content:
                Text(ok ? 'Rescheduled.' : (prov.error ?? 'Update failed')),
          ));
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'reschedule', child: Text('Reschedule')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }
}
