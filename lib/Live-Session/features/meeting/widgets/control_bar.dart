import 'package:flutter/material.dart';

class ControlBar extends StatelessWidget {
  final bool micOn;
  final bool cameraOn;
  final bool screenSharing;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleScreenShare;
  final VoidCallback? onMarkAttendance;
  final VoidCallback onLeave;
  final int participantCount;

  const ControlBar({
    super.key,
    required this.micOn,
    required this.cameraOn,
    required this.screenSharing,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onToggleScreenShare,
    this.onMarkAttendance,
    required this.onLeave,
    required this.participantCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🎀 Participant Count Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people, color: Colors.pinkAccent, size: 16),
                SizedBox(width: 4),
                Text(
                  '$participantCount participants',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),

          // 🎀 Control Buttons Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 🎤 Mic Toggle
              _ControlButton(
                icon: micOn ? Icons.mic : Icons.mic_off,
                label: 'Mic',
                isActive: micOn,
                onTap: onToggleMic,
                color: micOn ? Colors.green : Colors.red,
              ),

              // 📷 Camera Toggle
              _ControlButton(
                icon: cameraOn ? Icons.videocam : Icons.videocam_off,
                label: 'Cam',
                isActive: cameraOn,
                onTap: onToggleCamera,
                color: cameraOn ? Colors.green : Colors.red,
              ),

              // 🖥️ Screen Share Toggle
              _ControlButton(
                icon: screenSharing ? Icons.stop_screen_share : Icons.screen_share,
                label: 'Share',
                isActive: screenSharing,
                onTap: onToggleScreenShare,
                color: screenSharing ? Colors.orange : Colors.purple,
              ),

              // 📝 Attendance (Teacher Only)
              if (onMarkAttendance != null)
                _ControlButton(
                  icon: Icons.checklist,
                  label: 'Attend',
                  isActive: true,
                  onTap: onMarkAttendance!,
                  color: Colors.blue,
                ),

              // 🚪 Leave Button (Big & Red!)
              _ControlButton(
                icon: Icons.call_end,
                label: 'Leave',
                isActive: true,
                onTap: onLeave,
                color: Colors.red,
                isLarge: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 🎀 Reusable Control Button Widget
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color color;
  final bool isLarge;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.color,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isLarge ? 28 : 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isLarge ? 56 : 48,
              height: isLarge ? 56 : 48,
              decoration: BoxDecoration(
                color: isActive ? color : Colors.grey,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: isLarge ? 12 : 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: isLarge ? 28 : 24,
              ),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}