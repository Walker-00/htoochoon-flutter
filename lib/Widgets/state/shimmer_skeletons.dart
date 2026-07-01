import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton loaders shown while content loads (>300ms). Reserve the same
/// approximate layout as the real content to avoid layout shift (UX §3 CLS).
/// All variants use theme-derived shimmer colors so they read in light + dark.

Widget _shimmer(BuildContext context, Widget child) {
  final cs = Theme.of(context).colorScheme;
  final base = cs.surfaceContainerHighest;
  final highlight = Color.alphaBlend(cs.surface.withValues(alpha: 0.6), base);
  return Shimmer.fromColors(
    baseColor: base,
    highlightColor: highlight,
    child: child,
  );
}

BoxDecoration _box(BuildContext context, [double radius = 8]) => BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(radius),
    );

/// Vertical list of placeholder rows (avatar + two text lines).
class ShimmerList extends StatelessWidget {
  final int rows;
  final EdgeInsets padding;
  const ShimmerList({super.key, this.rows = 6, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return _shimmer(
      context,
      ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rows,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, __) => Row(
          children: [
            Container(width: 48, height: 48,
                decoration: _box(context, 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: double.infinity, height: 14, decoration: _box(context)),
                  const SizedBox(height: 8),
                  Container(width: 160, height: 12, decoration: _box(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid of placeholder cards.
class ShimmerCardGrid extends StatelessWidget {
  final int count;
  final int columns;
  const ShimmerCardGrid({super.key, this.count = 6, this.columns = 2});

  @override
  Widget build(BuildContext context) {
    return _shimmer(
      context,
      GridView.builder(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        itemCount: count,
        itemBuilder: (_, __) => Container(decoration: _box(context, 16)),
      ),
    );
  }
}

/// Detail screen placeholder (header block + body lines).
class ShimmerDetail extends StatelessWidget {
  const ShimmerDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return _shimmer(
      context,
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: double.infinity, height: 160, decoration: _box(context, 16)),
            const SizedBox(height: 20),
            Container(width: 220, height: 20, decoration: _box(context)),
            const SizedBox(height: 12),
            for (var i = 0; i < 5; i++) ...[
              Container(width: double.infinity, height: 12, decoration: _box(context)),
              const SizedBox(height: 10),
            ],
            Container(width: 180, height: 12, decoration: _box(context)),
          ],
        ),
      ),
    );
  }
}

/// Chart placeholder (axis frame + bars), for analytics screens.
class ShimmerChart extends StatelessWidget {
  final double height;
  const ShimmerChart({super.key, this.height = 200});

  @override
  Widget build(BuildContext context) {
    return _shimmer(
      context,
      Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final h in [0.5, 0.8, 0.35, 0.95, 0.6, 0.75, 0.45]) ...[
                Expanded(
                  child: Container(
                    height: height * h,
                    decoration: _box(context, 6),
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
