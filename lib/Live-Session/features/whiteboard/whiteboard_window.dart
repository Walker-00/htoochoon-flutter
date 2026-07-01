import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Live-Session/core/services/socket_service.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';

import 'whiteboard_page.dart';

/// Root app for the **detached whiteboard OS window** (desktop only).
///
/// This runs in its own Flutter engine, separate from the main app + meeting
/// window, so it cannot share the parent's socket object. Instead it opens its
/// OWN socket connection to the same room (the singleton [SocketService] + the
/// shared SharedPreferences token mean it authenticates as the same user) and
/// joins the same `whiteboard:*` room, so strokes sync across windows exactly
/// like any other participant.
///
/// Launched from `main()` when args start with `multi_window`.
class WhiteboardWindowApp extends StatelessWidget {
  final WindowController windowController;
  final Map<String, dynamic> args;

  const WhiteboardWindowApp({
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
      home: _WhiteboardBoot(
        windowController: windowController,
        args: args,
      ),
    );
  }
}

class _WhiteboardBoot extends StatefulWidget {
  final WindowController windowController;
  final Map<String, dynamic> args;
  const _WhiteboardBoot({required this.windowController, required this.args});

  @override
  State<_WhiteboardBoot> createState() => _WhiteboardBootState();
}

class _WhiteboardBootState extends State<_WhiteboardBoot> {
  final SocketService _socket = SocketService();
  bool _connecting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      final ok = await _socket.connect();
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = ok ? null : 'Could not connect to the session.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = '$e';
      });
    }
  }

  // Self-close = HIDE only. We never destroy this window from inside its own
  // engine: on Linux tearing down the sub-window engine can take the whole
  // process (and the meeting) down with it. Hiding keeps the engine + socket
  // alive, so closing the board never affects the main app. The real destroy
  // happens from the MAIN side (meeting dispose -> WindowController.close), or
  // when the OS process exits. Reopening from the meeting just re-shows this
  // same window with its board intact.
  void _closeWindow() {
    try {
      widget.windowController.hide();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_connecting) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 44),
              const SizedBox(height: 10),
              Text(_error!),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  setState(() => _connecting = true);
                  _connect();
                },
                child: const Text('Retry'),
              ),
              TextButton(onPressed: _closeWindow, child: const Text('Close')),
            ],
          ),
        ),
      );
    }

    return WhiteboardPage(
      roomId: (widget.args['roomId'] ?? '').toString(),
      userId: (widget.args['userId'] ?? '').toString(),
      role: (widget.args['role'] ?? 'teacher').toString(),
      socketService: _socket,
      initialStudentsCanDraw: widget.args['studentsCanDraw'] == true,
      liveSync: widget.args['liveSync'] != false,
      showSetupOnStart: false,
      onClose: _closeWindow,
    );
  }
}
