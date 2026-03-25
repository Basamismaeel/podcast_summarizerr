import 'package:flutter/widgets.dart';

/// Logical size × [MediaQuery.devicePixelRatio], clamped so decoded bitmaps stay
/// bounded (perf: less GPU memory / decode work for thumbnails and heroes).
int decodeCacheExtent(BuildContext context, double logicalPixels) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return (logicalPixels * dpr).round().clamp(48, 2048);
}
