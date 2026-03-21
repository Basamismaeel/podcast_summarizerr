import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/tokens.dart';

enum ButtonVariant { primary, secondary, ghost, danger }

enum ButtonSize { sm, md, lg }

class PSNButton extends StatefulWidget {
  const PSNButton({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.md,
    this.icon,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final ButtonVariant variant;
  final ButtonSize size;
  final Widget? icon;
  final bool fullWidth;

  @override
  State<PSNButton> createState() => _PSNButtonState();
}

class _PSNButtonState extends State<PSNButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _pressed = false;

  bool get _disabled => widget.onTap == null || widget.isLoading;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _height => switch (widget.size) {
        ButtonSize.sm => 36.0,
        ButtonSize.md => 48.0,
        ButtonSize.lg => 56.0,
      };

  EdgeInsets get _padding => switch (widget.size) {
        ButtonSize.sm => const EdgeInsets.symmetric(horizontal: 16),
        ButtonSize.md => const EdgeInsets.symmetric(horizontal: 20),
        ButtonSize.lg => const EdgeInsets.symmetric(horizontal: 24),
      };

  double get _fontSize => switch (widget.size) {
        ButtonSize.sm => 13.0,
        ButtonSize.md => 15.0,
        ButtonSize.lg => 16.0,
      };

  Color get _bg => switch (widget.variant) {
        ButtonVariant.primary => Tokens.accent,
        ButtonVariant.secondary => Tokens.bgElevated,
        ButtonVariant.ghost => Colors.transparent,
        ButtonVariant.danger => Tokens.errorDim,
      };

  Color get _pressedBg => switch (widget.variant) {
        ButtonVariant.primary =>
          HSLColor.fromColor(Tokens.accent).withLightness(0.38).toColor(),
        ButtonVariant.secondary => Tokens.bgOverlay,
        ButtonVariant.ghost => Tokens.bgElevated,
        ButtonVariant.danger => Tokens.errorDim,
      };

  Color get _fg => switch (widget.variant) {
        ButtonVariant.primary => Colors.white,
        ButtonVariant.secondary => Colors.white,
        ButtonVariant.ghost => Tokens.accent,
        ButtonVariant.danger => Tokens.error,
      };

  BorderSide get _border => switch (widget.variant) {
        ButtonVariant.primary => BorderSide.none,
        ButtonVariant.secondary =>
          const BorderSide(color: Tokens.borderMedium, width: 1),
        ButtonVariant.ghost => BorderSide.none,
        ButtonVariant.danger =>
          BorderSide(color: Tokens.error.withValues(alpha: 0.3), width: 1),
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: child,
        );
      },
      child: Opacity(
        opacity: _disabled ? 0.4 : 1.0,
        child: GestureDetector(
          onTapDown: _disabled ? null : (_) => _onPressDown(),
          onTapUp: _disabled ? null : (_) => _onPressUp(),
          onTapCancel: _disabled ? null : _onPressUp,
          onTap: _disabled ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            height: _height,
            padding: _padding,
            constraints: widget.fullWidth
                ? const BoxConstraints(minWidth: double.infinity)
                : null,
            decoration: BoxDecoration(
              color: _pressed ? _pressedBg : _bg,
              borderRadius: BorderRadius.circular(Tokens.radiusMd),
              border: Border.fromBorderSide(_border),
            ),
            child: Center(
              widthFactor: widget.fullWidth ? null : 1.0,
              child: widget.isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _fg,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          widget.icon!,
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.label,
                          style: GoogleFonts.dmSans(
                            fontSize: _fontSize,
                            fontWeight: FontWeight.w600,
                            color: _fg,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _onPressDown() {
    setState(() => _pressed = true);
    _controller.forward();
  }

  void _onPressUp() {
    setState(() => _pressed = false);
    _controller.reverse();
  }
}
