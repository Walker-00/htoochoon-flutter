import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/invitation_provider.dart';
import 'package:provider/provider.dart';

class AnnouncementsTab extends StatelessWidget {
  const AnnouncementsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvitationProvider>();

    if (provider.announcements.isEmpty) {
      return const Center(child: Text('No announcements'));
    }

    return ListView.builder(
      itemCount: provider.announcements.length,
      itemBuilder: (context, index) {
        final data = provider.announcements[index];

        return ListTile(
          title: Text(data['title'] ?? ''),
          subtitle: Text(data['message'] ?? ''),
        );
      },
    );
  }
}
