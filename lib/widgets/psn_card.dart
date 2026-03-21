import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// Grouped-style surface; no heavy shadows (HIG).
class PSNCard extends StatelessWidget {
  const PSNCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Tokens.spaceMd),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final material = Material(
      color: cs.surfaceContainerLow,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );

    return AnimatedScale(
      scale: 1,
      duration: Tokens.durationFast,
      curve: Tokens.springCurve,
      child: material,
    );
  }
}
