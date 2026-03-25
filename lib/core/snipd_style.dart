import 'dart:ui';

import 'package:flutter/material.dart';

/// Snipd-inspired dark podcast UI tokens (layout/colors only).
abstract final class SnipdStyle {
  static const Color bgDeep = Color(0xFF070D1A);
  static const Color card = Color(0xFF0F1C30);
  static const Color label = Color(0xFFBDD4EE);
  static const Color meta = Color(0xFF5E82A8);
  /// Matches app primary (deeper blue — consistent with Material dark seed).
  static const Color accent = Color(0xFF2563EB);
  static const Color title = Color(0xFFFFFFFF);

  static Color get borderSubtle =>
      const Color(0xFF64B4FF).withValues(alpha: 0.1);

  static Color get chipFill =>
      const Color(0xFF38BDF8).withValues(alpha: 0.08);

  static Color get miniBarBg =>
      const Color(0xFF0F1C30).withValues(alpha: 0.97);

  static Color get bottomNavBg =>
      const Color(0xFF070D1A).withValues(alpha: 0.97);

  static Border get cardBorder =>
      Border.all(color: borderSubtle, width: 1);

  static BoxDecoration get quickNavCardDecoration => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderSubtle, width: 1),
      );

  static List<BoxShadow> miniBarShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static ImageFilter blur20 = ImageFilter.blur(sigmaX: 20, sigmaY: 20);
}
