import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'dart:async';
import 'dart:convert';

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:ui' show ImageFilter, FontFeature;
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/live_sessions_provider.dart';
import 'package:htoochoon_flutter/models/api_models/live_session_model.dart';
import 'package:mediasfu_mediasoup_client/mediasfu_mediasoup_client.dart';
import 'package:htoochoon_flutter/Live-Session/core/services/mediasoup_service.dart';
import 'package:htoochoon_flutter/Live-Session/core/services/screen_service.dart';
import 'package:htoochoon_flutter/Live-Session/core/services/socket_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:htoochoon_flutter/Live-Session/features/meeting/widgets/full_screen_meeting_view.dart';
import 'package:htoochoon_flutter/Live-Session/features/meeting/widgets/hand_raise_indicator.dart';
import 'package:htoochoon_flutter/Live-Session/features/meeting/widgets/meeting_chat_overlay.dart';
import 'package:htoochoon_flutter/Live-Session/features/meeting/widgets/screen_share_banner.dart';
import 'package:htoochoon_flutter/Live-Session/features/meeting/widgets/reaction_overlay.dart';
import 'package:htoochoon_flutter/Live-Session/features/whiteboard/whiteboard_page.dart';
import 'package:htoochoon_flutter/Live-Session/features/notes/notes_page.dart';
import 'package:htoochoon_flutter/Live-Session/features/recording/recording_service.dart';
import 'package:htoochoon_flutter/Live-Session/features/meeting/widgets/video_grid.dart';
import 'package:htoochoon_flutter/Live-Session/features/meeting/waiting_room_view.dart';
import 'package:htoochoon_flutter/Live-Session/models/user_model.dart';
import 'package:provider/provider.dart';
import 'package:htoochoon_flutter/Providers/insights_provider.dart';

class MeetingPage extends StatefulWidget {
  final String sessionId;
  final String roomId;
  final String role;
  final String userName;
  final SocketService socketService;
  final String accessToken;
  final String refreshToken;
  final bool isLocal;

  const MeetingPage({
    super.key,
    required this.sessionId,
    required this.roomId,
    required this.role,
    required this.userName,
    required this.socketService,
    required this.accessToken,
    required this.refreshToken,
    required this.isLocal,
  });
  @override
  State<MeetingPage> createState() => _MeetingPageState();
}

class RemoteParticipant {
  final String userId;
  final String userName;
  final String producerId;
  final bool isScreen;

  final RTCVideoRenderer? renderer; // video only
  final MediaStream? audioStream; // optional audio reference

  RemoteParticipant({
    required this.userId,
    required this.userName,
    required this.producerId,
    this.isScreen = false,
    this.renderer,
    this.audioStream,
  });
}

class _MeetingPageState extends State<MeetingPage> with WidgetsBindingObserver {
  late final MediasoupService _ms;
  // 👁️ Attention tracking. Students emit; teachers collect reports.
  Timer? _attnTimer;
  bool _appFocused = true;
  // Elapsed meeting time shown in the live chip.
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;
  // Right-side chat panel (replaces the old floating chat bubble).
  bool _chatOpen = false;
  int _chatUnread = 0;

  // Host (teacher/admin) controls — Zoom/Meet-style. The whiteboard is a single
  // shared board for everyone; the host decides whether students may OPEN it and
  // whether their default mode is view or edit. Broadcast to the room via the
  // existing meeting:action relay (see _onMeetingActionBroadcast).
  bool _hostPanelOpen = false;
  bool _studentsCanOpenWhiteboard = false;
  bool _studentsCanDrawWhiteboard = false; // false = view, true = edit
  bool get _isHost =>
      widget.role == 'teacher' || widget.role == 'admin' || widget.role == 'staff';
  final Map<String, Map<String, dynamic>> _attentionReports = {};
  final Map<String, RemoteParticipant> _remoteParticipants = {};
  List _initialProducers = [];
  bool _isScreenSharing = false;
  // Detached whiteboard OS window (desktop). Tracked so it auto-closes when the
  // meeting ends / this page is disposed.
  WindowController? _whiteboardWindow;
  // Detached personal-notes OS window (desktop). Local-only, all roles.
  WindowController? _notesWindow;
  final Set<String> _activeConsumers = {};
  final Map<String, bool> _videoEnabledMap = {};
  final Map<String, bool> _audioEnabledMap = {};
  String? _myTrustedUserId;
  final ScreenService _screenService = ScreenService();
  bool _isRecording = false;
  // Pausable local recorder (native pause on Android, plugin fallback elsewhere).
  late final RecordingService _recorder = RecordingService(_screenService);

  final Set<String> _handRaisedUsers = {};
  Timer? _handLowerTimer; // auto-lowers our own raised hand after 30s
  String? _screenSharerId;
  String? _fullscreenUserId;

  bool _micOn = true;
  bool _cameraOn = true;
  bool _isInitializing = false;

  // Meeting reactions (emoji rain) + host controls.
  final ReactionController _reactions = ReactionController();
  bool _showReactionBar = false;
  bool _meetingLocked = false;
  String? _spotlightUserId;
  late void Function(dynamic) _onNewProducer;
  late void Function(dynamic) _onParticipantLeft;
  late void Function(dynamic) _onScreenShareStopped;
  late void Function(dynamic) _onMediaStateChanged;
  late void Function(dynamic) _onScreenShareStarted;

  bool _meetingStarted = false;
  bool _waitingForHost = false;
  //NEW Variable for session details
  LiveSession? _sessionDetails;

  Producer? _videoProducer;

