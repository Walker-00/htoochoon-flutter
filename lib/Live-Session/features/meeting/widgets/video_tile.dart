import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VideoTile extends StatefulWidget {
  final RTCVideoRenderer? renderer;
  final String label;
  final bool isLocal;
  final bool isTeacher;
  final bool isVideoEnabled;
  final bool isAudioEnabled;
  final bool isHandRaised;
  final bool isTalking;
  final VoidCallback? onToggleFullscreen;
  final bool isFullscreen;
  final bool isRecording;
  final VoidCallback? onToggleRecording;
  final bool isScreenShare;

  const VideoTile({
    super.key, // Expects standard ValueKey(userId) passed down cleanly from VideoGrid!
    required this.renderer,
    required this.label,
    required this.isLocal,
    required this.isTeacher,
    this.isVideoEnabled = true,
    this.isAudioEnabled = true,
    this.isHandRaised = false,
    this.isTalking = false,
    this.onToggleFullscreen,
    this.isFullscreen = false,
    this.isRecording = false,
    this.onToggleRecording,
    this.isScreenShare = false,
  });

  @override
  State<VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends State<VideoTile> {
  // Manual rotation correction (quarter turns). Some Android senders ship video
  // whose orientation metadata is wrong, so a peer can arrive rotated 90°/180°.
  // The viewer can tap the rotate button to straighten that tile; the root
  // cause is device/codec-specific and can't be detected reliably here.
  int _rotation = 0;

  @override
  void didUpdateWidget(covariant VideoTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 🛰️ If the grid cell updates or returns from fullscreen, re-signal the decoder engine
    if (widget.renderer != oldWidget.renderer && widget.renderer != null && !widget.isLocal) {
      _requestDecoderKeyframe();
    }
  }

  @override
  void dispose() {
    // 🧼 REMOVED: widget.renderer?.srcObject = null;
    // Clearing this here breaks parent rendering states when layout toggles occur!
    super.dispose();
  }

  void _requestDecoderKeyframe() {
    try {
      // Wakes up any paused OpenH264 stream pipes immediately upon redraw
      widget.renderer?.srcObject?.getVideoTracks().forEach((track) {
        track.enabled = widget.isVideoEnabled;
      });
    } catch (e) {
      debugPrint("⚠️ Stream wake hardware handshake skipped: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Robust validation check ensuring we don't accidentally check dead array pointers
    final bool hasValidStream = widget.renderer != null &&
        widget.renderer!.srcObject != null &&
        widget.renderer!.srcObject!.getVideoTracks().isNotEmpty;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(widget.isFullscreen ? 0 : 12),
        border: Border.all(
          color: widget.isTalking
              ? cs.tertiary
              : (widget.isTeacher
              ? cs.primary
              : (widget.isHandRaised ? cs.secondary : cs.outlineVariant)),
          width: widget.isTalking || widget.isTeacher ? 2.5 : 1.0,
        ),
        boxShadow: widget.isTalking
            ? [BoxShadow(color: cs.tertiary.withValues(alpha: 0.2), blurRadius: 10)]
            : null,
      ),
      child: Stack(
        fit: StackFit.loose,
        children: [
          if (widget.isVideoEnabled && hasValidStream)
          Positioned.fill(
            child: RotatedBox(
              quarterTurns: _rotation,
              child: RTCVideoView(
                widget.renderer!,
                objectFit: widget.isScreenShare
                    ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
                    : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                mirror: widget.isLocal && !widget.isScreenShare,
              ),
            ),
          )
          else
            _buildPlaceholder(),

          // --- INFO OVERLAYS ---
          _buildTopActions(),
          _buildBottomLabel(),
          if (widget.isHandRaised) _buildHandBadge(),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHigh,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: widget.isFullscreen ? 50 : 30,
              backgroundColor: widget.isTeacher
                  ? cs.primary.withValues(alpha: 0.12)
                  : cs.onSurface.withValues(alpha: 0.05),
              child: Text(
                widget.label.isNotEmpty ? widget.label[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: widget.isFullscreen ? 40 : 24,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (widget.isFullscreen) ...[
              const SizedBox(height: 16),
              Text(widget.label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 18)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildTopActions() {
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      top: 8,
      left: 8,
      child: Row(
        children: [
          if (!widget.isLocal && widget.onToggleFullscreen != null)
            GestureDetector(
              onTap: widget.onToggleFullscreen,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cs.scrim.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                // White icon: this sits on a dark scrim over live video, so a
                // fixed light foreground (not a theme surface token) is correct.
                child: const Icon(Icons.fullscreen, color: Colors.white, size: 18),
              ),
            ),
          // Rotate-correction: straighten a peer whose video arrives sideways.
          if (!widget.isLocal && !widget.isScreenShare && widget.isVideoEnabled)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: GestureDetector(
                onTap: () => setState(() => _rotation = (_rotation + 1) % 4),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.scrim.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.screen_rotation,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomLabel() {
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      bottom: 8,
      left: 8,
      right: 8,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: cs.scrim.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isTeacher)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.school, color: cs.primary, size: 14),
                  ),
                Flexible(
                  child: Text(
                    widget.label,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Screen Record / Projection Button Wire
              GestureDetector(
                onTap: widget.onToggleRecording, // 🔌 Added missing operational gesture link!
                child: Container(
                  padding: const EdgeInsets.all(6),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: widget.isRecording
                        ? cs.error.withValues(alpha: 0.8)
                        : cs.scrim.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.isRecording ? Icons.fiber_manual_record : Icons.screen_share,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),

              // Audio Status Icon
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: cs.scrim.withValues(alpha: 0.45), shape: BoxShape.circle),
                child: Icon(
                  widget.isAudioEnabled ? Icons.mic : Icons.mic_off,
                  color: widget.isAudioEnabled ? cs.tertiary : cs.error,
                  size: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHandBadge() {
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: cs.secondary,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: const Text('✋', style: TextStyle(fontSize: 14)),
      ),
    );
  }
}