import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Fetches real episode + show names from Spotify using the Client Credentials
/// flow. Used when the user pastes an `open.spotify.com/episode/...` link.
///
/// Credentials are resolved in order:
/// 1. Bundled `.env` (`SPOTIFY_CLIENT_ID` / `SPOTIFY_CLIENT_SECRET`)
/// 2. **Settings → Spotify API keys** ([SharedPreferences] on device)
/// 3. `String.fromEnvironment` (e.g. `flutter run --dart-define=SPOTIFY_CLIENT_ID=...`)
///
/// Also accepts `SPOTIFY_CLIENT_SECRET_ID` (common naming mistake) and reads
/// `Platform.environment` for the same keys if missing from `.env` (see [main]).
class SpotifyEpisodeService {
  SpotifyEpisodeService._();

  static String? _accessToken;
  static DateTime? _tokenExpiry;

  /// Filled from [hydrateFromPrefs] at startup (and after saving in Settings).
  static String? _prefsClientId;
  static String? _prefsClientSecret;

  static Map<String, String> get _e {
    if (!dotenv.isInitialized) return {};
    return dotenv.env;
  }

  static String _firstNonEmpty(Iterable<String> keys) {
    for (final k in keys) {
      final v = _e[k]?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return '';
  }

  static String get _clientId {
    final fromDot = _firstNonEmpty(const [
      'SPOTIFY_CLIENT_ID',
      'SPOTIFY_CLIENTID',
    ]);
    if (fromDot.isNotEmpty) return fromDot;
    final fromPrefs = _prefsClientId?.trim() ?? '';
    if (fromPrefs.isNotEmpty) return fromPrefs;
    return const String.fromEnvironment(
      'SPOTIFY_CLIENT_ID',
      defaultValue: '',
    ).trim();
  }

  static String get _clientSecret {
    final fromDot = _firstNonEmpty(const [
      'SPOTIFY_CLIENT_SECRET',
      'SPOTIFY_CLIENT_SECRET_ID',
      'SPOTIFY_SECRET',
    ]);
    if (fromDot.isNotEmpty) return fromDot;
    final fromPrefs = _prefsClientSecret?.trim() ?? '';
    if (fromPrefs.isNotEmpty) return fromPrefs;
    return const String.fromEnvironment(
      'SPOTIFY_CLIENT_SECRET',
      defaultValue: '',
    ).trim();
  }

  /// Call from [main] after [SharedPreferences.getInstance] and whenever keys
  /// are saved in Settings.
  static void hydrateFromPrefs(SharedPreferences p) {
    _prefsClientId = p.getString('spotify_client_id');
    _prefsClientSecret = p.getString('spotify_client_secret');
  }

  static bool get isConfigured =>
      _clientId.isNotEmpty && _clientSecret.isNotEmpty;

  /// Fetches episode metadata. Uses the **oEmbed API** (no auth needed) first,
  /// then falls back to the authenticated Web API if oEmbed fails.
  static Future<SpotifyEpisodeInfo?> fetchEpisode(String spotifyEpisodeId) async {
    // ── Primary: oEmbed (no credentials required) ─────────────────────────
    final oembedResult = await _fetchViaOembed(spotifyEpisodeId);
    if (oembedResult != null) return oembedResult;

    // ── Fallback: Web API (needs client credentials) ──────────────────────
    if (!isConfigured) {
      return null;
    }
    return _fetchViaWebApi(spotifyEpisodeId);
  }

  /// Uses Spotify's public oEmbed endpoint — no auth, no rate-limit issues.
  /// Returns episode title + thumbnail. Show name is extracted from the
  /// oEmbed HTML iframe title attribute (format: "Spotify Embed: TITLE").
  static Future<SpotifyEpisodeInfo?> _fetchViaOembed(String spotifyEpisodeId) async {
    try {
      final episodeUrl = 'https://open.spotify.com/episode/$spotifyEpisodeId';
      final uri = Uri.parse(
        'https://open.spotify.com/oembed?url=${Uri.encodeComponent(episodeUrl)}',
      );
      final res = await http.get(uri);
      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final title = body['title'] as String?;
      final thumbnail = body['thumbnail_url'] as String?;
      if (title == null || title.isEmpty) return null;

      // oEmbed title is just the episode name. Try to extract the show name
      // from the iframe HTML (title attr = "Spotify Embed: EpisodeName").
      // There's no separate show field, so we leave showName empty and let
      // the pipeline search Taddy by episode title alone.
      return SpotifyEpisodeInfo(
        episodeTitle: title,
        showName: '',
        imageUrl: thumbnail,
      );
    } catch (_) {
      return null;
    }
  }

  /// Authenticated fallback using /v1/episodes endpoint.
  static Future<SpotifyEpisodeInfo?> _fetchViaWebApi(String spotifyEpisodeId) async {
    final token = await _ensureToken();
    if (token == null) {
      return null;
    }

    final markets = [null, 'US', 'GB', 'AZ', 'TR', 'DE', 'CA', 'AU', 'FR'];
    for (final market in markets) {
      final qs = market != null ? '?market=$market' : '';
      final uri = Uri.parse(
        'https://api.spotify.com/v1/episodes/$spotifyEpisodeId$qs',
      );
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final info = _parseEpisode(jsonDecode(res.body) as Map<String, dynamic>);
        if (info != null) {
          return info;
        }
      }
    }
    return null;
  }

  static Future<String?> _ensureToken() async {
    final now = DateTime.now();
    if (_accessToken != null &&
        _tokenExpiry != null &&
        now.isBefore(_tokenExpiry!.subtract(const Duration(seconds: 60)))) {
      return _accessToken;
    }

    final basic = base64Encode(utf8.encode('$_clientId:$_clientSecret'));
    final res = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Authorization': 'Basic $basic',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'grant_type': 'client_credentials'},
    );
    if (res.statusCode != 200) {
      return null;
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final token = body['access_token'] as String?;
    final expiresIn = (body['expires_in'] as num?)?.toInt() ?? 3600;
    if (token == null) return null;

    _accessToken = token;
    _tokenExpiry = now.add(Duration(seconds: expiresIn));
    return token;
  }

  static SpotifyEpisodeInfo? _parseEpisode(Map<String, dynamic> json) {
    final name = json['name'] as String?;
    final show = json['show'] as Map<String, dynamic>?;
    final showName = show?['name'] as String?;
    if (name == null || name.isEmpty || showName == null || showName.isEmpty) {
      return null;
    }

    final images = json['images'] as List<dynamic>?;
    String? imageUrl;
    if (images != null && images.isNotEmpty) {
      final first = images.first as Map<String, dynamic>?;
      imageUrl = first?['url'] as String?;
    }

    final durationMs = (json['duration_ms'] as num?)?.toInt();

    return SpotifyEpisodeInfo(
      episodeTitle: name,
      showName: showName,
      imageUrl: imageUrl,
      durationMs: durationMs,
    );
  }
}

class SpotifyEpisodeInfo {
  const SpotifyEpisodeInfo({
    required this.episodeTitle,
    required this.showName,
    this.imageUrl,
    this.durationMs,
  });

  final String episodeTitle;
  final String showName;
  final String? imageUrl;
  final int? durationMs;
}
