import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../models/user_model.dart';
import 'video_tile.dart';

class VideoGrid extends StatelessWidget {
  final RTCVideoRenderer localRenderer;
  // Our own shared-screen preview tile (null unless we are sharing).
  final RTCVideoRenderer? localScreenRenderer;
  final List<UserModel> participants;
  final bool isTeacher;
  final Map<String, RTCVideoRenderer> consumerRenderers;
  final Map<String, bool> videoEnabledMap;
  final Map<String, bool> audioEnabledMap;
  // userIds whose tile is a screen share (rendered "contain", never mirrored).
  final Set<String> screenShareUserIds;
  final Function(String userId)? onToggleFullscreen;
  final Set<String> handRaisedUsers;
  final String? activeSpeakerId; // 🎤 Track who is currently talking
  final Function(String userId)? onRecordToggled;

  const VideoGrid({
    super.key,
    required this.localRenderer,
    this.localScreenRenderer,
    required this.participants,
    this.isTeacher = false,
    this.consumerRenderers = const {},
    this.videoEnabledMap = const {},
    this.audioEnabledMap = const {},
    this.screenShareUserIds = const {},
    this.onToggleFullscreen,
    this.handRaisedUsers = const {},
    this.activeSpeakerId,
    this.onRecordToggled,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Convert everything to a unified list for sorting
    final List<_VideoItemData> allItems = [
      _VideoItemData(
        userId: 'local',
        label: 'You 🎀',
        isLocal: true,
        isTeacher: isTeacher,
        renderer: localRenderer,
        isVideoEnabled: true,
        isAudioEnabled: true,
      ),
      // Our own screen, when sharing, as a dedicated tile next to our camera.
      if (localScreenRenderer != null)
        _VideoItemData(
          userId: 'local-screen',
          label: 'Your screen 🖥️',
          isLocal: true,
          isTeacher: isTeacher,
          renderer: localScreenRenderer,
          isVideoEnabled: true,
          isAudioEnabled: true,
          isScreen: true,
        ),
      ...participants.map((p) => _VideoItemData(
        userId: p.id,
        label: p.name,
        isLocal: false,
        isTeacher: p.role == UserRole.teacher,
        renderer: consumerRenderers[p.id],
        isVideoEnabled: videoEnabledMap[p.id] ?? true,
        isAudioEnabled: audioEnabledMap[p.id] ?? true,
        isScreen: screenShareUserIds.contains(p.id),
      )),
    ];

    // 2. 🛰️ ZOOM SORTING ALGORITHM
    allItems.sort((a, b) {
      // Priority 0: Screen shares get the spotlight (that's the point of sharing).
      if (a.isScreen != b.isScreen) return a.isScreen ? -1 : 1;
      // Priority 2: Active Speaker
      if (a.userId == activeSpeakerId) return -1;
      if (b.userId == activeSpeakerId) return 1;

      // Priority 3: Hand Raised
      bool aHand = handRaisedUsers.contains(a.userId);
      bool bHand = handRaisedUsers.contains(b.userId);
      if (aHand != bHand) return bHand ? 1 : -1;

      // Priority 4: Teachers
      if (a.isTeacher != b.isTeacher) return b.isTeacher ? 1 : -1;

      // Priority 5: Video On vs Video Off
      if (a.isVideoEnabled != b.isVideoEnabled) return b.isVideoEnabled ? 1 : -1;

      return 0;
    });

    // 3. Separate into "Spotlight" (Top 1-2) and "Gallery"
    final spotlightItems = allItems.take(allItems.length > 1 ? 2 : 1).toList();
    final galleryItems = allItems.skip(spotlightItems.length).toList();

    return CustomScrollView(
      slivers: [
        // --- SPOTLIGHT SECTION ---
        SliverPadding(
          padding: const EdgeInsets.all(8.0),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: spotlightItems.length == 1 ? 1 : 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: spotlightItems.length == 1 ? 16/9 : 1.2,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildTile(spotlightItems[index], isSpotlight: true),
              childCount: spotlightItems.length,
            ),
          ),
        ),

        // --- GALLERY SECTION ---
        if (galleryItems.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 250, // Smaller tiles for others
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 16 / 10,
              ),
              delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildTile(galleryItems[index]),
                childCount: galleryItems.length,
              ),
            ),
          ),

        // Add bottom padding for controls
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildTile(_VideoItemData item, {bool isSpotlight = false}) {
    return VideoTile(
      // key: ValueKey(item.userId),
      // renderer: item.renderer,
      // label: item.label,
      isLocal: item.isLocal,
      isTeacher: item.isTeacher,
      isVideoEnabled: item.isVideoEnabled,
      key: ValueKey(item.userId),
      renderer: item.renderer,
      label: item.label,
      isAudioEnabled: item.isAudioEnabled,
      isHandRaised: handRaisedUsers.contains(item.userId),
      isTalking: item.userId == activeSpeakerId,
      isScreenShare: item.isScreen,

      // ➕ Pass the new recording states down here
      isRecording: item.isRecording,
      onToggleRecording: () {
        // Pass the event straight back out to the parent page handler
        onRecordToggled?.call(item.userId);
      },

      onToggleFullscreen: item.isLocal
          ? null
          : () => onToggleFullscreen?.call(item.userId),
    );
  }
}

class _VideoItemData {
  final String userId;
  final String label;
  final dynamic renderer; // or RTCVideoRenderer
  final bool isLocal;
  final bool isTeacher;
  final bool isVideoEnabled;
  final bool isAudioEnabled;
  final bool isRecording; // ➕ Add this
  final bool isScreen;

  _VideoItemData({
    required this.userId,
    required this.label,
    this.renderer,
    this.isLocal = false,
    this.isTeacher = false,
    this.isVideoEnabled = true,
    this.isAudioEnabled = true,
    this.isRecording = false, // ➕ Default to false
    this.isScreen = false,
  });
}