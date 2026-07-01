// lib/features/meeting/screens/fullscreen_meeting_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:htoochoon_flutter/Live-Session/features/meeting/widgets/video_grid.dart';
import 'package:htoochoon_flutter/Live-Session/features/meeting/widgets/video_tile.dart';

class FullscreenMeetingView extends StatefulWidget {
  final String focusedUserId;
  final String focusedUserName;
  final RTCVideoRenderer? focusedRenderer;
  final bool isFocusedVideoEnabled;
  final bool isFocusedAudioEnabled;
  final Map<String, RTCVideoRenderer>
  otherRenderers; // ✅ Keep these for AUDIO only!
  final VoidCallback onExitFullscreen;
  final bool isFocusedUserTeacher;

  const FullscreenMeetingView({
    super.key,
    required this.focusedUserId,
    required this.focusedUserName,
    required this.isFocusedUserTeacher,
    required this.focusedRenderer,
    required this.isFocusedVideoEnabled,
    required this.isFocusedAudioEnabled,
    required this.otherRenderers,
    required this.onExitFullscreen,
  });

  @override
  State<FullscreenMeetingView> createState() => _FullscreenMeetingViewState();
}

class _FullscreenMeetingViewState extends State<FullscreenMeetingView> {
  // ✅ CRITICAL: Keep all remote audio tracks playing!
  // The RTCVideoRenderer for audio-only streams should still be initialized
  // but not rendered visually~ ✨

  @override
  void dispose() {
    // ✅ Don't dispose otherRenderers here! They're managed by parent.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🎬 Main Focused Video (or placeholder)
          VideoTile(
            renderer: widget.focusedRenderer,
            label: widget.focusedUserName,
            isLocal: false,
            isTeacher: false, // Pass real value~
            isVideoEnabled: widget.isFocusedVideoEnabled,
            isAudioEnabled: widget.isFocusedAudioEnabled,
            isFullscreen: true,
          ),

          // 🎀 Top Bar with Exit Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onExitFullscreen,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back, color: Colors.white, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'Exit Fullscreen',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 💡 Hint: Other participants' audio is still playing~ ✨
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '🔊 Listening to all participants~ ✧',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
