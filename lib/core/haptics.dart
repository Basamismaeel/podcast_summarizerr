import 'package:flutter/services.dart';

/// Light haptic for taps (aligned with iOS `UIImpactFeedbackGenerator(.light)`).
void higLightTap() {
  HapticFeedback.lightImpact();
}
