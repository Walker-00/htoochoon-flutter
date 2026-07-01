import 'package:flutter/material.dart';

/// Fixed height for KPI grid tiles. Pair with [SliverGridDelegateWithFixedCrossAxisCount.mainAxisExtent]
/// so cards stay compact regardless of how wide the column gets (no giant empty
/// blocks on desktop).
const double kStatCardExtent = 118;

/// Compact, colored KPI card for data-dense LMS dashboards.
///
/// - Tinted surface + colored icon chip so each metric reads at a glance
///   instead of being a flat grey slab.
/// - Count-up animation on the number (motion conveys the value growing).
/// - Subtle staggered fade/slide entrance (driven by [index]).
/// - Honors the platform "reduce motion" setting.
class AnimatedStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final int index;
  final VoidCallback? onTap;

  const AnimatedStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.index = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final card = Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.07), cs.surface),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          _CountUpText(
            value,
            reduce: reduce,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.0,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    final content = onTap == null
        ? card
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: card,
            ),
          );

    if (reduce) return content;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + index * 55),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: child,
        ),
      ),
      child: content,
    );
  }
}

/// Animates a numeric value from 0 to its target, preserving any prefix/suffix
/// (e.g. "72%", "$1.2k"). Falls back to plain text for non-numeric values ("—").
class _CountUpText extends StatelessWidget {
  final String raw;
  final TextStyle style;
  final bool reduce;
  const _CountUpText(this.raw, {required this.style, required this.reduce});

  @override
  Widget build(BuildContext context) {
    final m = RegExp(r'^(\D*)(\d+(?:\.\d+)?)(.*)$').firstMatch(raw);
    if (m == null || reduce) {
      return Text(raw, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final prefix = m.group(1) ?? '';
    final target = double.tryParse(m.group(2) ?? '') ?? 0;
    final suffix = m.group(3) ?? '';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(
        '$prefix${v.round()}$suffix',
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Builds a fixed-height KPI grid from [AnimatedStatCard]s — compact rows that
/// never stretch into oversized blocks. [crossAxisCount] is caller-controlled
/// so it can adapt to width.
class StatCardGrid extends StatelessWidget {
  final List<AnimatedStatCard> cards;
  final int crossAxisCount;
  const StatCardGrid({
    super.key,
    required this.cards,
    required this.crossAxisCount,
  });

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: kStatCardExtent,
      ),
      children: cards,
    );
  }
}
