import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/podcast_home_colors.dart';
import '../core/tokens.dart';

class PSNBottomSheet extends StatelessWidget {
  const PSNBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.showHandle = true,

    /// Max fraction of usable viewport height (e.g. 0.72 for dense forms that must not scroll).
    this.maxHeightFraction = 0.52,
  });

  final Widget child;
  final String? title;
  final bool showHandle;
  final double maxHeightFraction;

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
      builder: (_) =>
          PSNBottomSheet(title: title, showHandle: showHandle, child: child),
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

    final mq = MediaQuery.of(context);
    // Space above keyboard — never treat the sheet as “almost full screen”.
    final availableMain =
        (mq.size.height - mq.viewInsets.bottom - mq.padding.vertical).clamp(
          240.0,
          mq.size.height,
        );
    final frac = maxHeightFraction.clamp(0.35, 0.92);
    final maxSheetHeight = availableMain * frac;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetTint = isDark
        ? PodcastHomeColors.card(context).withValues(alpha: 0.94)
        : cs.surfaceContainerHigh.withValues(alpha: 0.94);

    final sheetRows = <Widget Function()>[
      if (showHandle)
        () => Padding(
          padding: const EdgeInsets.only(top: Tokens.spaceSm),
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      if (title != null)
        () => Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.spaceMd,
            Tokens.spaceMd,
            Tokens.spaceMd,
            Tokens.spaceSm,
          ),
          child: Text(
            title!,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: isDark ? PodcastHomeColors.title(context) : null,
            ),
          ),
        ),
      () => Padding(
        padding: EdgeInsets.fromLTRB(
          Tokens.spaceMd,
          title == null ? Tokens.spaceMd : 0,
          Tokens.spaceMd,
          mq.viewPadding.bottom + Tokens.spaceMd,
        ),
        child: child,
      ),
    ];

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Material(
            color: sheetTint,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.zero,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: false,
                cacheExtent: 500,
                itemCount: sheetRows.length,
                itemBuilder: (context, index) => sheetRows[index](),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
