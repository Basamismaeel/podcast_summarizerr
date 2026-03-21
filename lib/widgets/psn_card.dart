import 'package:flutter/material.dart';

import '../core/tokens.dart';

class PSNCard extends StatefulWidget {
  const PSNCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.glowColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? glowColor;

  @override
  State<PSNCard> createState() => _PSNCardState();
}

class _PSNCardState extends State<PSNCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => _setPressed(true) : null,
      onTapUp: widget.onTap != null ? (_) => _setPressed(false) : null,
      onTapCancel: widget.onTap != null ? () => _setPressed(false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.99 : 1.0,
        duration: const Duration(milliseconds: 50),
        child: AnimatedContainer(
          duration: Tokens.durationFast,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: Tokens.bgSurface,
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
            border: Border.all(color: Tokens.borderLight, width: 1),
            boxShadow: [
              Tokens.cardShadow,
              if (widget.glowColor != null)
                BoxShadow(
                  color: widget.glowColor!.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: -4,
                ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }

  void _setPressed(bool value) => setState(() => _pressed = value);
}
