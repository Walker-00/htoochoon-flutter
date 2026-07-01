import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';

import 'notes_page.dart';

/// Root app for the **detached notes OS window** (desktop only). Notes are
/// LOCAL — no socket, no sync — so unlike the whiteboard window this just needs
/// SharedPreferences (already initialised in `main()`). Launched from `main()`
/// when args are `multi_window` with `windowType == 'notes'`.
class NotesWindowApp extends StatelessWidget {
  final WindowController windowController;
  final Map<String, dynamic> args;

  const NotesWindowApp({
    super.key,
    required this.windowController,
    required this.args,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: NotesPage(
        sessionId: (args['sessionId'] ?? '').toString(),
        userId: (args['userId'] ?? '').toString(),
        orgName: (args['orgName'] ?? '').toString(),
        programName: (args['programName'] ?? '').toString(),
        // Self-close = hide (same rationale as the whiteboard window: tearing
        // down a sub-window engine on Linux can take the whole process down).
        onClose: () {
          try {
            windowController.hide();
          } catch (_) {}
        },
      ),
    );
  }
}
