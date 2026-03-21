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
}
