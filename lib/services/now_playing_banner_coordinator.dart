import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';
import 'now_playing_service.dart';

/// Keeps the now-playing notification banner updated while
/// `banner_enabled` is true. Use from Home (startup) and Settings (toggle on).
class NowPlayingBannerCoordinator {
  NowPlayingBannerCoordinator._();
  static final NowPlayingBannerCoordinator instance =
      NowPlayingBannerCoordinator._();

  Timer? _timer;

  /// Starts periodic updates if banner is enabled and permission granted.
  /// Safe to call multiple times (restarts timer).
  Future<void> startIfEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final bannerEnabled = prefs.getBool('banner_enabled') ?? true;
    if (!bannerEnabled) return;

    final permitted = await NotificationService.instance.requestPermission();
    if (!permitted) return;

    _timer?.cancel();
    await _pollOnce();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_pollOnce());
    });
  }

  /// Stop polling (e.g. user disabled banner in Settings).
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _pollOnce() async {
    final info = await NowPlayingService.instance.getCurrentNowPlaying();
    if (info != null) {
      await NotificationService.instance.updateBanner(info.title, info.artist);
    }
  }
}
