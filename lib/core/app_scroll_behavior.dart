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
    // Bounce on all platforms for a premium, consistent feel.
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}
