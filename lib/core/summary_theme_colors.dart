import 'package:flutter/material.dart';

import 'tokens.dart';

/// Summary screen body: cinema dark tokens in dark mode, Material surfaces in light mode.
abstract final class SummaryThemeColors {
  static bool _dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bgPrimary(BuildContext context) => _dark(context)
      ? Tokens.bgPrimary
      : Theme.of(context).colorScheme.surface;

  static Color bgSurface(BuildContext context) => _dark(context)
      ? Tokens.bgSurface
      : Theme.of(context).colorScheme.surfaceContainerLow;

  static Color bgElevated(BuildContext context) => _dark(context)
      ? Tokens.bgElevated
      : Theme.of(context).colorScheme.surfaceContainerHigh;

  static Color textMuted(BuildContext context) => _dark(context)
      ? Tokens.textMuted
      : Theme.of(context).colorScheme.onSurfaceVariant;

  static Color borderLight(BuildContext context) => _dark(context)
      ? Tokens.borderLight
      : Theme.of(context).colorScheme.outlineVariant;

  static Color accent(BuildContext context) => _dark(context)
      ? Tokens.accent
      : Theme.of(context).colorScheme.primary;

  static Color onBody(BuildContext context) => _dark(context)
      ? const Color(0xFFF0F0F0)
      : Theme.of(context).colorScheme.onSurface;

  static Color onBodySoft(BuildContext context) => _dark(context)
      ? Colors.white.withValues(alpha: 0.68)
      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72);
}
