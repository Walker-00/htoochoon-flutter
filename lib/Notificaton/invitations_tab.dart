import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/invitation_provider.dart';
import 'package:provider/provider.dart';

class InvitationsTab extends StatefulWidget {
  const InvitationsTab({Key? key}) : super(key: key);

  @override
  State<InvitationsTab> createState() => _InvitationsTabState();
}

class _InvitationsTabState extends State<InvitationsTab>
    with SingleTickerProviderStateMixin {
  // Re-runs the provider's load (its only reload entry-point takes a vsync +
  // email) so pull-to-refresh pulls the latest invitations from the backend.
  Future<void> _refresh() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;
    context.read<InvitationProvider>().init(vsync: this, email: email);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InvitationProvider>(
      builder: (context, provider, child) {
        return RefreshIndicator(
          onRefresh: _refresh,
          child: provider.invitations.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text("No pending invitations")),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: provider.invitations.length,
                  itemBuilder: (context, index) {
                    logD(provider.invitations.length);
                    return InvitationTile(
                      inviteData: provider.invitations[index],
                    );
                  },
                ),
        );
      },
    );
  }
}

class InvitationTile extends StatefulWidget {
  final Map<String, dynamic> inviteData;

  const InvitationTile({Key? key, required this.inviteData}) : super(key: key);

  @override
  State<InvitationTile> createState() => _InvitationTileState();
}

class _InvitationTileState extends State<InvitationTile> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.inviteData;
    final user = FirebaseAuth.instance.currentUser!;

    return Card(
      child: ListTile(
        title: Text(data['title'] ?? 'Invitation'),
        subtitle: Text(data['body'] ?? ''),
        trailing: _isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : ElevatedButton(
                onPressed: () async {
                  setState(() => _isProcessing = true);

                  try {
                    await context.read<InvitationProvider>().acceptInvitation(
                      orgId: data['orgId'],
                      inviteId: data['id'] ?? '',
                      userId: user.uid,
                      email: user.email!,
                    );
                  } catch (e) {
                    setState(() => _isProcessing = false);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Failed to accept invitation"),
                      ),
                    );
                  }
                },
                child: const Text("Accept"),
              ),
      ),
    );
  }
}