  Producer? get videoProducer => _videoProducer;
  @override
  void initState() {
    super.initState();
    _ms = MediasoupService(widget.socketService);

    // 👁️ Attention tracking lifecycle.
    WidgetsBinding.instance.addObserver(this);
    if (widget.role == 'student') {
      _attnTimer =
          Timer.periodic(const Duration(seconds: 15), (_) => _emitAttention());
    } else {
      widget.socketService.socket.on('live:attention:report', _onAttentionReport);
    }

    _ms.onRemoteConsumerReady = _onRemoteConsumerReady;
    _ms.onRemoteConsumerClosed = _onRemoteConsumerClosed;

    // Phase 3: waiting-room / host-presence. Registered before join so parked
    // students still receive 'host:joined'.
    widget.socketService.socket.on('host:joined', (_) {
      if (!mounted) return;
      if (_waitingForHost) {
        setState(() => _waitingForHost = false);
        _meetingStarted = false;
        _isInitializing = false;
        _initMeeting();
      }
    });
    widget.socketService.socket.on('host:left', (_) {
      if (!mounted || widget.role == 'teacher') return;
      setState(() => _waitingForHost = true);
    });

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
    });

    _initMeeting();
    //NEW METHOD
    _loadSessionMetadata();
  }

  String get _elapsedLabel {
    final h = _elapsed.inHours;
    final m = _elapsed.inMinutes % 60;
    final s = _elapsed.inSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  //NEW DETAIL DIALOGS
  Future<void> _loadSessionMetadata() async {
    final provider = context.read<LiveSessionProvider>();
    final details = await provider.fetchSessionDetail(widget.sessionId);
    if (mounted && details != null) {
      setState(() {
        _sessionDetails = details;
      });
    }
  }

  // Zoom-style bottom sheet layout panel overlay
  void _showMeetingDetailsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[950],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final localStyle = TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontSize: 13,
        );
        final valueStyle = TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        );

        final startTimeStr =
            _sessionDetails?.startTime.toLocal().toString().substring(0, 16) ??
            '---';
        final endTimeStr =
            _sessionDetails?.endTime.toLocal().toString().substring(0, 16) ??
            '---';

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _sessionDetails?.topic ?? widget.roomId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "Connected",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.background,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: Colors.white10),

              _detailRow(
                "Host Name",
                _sessionDetails?.host?.name ?? 'Teacher',
                localStyle,
                valueStyle,
              ),
              _detailRow(
                "Room ID",
                widget.roomId,
                localStyle,
                valueStyle,
                isCopyable: true,
              ),
              _detailRow("Start Time", startTimeStr, localStyle, valueStyle),
              _detailRow("End Time", endTimeStr, localStyle, valueStyle),
              _detailRow(
                "Class",
                _sessionDetails?.liveClass?.name ?? 'General Room',
                localStyle,
                valueStyle,
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(
    String label,
    String value,
    TextStyle labelStyle,
    TextStyle valStyle, {
    bool isCopyable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: labelStyle)),
          Expanded(
            child: Row(
              children: [
                Expanded(child: Text(value, style: valStyle)),
                if (isCopyable)
                  IconButton(
                    icon: const Icon(
                      Icons.copy,
                      size: 16,
                      color: Colors.white54,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Copied to clipboard! 📋"),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onRemoteConsumerReady(String consumerId, RTCVideoRenderer renderer) {
    if (!mounted) return;
    logD("🎨 UI: Received renderer for $consumerId");

    if (renderer.srcObject != null &&
        renderer.srcObject!.getVideoTracks().isNotEmpty) {
      var track = renderer.srcObject!.getVideoTracks().first;

      logD("📹 Track Info: ID=${track.id}");
      logD("📹 Track Kind: ${track.kind}");
      logD("📹 Track Enabled: ${track.enabled}");
      logD("📹 Track Muted: ${track.muted}");
    }

    setState(() {
      _remoteParticipants[consumerId] = RemoteParticipant(
        renderer: renderer,
        userName: "Remote Peer",
        userId: consumerId,
        producerId: consumerId,
        isScreen: false,
      );
    });
  }

  void _onRemoteConsumerClosed(String consumerId) async {
    if (!mounted) return;

    final participant = _remoteParticipants[consumerId];

    if (participant != null) {
      // 🔥 IMPORTANT: detach stream first
      participant.renderer?.srcObject = null;

      // optional safety delay for GPU release
      await Future.delayed(const Duration(milliseconds: 50));

      participant.renderer?.dispose();
    }

    setState(() {
      _remoteParticipants.remove(consumerId);
    });

    logD("🔕 Removed remote participant: $consumerId");
  }

  Future<void> _initMeeting() async {
    widget.socketService.currentRoomId = widget.roomId;

    if (_meetingStarted) return;
    _meetingStarted = true;

    if (_isInitializing) return;
    _isInitializing = true;

    try {
      // ✅ Web-safe platform check
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final statuses = await [
          Permission.camera,
          Permission.microphone,
        ].request();

        if (statuses[Permission.camera] != PermissionStatus.granted ||
            statuses[Permission.microphone] != PermissionStatus.granted) {
          throw Exception("Permissions not granted");
        }
      }

      await _ms.initLocalStream(xiaomiWorkaround: true);

      if (_ms.localStream?.getVideoTracks().isEmpty ?? true) {
        logD("⚠️ No video tracks found!");
      }

      if (!mounted) return;

      if (mounted) setState(() {}); // refresh controls now that camera is up

      final RtpCapabilities rtpCapabilities;
      try {
        rtpCapabilities = await fetchRouterRtpCapabilities();
      } catch (e) {
        if (e.toString().contains('WAITING_FOR_HOST')) {
          if (mounted) setState(() => _waitingForHost = true);
          _meetingStarted = false; // allow re-init on host:joined
          _isInitializing = false;
          return;
        }
        rethrow;
      }

      await _ms.init(rtpCapabilities);

      final sendParams = await fetchSendTransportParams();
      await _ms.createSendTransport(sendParams);

      // ✅ Wait transport connect
      int retry = 0;

      await Future.delayed(const Duration(milliseconds: 100));

      while (!_ms.isSendTRXConnected && retry < 20) {
        logD("⏳ Waiting for transport...");
        await Future.delayed(const Duration(milliseconds: 500));
        retry++;
      }

      if (!_ms.isSendTRXConnected) {
        throw Exception("Transport never connected");
      }

      final recvParams = await fetchRecvTransportParams();
      await _ms.createRecvTransport(recvParams);

      logD("🎥 Producing video...");
      await _ms.produceVideo(widget.userName);

      logD("🎤 Producing audio...");
      await _ms.produceAudio();

      logD("✅ Media production started!");
    } catch (e, stack) {
      logD("❌ Meeting init failed: $e\n$stack");
      _showInitError(e.toString());
    } finally {
      _setupSocketListeners();

      for (var p in _initialProducers) {
        _consumeRemoteStream(
          producerId: p['producerId'],
          userId: p['userId'],
          kind: p['kind'],
          type: p['appData']?['type'] ?? 'video',
        );
      }

      _isInitializing = false;
    }
  }

  void _showPermissionError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📷 Camera & Mic permissions required!')),
    );
  }

  void _showInitError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('⚠️ Init error: $message')));
  }

  void _setupSocketListeners() {
    _onMediaStateChanged = (data) {
      if (!mounted) return;
      setState(() {
        _videoEnabledMap[data['userId']] = data['videoEnabled'];
        _audioEnabledMap[data['userId']] = data['audioEnabled'];
      });
    };

    _onScreenShareStarted = (data) {
      if (!mounted) return;
      setState(() => _screenSharerId = data['userId']);
    };
    _onParticipantLeft = (data) async {
      if (!mounted) return;

      final userId = data['userId'];

      // Find all consumers/renderers matching this leaving user
      final keysToRemove = _remoteParticipants.entries
          .where((e) => e.value.userId == userId)
          .map((e) => e.key)
          .toList();

      for (final key in keysToRemove) {
        final participant = _remoteParticipants[key];

        if (participant?.renderer != null) {
          // 1. 🔥 CRITICAL: Set to null to clear the frozen frame
          participant!.renderer!.srcObject = null;

          // 2. Give the UI a tiny delay to register the empty state
          await Future.delayed(const Duration(milliseconds: 50));

          // 3. Safely dispose
          participant.renderer!.dispose();
        }
        // Rebuilds the ui when a user left
        setState(() {
          _remoteParticipants.remove(key);
          _videoEnabledMap.remove(userId);
          _audioEnabledMap.remove(userId);
          _handRaisedUsers.remove(userId);
        });
      }

      setState(() {});
      logD("🚪 User $userId left. Video cleanly removed.");
    };

    widget.socketService.socket.on('participant:left', _onParticipantLeft);
    // NEW: Listen for remote hand raise updates from backend broadcaster
    widget.socketService.socket.on('meeting:action-broadcast', (data) {
      if (!mounted) return;
      final String action = data['action'];
      final String targetUserId = data['targetUserId'] ?? data['userId'];

      // Host pushed a whiteboard policy update → students adopt it.
      if (action == 'whiteboard-policy') {
        final payload = data['payload'];
        if (payload is Map) {
          setState(() {
            _studentsCanOpenWhiteboard = payload['canOpen'] == true;
            _studentsCanDrawWhiteboard = payload['canDraw'] == true;
          });
        }
        return;
      }

      // Floating emoji reaction from any participant.
      if (action == 'reaction') {
        final emoji = (data['emoji'] ?? '👍').toString();
        _reactions.add(emoji);
        return;
      }
      // Host pressed "Mute all" → non-hosts mute their mic.
      if (action == 'mute-all') {
        if (!_isHost && _micOn) _toggleMic();
        return;
      }
      // Host locked/unlocked the meeting (blocks new joins; banner for all).
      if (action == 'meeting-lock' || action == 'meeting-unlock') {
        setState(() => _meetingLocked = action == 'meeting-lock');
        return;
      }
      // Host spotlighted a participant.
      if (action == 'spotlight') {
        setState(() => _spotlightUserId =
            (data['targetUserId'] ?? data['userId'])?.toString());
        return;
      }
      // Host removed a participant → if it's me, leave.
      if (action == 'remove') {
        if (targetUserId == widget.userName) _handleExitMeeting();
        return;
      }

      setState(() {
        if (action == 'hand-raise') {
          _handRaisedUsers.add(targetUserId);
        } else if (action == 'hand-lower') {
          _handRaisedUsers.remove(targetUserId);
        }
      });
    });
    _onScreenShareStopped = (data) {
      final String? targetProducerId = data['producerId'];
      final String? stoppedUserId = data['userId'];

      setState(() {
        if (stoppedUserId != null && _screenSharerId == stoppedUserId) {
          _screenSharerId = null;
        }
        _remoteParticipants.removeWhere((key, p) {
          // Check if the key itself matches the target,
          // or if the internal producerId matches.
          bool isMatch =
              (key == targetProducerId || p.producerId == targetProducerId);

          // If your map is corrupted and isScreen is false,
          // temporarily remove the p.isScreen check to clean up the zombie
          if (isMatch) {
            p.renderer?.srcObject = null;
            p.renderer?.dispose();
            return true;
          }
          return false;
        });
      });
    };
    _onNewProducer = (data) {
      if (!mounted || _ms.isDisposed) return;
      if (_activeConsumers.contains(data['consumerId'])) {
        logD("Already consuming this! Skipping...");
        return;
      }
      logD('$data');
      _consumeRemoteStream(
        producerId: data['producerId'],
        userId: data['userId'],
        kind: data['kind'],
        type: data['type'] ?? 'video', // Pass the type from the backend signal
      );
    };
    widget.socketService.socket.on(
      'participant:media-state',
      _onMediaStateChanged,
    );
    widget.socketService.socket.on(
      'screen-share:started',
      _onScreenShareStarted,
    );

    widget.socketService.socket.on('new-producer', _onNewProducer);
    // widget.socketService.socket.on('screen-share:started', (data) {
    //   if (!mounted) return;
    //   setState(() => _screenSharerId = data['userId']);
    // });
    widget.socketService.socket.on(
      'mediasoup:screenshare:stopped',
      _onScreenShareStopped,
    );
    try {
      // 2. AWAIT the response from the server
      // widget.socketService.socket.on('new-producer', (data) {
      //   logD("🔔 UI: Someone else started their video!");
      //   _consumeRemoteStream(
      //     producerId: data['producerId'],
      //     userId: data['userId'], // NestJS sends this
      //     kind: data['kind'],     // NestJS sends this
      //   );
      // });
    } catch (e) {
      logD("❌ Error during join-room ack: $e");
    }
  }

  void _handleFullscreen(String userId) {
    logD("handling _handleFullscreen");
    final renderer = _remoteParticipants[userId]?.renderer;

    if (renderer == null) return;
    setState(() => _fullscreenUserId = userId);
    // Navigate to fullscreen view or show modal~
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenMeetingView(
          focusedUserId: userId,
          focusedUserName: _getUserName(userId),
          isFocusedUserTeacher: _isUserTeacher(userId), // ✅ Helper method below
          focusedRenderer: renderer,
          isFocusedVideoEnabled: _videoEnabledMap[userId] ?? true,
          isFocusedAudioEnabled: _audioEnabledMap[userId] ?? true,
          otherRenderers: Map.fromEntries(
            _remoteParticipants.entries
                .where((e) => e.value.renderer != null)
                .map((e) => MapEntry(e.key, e.value.renderer!)),
          ),
          onExitFullscreen: () => Navigator.pop(context),
        ),
      ),
    ).then((_) {
      setState(() => _fullscreenUserId = null);
    });
  }

  bool _isUserTeacher(String userId) {
    return false;
  }

  void _handleHandRaise(String userId) {
    // ✅ Optimistic UI: flip the local state FIRST so the button reacts instantly
    // (the old code only emitted to the server and waited for the echo, so the
    // raiser saw no feedback). The server broadcast later reconciles idempotently.
    setState(() => _handRaisedUsers.add(userId));
    widget.socketService.emit('meeting:action', {
      'roomId': widget.roomId,
      'action': 'hand-raise',
      'targetUserId': userId,
    });

    // Auto-lower our own hand after 30s if not acknowledged/lowered.
    if (userId == widget.userName) {
      _handLowerTimer?.cancel();
      _handLowerTimer = Timer(const Duration(seconds: 30), () {
        if (mounted && _handRaisedUsers.contains(widget.userName)) {
          _handleHandLower(widget.userName);
        }
      });
    }
  }

  void _handleHandLower(String userId) {
    if (userId == widget.userName) _handLowerTimer?.cancel();
    widget.socketService.emit('meeting:action', {
      'roomId': widget.roomId,
      'action': 'hand-lower',
      'targetUserId': userId,
    });
    setState(() => _handRaisedUsers.remove(userId));
  }

  String _getUserName(String userId) {
    if (userId == 'local') return widget.userName;
    return _remoteParticipants[userId]?.userName ?? 'Unknown~';
  }

  // ── Reactions (everyone) + host controls ─────────────────────────
  void _sendReaction(String emoji) {
    _reactions.add(emoji); // optimistic, local
    widget.socketService.emit('meeting:action', {
      'roomId': widget.roomId,
      'action': 'reaction',
      'emoji': emoji,
    });
    setState(() => _showReactionBar = false);
  }

  void _hostMuteAll() {
    widget.socketService.emit('meeting:action', {
      'roomId': widget.roomId,
      'action': 'mute-all',
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Asked everyone to mute')),
    );
  }

  void _hostToggleLock() {
    final lock = !_meetingLocked;
    setState(() => _meetingLocked = lock);
    widget.socketService.emit('meeting:action', {
      'roomId': widget.roomId,
      'action': lock ? 'meeting-lock' : 'meeting-unlock',
    });
  }

  void _hostSpotlight(String userId) {
    setState(() => _spotlightUserId = userId);
    widget.socketService.emit('meeting:action', {
      'roomId': widget.roomId,
      'action': 'spotlight',
      'targetUserId': userId,
    });
  }

  void _hostRemove(String userId) {
    widget.socketService.emit('meeting:action', {
      'roomId': widget.roomId,
      'action': 'remove',
      'targetUserId': userId,
    });
  }

  void _openHostControls() {
    final remoteNames = _remoteParticipants.values
        .where((p) => !p.isScreen)
        .map((p) => p.userName)
        .toSet()
        .toList();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.mic_off),
              title: const Text('Mute everyone'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _hostMuteAll();
              },
            ),
            ListTile(
              leading: Icon(_meetingLocked ? Icons.lock_open : Icons.lock),
              title: Text(_meetingLocked ? 'Unlock meeting' : 'Lock meeting'),
              subtitle: const Text('Blocks new participants from joining'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _hostToggleLock();
              },
            ),
            if (_sessionDetails != null)
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Export attendance (CSV)'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final ok = await context.read<InsightsProvider>().exportAttendanceCsv(
                        _sessionDetails!.id,
                        label: _sessionDetails!.topic,
                      );
                  if (mounted && !ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Export failed')),
                    );
                  }
                },
              ),
            if (remoteNames.isNotEmpty) const Divider(),
            ...remoteNames.map((name) => ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(name),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Spotlight',
                        icon: Icon(
                          Icons.star,
                          color: _spotlightUserId == name ? Colors.amber : null,
                        ),
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          _hostSpotlight(name);
                        },
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.person_remove, color: Colors.red),
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          _hostRemove(name);
                        },
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _consumeRemoteStream({
    required String producerId,
    required String userId,
    required String kind,
    required String type,
  }) async {
    try {
      if (_activeConsumers.contains(producerId)) return;
      _activeConsumers.add(producerId);

      int attempts = 0;
      while (_ms.recvTransport == null && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 300));
        attempts++;
      }

      if (_ms.recvTransport == null) {
        _activeConsumers.remove(producerId);
        return;
      }

      widget.socketService.emitWithAck(
        'mediasoup:consume',
        {
          'roomId': widget.roomId,
          'transportId': _ms.recvTransport!.id,
          'producerId': producerId,
          'rtpCapabilities': _ms.deviceRtpCapabilities.toMap(),
          'type': type,
        },
        ack: (data) async {
          if (data == null) {
            _activeConsumers.remove(producerId);
            return;
          }

          final consumerId = data['id'];
          final remoteProducerId = data['producerId'];
          final actualUserId = data['producerUserId'] ?? userId;
          final actualUserName = data['producerName'] ?? "Remote User";

          RTCVideoRenderer? renderer;

          // ✅ ONLY VIDEO gets renderer
          if (kind == 'video') {
            renderer = RTCVideoRenderer();
            await renderer.initialize();
          }

          await _ms.consume(
            id: consumerId,
            producerId: remoteProducerId,
            peerId: actualUserId,
            kind: kind == 'video'
                ? RTCRtpMediaType.RTCRtpMediaTypeVideo
                : RTCRtpMediaType.RTCRtpMediaTypeAudio,
            rtpParameters: RtpParameters.fromMap(data['rtpParameters']),
            roomId: widget.roomId,
            appData: {'type': type},
          );

          setState(() {
            final existing = _remoteParticipants[consumerId];

            _remoteParticipants[consumerId] = RemoteParticipant(
              userId: actualUserId,
              userName: actualUserName,
              producerId: remoteProducerId,
              isScreen: type == 'screen',
              renderer: renderer ?? existing?.renderer,
              audioStream: existing?.audioStream,
            );

            // A remote screen producer arrived → surface the "X is sharing"
            // banner. (The backend broadcasts the screen as a normal
            // new-producer with type:'screen'; it never sends a separate
            // 'screen-share:started', so we drive the banner from here.)
            if (type == 'screen') {
              _screenSharerId = actualUserId;
            }
          });
        },
      );
    } catch (e) {
      _activeConsumers.remove(producerId);
      logD("❌ consume error: $e");
    }
  }

  // Camera/mic toggles only flip `track.enabled` on the EXISTING local track.
  //
  // Why not stop()/getUserMedia()/produceVideo() again? Calling track.stop()
  // destroys the hardware track, so re-opening had to acquire a brand-new track
  // and re-produce it — which (a) showed a black screen until renegotiation and
  // (b) leaked a second producer each time. `enabled = false` instead sends
  // muted (black/silent) frames while keeping the track AND its mediasoup
  // producer alive, so resume is instant and the renderer's srcObject never
  // changes. We then tell peers via the dedicated media-state channel so their
  // tiles show the correct mic/cam status.
  Future<void> _toggleCamera() async {
    if (_isInitializing || !mounted) return;

    setState(() => _cameraOn = !_cameraOn);

    if (_cameraOn) {
      _ms.resumeVideoTrack();
    } else {
      _ms.pauseVideoTrack();
    }

    _emitMediaState();
    _emitAttention(); // 👁️ camera state feeds attention
  }

  void _toggleMic() {
    if (!mounted) return;
    setState(() => _micOn = !_micOn);

    if (_micOn) {
      _ms.resumeAudioTrack();
    } else {
      _ms.pauseAudioTrack();
    }

    _emitMediaState();
  }

  // Single source of truth for broadcasting our cam/mic state. The gateway
  // (`media:state-update`) re-emits `participant:media-state`, which peers
  // already consume into _videoEnabledMap / _audioEnabledMap.
  void _emitMediaState() {
    widget.socketService.emit('media:state-update', {
      'roomId': widget.roomId,
      'videoEnabled': _cameraOn,
      'audioEnabled': _micOn,
    });
  }

  // Single source of truth for recording — both the header toggle and the
  // control-bar button route here so the start/stop socket payload is always
  // emitted (previously the header stop path silently dropped the recording).
  Future<void> _toggleRecording() async {
    try {
      if (_recorder.isActive) {
        final savedPath = await _recorder.stop();
        if (!mounted) return;
        setState(() => _isRecording = false);
        widget.socketService.emit('meeting:action', {
          'roomId': widget.roomId,
          'action': 'session-record-stop',
          'userId': widget.userName,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(savedPath != null
                ? 'Recording saved: ${savedPath.split('/').last}'
                : 'Recording stopped'),
          ),
        );
      } else {
        final started = await _recorder.start(
          org: 'HtooChoon',
          program: _sessionDetails?.topic ?? widget.roomId,
          includeMic: _micOn,
        );
        if (!started) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('⚠️ Could not start recording')),
            );
          }
          return;
        }
        if (!mounted) return;
        setState(() => _isRecording = true);
        widget.socketService.emit('meeting:action', {
          'roomId': widget.roomId,
          'action': 'session-record-start',
          'userId': widget.userName,
        });
      }
    } catch (e) {
      logD("❌ Session recording error: $e");
      if (mounted) setState(() => _isRecording = false);
    }
  }

  // Pause / resume the in-progress recording. Native true-pause on Android;
  // best-effort flag elsewhere.
  Future<void> _toggleRecordingPause() async {
    if (_recorder.state.value == RecordingState.paused) {
      await _recorder.resume();
    } else {
      await _recorder.pause();
    }
    if (mounted) setState(() {});
  }

  // 1. Move this to the top of your _MeetingPageState class
  bool _isExiting = false;

  Future<void> _handleExitMeeting() async {
    if (_isExiting) return;

    logD("🚪 Local user exiting. Cleaning up...");
    setState(() => _isExiting = true);
    widget.socketService.emit('live-session:leave', {
      'roomId': widget.roomId,
      'userId': widget.userName,
    });
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // ── Whiteboard (teacher only) ────────────────────────────────────────
  Future<void> _openWhiteboardSetup() async {
    bool studentsCanDraw = false;
    bool shareScreen = false;
    bool liveSync = true;

    final start = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          icon: Icon(Icons.draw_outlined,
              color: Theme.of(ctx).colorScheme.primary),
          title: const Text('Start whiteboard'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow students to draw'),
                subtitle: const Text('Off = students can only view',
                    style: TextStyle(fontSize: 12)),
                value: studentsCanDraw,
                onChanged: (v) => setS(() => studentsCanDraw = v),
                secondary:
                    Icon(studentsCanDraw ? Icons.lock_open : Icons.lock),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Share via screen share'),
                subtitle: const Text(
                    'Broadcast the whiteboard to participants',
                    style: TextStyle(fontSize: 12)),
                value: shareScreen,
                onChanged: (v) => setS(() => shareScreen = v),
                secondary: const Icon(Icons.screen_share_outlined),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sync board live'),
                subtitle: const Text('Off = board stays local to you',
                    style: TextStyle(fontSize: 12)),
                value: liveSync,
                onChanged: (v) => setS(() => liveSync = v),
                secondary: const Icon(Icons.sync_rounded),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Open whiteboard')),
          ],
        ),
      ),
    );

    if (start != true || !mounted) return;

    // Keep the host policy in sync with the choice made here, so the host panel
    // reflects it and students get the same draw mode on the shared board.
    if (liveSync) {
      _studentsCanDrawWhiteboard = studentsCanDraw;
      _broadcastWhiteboardPolicy();
    }

    if (shareScreen && !_isScreenSharing) {
      await _handleScreenShare();
    }
    await _launchWhiteboard(
      studentsCanDraw: studentsCanDraw,
      liveSync: liveSync,
    );
  }

  Future<void> _launchWhiteboard({
    required bool studentsCanDraw,
    required bool liveSync,
  }) async {
    final isDesktop =
        Platform.isLinux || Platform.isWindows || Platform.isMacOS;

    // Mobile: no second OS window — open a full-screen route instead.
    if (!isDesktop) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WhiteboardPage(
            roomId: widget.roomId,
            userId: widget.userName,
            role: widget.role,
            socketService: widget.socketService,
            initialStudentsCanDraw: studentsCanDraw,
            liveSync: liveSync,
            showSetupOnStart: false,
          ),
        ),
      );
      return;
    }

    // Desktop: re-focus an already-open board instead of spawning a second one.
    if (_whiteboardWindow != null) {
      try {
        await _whiteboardWindow!.show();
        return;
      } catch (_) {
        _whiteboardWindow = null;
      }
    }

    try {
      final window = await DesktopMultiWindow.createWindow(jsonEncode({
        'roomId': widget.roomId,
        'userId': widget.userName,
        'role': widget.role,
        'studentsCanDraw': studentsCanDraw,
        'liveSync': liveSync,
      }));
      window
        ..setFrame(const Offset(120, 80) & const Size(1100, 760))
        ..center()
        ..setTitle('Whiteboard');
      await window.show();
      _whiteboardWindow = window;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open whiteboard window: $e')),
        );
      }
    }
  }

  // Auto-closes the detached whiteboard window when the meeting ends.
  void _closeWhiteboardWindow() {
    final w = _whiteboardWindow;
    _whiteboardWindow = null;
    if (w == null) return;
    try {
      w.close();
    } catch (_) {}
  }

  // ── Notes (everyone, private + local) ────────────────────────────────
  Future<void> _openNotes() async {
    final isDesktop =
        Platform.isLinux || Platform.isWindows || Platform.isMacOS;

    // Mobile: full-screen route (no second OS window).
    if (!isDesktop) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NotesPage(
            sessionId: widget.sessionId,
            userId: widget.userName,
          ),
        ),
      );
      return;
    }

    // Desktop: re-focus an open notes window instead of spawning a second.
    if (_notesWindow != null) {
      try {
        await _notesWindow!.show();
        return;
      } catch (_) {
        _notesWindow = null;
      }
    }
    try {
      final window = await DesktopMultiWindow.createWindow(jsonEncode({
        'windowType': 'notes',
        'sessionId': widget.sessionId,
        'userId': widget.userName,
      }));
      window
        ..setFrame(const Offset(160, 100) & const Size(720, 640))
        ..center()
        ..setTitle('My Notes');
      await window.show();
      _notesWindow = window;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open notes window: $e')),
        );
      }
    }
  }

  // Auto-closes the detached notes window when the meeting ends.
  void _closeNotesWindow() {
    final w = _notesWindow;
    _notesWindow = null;
    if (w == null) return;
    try {
      w.close();
    } catch (_) {}
  }

  // Host pushes the current whiteboard policy to the whole room. Reuses the
  // meeting:action relay (which already forwards `payload`, see record actions)
  // so no new backend event is needed. Also pings the whiteboard:permission
  // channel so any board that's already open flips view/edit mode live.
  void _broadcastWhiteboardPolicy() {
    widget.socketService.emit('meeting:action', {
      'roomId': widget.roomId,
      'action': 'whiteboard-policy',
      'userId': widget.userName,
      'payload': {
        'canOpen': _studentsCanOpenWhiteboard,
        'canDraw': _studentsCanDrawWhiteboard,
      },
    });
    widget.socketService.emit('whiteboard:permission', {
      'roomId': widget.roomId,
      'studentsCanDraw': _studentsCanDrawWhiteboard,
    });
  }

  void _setStudentsCanOpenWhiteboard(bool v) {
    setState(() {
      _studentsCanOpenWhiteboard = v;
      if (!v) _studentsCanDrawWhiteboard = false; // closed → mode irrelevant
    });
    _broadcastWhiteboardPolicy();
  }

  void _setStudentsCanDrawWhiteboard(bool v) {
    setState(() => _studentsCanDrawWhiteboard = v);
    _broadcastWhiteboardPolicy();
  }

  // 👁️ Emit the student's current attention state (focused + camera) to the server.
  void _emitAttention() {
    if (widget.role != 'student') return;
    widget.socketService.emit('live:attention:update', {
      'focused': _appFocused,
      'cameraOn': _cameraOn,
    });
  }

  void _onAttentionReport(dynamic data) {
    if (!mounted || data is! Map) return;
    setState(() {
      _attentionReports[data['userId'].toString()] =
          Map<String, dynamic>.from(data);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final focused = state == AppLifecycleState.resumed;
    if (focused != _appFocused) {
      _appFocused = focused;
      _emitAttention();
    }
  }

  void _showAttentionPanel() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        final reports = _attentionReports.values.toList()
          ..sort((a, b) =>
              ((a['attentionScore'] ?? 100) as num).compareTo((b['attentionScore'] ?? 100) as num));
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text('Student attention',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              if (reports.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No attention data yet.')),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: reports.map((r) {
                      final focused = r['focused'] == true;
                      final cameraOn = r['cameraOn'] == true;
                      final score = r['attentionScore'];
                      final color = focused ? Colors.green : Colors.red;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          focused ? Icons.visibility : Icons.visibility_off,
                          color: color,
                        ),
                        title: Text(r['name']?.toString() ?? 'Student'),
                        subtitle: Text(
                          '${focused ? 'Focused' : 'Away'} · camera ${cameraOn ? 'on' : 'off'}',
                        ),
                        trailing: Text(
                          score is num ? '${score.round()}%' : '—',
                          style: TextStyle(fontWeight: FontWeight.w800, color: color),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _closeWhiteboardWindow();
    _closeNotesWindow();
    _attnTimer?.cancel();
    _elapsedTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (widget.role != 'student') {
      widget.socketService.socket.off('live:attention:report');
    }
    _handLowerTimer?.cancel();
    _reactions.dispose();
    widget.socketService.socket.off('participant:left', _onParticipantLeft);
    widget.socketService.socket.off('new-producer', _onNewProducer);
    widget.socketService.socket.off('host:joined');
    widget.socketService.socket.off('host:left');

    // IMPORTANT:
    // Detach renderer streams BEFORE cleanup

    for (final participant in _remoteParticipants.values) {
      try {
        participant.renderer?.srcObject = null;
      } catch (_) {}
    }
    _ms.sendTransport?.close();
    _ms.recvTransport?.close();

    try {
      _ms.localRenderer.srcObject = null;
    } catch (_) {}

    _remoteParticipants.clear();

    // Fire-and-forget safely
    unawaited(_ms.dispose());

    super.dispose();
  }

  // lib/features/meeting/meeting_page.dart (build method fix)
  @override
  Widget build(BuildContext context) {
    if (_waitingForHost) {
      return WaitingRoomView(
        topic: _sessionDetails?.topic ?? widget.roomId,
        onLeave: () => Navigator.of(context).maybePop(),
      );
    }
    // Only show tiles that actually carry video — a camera or a screen. Audio-only
    // consumers (renderer == null) and duplicate producers for the same user are
    // dropped, so the grid stops filling with empty "ghost"/phantom tiles. Tile
    // identity is the consumer key, which keeps renderer/screen/fullscreen lookups
    // consistent (the _remoteParticipants map is keyed by consumerId).
    final tileEntries = <MapEntry<String, RemoteParticipant>>[];
    final seenTiles = <String>{};
    for (final e in _remoteParticipants.entries) {
      final p = e.value;
      if (p.renderer == null) continue; // audio-only / no media → not a tile
      final dedupe = '${p.userId}|${p.isScreen}'; // one camera + one screen / user
      if (!seenTiles.add(dedupe)) continue;
      tileEntries.add(e);
    }

    final remoteRenderers = <String, RTCVideoRenderer>{
      for (final e in tileEntries) e.key: e.value.renderer!,
    };

    // The tile keys of remote participants sharing a screen, so the grid renders
    // those tiles with "contain" fit + a screen label.
    final screenShareUserIds = <String>{
      for (final e in tileEntries.where((e) => e.value.isScreen)) e.key,
    };

    // Distinct humans = deduped remote users + me.
    final participantCount = _liveChatParticipants().length + 1;

    final participantModels = tileEntries.map((e) {
      final p = e.value;
      return UserModel(
        id: e.key,
        name: p.isScreen ? '${p.userName} (screen)' : p.userName,
        email: '',
        role: UserRole.student,
        isActive: true,
        isTwoFactorEnabled: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        // ✅ Use Stack for overlays~
        children: [
          Column(
            children: [
              Expanded(
                // ✅ FIX: Use VideoGrid (not VideoTile!) with correct props~
                child: VideoGrid(
                  localRenderer: _ms.localRenderer,
                  // Our own shared screen as a separate local tile (null unless
                  // we're sharing) so we see camera + screen, just like peers do.
                  localScreenRenderer:
                      _isScreenSharing ? _ms.screenRenderer : null,
                  participants: participantModels,
                  isTeacher: widget.role == 'teacher',
                  consumerRenderers: remoteRenderers,
                  screenShareUserIds: screenShareUserIds,
                  // ✅ Pass media state maps
                  videoEnabledMap: _videoEnabledMap,
                  audioEnabledMap: _audioEnabledMap,
                  // ✅ Pass callbacks
                  onToggleFullscreen: _handleFullscreen,
                  handRaisedUsers: _handRaisedUsers,
                  onRecordToggled: (userId) => _toggleRecording(),
                ),
              ),
              _buildBottomControls(),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: _buildLiveChip(context, participantCount),
          ),
          // ✅ Overlay: Screen Share Banner
          if (_screenSharerId != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 12,
              right: 12,
              child: ScreenShareBanner(
                sharerName: _getUserName(_screenSharerId!),
                onViewScreen: () => _handleFullscreen(_screenSharerId!),
                onClose: () => setState(() => _screenSharerId = null),
              ),
            ),
          // Raised-hand banners — shown to EVERYONE (the old code hid them from
          // teachers, who are exactly the people who need to see them). The
          // teacher can lower anyone's hand; a student can lower their own.
          if (_handRaisedUsers.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              left: 12,
              right: 12,
              child: Column(
                children: _handRaisedUsers.map((userId) {
                  final isSelf = userId == widget.userName;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: HandRaiseIndicator(
                      // userId IS the display name peers joined with.
                      userName: isSelf ? 'You' : userId,
                      isSelf: isSelf,
                      onLowerHand: (isSelf || widget.role == 'teacher')
                          ? () => _handleHandLower(userId)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          // Floating emoji reactions (rises + fades).
          ReactionOverlay(controller: _reactions),
          // Lock banner.
          if (_meetingLocked)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Locked', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ),
          // Reactions + host-controls cluster, just above the bottom bar.
          Positioned(
            right: 12,
            bottom: 96,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_showReactionBar)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ReactionBar(onPick: _sendReaction),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isHost)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FloatingActionButton.small(
                          heroTag: 'host-controls',
                          backgroundColor: Colors.black54,
                          onPressed: _openHostControls,
                          child: const Icon(Icons.shield_outlined, color: Colors.white),
                        ),
                      ),
                    FloatingActionButton.small(
                      heroTag: 'reactions',
                      backgroundColor: Colors.black54,
                      onPressed: () =>
                          setState(() => _showReactionBar = !_showReactionBar),
                      child: const Icon(Icons.emoji_emotions_outlined, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Right-side chat panel (Positioned.fill internally). Opened from the
          // control bar; no floating bubble anymore.
          MeetingChatOverlay(
            socket: widget.socketService,
            roomId: widget.roomId,
            myName: widget.userName,
            role: widget.role,
            participants: _liveChatParticipants(),
            isOpen: _chatOpen,
            onClose: () => setState(() => _chatOpen = false),
            onUnreadChanged: (n) {
              if (mounted) setState(() => _chatUnread = n);
            },
          ),
          // Host control side panel (teacher/admin only).
          if (_isHost) _buildHostPanel(context),
        ],
      ),
    );
  }

  // Zoom/Meet-style host control panel: a right-side slide-in the teacher/admin
  // uses to govern the shared whiteboard for everyone.
  Widget _buildHostPanel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final panelW = size.width < 420 ? size.width : 340.0;
    final open = _hostPanelOpen;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !open,
        child: Stack(
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: open ? 1 : 0,
              child: GestureDetector(
                onTap: () => setState(() => _hostPanelOpen = false),
                child: Container(color: Colors.black.withValues(alpha: 0.45)),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              top: 0,
              bottom: 0,
              right: open ? 0 : -panelW,
              width: panelW,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(22)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF121218).withValues(alpha: 0.94),
                      border: Border(
                        left: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                    ),
                    child: SafeArea(
                      left: false,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          Row(
                            children: [
                              Icon(Icons.admin_panel_settings_outlined,
                                  color: cs.primary, size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text('Host controls',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                              ),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _hostPanelOpen = false),
                                icon: const Icon(Icons.close_rounded,
                                    color: Colors.white70),
                                tooltip: 'Close',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _hostSectionLabel('Whiteboard'),
                          const Text(
                            'One shared board for everyone in the session.',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeColor: cs.primary,
                            title: const Text('Students can open whiteboard',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              _studentsCanOpenWhiteboard
                                  ? 'Anyone can open the shared board'
                                  : 'Only you can open the board',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12),
                            ),
                            value: _studentsCanOpenWhiteboard,
                            onChanged: _setStudentsCanOpenWhiteboard,
                            secondary: Icon(
                              _studentsCanOpenWhiteboard
                                  ? Icons.lock_open_rounded
                                  : Icons.lock_outline_rounded,
                              color: Colors.white70,
                            ),
                          ),
                          // Default mode only matters when students may open it.
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _studentsCanOpenWhiteboard ? 1 : 0.4,
                            child: IgnorePointer(
                              ignoring: !_studentsCanOpenWhiteboard,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: Text('Default student mode',
                                          style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    _modeSelector(cs),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hostSectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(t.toUpperCase(),
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6)),
      );

  // View | Edit segmented selector for the student default whiteboard mode.
  Widget _modeSelector(ColorScheme cs) {
    Widget seg(String label, IconData icon, bool edit) {
      final selected = _studentsCanDrawWhiteboard == edit;
      return Expanded(
        child: GestureDetector(
          onTap: () => _setStudentsCanDrawWhiteboard(edit),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? cs.primary
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? cs.primary
                    : Colors.white.withValues(alpha: 0.10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16,
                    color: selected ? cs.onPrimary : Colors.white60),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: selected ? cs.onPrimary : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        seg('View', Icons.visibility_outlined, false),
        const SizedBox(width: 8),
        seg('Edit', Icons.edit_outlined, true),
      ],
    );
  }

  // Glassy "LIVE" chip: pulsing dot + topic + elapsed timer + people count.
  // Tap opens the meeting-details sheet.
  Widget _buildLiveChip(BuildContext context, int people) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: _showMeetingDetailsBottomSheet,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A24).withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _LiveDot(),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    _sessionDetails?.topic ?? 'Live session',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _elapsedLabel,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: cs.primary.withValues(alpha: 0.28)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_alt_rounded,
                          size: 12, color: cs.primary),
                      const SizedBox(width: 4),
                      Text(
                        '$people',
                        style: TextStyle(
                          color: cs.primary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Deduped remote participants the teacher can privately address in chat.
  List<LiveChatParticipant> _liveChatParticipants() {
    final seen = <String>{};
    final out = <LiveChatParticipant>[];
    for (final p in _remoteParticipants.values) {
      if (p.userId.isEmpty || !seen.add(p.userId)) continue;
      out.add(LiveChatParticipant(p.userId, p.userName));
    }
    return out;
  }

  //
  // Widget _videoTile(
  //     RTCVideoRenderer renderer,
  //     String name, {
  //       required Key key,
  //       bool isLocal = false,
  //     }) {
  //   return Container(
  //     decoration: BoxDecoration(
  //       color: Colors.grey[900],
  //       borderRadius: BorderRadius.circular(16),
  //       border: Border.all(color: Colors.white10),
  //     ),
  //     clipBehavior: Clip.antiAlias,
  //     child: Stack(
  //       children: [
  //         renderer.srcObject != null
  //             ? RTCVideoView(
  //           renderer,
  //           mirror: isLocal,
  //           objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
  //           key: key,
  //         )
  //             : Center(child: CircularProgressIndicator()),
  //         Positioned(
  //           bottom: 12, left: 12,
  //           child: Container(
  //             padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  //             decoration: BoxDecoration(
  //               color: Colors.black54,
  //               borderRadius: BorderRadius.circular(4),
  //             ),
  //             child: Text(name, style: TextStyle(color: Colors.white, fontSize: 12)),
  //           ),
  //         ),
  //         if (!isLocal)
  //           Positioned(top: 8, right: 8, child: Icon(Icons.circle, color: Colors.green, size: 12)),
  //       ],
  //     ),
  //   );
  // }

  void _showMoreActions() {
    final cs = Theme.of(context).colorScheme;
    final bool isHandRaised = _handRaisedUsers.contains(widget.userName);
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Wrap(
            spacing: 20,
            runSpacing: 16,
            children: [
              _sheetAction(
                icon: _isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                label: _isScreenSharing ? 'Stop share' : 'Share screen',
                color: _isScreenSharing ? cs.error : cs.tertiary,
                onTap: () {
                  Navigator.pop(context);
                  _handleScreenShare();
                },
              ),
              if (_isHost)
                _sheetAction(
                  icon: Icons.draw_outlined,
                  label: 'Whiteboard',
                  color: cs.primary,
                  onTap: () {
                    Navigator.pop(context);
                    _openWhiteboardSetup();
                  },
                )
              else if (_studentsCanOpenWhiteboard)
                _sheetAction(
                  icon: Icons.draw_outlined,
                  label: 'Whiteboard',
                  color: cs.primary,
                  onTap: () {
                    Navigator.pop(context);
                    _launchWhiteboard(
                      studentsCanDraw: _studentsCanDrawWhiteboard,
                      liveSync: true,
                    );
                  },
                )
              else
                _sheetAction(
                  icon: Icons.lock_outline_rounded,
                  label: 'Whiteboard',
                  color: cs.onSurfaceVariant,
                  enabled: false,
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            "The host hasn't allowed students to open the whiteboard yet."),
                      ),
                    );
                  },
                ),
              // Personal notes — available to EVERYONE (incl. students), no host
              // gating, private + local. Opens its own window like the board.
              _sheetAction(
                icon: Icons.sticky_note_2_outlined,
                label: 'Notes',
                color: cs.secondary,
                onTap: () {
                  Navigator.pop(context);
                  _openNotes();
                },
              ),
              if (_isHost)
                _sheetAction(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Host controls',
                  color: Colors.teal,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _hostPanelOpen = true);
                  },
                ),
              _sheetAction(
                icon: _isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
                label: _isRecording ? 'Stop record' : 'Record',
                color: _isRecording ? cs.error : cs.onSurfaceVariant,
                onTap: () {
                  Navigator.pop(context);
                  _toggleRecording();
                },
              ),
              // Pause / resume only while a recording is running.
              if (_recorder.isActive)
                _sheetAction(
                  icon: _recorder.state.value == RecordingState.paused
                      ? Icons.play_circle_outline
                      : Icons.pause_circle_outline,
                  label: _recorder.state.value == RecordingState.paused
                      ? 'Resume'
                      : 'Pause',
                  color: cs.tertiary,
                  onTap: () {
                    Navigator.pop(context);
                    _toggleRecordingPause();
                  },
                ),
              _sheetAction(
                icon: isHandRaised ? Icons.front_hand : Icons.back_hand_outlined,
                label: isHandRaised ? 'Lower hand' : 'Raise hand',
                color: isHandRaised ? cs.tertiary : cs.onSurfaceVariant,
                onTap: () {
                  Navigator.pop(context);
                  if (isHandRaised) {
                    _handleHandLower(widget.userName);
                  } else {
                    _handleHandRaise(widget.userName);
                  }
                },
              ),
              if (widget.role == 'teacher')
                _sheetAction(
                  icon: Icons.visibility_rounded,
                  label: 'Attention',
                  color: Colors.deepPurple,
                  onTap: () {
                    Navigator.pop(context);
                    _showAttentionPanel();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final tint = enabled ? color : color.withValues(alpha: 0.45);
    return SizedBox(
      width: 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: tint.withValues(alpha: 0.12),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: 52,
                height: 52,
                child: Icon(icon, color: tint, size: 24),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _handleScreenShare() async {
    final wasSharing = _isScreenSharing;
    setState(() => _isScreenSharing = !wasSharing);
    try {
      if (wasSharing) {
        await _ms.stopScreenShare();
      } else {
        await _ms.startScreenShare(_myTrustedUserId ?? widget.userName);
      }
    } catch (e) {
      logD("Screen share error: $e");
      if (!mounted) return;
      setState(() => _isScreenSharing = wasSharing);
      final msg = e.toString().toLowerCase();
      final friendly = msg.contains('denied')
          ? 'Screen sharing permission was denied.'
          : (msg.contains('not supported') || msg.contains('ios'))
              ? "Screen sharing isn't supported on this device."
              : "Couldn't start screen sharing. Please try again.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendly)),
      );
    }
  }

  Widget _buildBottomControls() {
    final cs = Theme.of(context).colorScheme;
    final screenW = MediaQuery.of(context).size.width;
    final isCompact = screenW < 500;
    final btnSize = isCompact ? 40.0 : 44.0;
    final iconSize = isCompact ? 18.0 : 21.0;
    final gap = isCompact ? 5.0 : 8.0;
    final bool isHandRaised = _handRaisedUsers.contains(widget.userName);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final buttons = <Widget>[
      _ctrlBtn(
        icon: _micOn ? Icons.mic : Icons.mic_off,
        color: _micOn ? cs.primary : cs.error,
        size: btnSize, iconSize: iconSize,
        tooltip: _micOn ? 'Mute' : 'Unmute',
        onPressed: _toggleMic,
      ),
      _ctrlBtn(
        icon: _cameraOn ? Icons.videocam : Icons.videocam_off,
        color: _cameraOn ? cs.primary : cs.error,
        size: btnSize, iconSize: iconSize,
        tooltip: _cameraOn ? 'Camera off' : 'Camera on',
        onPressed: _toggleCamera,
      ),
      if (!isCompact) ...[
        _ctrlBtn(
          icon: _isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
          color: _isScreenSharing ? cs.error : cs.surfaceContainerHighest,
          size: btnSize, iconSize: iconSize,
          tooltip: _isScreenSharing ? 'Stop sharing' : 'Share screen',
          onPressed: _handleScreenShare,
        ),
        _ctrlBtn(
          icon: isHandRaised ? Icons.front_hand : Icons.back_hand_outlined,
          color: isHandRaised ? cs.tertiary : cs.surfaceContainerHighest,
          size: btnSize, iconSize: iconSize,
          tooltip: isHandRaised ? 'Lower hand' : 'Raise hand',
          onPressed: () {
            if (isHandRaised) {
              _handleHandLower(widget.userName);
            } else {
              _handleHandRaise(widget.userName);
            }
          },
        ),
      ],
      _ctrlBtnBadged(
        icon: Icons.forum_rounded,
        color: _chatOpen ? cs.primary : cs.surfaceContainerHighest,
        size: btnSize, iconSize: iconSize,
        tooltip: 'Chat',
        badge: _chatUnread,
        onPressed: () => setState(() {
          _chatOpen = !_chatOpen;
          if (_chatOpen) _chatUnread = 0;
        }),
      ),
      _ctrlBtn(
        icon: Icons.more_horiz,
        color: cs.surfaceContainerHighest,
        size: btnSize, iconSize: iconSize,
        tooltip: 'More',
        onPressed: _showMoreActions,
      ),
      _ctrlBtn(
        icon: Icons.call_end,
        color: cs.error,
        size: isCompact ? 44.0 : 48.0,
        iconSize: iconSize,
        tooltip: 'Leave',
        onPressed: _handleExitMeeting,
      ),
    ];

    // Full-width bar flush to the bottom edge; buttons stay a tight centered
    // cluster (small fixed gaps, not stretched across the width).
    final bar = ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            12,
            isCompact ? 8 : 10,
            12,
            (isCompact ? 8 : 10) + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.72),
            border: Border(
              top: BorderSide(color: cs.onSurface.withValues(alpha: 0.08)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < buttons.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                buttons[i],
              ],
            ],
          ),
        ),
      ),
    );

    return reduceMotion
        ? bar
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            builder: (_, t, child) => Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 26),
                child: child,
              ),
            ),
            child: bar,
          );
  }

  Widget _ctrlBtn({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    double size = 48,
    double iconSize = 22,
    String? tooltip,
  }) {
    final iconColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface;
    final disabled = onPressed == null;
    Widget button = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: disabled ? color.withValues(alpha: 0.4) : color,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(icon, key: ValueKey(icon), color: iconColor, size: iconSize),
          ),
        ),
      ),
    );
    button = _Pressable(child: button);
    return tooltip != null
        ? Tooltip(message: tooltip, child: button)
        : button;
  }

  // Control button with an unread-count badge (used by the chat toggle).
  Widget _ctrlBtnBadged({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    required int badge,
    double size = 48,
    double iconSize = 22,
    String? tooltip,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _ctrlBtn(
          icon: icon,
          color: color,
          size: size,
          iconSize: iconSize,
          tooltip: tooltip,
          onPressed: onPressed,
        ),
        if (badge > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: BoxDecoration(
                color: cs.error,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 1.5),
              ),
              child: Text(
                badge > 9 ? '9+' : '$badge',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onError,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<RtpCapabilities> fetchRouterRtpCapabilities() async {
    final completer = Completer<RtpCapabilities>();
    widget.socketService.emitWithAck(
      'live-session:join',
      {
        'roomId': widget.roomId,
        'name': widget.userName,
        'userId': widget.userName,
        'role': widget.role,
      },
      ack: (data) {
        if (data != null && data['success'] == true) {
          if (data != null && data['success'] == true) {
            setState(() {
              // 🔒 Store the server-verified ID
              _myTrustedUserId = data['user']['id'];
            });
            logD("🆔 Server-Verified User ID locked: $_myTrustedUserId");
          }
          // 1. Handle Users who might not have media yet (The "Ghost" Fix)
          // final List participants = data['activeParticipants'] ?? [];
          // for (var p in participants) {
          //   final String remoteId = p['userId'];
          //   if (!_remoteParticipants.containsKey(remoteId)) {
          //     setState(() {
          //       _remoteParticipants[remoteId] = RemoteParticipant(
          //         userId: remoteId,
          //         userName: p['name'] ?? 'Unknown',
          //         renderer: RTCVideoRenderer(),
          //         producerId: p['[producerId'],
          //         isLocal: false,
          //       );
          //     });
          //   }
          // }

          _initialProducers = data['existingProducers'] ?? [];

          completer.complete(RtpCapabilities.fromMap(data['rtpCapabilities']));
        } else if (data != null && data['waiting'] == true) {
          completer.completeError("WAITING_FOR_HOST");
        } else {
          completer.completeError("Join failed");
        }
      },
    );
    return completer.future;
  }

  // Future<RtpCapabilities> joinRoomAndGetCapabilities() async {
  //   final completer = Completer<RtpCapabilities>();
  //
  //   logD("🛰️ Joining room: ${widget.roomId}");
  //
  //   widget.socketService.socket.emitWithAck('live-session:join', {
  //     'roomId': widget.roomId,
  //     'userId': widget.userName,
  //     'name': widget.userName,
  //     'role': widget.role,
  //   }, ack: (data) {
  //     if (data != null && data['success'] == true) {
  //       // We will handle existingProducers AFTER the device is loaded
  //       // so the transports are ready to consume.
  //       _initialProducers = data['existingProducers'] ?? [];
  //       completer.complete(RtpCapabilities.fromMap(data['rtpCapabilities']));
  //     } else {
  //       completer.completeError("Join failed or data null");
  //     }
  //   });
  //   return completer.future;
  // }

  Future<Map<String, dynamic>> fetchSendTransportParams() async {
    final completer = Completer<Map<String, dynamic>>();
    widget.socketService.emitWithAck(
      'mediasoup:create-transport',
      {'roomId': widget.roomId, 'direction': 'send'},
      ack: (data) => completer.complete(Map<String, dynamic>.from(data)),
    );
    return completer.future;
  }

  Future<Map<String, dynamic>> fetchRecvTransportParams() async {
    final completer = Completer<Map<String, dynamic>>();

    widget.socketService.emitWithAck(
      'mediasoup:create-transport',
      {'roomId': widget.roomId, 'direction': 'recv'},
      ack: (data) {
        logD("🎯 Recv Transport Ack received!");
        completer.complete(Map<String, dynamic>.from(data));
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw Exception("Recv Transport Timeout"),
    );
  }
}

// Scale-down feedback on press for control buttons. Listener is non-consuming,
// so the inner InkWell still receives the tap.
class _Pressable extends StatefulWidget {
  final Widget child;
  const _Pressable({required this.child});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// Small red "LIVE" dot with an expanding pulse ring (mirrors meeting.html).
class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const dot = Color(0xFFF87171);
    return SizedBox(
      width: 12,
      height: 12,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final t = _c.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - t).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 1 + t * 1.4,
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: dot,
                    ),
                  ),
                ),
              ),
              child!,
            ],
          );
        },
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: dot,
            ),
          ),
        ),
      ),
    );
  }
}
