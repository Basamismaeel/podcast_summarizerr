import 'package:flutter/material.dart';

import '../widgets/psn_snackbar.dart';

// ── BuildContext ────────────────────────────────────────────────────────

extension BuildContextX on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  EdgeInsets get viewPadding => MediaQuery.of(this).viewPadding;

  void showSnackbar(String message, PSNSnackbarType type) {
    PSNSnackbar.show(this, message, type);
  }
}

// ── int (timestamps) ───────────────────────────────────────────────────

extension IntTimestampX on int {
  /// 2045 -> '34:05'
  String toTimestamp() {
    final m = this ~/ 60;
    final s = this % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// 2045 -> '34 mins', 4920 -> '1h 22m'
  String toDuration() {
    final totalMinutes = (this / 60).round();
    if (totalMinutes < 60) return '$totalMinutes mins';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }
}

// ── String ─────────────────────────────────────────────────────────────

extension StringX on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String toEpisodeTitle() {
    if (length <= 60) return this;
    return '${substring(0, 57)}…';
  }
}
