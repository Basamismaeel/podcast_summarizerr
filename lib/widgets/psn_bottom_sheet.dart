import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/tokens.dart';

class PSNBottomSheet extends StatelessWidget {
  const PSNBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.showHandle = true,
  });

  final Widget child;
  final String? title;
  final bool showHandle;

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool showHandle = true,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: isScrollControlled,
      showDragHandle: false,
      useSafeArea: true,
      enableDrag: true,
      builder: (_) => PSNBottomSheet(
        title: title,
        showHandle: showHandle,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Strong blur is expensive on some Android GPUs; keep iOS/macOS richer.
    final blurSigma = switch (defaultTargetPlatform) {
      TargetPlatform.android => 14.0,
      TargetPlatform.iOS || TargetPlatform.macOS => 22.0,
      _ => 18.0,
    };

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Material(
          color: cs.surfaceContainerHigh.withValues(alpha: 0.92),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHandle)
                Padding(
                  padding: const EdgeInsets.only(top: Tokens.spaceSm),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Tokens.spaceMd,
                    Tokens.spaceMd,
                    Tokens.spaceMd,
                    Tokens.spaceSm,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title!,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              Flexible(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    Tokens.spaceMd,
                    title == null ? Tokens.spaceMd : 0,
                    Tokens.spaceMd,
                    MediaQuery.of(context).viewPadding.bottom + Tokens.spaceMd,
                  ),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
