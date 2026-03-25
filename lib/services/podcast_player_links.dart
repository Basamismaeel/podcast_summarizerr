import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// #region agent log
Future<void> _agentAppleOpenLog(
  String hypothesisId,
  String location,
  String message,
  Map<String, Object?> data,
) async {
  final payload = <String, Object?>{
    'sessionId': '1f97d9',
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': data,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };
  try {
    await http
        .post(
          Uri.parse(
            'http://127.0.0.1:7916/ingest/7da75ee9-c2ca-47eb-8c80-eb256be4a61e',
          ),
          headers: {
            'Content-Type': 'application/json',
            'X-Debug-Session-Id': '1f97d9',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 2));
  } catch (_) {
    debugPrint('AGENT_APPLE_OPEN ${jsonEncode(payload)}');
  }
}

String _agentUrlSample(String? u, {int max = 140}) {
  if (u == null) return '';
  final t = u.trim();
  if (t.length <= max) return t;
  return '${t.substring(0, max)}…';
}

// #endregion

/// Opens the user’s podcast app near the saved position when possible.
class PodcastPlayerLinks {
  PodcastPlayerLinks._();

  static final _spotifyEpisodeRe = RegExp(
    r'spotify\.com/(?:episode|show)/([a-zA-Z0-9]+)',
  );

  /// Spotify web / app link with `t` in milliseconds.
  static Uri? spotifyUriAtPosition(String? episodeUrl, int positionSec) {
    if (episodeUrl == null || episodeUrl.isEmpty) return null;
    final uri = Uri.tryParse(episodeUrl);
    if (uri == null || !uri.host.contains('spotify')) return null;
    final tMs = (positionSec * 1000).clamp(0, 1 << 31);
    final q = Map<String, String>.from(uri.queryParameters);
    q['t'] = '$tMs';
    return uri.replace(queryParameters: q);
  }

  static Future<bool> openSpotifyAt(String? episodeUrl, int positionSec) async {
    final u = spotifyUriAtPosition(episodeUrl, positionSec);
    if (u == null) return false;
    try {
      return launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (e, st) {
      debugPrint('[PodcastPlayerLinks] Spotify: $e\n$st');
      return false;
    }
  }

  /// True if [episodeUrl] looks like a Spotify episode/show link.
  static bool looksLikeSpotify(String? episodeUrl) {
    if (episodeUrl == null) return false;
    return _spotifyEpisodeRe.hasMatch(episodeUrl);
  }

  /// Opens the **Apple Podcasts** app when possible.
  ///
  /// Plain `https://podcasts.apple.com/...` often opens Safari (or does nothing
  /// from in-app WebViews). iOS/macOS need the **`podcasts:`** scheme so the
  /// system routes to the Podcasts app.
  static Future<bool> openApplePodcasts(String? episodeUrl) async {
    // #region agent log
    await _agentAppleOpenLog(
      'A',
      'podcast_player_links.dart:openApplePodcasts:entry',
      'openApplePodcasts called',
      {
        'platform': describeEnum(defaultTargetPlatform),
        'kIsWeb': kIsWeb,
        'sample': _agentUrlSample(episodeUrl),
        'len': episodeUrl?.length ?? 0,
      },
    );
    // #endregion
    if (episodeUrl == null || episodeUrl.isEmpty) return false;
    final uri = Uri.tryParse(episodeUrl.trim());
    if (uri == null) {
      // #region agent log
      await _agentAppleOpenLog('A', 'podcast_player_links.dart:parse',
          'Uri.tryParse null', {'sample': _agentUrlSample(episodeUrl)});
      // #endregion
      return false;
    }
    final hostOk = uri.host.contains('podcasts.apple.com') ||
        uri.host.contains('itunes.apple.com');
    if (!hostOk) {
      // #region agent log
      await _agentAppleOpenLog(
        'B',
        'podcast_player_links.dart:host',
          'host rejected',
          {'host': uri.host, 'scheme': uri.scheme},
      );
      // #endregion
      return false;
    }

    // #region agent log
    await _agentAppleOpenLog(
      'B',
      'podcast_player_links.dart:parsed',
      'parsed uri',
      {
        'scheme': uri.scheme,
        'host': uri.host,
        'pathLen': uri.path.length,
        'hasQuery': uri.query.isNotEmpty,
      },
    );
    // #endregion

    Future<bool> tryOpen(Uri u, List<LaunchMode> modes, String branch) async {
      for (final mode in modes) {
        try {
          // Do not call [canLaunchUrl] here: on some iOS builds it throws
          // PlatformException(channel-error) on the Pigeon channel and would
          // skip [launchUrl] entirely. Opening does not require a prior check.
          // #region agent log
          await _agentAppleOpenLog(
            'C',
            'podcast_player_links.dart:tryOpen',
            'launchUrl attempt (canLaunchUrl skipped)',
            {
              'branch': branch,
              'mode': describeEnum(mode),
              'runId': 'post-fix',
              'target': _agentUrlSample(u.toString(), max: 200),
            },
          );
          // #endregion
          final launched = await launchUrl(u, mode: mode);
          // #region agent log
          await _agentAppleOpenLog(
            'C',
            'podcast_player_links.dart:tryOpen',
            'after launchUrl',
            {
              'branch': branch,
              'mode': describeEnum(mode),
              'runId': 'post-fix',
              'launched': launched,
              'target': _agentUrlSample(u.toString(), max: 200),
            },
          );
          // #endregion
          if (launched) return true;
        } catch (e, st) {
          // #region agent log
          await _agentAppleOpenLog(
            'D',
            'podcast_player_links.dart:tryOpen',
            'launch exception',
            {
              'branch': branch,
              'mode': describeEnum(mode),
              'err': e.toString().length > 200
                  ? '${e.toString().substring(0, 200)}…'
                  : e.toString(),
              'st': st.toString().length > 120
                  ? '${st.toString().substring(0, 120)}…'
                  : st.toString(),
            },
          );
          // #endregion
          debugPrint('[PodcastPlayerLinks] Apple launch $u ($mode): $e\n$st');
        }
      }
      return false;
    }

    final modes = <LaunchMode>[
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
    ];

    final usePodcastsScheme = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS) &&
        uri.scheme == 'https' &&
        uri.host.contains('podcasts.apple.com');

    // #region agent log
    await _agentAppleOpenLog(
      'B',
      'podcast_player_links.dart:branch',
      'branch flags',
      {
        'usePodcastsScheme': usePodcastsScheme,
        'willTryItunes': !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.iOS &&
            uri.host.contains('itunes.apple.com') &&
            uri.path.contains('podcast'),
      },
    );
    // #endregion

    if (usePodcastsScheme) {
      final native = uri.replace(scheme: 'podcasts');
      // #region agent log
      await _agentAppleOpenLog(
        'A',
        'podcast_player_links.dart:nativeUri',
        'podcasts scheme uri',
        {'native': _agentUrlSample(native.toString(), max: 220)},
      );
      // #endregion
      if (await tryOpen(native, modes, 'podcasts-scheme')) return true;
    }

    // Legacy iTunes podcast URLs → try store/podcast deep link, then https.
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        uri.host.contains('itunes.apple.com') &&
        uri.path.contains('podcast')) {
      final itms = uri.replace(scheme: 'itms-podcasts');
      // #region agent log
      await _agentAppleOpenLog(
        'D',
        'podcast_player_links.dart:itms',
        'itms uri',
        {'itms': _agentUrlSample(itms.toString(), max: 220)},
      );
      // #endregion
      if (await tryOpen(itms, modes, 'itms-podcasts')) return true;
    }

    final ok = await tryOpen(uri, modes, 'https-fallback');
    // #region agent log
    await _agentAppleOpenLog(
      'C',
      'podcast_player_links.dart:exit',
      'openApplePodcasts final',
      {
        'success': ok,
        'runId': 'post-fix',
        'sample': _agentUrlSample(episodeUrl),
      },
    );
    // #endregion
    return ok;
  }

  static bool looksLikeApplePodcasts(String? episodeUrl) {
    if (episodeUrl == null) return false;
    final u = Uri.tryParse(episodeUrl);
    return u != null &&
        (u.host.contains('podcasts.apple.com') ||
            u.host.contains('itunes.apple.com'));
  }

  /// Apple Podcasts web URLs support [`t`]=start offset in **seconds**.
  static Uri? applePodcastsUriWithTime(String? episodeUrl, int positionSec) {
    if (episodeUrl == null || episodeUrl.isEmpty) return null;
    final uri = Uri.tryParse(episodeUrl.trim());
    if (uri == null || !looksLikeApplePodcasts(episodeUrl)) return null;
    final t = positionSec.clamp(0, 1 << 30);
    final q = Map<String, String>.from(uri.queryParameters);
    q['t'] = '$t';
    return uri.replace(queryParameters: q);
  }

  /// Opens Apple Podcasts at [positionSec] when the link is an Apple episode URL.
  static Future<bool> openApplePodcastsAt(
    String? episodeUrl,
    int positionSec,
  ) {
    final u = applePodcastsUriWithTime(episodeUrl, positionSec);
    if (u == null) return openApplePodcasts(episodeUrl);
    return openApplePodcasts(u.toString());
  }
}
