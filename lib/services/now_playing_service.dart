import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/now_playing_info.dart';

class NowPlayingService {
  NowPlayingService._();
  static final instance = NowPlayingService._();

  static const _channel = MethodChannel('com.podcasts.safetynet/nowplaying');

  /// Returns the currently playing media info, or null if nothing is
  /// playing / playback is paused / platform unsupported.
  Future<NowPlayingInfo?> getCurrentNowPlaying() async {
    if (kIsWeb) return null;

    try {
      final dynamic raw = await _channel.invokeMethod<dynamic>('getNowPlaying');
      if (raw == null) {
        if (kDebugMode) {
          debugPrint(
            '[NowPlayingService] native returned null — on iOS open Xcode console for [NowPlaying] logs (flutter run hides them)',
          );
        }
        return null;
      }
      if (raw is! Map) {
        if (kDebugMode) {
          debugPrint('[NowPlayingService] unexpected native type: ${raw.runtimeType}');
        }
        return null;
      }
      final result = Map<dynamic, dynamic>.from(raw);
      if (kDebugMode) {
        debugPrint('[NowPlayingService] raw map: $result');
      }

      final info = NowPlayingInfo.fromMap(result);
      if (info.title.isEmpty) {
        if (kDebugMode) {
          debugPrint('[NowPlayingService] parsed empty title after fallbacks');
        }
        return null;
      }
      return info;
    } on PlatformException catch (e) {
      debugPrint('[NowPlayingService] PlatformException: $e');
      return null;
    } on MissingPluginException {
      debugPrint('[NowPlayingService] MethodChannel not registered on this platform');
      return null;
    }
  }
}
