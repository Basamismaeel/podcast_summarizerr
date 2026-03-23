import 'package:flutter/services.dart';

/// Rich haptic vocabulary for PSN interactions.
class PSNHaptics {
  PSNHaptics._();

  /// Moment saved — double tap feel.
  static Future<void> momentSaved() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();
  }

  /// Summary complete — warm success.
  static Future<void> summaryComplete() async {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }

  /// Error — sharp attention.
  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
  }

  /// Selection / light tap.
  static Future<void> select() async {
    await HapticFeedback.selectionClick();
  }

  /// Delete — firm warning.
  static Future<void> delete() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.mediumImpact();
  }
}

/// Default tap feedback (maps to selection-style haptic).
void higLightTap() {
  HapticFeedback.selectionClick();
}
