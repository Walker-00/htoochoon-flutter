import 'dart:math';

import 'package:flutter/material.dart';

/// Holds the in-flight floating reactions. Call [add] when a reaction arrives
/// (locally or over the socket); each emoji animates up and removes itself.
class ReactionController extends ChangeNotifier {
  final List<ReactionItem> items = [];
  int _seq = 0;
  final _rng = Random();

  void add(String emoji) {
    final id = _seq++;
    final item = ReactionItem(id: id, emoji: emoji, xFactor: _rng.nextDouble());
    items.add(item);
    notifyListeners();
  }

  void remove(int id) {
    items.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}

class ReactionItem {
  final int id;
  final String emoji;
  final double xFactor; // 0..1 horizontal position
  ReactionItem({required this.id, required this.emoji, required this.xFactor});
}

/// Renders floating emoji reactions rising from the bottom and fading out.
/// Place inside the meeting [Stack] (it expands to fill).
class ReactionOverlay extends StatelessWidget {
  final ReactionController controller;
  const ReactionOverlay({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return Stack(
              children: controller.items
                  .map((item) => _FloatingEmoji(
                        key: ValueKey(item.id),
                        item: item,
                        onDone: () => controller.remove(item.id),
                      ))
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}

class _FloatingEmoji extends StatefulWidget {
  final ReactionItem item;
  final VoidCallback onDone;
  const _FloatingEmoji({super.key, required this.item, required this.onDone});

  @override
  State<_FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<_FloatingEmoji>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final double _drift;

  @override
  void initState() {
    super.initState();
    _drift = (widget.item.xFactor - 0.5) * 60; // slight horizontal sway
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final bottom = 90 + t * (size.height * 0.55);
        final opacity = t < 0.15 ? t / 0.15 : (1 - ((t - 0.15) / 0.85)).clamp(0.0, 1.0);
        final left = size.width * (0.2 + widget.item.xFactor * 0.6) + _drift * t;
        final scale = 0.7 + 0.6 * (t < 0.3 ? t / 0.3 : 1);
        return Positioned(
          bottom: bottom,
          left: left,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Text(widget.item.emoji, style: const TextStyle(fontSize: 34)),
            ),
          ),
        );
      },
    );
  }
}

/// Horizontal emoji picker shown above the control bar.
class ReactionBar extends StatelessWidget {
  final void Function(String emoji) onPick;
  const ReactionBar({super.key, required this.onPick});

  static const emojis = ['❤️', '🎉', '👍', '👏', '😂', '🙌', '🔥', '😮'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: emojis
            .map((e) => InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onPick(e),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(e, style: const TextStyle(fontSize: 26)),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
