import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Theme/peacock_logo.dart';

/// Shown while a student waits for the host to start/return.
class WaitingRoomView extends StatelessWidget {
  final String topic;
  final VoidCallback onLeave;
  const WaitingRoomView({super.key, required this.topic, required this.onLeave});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const PeacockLogoLockup(markSize: 96, title: 'Htoo Choon', mono: true),
              const SizedBox(height: 28),
              Text(
                topic,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text('Waiting for the host to start the session…',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(height: 36),
              TextButton.icon(
                onPressed: onLeave,
                icon: const Icon(Icons.logout, color: Colors.white70),
                label:
                    const Text('Leave', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
