import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Consistent, fluid scrolling on phones: platform-native physics + all drag devices.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS =>
        const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
      _ => const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
    };
  }
}
