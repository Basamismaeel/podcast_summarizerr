import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../core/tokens.dart';

class PSNSkeleton extends StatelessWidget {
  const PSNSkeleton({
    super.key,
    this.lines = 3,
    this.lineHeight = 14,
    this.spacing = 12,
  });

  final int lines;
  final double lineHeight;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.surfaceContainerHighest;
    final highlight = cs.surfaceContainerHigh;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(lines, (i) {
          final isLast = i == lines - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : spacing),
            child: Container(
              height: lineHeight,
              width: isLast ? 160 : double.infinity,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(Tokens.radiusSm),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class PSNSkeletonCard extends StatelessWidget {
  const PSNSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.surfaceContainerHighest;
    final highlight = cs.surfaceContainerHigh;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          border: Border.all(color: cs.outlineVariant),
        ),
      ),
    );
  }
}
