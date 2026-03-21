import 'package:flutter/material.dart';

/// Semantic access to Material 3 / Apple-aligned theme values.
extension HigBuildContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;

  TextTheme get textTheme => Theme.of(this).textTheme;
}
