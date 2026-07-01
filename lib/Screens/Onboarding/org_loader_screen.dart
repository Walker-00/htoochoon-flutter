import 'dart:async';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Theme/peacock_logo.dart';

class OrgLoaderScreen extends StatefulWidget {
  final Future<void> Function()? onLoadAction;

  const OrgLoaderScreen({super.key, this.onLoadAction});

  static Future<void> show(
    BuildContext context, {
    Future<void> Function()? action,
  }) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, __) => OrgLoaderScreen(onLoadAction: action),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<OrgLoaderScreen> createState() => _OrgLoaderScreenState();
}

class _OrgLoaderScreenState extends State<OrgLoaderScreen> {
  late Timer _textTimer;
  int _textIndex = 0;

  // 🌟 Warm, friendly micro-copy phrases to cycle through
  final List<String> _loadingPhrases = [
    "Setting up your workspace...",
    "Gathering your classes...",
    "Connecting with your academy...",
    "Almost there, getting things ready...",
  ];

  @override
  void initState() {
    super.initState();
    _startTextRotation();
    _runLoadingSequence();
  }

  @override
  void dispose() {
    _textTimer.cancel(); // 🧼 Clean up timer loops safely
    super.dispose();
  }

  void _startTextRotation() {
    _textTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (mounted && _textIndex < _loadingPhrases.length - 1) {
        setState(() {
          _textIndex++;
        });
      }
    });
  }

  Future<void> _runLoadingSequence() async {
    await Future.wait([
      if (widget.onLoadAction != null) widget.onLoadAction!(),
      Future.delayed(
        Duration(milliseconds: 2400),
      ), // Slightly extended for reading comfort
    ]);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── 🦚 Peacock brand splash mark ────────────────
              const PeacockLogoLockup(markSize: 116, title: 'Htoo Choon'),

              const SizedBox(height: 28),

              // ── User-Friendly Animated Subtitle ──────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.1),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  _loadingPhrases[_textIndex],
                  key: ValueKey<int>(
                    _textIndex,
                  ), // Forces AnimatedSwitcher to register changes
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.7),
                    letterSpacing: 0.2,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Minor Soft Loading Feedback ──────────────────
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    cs.primary.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
