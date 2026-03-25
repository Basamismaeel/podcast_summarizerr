import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/tokens.dart';

enum ButtonVariant {
  primary,
  /// Deep navy fill + soft shadow (premium primary actions).
  primaryDark,
  secondary,
  ghost,
  danger,
}

enum ButtonSize { sm, md, lg }

/// HIG-aligned buttons: Material 3, 44pt minimum touch target, system colors.
class PSNButton extends StatelessWidget {
  const PSNButton({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.isDisabled = false,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.md,
    this.icon,
    this.fullWidth = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  /// When true, the button is non-interactive (same as null [onTap]).
  final bool isDisabled;
  final ButtonVariant variant;
  final ButtonSize size;
  final Widget? icon;
  final bool fullWidth;
  /// Accessibility for icon-only usage.
  final String? semanticLabel;

  bool get _disabled => isDisabled || onTap == null || isLoading;

  EdgeInsets get _pad => switch (size) {
        ButtonSize.sm => const EdgeInsets.symmetric(horizontal: 12),
        ButtonSize.md => const EdgeInsets.symmetric(horizontal: 16),
        ButtonSize.lg => const EdgeInsets.symmetric(horizontal: 20),
      };

  void _handleTap() {
    if (_disabled) return;
    higLightTap();
    onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final child = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: switch (variant) {
                ButtonVariant.primary => cs.onPrimary,
                ButtonVariant.primaryDark => Colors.white,
                ButtonVariant.danger => cs.onError,
                _ => cs.primary,
              },
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                IconTheme.merge(
                  data: IconThemeData(size: 20),
                  child: icon!,
                ),
                const SizedBox(width: Tokens.spaceSm),
              ],
              Text(
                label,
                style: tt.labelLarge?.copyWith(
                  fontWeight: variant == ButtonVariant.ghost
                      ? FontWeight.w400
                      : FontWeight.w600,
                ),
              ),
            ],
          );

    Widget button;
    switch (variant) {
      case ButtonVariant.primary:
        button = FilledButton(
          onPressed: _disabled ? null : _handleTap,
          style: FilledButton.styleFrom(
            minimumSize: const Size(Tokens.minTap, Tokens.minTap),
            padding: _pad,
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
          ),
          child: child,
        );
        break;
      case ButtonVariant.primaryDark:
        const top = Color(0xFF1D4ED8);
        const bottom = Color(0xFF172554);
        button = Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _disabled ? null : _handleTap,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _disabled
                      ? [cs.surfaceContainerHighest, cs.surfaceContainerHigh]
                      : const [top, bottom],
                ),
                boxShadow: _disabled
                    ? null
                    : [
                        BoxShadow(
                          color: bottom.withValues(alpha: 0.55),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: Align(
                alignment: Alignment.center,
                widthFactor: fullWidth ? null : 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: Tokens.minTap,
                    minHeight: 52,
                  ),
                  child: Padding(
                    padding: _pad,
                    child: Center(
                      child: DefaultTextStyle.merge(
                        style: tt.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _disabled
                              ? cs.onSurfaceVariant
                              : Colors.white,
                        ),
                        child: IconTheme.merge(
                          data: IconThemeData(
                            size: 20,
                            color: _disabled
                                ? cs.onSurfaceVariant
                                : Colors.white,
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        break;
      case ButtonVariant.secondary:
        button = OutlinedButton(
          onPressed: _disabled ? null : _handleTap,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(Tokens.minTap, Tokens.minTap),
            padding: _pad,
            foregroundColor: cs.primary,
            side: BorderSide(color: cs.outline),
          ),
          child: child,
        );
        break;
      case ButtonVariant.ghost:
        button = TextButton(
          onPressed: _disabled ? null : _handleTap,
          style: TextButton.styleFrom(
            minimumSize: const Size(Tokens.minTap, Tokens.minTap),
            padding: _pad,
            foregroundColor: cs.primary,
          ),
          child: child,
        );
        break;
      case ButtonVariant.danger:
        button = FilledButton(
          onPressed: _disabled ? null : _handleTap,
          style: FilledButton.styleFrom(
            minimumSize: const Size(Tokens.minTap, Tokens.minTap),
            padding: _pad,
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
          child: child,
        );
        break;
    }

    if (semanticLabel != null) {
      button = Semantics(
        button: true,
        label: semanticLabel,
        child: button,
      );
    }

    final wrapped = _PressScale(child: button);

    if (fullWidth) {
      return SizedBox(
        width: double.infinity,
        child: wrapped,
      );
    }
    return wrapped;
  }
}

class _PressScale extends StatefulWidget {
  const _PressScale({required this.child});

  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: _down
            ? const Duration(milliseconds: 80)
            : const Duration(milliseconds: 150),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
