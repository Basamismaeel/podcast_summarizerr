import 'package:flutter/material.dart';

import 'podcast_dark_tokens.dart';

/// Podcast home / shell: [PodcastDarkTokens] in dark mode, [ColorScheme] in light mode.
abstract final class PodcastHomeColors {
  static bool _dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color scaffold(BuildContext context) => _dark(context)
      ? PodcastDarkTokens.bgDeep
      : Theme.of(context).colorScheme.surface;

  static Color label(BuildContext context) => _dark(context)
      ? PodcastDarkTokens.label
      : Theme.of(context).colorScheme.onSurface;

  static Color meta(BuildContext context) => _dark(context)
      ? PodcastDarkTokens.meta
      : Theme.of(context).colorScheme.onSurfaceVariant;

  static Color title(BuildContext context) => _dark(context)
      ? PodcastDarkTokens.title
      : Theme.of(context).colorScheme.onSurface;

  static Color card(BuildContext context) => _dark(context)
      ? PodcastDarkTokens.card
      : Theme.of(context).colorScheme.surfaceContainerLow;

  static Color accent(BuildContext context) => _dark(context)
      ? PodcastDarkTokens.accent
      : Theme.of(context).colorScheme.primary;

  static Color borderSubtle(BuildContext context) => _dark(context)
      ? PodcastDarkTokens.borderSubtle
      : Theme.of(context).colorScheme.outlineVariant;

  static Color chipFill(BuildContext context) => _dark(context)
      ? PodcastDarkTokens.chipFill
      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);

  static Color miniBarBg(BuildContext context) => _dark(context)
      ? PodcastDarkTokens.miniBarBg
      : Theme.of(context).colorScheme.surfaceContainer;

  static Color bottomNavBg(BuildContext context) => _dark(context)
      ? PodcastDarkTokens.bottomNavBg
      : Theme.of(context).colorScheme.surfaceContainer;

  static BoxDecoration quickNavCardDecoration(BuildContext context) =>
      BoxDecoration(
        color: card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderSubtle(context), width: 1),
      );
}
