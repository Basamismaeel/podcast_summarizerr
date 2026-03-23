import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';

class AppBadgeService {
  AppBadgeService._();

  static Future<void> updateQueueCount(int count) async {
    if (kIsWeb) return;
    try {
      if (count <= 0) {
        await AppBadgePlus.updateBadge(0);
      } else {
        await AppBadgePlus.updateBadge(count);
      }
    } catch (e) {
      debugPrint('[AppBadgeService] updateBadge: $e');
    }
  }
}
