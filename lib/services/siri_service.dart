import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges Siri / App Intents–queued sessions from the iOS App Group
/// (`UserDefaults` suite `group.com.safetynet.podcast`) into Flutter.
class SiriService {
  SiriService._();

  static const _channel = MethodChannel('com.podcasts.safetynet/siri');

  /// Reads pending Siri saves and clears the queue on the native side.
  static Future<List<Map<String, dynamic>>> getPendingSessions() async {
    if (kIsWeb) return [];

    try {
      final raw = await _channel.invokeMethod<dynamic>('getPendingSessions');
      if (raw == null) return [];
      if (raw is! List) return [];
      return raw
          .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
          .toList();
    } on MissingPluginException {
      debugPrint('[SiriService] MethodChannel not available on this platform');
      return [];
    } on PlatformException catch (e) {
      debugPrint('[SiriService] getPendingSessions failed: $e');
      return [];
    }
  }
}
