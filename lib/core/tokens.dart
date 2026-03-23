import 'package:flutter/material.dart';

/// Layout constants only — 8pt grid, minimum HIG tap target.
/// Colors and typography come from [Theme.of] / [ColorScheme] / [TextTheme].
abstract final class Tokens {
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;
  static const double spaceXxl = 48;

  /// Apple HIG minimum tappable area.
  static const double minTap = 44;

  static const double radiusXs = 4;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusFull = 999;

  /// Spring-like curve for UI motion (avoid linear UI transitions).
  static const Curve springCurve = Curves.easeOutCubic;

  static const Duration durationFast = Duration(milliseconds: 200);
  static const Duration durationNormal = Duration(milliseconds: 320);

  // ── Summary screen (cinema hero + body) ─────────────────────────────
  static const Color bgPrimary = Color(0xFF070D1A);
  static const Color bgSurface = Color(0xFF12121F);
  static const Color bgElevated = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color accent = Color(0xFF38BDF8);
  static const Color error = Color(0xFFF87171);

  static Color get accentDim => accent.withValues(alpha: 0.12);
  static Color get accentBorder => accent.withValues(alpha: 0.35);
  static Color get errorDim =>
      const Color(0xFF450A0A).withValues(alpha: 0.55);
  static Color get borderLight => Colors.white.withValues(alpha: 0.08);
}
