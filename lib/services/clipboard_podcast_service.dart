import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ClipboardPodcastInfo {
  const ClipboardPodcastInfo({
    required this.episodeTitle,
    required this.podcastName,
    required this.timestampSeconds,
    required this.sourceUrl,
    required this.source,
    this.itunesPodcastId,
    this.itunesEpisodeId,
    this.spotifyEpisodeId,
    this.supportsPipeline = true,
  });

  final String episodeTitle;
  final String podcastName;
  final int timestampSeconds;
  final String sourceUrl;
  final String source;

  /// False for sources we detect but cannot transcribe (e.g. Audible DRM).
  final bool supportsPipeline;

  /// Apple iTunes numeric podcast ID (from /id123456 in the URL path).
  final String? itunesPodcastId;

  /// Apple iTunes numeric episode ID (from ?i=100060000 query param).
  final String? itunesEpisodeId;

  /// Spotify episode ID (from /episode/{id} path).
  final String? spotifyEpisodeId;

  String get formattedTimestamp {
    final m = timestampSeconds ~/ 60;
    final s = timestampSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  String toString() =>
      'ClipboardPodcastInfo(episode: $episodeTitle, podcast: $podcastName, '
      'at: $formattedTimestamp, source: $source, '
      'itunesPodId: $itunesPodcastId, itunesEpId: $itunesEpisodeId, '
      'spotifyEpId: $spotifyEpisodeId)';
}

class ClipboardPodcastService {
  ClipboardPodcastService._();
  static final instance = ClipboardPodcastService._();

  String? _lastProcessedUrl;

  /// Reads the system clipboard when the app is in the foreground.
  /// iOS + Android (Samsung, etc.): use after app resume or from an explicit
  /// user action (e.g. "Paste link") so OEM clipboard policies are satisfied.
  Future<ClipboardPodcastInfo?> checkClipboard() async {
    if (kIsWeb) return null;
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      return null;
    }

    try {
      // Some Android builds need a beat after resume before clip is visible.
      if (Platform.isAndroid) {
        await Future.delayed(const Duration(milliseconds: 350));
      }

      ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);

      if (data == null || (data.text?.trim().isEmpty ?? true)) {
        await Future.delayed(const Duration(milliseconds: 1800));
        data = await Clipboard.getData(Clipboard.kTextPlain);
      }

      var text = data?.text?.trim();
      if (text == null || text.isEmpty) return null;

      text = await _expandSpotifyShareUrl(text);

      if (text == _lastProcessedUrl) {
        return null;
      }

      final info = _tryParseApplePodcastsUrl(text) ??
          _tryParseSpotifyUrl(text) ??
          await _tryParseAudibleUrl(text);

      if (info != null) {
        _lastProcessedUrl = text;
      }
      return info;
    } catch (e) {
      debugPrint('[ClipboardPodcast] error: $e');
      return null;
    }
  }

  void markProcessed(String url) {
    _lastProcessedUrl = url;
  }

  void reset() {
    _lastProcessedUrl = null;
  }

  /// Resolves spotify.link / spoti.fi redirects to open.spotify.com URLs.
  static Future<String> _expandSpotifyShareUrl(String input) async {
    final uri = Uri.tryParse(input.trim());
    if (uri == null || !uri.hasScheme) return input;

    final host = uri.host.toLowerCase();
    final isShort = host == 'spoti.fi' || host.endsWith('spotify.link');
    if (!isShort) return input;

    try {
      var current = uri;
      final client = http.Client();
      try {
        for (var i = 0; i < 14; i++) {
          final req = http.Request('GET', current)..followRedirects = false;
          final streamed =
              await client.send(req).timeout(const Duration(seconds: 12));
          final code = streamed.statusCode;
          if (code >= 300 && code < 400) {
            final loc = streamed.headers['location'];
            await streamed.stream.drain();
            if (loc == null) break;
            current = current.resolve(loc);
            continue;
          }
          await streamed.stream.drain();
          break;
        }
        if (current.host.toLowerCase().contains('spotify.com')) {
          return current.toString();
        }
      } finally {
        client.close();
      }
    } catch (_) {}
    return input;
  }

  /// Parses Apple Podcasts URLs like:
  /// https://podcasts.apple.com/us/podcast/episode-slug-title/id123456789?i=1000600000000&t=757
  static ClipboardPodcastInfo? _tryParseApplePodcastsUrl(String text) {
    final uri = Uri.tryParse(text);
    if (uri == null) return null;
    if (!uri.host.contains('podcasts.apple.com')) return null;

    final segments = uri.pathSegments;

    final tParam = uri.queryParameters['t'];
    final timestamp = tParam != null ? int.tryParse(tParam) ?? 0 : 0;

    // Extract the iTunes podcast ID from /id123456789
    String? itunesPodcastId;
    for (final seg in segments) {
      if (seg.startsWith('id')) {
        itunesPodcastId = seg.substring(2);
        break;
      }
    }

    // Extract the iTunes episode ID from ?i=1000600000000
    final itunesEpisodeId = uri.queryParameters['i'];

    // Slug-based title extraction as fallback display name
    String episodeTitle = '';
    String podcastName = '';

    final contentSegments = segments
        .where((s) =>
            s.length > 2 &&
            s != 'podcast' &&
            !s.startsWith('id'))
        .toList();

    if (contentSegments.length >= 2) {
      podcastName = _slugToTitle(contentSegments[0]);
      episodeTitle = _slugToTitle(contentSegments[1]);
    } else if (contentSegments.length == 1) {
      episodeTitle = _slugToTitle(contentSegments[0]);
    }

    if (episodeTitle.isEmpty && itunesEpisodeId == null) return null;

    return ClipboardPodcastInfo(
      episodeTitle: episodeTitle,
      podcastName: podcastName,
      timestampSeconds: timestamp,
      sourceUrl: text,
      source: 'apple_podcasts',
      itunesPodcastId: itunesPodcastId,
      itunesEpisodeId: itunesEpisodeId,
    );
  }

  /// Parses Spotify URLs like:
  /// https://open.spotify.com/episode/4rOoJ6Egrf8K2IrywzwOMk?t=757
  static ClipboardPodcastInfo? _tryParseSpotifyUrl(String text) {
    final uri = Uri.tryParse(text);
    if (uri == null) return null;
    if (!uri.host.contains('open.spotify.com')) return null;
    if (!uri.pathSegments.contains('episode')) return null;

    final tParam = uri.queryParameters['t'];
    final timestamp = tParam != null ? int.tryParse(tParam) ?? 0 : 0;

    // Extract the Spotify episode ID from /episode/{id}
    final epIdx = uri.pathSegments.indexOf('episode');
    if (epIdx < 0) return null;
    if (epIdx + 1 >= uri.pathSegments.length) return null;

    final rawId = uri.pathSegments[epIdx + 1];
    final spotifyId = rawId.split('?').first.trim();
    if (spotifyId.isEmpty) return null;

    return ClipboardPodcastInfo(
      episodeTitle: 'Spotify Episode',
      podcastName: '',
      timestampSeconds: timestamp,
      sourceUrl: text,
      source: 'spotify',
      spotifyEpisodeId: spotifyId,
    );
  }

  /// Audible links — audio is DRM-protected but most Audible podcasts are also
  /// on Apple Podcasts / Spotify with a public RSS feed. We extract the title
  /// from the URL slug (or scrape the page) and let Taddy find the episode.
  static Future<ClipboardPodcastInfo?> _tryParseAudibleUrl(String text) async {
    final uri = Uri.tryParse(text.trim());
    if (uri == null || !uri.hasScheme) return null;
    final host = uri.host.toLowerCase();
    if (!host.contains('audible.')) return null;

    final asinPattern = RegExp(r'^B[0-9A-Z]{9}$');

    var title = '';
    String? asin;
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    // Collect all title-slugs and ASINs from path segments.
    final slugs = <String>[];
    for (final s in segs) {
      if (const {'pd', 'ep', 'podcast', 'podcasts', 'episode', 'episodes'}
          .contains(s.toLowerCase())) {
        continue;
      }
      if (asinPattern.hasMatch(s)) {
        asin = s;
      } else {
        slugs.add(s);
      }
    }

    // Use the last slug (closest to the ASIN) as the title.
    if (slugs.isNotEmpty) {
      title = _slugToTitle(slugs.last);
    }

    // If no readable slug found (URL was just /podcast/ASIN), scrape the page.
    if (title.isEmpty && asin != null) {
      title = await _scrapeAudibleTitle(text.trim()) ?? '';
    }

    if (title.isEmpty) title = 'Audible Episode';

    final tParam = uri.queryParameters['t'];
    final timestamp = tParam != null ? int.tryParse(tParam) ?? 0 : 0;

    return ClipboardPodcastInfo(
      episodeTitle: title,
      podcastName: '',
      timestampSeconds: timestamp,
      sourceUrl: text,
      source: 'audible',
    );
  }

  /// Fetches the Audible page and extracts the title from the HTML <title> tag
  /// or og:title meta tag. Returns null on failure.
  static Future<String?> _scrapeAudibleTitle(String url) async {
    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Mozilla/5.0'},
      );
      if (res.statusCode != 200) {
        return null;
      }
      final body = res.body;

      // Try og:title first (usually cleaner).
      // Triple-quoted raw string so single quotes inside the pattern don't break parsing.
      final ogMatch = RegExp(
        r'''<meta\s+[^>]*property=["']og:title["']\s+content=["'](.*?)["']''',
        caseSensitive: false,
      ).firstMatch(body);
      if (ogMatch != null) {
        final raw = ogMatch.group(1)!.trim();
        // og:title is often "Episode Title | Audible.com" — strip suffix.
        final cleaned = raw.replaceAll(RegExp(r'\s*\|.*$'), '').trim();
        if (cleaned.isNotEmpty) {
          return cleaned;
        }
      }

      // Fallback: <title> tag.
      final titleMatch = RegExp(
        r'<title[^>]*>(.*?)</title>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(body);
      if (titleMatch != null) {
        var raw = titleMatch.group(1)!.trim();
        // Remove common suffixes like " | Audible.com", " - Audible.com".
        raw = raw.replaceAll(RegExp(r'\s*[|\-–—].*[Aa]udible.*$'), '').trim();
        if (raw.isNotEmpty) {
          return raw;
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static String _slugToTitle(String slug) {
    return slug
        .replaceAll('-', ' ')
        .replaceAllMapped(
          RegExp(r'(^|\s)\w'),
          (m) => m.group(0)!.toUpperCase(),
        );
  }
}
