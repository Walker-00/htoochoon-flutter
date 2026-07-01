// lib/features/meeting/widgets/hand_raise_indicator.dart
import 'package:flutter/material.dart';

class HandRaiseIndicator extends StatefulWidget {
  final String userName;
  final VoidCallback? onLowerHand;
  final bool isSelf;

  const HandRaiseIndicator({
    super.key,
    required this.userName,
    this.onLowerHand,
    this.isSelf = false,
  });

  @override
  State<HandRaiseIndicator> createState() => _HandRaiseIndicatorState();
}

class _HandRaiseIndicatorState extends State<HandRaiseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true); // ✨ Cute waving loop~

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.isSelf
                  ? Colors.purpleAccent.withValues(alpha: 0.9) // Different color for self~
                  : Colors.pinkAccent.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (widget.isSelf ? Colors.purpleAccent : Colors.pinkAccent)
                      .withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.pinkAccent.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pinkAccent.withValues(alpha: 0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✋ Animated waving hand emoji~
                  const Text('👋', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.userName} wants to speak~',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ✨ Lower hand button for teachers
                  if (widget.onLowerHand != null)
                    InkWell(
                      onTap: widget.onLowerHand,
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}