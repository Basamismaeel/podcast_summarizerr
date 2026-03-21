import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../database/database.dart';
import '../database/session_dao.dart';
import '../models/episode_metadata.dart';
import '../models/pipeline_models.dart';
import '../models/summary_style.dart';
import 'spotify_episode_service.dart';
import 'transcription_service.dart';

/// Orchestrates the full summarization pipeline:
/// Load session → Resolve episode → Transcribe → Summarize → Parse → Save.
class CloudPipelineService {
  CloudPipelineService({required this.dao});

  final SessionDao dao;

  String get _geminiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  String get _taddyKey => dotenv.env['TADDY_API_KEY'] ?? '';
  String get _taddyUserId => dotenv.env['TADDY_USER_ID'] ?? '';

  static const _maxRetries = 3;
  static const _retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  // ═════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═════════════════════════════════════════════════════════════════════════

  /// Run the full pipeline for a session. Retries on transient errors.
  /// [episodeHint] contains platform-specific IDs for exact episode lookup.
  Future<void> processSession(String sessionId,
      {SummaryStyle? style, Map<String, String>? episodeHint}) async {
    PipelineException? lastError;

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        await _runPipeline(sessionId, style: style, episodeHint: episodeHint);
        return; // success
      } on PipelineException catch (e) {
        lastError = e;
        if (!e.retryable || attempt == _maxRetries - 1) break;
        debugPrint(
          '[Pipeline] Attempt ${attempt + 1} failed: ${e.userMessage}. Retrying…',
        );
        await Future.delayed(_retryDelays[attempt]);
      } catch (e) {
        // Network / timeout errors are retryable
        lastError = PipelineException(
          _friendlyNetworkMessage(e),
          retryable: true,
        );
        if (attempt == _maxRetries - 1) break;
        debugPrint('[Pipeline] Attempt ${attempt + 1} error: $e. Retrying…');
        await Future.delayed(_retryDelays[attempt]);
      }
    }

    // All retries exhausted — mark session as error
    await _updateSessionStatus(
      sessionId,
      SessionStatus.error,
      errorMessage: lastError?.userMessage ??
          'AI service unavailable — try again in a moment',
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // PIPELINE STEPS
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _runPipeline(String sessionId,
      {SummaryStyle? style, Map<String, String>? episodeHint}) async {
    // ── STEP 1: Load session ──────────────────────────────────────────────
    final session = await dao.getSessionById(sessionId);
    if (session == null) {
      throw const PipelineException('Session not found', retryable: false);
    }

    final summaryStyle = style ??
        SummaryStyle.fromJson(session.summaryStyle) ??
        SummaryStyle.insights;

    await _updateSessionStatus(sessionId, SessionStatus.summarizing);

    // ── STEP 2: Resolve episode metadata ─────────────────────────────────
    // Apple: iTunes lookup by podcast + episode trackId.
    // Spotify: Spotify Web API for title/show, then Taddy for audio URL.
    EpisodeMetadata? episode;
    final itunesEpId = episodeHint?['itunesEpisodeId'];
    final itunesPodId = episodeHint?['itunesPodcastId'];
    final spotifyEpId = episodeHint?['spotifyEpisodeId'];

    if (itunesEpId != null && itunesEpId.isNotEmpty &&
        itunesPodId != null && itunesPodId.isNotEmpty) {
      episode = await _resolveViaItunes(itunesPodId, itunesEpId);
    } else if (spotifyEpId != null && spotifyEpId.isNotEmpty) {
      final spotifyMeta = await SpotifyEpisodeService.fetchEpisode(spotifyEpId);
      if (spotifyMeta == null) {
        throw const PipelineException(
          'Could not load this episode from Spotify. Check the link or try again.',
          retryable: true,
        );
      }
      episode = await _resolveEpisode(
        spotifyMeta.episodeTitle,
        spotifyMeta.showName,
        requireStrongMatch: true,
        preferredImageUrl: spotifyMeta.imageUrl,
      );
    }

    if (episode == null) {
      // Only use fuzzy fallback when source is NOT Spotify (for Spotify we
      // already tried the exact API + strong Taddy match above).
      if (spotifyEpId != null && spotifyEpId.isNotEmpty) {
        throw const PipelineException(
          'Could not find this Spotify episode in our audio index. '
          'Try copying the Apple Podcasts link for this show instead, or use Manual Entry.',
          retryable: false,
        );
      }
      episode = await _resolveEpisode(session.title, session.artist);
    }

    // Store episode metadata + corrected title/artist on the session row
    await _updateSessionFields(sessionId, {
      'episodeId': episode.id,
      'episodeUrl': episode.episodeUrl,
      'artworkUrl': episode.imageUrl,
      'title': episode.title.isNotEmpty ? episode.title : null,
      'artist': episode.podcastName.isNotEmpty ? episode.podcastName : null,
    });

    // ── STEP 3: Get transcript ───────────────────────────────────────────
    final isFullEpisode = session.endTimeSec == null || session.endTimeSec == -1;
    final startSec = session.startTimeSec;
    final endSec = isFullEpisode ? -1 : session.endTimeSec!;

    final transcription = await TranscriptionService.instance.fetchTranscript(
      episodeId: episode.id,
      audioUrl: episode.episodeUrl ?? '',
      startSec: startSec,
      endSec: endSec,
    );

    if (transcription.transcript.trim().isEmpty) {
      throw const PipelineException(
        'Transcript not available for this episode',
        retryable: false,
      );
    }

    // ── STEP 4: Generate summary ─────────────────────────────────────────
    // Build a timestamped transcript so Gemini can cite times.
    final timedTranscript = _buildTimestampedTranscript(transcription);
    final rawSummary =
        await _generateSummary(timedTranscript, summaryStyle);

    // ── STEP 5: Parse response ───────────────────────────────────────────
    final parsed = _parseSummaryResponse(rawSummary, summaryStyle);

    // ── STEP 6: Save to database ─────────────────────────────────────────
    final now = DateTime.now().millisecondsSinceEpoch;
    final bullets = parsed.bullets;
    final quotes = parsed.quotes;

    await dao.updateSession(
      ListeningSessionsCompanion(
        id: Value(sessionId),
        title: Value(session.title),
        artist: Value(session.artist),
        saveMethod: Value(session.saveMethod),
        startTimeSec: Value(session.startTimeSec),
        createdAt: Value(session.createdAt),
        status: const Value('done'),
        summaryStyle: Value(summaryStyle.toJson()),
        bullet1: Value(bullets.isNotEmpty ? bullets[0] : null),
        bullet2: Value(bullets.length > 1 ? bullets[1] : null),
        bullet3: Value(bullets.length > 2 ? bullets[2] : null),
        bullet4: Value(bullets.length > 3 ? bullets[3] : null),
        bullet5: Value(bullets.length > 4 ? bullets[4] : null),
        quote1: Value(quotes.isNotEmpty ? quotes[0] : null),
        quote2: Value(quotes.length > 1 ? quotes[1] : null),
        quote3: Value(quotes.length > 2 ? quotes[2] : null),
        chaptersJson: Value(
          parsed.chapters != null
              ? jsonEncode(parsed.chapters!.map((c) => c.toJson()).toList())
              : null,
        ),
        errorMessage: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // STEP 2a: RESOLVE VIA ITUNES LOOKUP (exact, no API key needed)
  // ═════════════════════════════════════════════════════════════════════════

  /// Uses Apple's free iTunes Lookup API to get exact episode metadata
  /// from the numeric episode ID embedded in Apple Podcasts share URLs.
  /// Looks up a specific episode by listing recent episodes from the podcast
  /// (using the iTunes podcast collection ID) and matching on trackId.
  Future<EpisodeMetadata?> _resolveViaItunes(
      String itunesPodcastId, String itunesEpisodeId) async {
    try {
      // Fetch up to 200 recent episodes from this podcast
      final url = Uri.parse(
        'https://itunes.apple.com/lookup?id=$itunesPodcastId'
        '&entity=podcastEpisode&limit=200',
      );
      final response = await http.get(url);
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>? ?? [];

      // Find the exact episode by matching trackId
      final targetId = int.tryParse(itunesEpisodeId);
      Map<String, dynamic>? ep;
      for (final r in results) {
        final m = r as Map<String, dynamic>;
        if (m['wrapperType'] == 'podcastEpisode' &&
            m['trackId'] == targetId) {
          ep = m;
          break;
        }
      }

      if (ep == null) {
        return null;
      }

      return EpisodeMetadata(
        id: itunesEpisodeId,
        title: ep['trackName'] as String? ?? '',
        podcastName: ep['collectionName'] as String? ?? '',
        imageUrl: ep['artworkUrl600'] as String? ??
            ep['artworkUrl100'] as String?,
        durationSeconds: (ep['trackTimeMillis'] as num?)?.toInt() != null
            ? ((ep['trackTimeMillis'] as num).toInt() ~/ 1000)
            : null,
        publishedAt: ep['releaseDate'] != null
            ? DateTime.tryParse(ep['releaseDate'] as String)
            : null,
        episodeUrl: ep['episodeUrl'] as String?,
      );
    } catch (e) {
      debugPrint('[Pipeline] iTunes lookup failed: $e');
      return null;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // STEP 2b: RESOLVE VIA TADDY SEARCH (fuzzy fallback)
  // ═════════════════════════════════════════════════════════════════════════

  Future<EpisodeMetadata> _resolveEpisode(
    String title,
    String artist, {
    bool requireStrongMatch = false,
    String? preferredImageUrl,
  }) async {
    if (_taddyKey.isEmpty || _taddyKey == 'placeholder') {
      throw const PipelineException(
        'Episode not found — try using Manual Entry to search directly',
        retryable: false,
      );
    }

    // Taddy limits search term to 8 words max.
    final rawTerm = '$title $artist'.trim();
    final words = rawTerm.split(RegExp(r'\s+'));
    final searchTerm = words.length > 8 ? words.take(8).join(' ') : rawTerm;
    final limit = requireStrongMatch ? 15 : 5;
    final query = '''
    {
      search(
        term: "${_escapeGraphQL(searchTerm)}"
        filterForTypes: PODCASTEPISODE
        limitPerPage: $limit
      ) {
        searchId
        podcastEpisodes {
          uuid
          name
          audioUrl
          duration
          datePublished
          podcastSeries {
            uuid
            name
            imageUrl
          }
        }
      }
    }
    ''';

    final response = await http.post(
      Uri.parse('https://api.taddy.org'),
      headers: {
        'Content-Type': 'application/json',
        'X-USER-ID': _taddyUserId,
        'X-API-KEY': _taddyKey,
      },
      body: jsonEncode({'query': query}),
    );

    if (response.statusCode != 200) {
      throw PipelineException(
        'Episode search failed (${response.statusCode})',
        retryable: true,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    // Taddy returns errors in the response body even with 200 status
    if (body.containsKey('errors')) {
      final errors = body['errors'] as List<dynamic>?;
      final msg = (errors?.firstOrNull as Map<String, dynamic>?)?['message'] as String? ?? 'Unknown error';
      debugPrint('[Pipeline] Taddy error: $msg');
      throw PipelineException('Episode search failed: $msg', retryable: true);
    }

    final data = body['data'] as Map<String, dynamic>?;
    final search = data?['search'] as Map<String, dynamic>?;
    final results = search?['podcastEpisodes'] as List<dynamic>? ?? [];

    if (results.isEmpty) {
      throw const PipelineException(
        'Episode not found — try using Manual Entry to search directly',
        retryable: false,
      );
    }

    final cast = results.cast<Map<String, dynamic>>().toList();
    Map<String, dynamic> best;
    if (requireStrongMatch) {
      final strong = cast
          .where((r) => _matchScore(r, title, artist) >= 4.0)
          .toList();
      if (strong.isEmpty) {
        throw const PipelineException(
          'This episode is on Spotify but we could not find the same episode '
          'in our audio index. Try the Apple Podcasts share link for this show, '
          'or use Manual Entry.',
          retryable: false,
        );
      }
      strong.sort(
        (a, b) => _matchScore(b, title, artist).compareTo(
              _matchScore(a, title, artist),
            ),
      );
      best = strong.first;
    } else {
      best = _bestMatch(cast, title, artist);
    }

    final podcastSeries = best['podcastSeries'] as Map<String, dynamic>?;
    final taddyShowName = podcastSeries?['name'] as String? ?? '';
    return EpisodeMetadata(
      id: best['uuid'] as String? ?? '',
      title: (requireStrongMatch && title.isNotEmpty)
          ? title
          : (best['name'] as String? ?? title),
      podcastName: (requireStrongMatch && artist.isNotEmpty)
          ? artist
          : (taddyShowName.isNotEmpty ? taddyShowName : artist),
      imageUrl: preferredImageUrl ?? podcastSeries?['imageUrl'] as String?,
      durationSeconds: (best['duration'] as num?)?.toInt(),
      publishedAt: best['datePublished'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (best['datePublished'] as num).toInt() * 1000)
          : null,
      episodeUrl: best['audioUrl'] as String?,
    );
  }

  /// Higher = better alignment with [title] / [artist] (episode + show names).
  static double _matchScore(
    Map<String, dynamic> r,
    String title,
    String artist,
  ) {
    final titleLower = title.toLowerCase().trim();
    final artistLower = artist.toLowerCase().trim();
    final name = (r['name'] as String? ?? '').toLowerCase().trim();
    final podName =
        ((r['podcastSeries'] as Map<String, dynamic>?)?['name'] as String? ??
                '')
            .toLowerCase()
            .trim();

    var s = 0.0;
    if (titleLower.isNotEmpty) {
      if (name == titleLower) {
        s += 12;
      } else if (name.contains(titleLower) || titleLower.contains(name)) {
        s += 4;
      }
    }
    if (artistLower.isNotEmpty) {
      if (podName == artistLower) {
        s += 8;
      } else if (podName.contains(artistLower) ||
          artistLower.contains(podName)) {
        s += 3;
      }
    }
    return s;
  }

  Map<String, dynamic> _bestMatch(
    List<Map<String, dynamic>> results,
    String title,
    String artist,
  ) {
    final sorted = [...results]
      ..sort(
        (a, b) => _matchScore(b, title, artist).compareTo(
              _matchScore(a, title, artist),
            ),
      );
    return sorted.first;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // STEP 4: GENERATE SUMMARY (Gemini)
  // ═════════════════════════════════════════════════════════════════════════

  Future<String> _generateSummary(
      String transcript, SummaryStyle style) async {
    if (_geminiKey.isEmpty || _geminiKey == 'placeholder') {
      throw const PipelineException(
        'AI service unavailable — try again in a moment',
        retryable: false,
      );
    }

    final prompt = _buildPrompt(transcript, style);

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-2.5-flash:generateContent?key=$_geminiKey',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.3,
          'maxOutputTokens': 2048,
        },
      }),
    );

    if (response.statusCode == 429) {
      throw const PipelineException(
        'AI service unavailable — try again in a moment',
        retryable: true,
      );
    }

    if (response.statusCode != 200) {
      throw PipelineException(
        'AI service error (${response.statusCode})',
        retryable: response.statusCode >= 500,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = body['candidates'] as List<dynamic>?;
    final content = (candidates?.firstOrNull
        as Map<String, dynamic>?)?['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    final text = (parts?.firstOrNull as Map<String, dynamic>?)?['text']
            as String? ??
        '';

    if (text.trim().isEmpty) {
      throw const PipelineException(
        'AI returned empty response — try again',
        retryable: true,
      );
    }

    return text;
  }

  /// Builds a transcript string with [MM:SS] markers inserted every ~30 seconds
  /// using word-level timestamps from Deepgram. Timestamps are absolute episode
  /// positions (Deepgram provides them relative to audio start, which equals
  /// absolute episode time). If no word timestamps, returns plain transcript.
  static String _buildTimestampedTranscript(TranscriptionResult transcription) {
    if (!transcription.hasWordTimestamps) return transcription.transcript;

    final buf = StringBuffer();
    var lastMarkerSec = -30; // force first marker immediately

    for (final w in transcription.wordTimestamps) {
      // Word timestamps from Deepgram are already absolute episode positions
      final absSec = w.startSec.round();
      if (absSec - lastMarkerSec >= 30) {
        final m = absSec ~/ 60;
        final s = absSec % 60;
        buf.write('[${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}] ');
        lastMarkerSec = absSec;
      }
      buf.write('${w.word} ');
    }

    return buf.toString().trimRight();
  }

  String _buildPrompt(String transcript, SummaryStyle style) {
    final capped = transcript.length > 50000
        ? transcript.substring(0, 50000)
        : transcript;

    const timeNote = 'The transcript contains [MM:SS] timestamp markers. '
        'For each item, include the approximate timestamp where it was said '
        'using the format TIME: [MM:SS].\n';

    switch (style) {
      case SummaryStyle.insights:
        return 'You are a podcast insight extractor. Extract the most '
            'valuable, specific, memorable insights. Be concrete not vague. '
            'Every insight must be something the listener can remember or use.\n\n'
            '$timeNote'
            'Return EXACTLY 3 bullet points from this transcript.\n'
            'Format each as:\n'
            'INSIGHT: [one sentence insight]\n'
            'TIME: [MM:SS]\n'
            'QUOTE: [verbatim sentence from transcript supporting it]\n\n'
            'Transcript:\n$capped';

      case SummaryStyle.deepNotes:
        return 'You are a podcast insight extractor. Extract the most '
            'valuable, specific, memorable insights. Be concrete not vague. '
            'Every insight must be something the listener can remember or use.\n\n'
            '$timeNote'
            'Return EXACTLY 7 bullet points. More detail per point.\n'
            'Format each as:\n'
            'INSIGHT: [one sentence insight]\n'
            'TIME: [MM:SS]\n'
            'QUOTE: [verbatim sentence from transcript supporting it]\n\n'
            'Transcript:\n$capped';

      case SummaryStyle.actionItems:
        return 'You extract specific, actionable takeaways from podcasts.\n\n'
            '$timeNote'
            'Return 3-5 specific action items. Start each with a verb.\n'
            'Format:\n'
            'ACTION: [do X]\n'
            'TIME: [MM:SS]\n'
            'CONTEXT: [why, from transcript]\n\n'
            'Only include actions that were explicitly or implicitly suggested.\n\n'
            'Transcript:\n$capped';

      case SummaryStyle.smartChapters:
        return 'You are a podcast chapter detector.\n\n'
            '$timeNote'
            'Detect topic changes in this transcript.\n'
            'Return 3-6 chapters.\n'
            'Format each:\n'
            'CHAPTER: [title]\n'
            'TIME: [MM:SS approximate start]\n'
            'SUMMARY: [2 sentences]\n\n'
            'Transcript:\n$capped';

      case SummaryStyle.keyQuotes:
        return 'You extract the most powerful verbatim quotes from podcasts.\n\n'
            '$timeNote'
            'Return exactly 3 verbatim quotes. Must be exact words from transcript.\n'
            'Choose quotes that are insightful, surprising, or highly memorable.\n'
            'Format:\n'
            'QUOTE: [exact words]\n'
            'TIME: [MM:SS]\n'
            'CONTEXT: [1 sentence why this matters]\n\n'
            'Transcript:\n$capped';
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // STEP 5: PARSE RESPONSE
  // ═════════════════════════════════════════════════════════════════════════

  ParsedSummary _parseSummaryResponse(String raw, SummaryStyle style) {
    switch (style) {
      case SummaryStyle.insights:
      case SummaryStyle.deepNotes:
        return _parseInsights(raw, style);
      case SummaryStyle.actionItems:
        return _parseActionItems(raw, style);
      case SummaryStyle.smartChapters:
        return _parseChapters(raw, style);
      case SummaryStyle.keyQuotes:
        return _parseKeyQuotes(raw, style);
    }
  }

  ParsedSummary _parseInsights(String raw, SummaryStyle style) {
    final insightPattern = RegExp(r'INSIGHT:\s*(.+)', caseSensitive: false);
    final timePattern = RegExp(r'TIME:\s*\[?(\d{1,2}:\d{2})\]?', caseSensitive: false);
    final quotePattern = RegExp(r'QUOTE:\s*(.+)', caseSensitive: false);

    final insights = insightPattern
        .allMatches(raw)
        .map((m) => m.group(1)!.trim())
        .take(5)
        .toList();
    final times = timePattern
        .allMatches(raw)
        .map((m) => m.group(1)!.trim())
        .take(5)
        .toList();
    final quotes = quotePattern
        .allMatches(raw)
        .map((m) => m.group(1)!.trim())
        .take(3)
        .toList();

    if (insights.isEmpty) {
      final lines = raw
          .split('\n')
          .map((l) => l.replaceFirst(RegExp(r'^[\-\*\d\.]+\s*'), '').trim())
          .where((l) => l.isNotEmpty && l.length > 10)
          .take(5)
          .toList();
      return ParsedSummary(bullets: lines, quotes: quotes, style: style);
    }

    // Prepend timestamp to each insight if available
    final bullets = <String>[];
    for (var i = 0; i < insights.length; i++) {
      final time = i < times.length ? '[${times[i]}] ' : '';
      bullets.add('$time${insights[i]}');
    }

    return ParsedSummary(bullets: bullets, quotes: quotes, style: style);
  }

  ParsedSummary _parseActionItems(String raw, SummaryStyle style) {
    final actionPattern = RegExp(r'ACTION:\s*(.+)', caseSensitive: false);
    final timePattern = RegExp(r'TIME:\s*\[?(\d{1,2}:\d{2})\]?', caseSensitive: false);
    final contextPattern = RegExp(r'CONTEXT:\s*(.+)', caseSensitive: false);

    final actions = actionPattern
        .allMatches(raw)
        .map((m) => m.group(1)!.trim())
        .take(5)
        .toList();
    final times = timePattern
        .allMatches(raw)
        .map((m) => m.group(1)!.trim())
        .take(5)
        .toList();
    final contexts = contextPattern
        .allMatches(raw)
        .map((m) => m.group(1)!.trim())
        .take(3)
        .toList();

    if (actions.isEmpty) {
      final lines = raw
          .split('\n')
          .map((l) => l.replaceFirst(RegExp(r'^[\-\*\d\.]+\s*'), '').trim())
          .where((l) => l.isNotEmpty && l.length > 10)
          .take(5)
          .toList();
      return ParsedSummary(bullets: lines, quotes: contexts, style: style);
    }

    final bullets = <String>[];
    for (var i = 0; i < actions.length; i++) {
      final time = i < times.length ? '[${times[i]}] ' : '';
      bullets.add('$time${actions[i]}');
    }

    return ParsedSummary(bullets: bullets, quotes: contexts, style: style);
  }

  ParsedSummary _parseChapters(String raw, SummaryStyle style) {
    final chapterPattern = RegExp(r'CHAPTER:\s*(.+)', caseSensitive: false);
    final timePattern = RegExp(r'TIME:\s*(.+)', caseSensitive: false);
    final summaryPattern = RegExp(r'SUMMARY:\s*(.+)', caseSensitive: false);

    final titles = chapterPattern
        .allMatches(raw)
        .map((m) => m.group(1)!.trim())
        .toList();
    final times = timePattern
        .allMatches(raw)
        .map((m) => m.group(1)!.trim())
        .toList();
    final summaries = summaryPattern
        .allMatches(raw)
        .map((m) => m.group(1)!.trim())
        .toList();

    final chapters = <ChapterInfo>[];
    final bullets = <String>[];
    for (var i = 0; i < titles.length && i < 6; i++) {
      chapters.add(ChapterInfo(
        title: titles[i],
        approximateTime: i < times.length ? times[i] : '',
        summary: i < summaries.length ? summaries[i] : '',
      ));
      final time = i < times.length ? '[${times[i]}] ' : '';
      bullets.add('$time${titles[i]} — ${i < summaries.length ? summaries[i] : ''}');
    }

    return ParsedSummary(
      bullets: bullets.take(5).toList(),
      quotes: const [],
      chapters: chapters,
      style: style,
    );
  }

  ParsedSummary _parseKeyQuotes(String raw, SummaryStyle style) {
    final quotePattern = RegExp(r'QUOTE:\s*(.+)', caseSensitive: false);
    final timePattern = RegExp(r'TIME:\s*\[?(\d{1,2}:\d{2})\]?', caseSensitive: false);
    final contextPattern = RegExp(r'CONTEXT:\s*(.+)', caseSensitive: false);

    final quotes = quotePattern
        .allMatches(raw)
        .map((m) => m.group(1)!.trim())
        .take(3)
        .toList();
    final times = timePattern
        .allMatches(raw)
        .map((m) => m.group(1)!.trim())
        .take(3)
        .toList();
    final contexts = contextPattern
        .allMatches(raw)
        .map((m) => m.group(1)!.trim())
        .take(3)
        .toList();

    final bullets = <String>[];
    for (var i = 0; i < quotes.length; i++) {
      final time = i < times.length ? '[${times[i]}] ' : '';
      final ctx = i < contexts.length ? ' — ${contexts[i]}' : '';
      bullets.add('$time"${quotes[i]}"$ctx');
    }

    return ParsedSummary(
      bullets: bullets.take(5).toList(),
      quotes: quotes,
      style: style,
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _updateSessionStatus(
    String sessionId,
    SessionStatus status, {
    String? errorMessage,
  }) async {
    final session = await dao.getSessionById(sessionId);
    if (session == null) return;

    await dao.updateSession(
      ListeningSessionsCompanion(
        id: Value(sessionId),
        title: Value(session.title),
        artist: Value(session.artist),
        saveMethod: Value(session.saveMethod),
        startTimeSec: Value(session.startTimeSec),
        createdAt: Value(session.createdAt),
        status: Value(status.name),
        errorMessage: Value(errorMessage),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> _updateSessionFields(
      String sessionId, Map<String, String?> fields) async {
    final session = await dao.getSessionById(sessionId);
    if (session == null) return;

    await dao.updateSession(
      ListeningSessionsCompanion(
        id: Value(sessionId),
        title: Value(fields['title'] ?? session.title),
        artist: Value(fields['artist'] ?? session.artist),
        saveMethod: Value(session.saveMethod),
        startTimeSec: Value(session.startTimeSec),
        createdAt: Value(session.createdAt),
        episodeId: Value(fields['episodeId']),
        episodeUrl: Value(fields['episodeUrl']),
        artworkUrl: Value(fields['artworkUrl']),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  static String _friendlyNetworkMessage(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('socketexception') || msg.contains('handshake')) {
      return 'No internet connection — will retry when you\'re back online';
    }
    if (msg.contains('timeout')) {
      return 'AI service unavailable — try again in a moment';
    }
    return 'AI service unavailable — try again in a moment';
  }

  static String _escapeGraphQL(String input) =>
      input.replaceAll('"', r'\"').replaceAll('\n', ' ');
}
