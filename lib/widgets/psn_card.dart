import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// Grouped-style surface; no heavy shadows (HIG). Use [PSNCard.glass] for frosted glass.
class PSNCard extends StatelessWidget {
  const PSNCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Tokens.spaceMd),
  }) : _glass = false;

  const PSNCard.glass({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Tokens.spaceMd),
  }) : _glass = true;

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final bool _glass;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_glass) {
      final clip = ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Material(
            color: Colors.white.withValues(alpha: 0.05),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Tokens.radiusMd),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(Tokens.radiusMd),
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      );
      return clip;
    }

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
