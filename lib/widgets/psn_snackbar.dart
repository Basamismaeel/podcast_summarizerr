import 'dart:async';

import 'package:flutter/material.dart';

import '../core/tokens.dart';

enum PSNSnackbarType { success, error, info }

class PSNSnackbar extends StatefulWidget {
  const PSNSnackbar._({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  final String message;
  final PSNSnackbarType type;
  final VoidCallback onDismiss;

  static void show(
    BuildContext context,
    String message,
    PSNSnackbarType type,
  ) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => PSNSnackbar._(
        message: message,
        type: type,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }

  @override
  State<PSNSnackbar> createState() => _PSNSnackbarState();
}

class _PSNSnackbarState extends State<PSNSnackbar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Tokens.durationNormal,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Tokens.springCurve,
      ),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Tokens.springCurve,
    );

    _controller.forward();
    _autoDismiss = Timer(const Duration(seconds: 3), _dismiss);
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismiss();
  }

  Color _accentColor(ColorScheme cs) => switch (widget.type) {
        PSNSnackbarType.success => cs.tertiary,
        PSNSnackbarType.error => cs.error,
        PSNSnackbarType.info => cs.primary,
      };

  IconData get _icon => switch (widget.type) {
        PSNSnackbarType.success => Icons.check_circle_outline_rounded,
        PSNSnackbarType.error => Icons.error_outline_rounded,
        PSNSnackbarType.info => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = _accentColor(cs);

    return Positioned(
      top: top + Tokens.spaceSm,
      left: Tokens.spaceMd,
      right: Tokens.spaceMd,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! < -200) {
                _dismiss();
              }
            },
            child: Material(
              elevation: 1,
              shadowColor: Colors.black26,
              color: cs.surfaceContainerHigh,
              surfaceTintColor: Colors.transparent,
              borderRadius: BorderRadius.circular(Tokens.radiusMd),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.spaceMd,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 32,
                      margin: const EdgeInsets.only(right: Tokens.spaceSm),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Icon(_icon, color: accent, size: 22),
                    const SizedBox(width: Tokens.spaceSm),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
