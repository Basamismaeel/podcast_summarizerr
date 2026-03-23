import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:string_similarity/string_similarity.dart';

import '../core/env_value.dart';
import '../debug/agent_ndjson_log.dart';
import '../core/moments_stats_service.dart';
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

  /// Compile-time override: `flutter run --dart-define=GEMINI_API_KEY=...`
  /// (useful when bundled `.env` is wrong; keys from AI Studio start with `AIza`).
  static const _geminiKeyFromDefine =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  String get _geminiKey {
    final raw = _geminiKeyFromDefine.isNotEmpty
        ? normalizeDotenvValue(_geminiKeyFromDefine)
        : normalizeDotenvValue(dotenv.env['GEMINI_API_KEY']);
    return normalizeGeminiApiKey(raw);
  }
  String get _taddyKey => normalizeDotenvValue(dotenv.env['TADDY_API_KEY']);
  String get _taddyUserId => normalizeDotenvValue(dotenv.env['TADDY_USER_ID']);

  /// `v1beta` is the default for AI Studio `generateContent`. Override with `GEMINI_API_VERSION=v1` in `.env` if needed.
  String get _geminiApiVersion {
    final v =
        normalizeDotenvValue(dotenv.env['GEMINI_API_VERSION']).toLowerCase();
    if (v == 'v1' || v == 'v1beta') return v;
    return 'v1beta';
  }

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
        // #region agent log
        agentNdjsonLog(
          hypothesisId: _agentHypothesisForMessage(e.userMessage),
          location: 'cloud_pipeline_service.dart:processSession',
          message: 'PipelineException in retry loop',
          data: <String, Object?>{
            'attempt': attempt + 1,
            'retryable': e.retryable,
            'userMessageLen': e.userMessage.length,
            'userMessagePreview': _agentTruncate(e.userMessage, 220),
          },
        );
        // #endregion
        if (!e.retryable || attempt == _maxRetries - 1) break;
        debugPrint(
          '[Pipeline] Attempt ${attempt + 1} failed: ${e.userMessage}. Retrying…',
        );
        await Future.delayed(_retryDelays[attempt]);
      } catch (e) {
        // Network / timeout errors are retryable
        lastError = PipelineException(
          '${_friendlyNetworkMessage(e)} '
          'Check your connection, then tap Retry.',
          retryable: true,
        );
        // #region agent log
        agentNdjsonLog(
          hypothesisId: 'H4',
          location: 'cloud_pipeline_service.dart:processSession',
          message: 'Non-PipelineException in retry loop',
          data: <String, Object?>{
            'attempt': attempt + 1,
            'errorType': e.runtimeType.toString(),
            'errorPreview': _agentTruncate(e.toString(), 280),
          },
        );
        // #endregion
        if (attempt == _maxRetries - 1) break;
        debugPrint('[Pipeline] Attempt ${attempt + 1} error: $e. Retrying…');
        await Future.delayed(_retryDelays[attempt]);
      }
    }

    // #region agent log
    agentNdjsonLog(
      hypothesisId: 'H0',
      location: 'cloud_pipeline_service.dart:processSession',
      message: 'processSession finished with failure, updating session error',
      data: <String, Object?>{
        'sessionIdLen': sessionId.length,
        'lastMessagePreview':
            _agentTruncate(lastError?.userMessage ?? 'null', 280),
        'lastRetryable': lastError?.retryable,
      },
    );
    // #endregion

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
    var spotifyEpId = episodeHint?['spotifyEpisodeId']?.trim();
    // Manual Entry / messy paste: title or notes may contain the episode URL
    // without going through clipboard parsing — still resolve via Spotify API.
    if (spotifyEpId == null || spotifyEpId.isEmpty) {
      spotifyEpId = SpotifyEpisodeService.extractEpisodeIdFromText(session.title);
    }
    if (spotifyEpId == null || spotifyEpId.isEmpty) {
      spotifyEpId = SpotifyEpisodeService.extractEpisodeIdFromText(session.artist);
    }
    final share = session.sourceShareUrl?.trim();
    if ((spotifyEpId == null || spotifyEpId.isEmpty) &&
        share != null &&
        share.isNotEmpty) {
      spotifyEpId = SpotifyEpisodeService.extractEpisodeIdFromText(share);
    }

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
      final sid = spotifyEpId;
      if (sid != null && sid.isNotEmpty) {
        throw const PipelineException(
          'Could not find this Spotify episode in our audio index. '
          'Try copying the Apple Podcasts link for this show instead, or use Manual Entry.',
          retryable: false,
        );
      }
      episode = await _resolveEpisode(session.title, session.artist);
    }

    // Store episode metadata + a **listenable** share URL for “Open in Spotify/Apple”.
    // [episode.episodeUrl] is often an RSS/audio URL — not openable in the player app.
    String? shareForButtons = session.sourceShareUrl?.trim();
    if (shareForButtons == null || shareForButtons.isEmpty) {
      final sid = spotifyEpId?.trim();
      if (sid != null && sid.isNotEmpty) {
        shareForButtons = 'https://open.spotify.com/episode/$sid';
      } else {
        final u = episode.episodeUrl?.trim();
        if (u != null &&
            u.isNotEmpty &&
            (u.contains('open.spotify.com') ||
                u.contains('podcasts.apple.com') ||
                u.contains('itunes.apple.com'))) {
          shareForButtons = u;
        }
      }
    }

    // Store episode metadata + corrected title/artist on the session row
    await _updateSessionFields(sessionId, {
      'episodeId': episode.id,
      'episodeUrl': episode.episodeUrl,
      'sourceShareUrl': shareForButtons,
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
      // #region agent log
      agentNdjsonLog(
        hypothesisId: 'H2',
        location: 'cloud_pipeline_service.dart:_runPipeline',
        message: 'Empty transcript after fetchTranscript',
        data: <String, Object?>{
          'episodeIdLen': episode.id.length,
          'audioUrlEmpty': (episode.episodeUrl ?? '').isEmpty,
          'transcriptionSource': transcription.source,
        },
      );
      // #endregion
      throw const PipelineException(
        'Transcript not available for this episode',
        retryable: false,
      );
    }

    // ── STEP 4: Generate summary ─────────────────────────────────────────
    // Build a timestamped transcript so Gemini can cite times.
    final timedTranscript = _buildTimestampedTranscript(transcription);
    final segmentContext = _buildSegmentContextForPrompt(
      episode: episode,
      session: session,
      isFullEpisode: isFullEpisode,
    );
    final rawSummary = await _generateSummary(
      timedTranscript,
      summaryStyle,
      segmentContext: segmentContext,
    );

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
        transcriptSource: Value(transcription.source),
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

    await MomentsStatsService.incrementSummariesDone();
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
  // STEP 2b: RESOLVE VIA MULTI-SIGNAL SEARCH (Taddy + iTunes + Gemini)
  // ═════════════════════════════════════════════════════════════════════════

  /// Normalizes episode titles for looser matching (Step 1).
  static String cleanTitle(String raw) {
    // Use Unicode letters/numbers — ASCII-only `\w` stripped non-Latin titles
    // (common for Spotify / international shows) and broke Taddy search.
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'episode\s*#?\d+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
        .trim();
  }

  /// Levenshtein distance normalized by max length, blended with Dice coefficient
  /// from [string_similarity] (0.0 = different, 1.0 = identical).
  static double scoreSimilarity(String a, String b) {
    final s1 = a.toLowerCase().trim();
    final s2 = b.toLowerCase().trim();
    if (s1.isEmpty && s2.isEmpty) return 1;
    if (s1.isEmpty || s2.isEmpty) return 0;
    final maxLen = math.max(s1.length, s2.length);
    final lev = 1.0 - _levenshteinDistance(s1, s2) / maxLen;
    final dice = StringSimilarity.compareTwoStrings(s1, s2);
    return (lev + dice) / 2.0;
  }

  static int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final m = a.length;
    final n = b.length;
    var row = List<int>.generate(n + 1, (j) => j);
    for (var i = 1; i <= m; i++) {
      var prev = row[0];
      row[0] = i;
      for (var j = 1; j <= n; j++) {
        final temp = row[j];
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        row[j] = math.min(
          prev + cost,
          math.min(row[j] + 1, row[j - 1] + 1),
        );
        prev = temp;
      }
    }
    return row[n];
  }

  static int? _episodeNumberFromTitle(String title) {
    final m = RegExp(r'#?(\d{3,4})').firstMatch(title);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  static bool _episodeNameContainsNumber(String name, int n) {
    if (name.contains('$n')) return true;
    final padded = n.toString().padLeft(3, '0');
    return name.contains(padded);
  }

  static String _truncateTaddyTerm(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '';
    if (words.length <= 8) return t;
    var out = words.take(8).join(' ');
    // Taddy also rejects very long single “words” (e.g. pasted URLs).
    const maxChars = 200;
    if (out.length > maxChars) {
      out = '${out.substring(0, maxChars)}…';
    }
    return out;
  }

  static double _episodeNumberMatchScore(
    int? wanted,
    String episodeName,
  ) {
    if (wanted == null) return 1;
    return _episodeNameContainsNumber(episodeName, wanted) ? 1.0 : 0.0;
  }

  static double _compositeScore({
    required double titleSim,
    required double artistSim,
    required double episodeNumberMatch,
  }) =>
      titleSim * 0.5 + artistSim * 0.3 + episodeNumberMatch * 0.2;

  static Map<String, double> _normalizeTaddyRanking(
    List<Map<String, dynamic>> rankingDetails,
  ) {
    if (rankingDetails.isEmpty) return {};
    double maxScore = 0;
    final raw = <String, double>{};
    for (final d in rankingDetails) {
      final uuid = d['uuid'] as String?;
      final rs = (d['rankingScore'] as num?)?.toDouble();
      if (uuid == null || rs == null) continue;
      raw[uuid] = rs;
      if (rs > maxScore) maxScore = rs;
    }
    if (maxScore <= 0) return {};
    return {
      for (final e in raw.entries) e.key: (e.value / maxScore).clamp(0.0, 1.0),
    };
  }

  static _ScoredEpisode _scoreTaddyRow(
    Map<String, dynamic> r,
    String title,
    String artist,
    int? epNum, {
    double taddyConfidence = 0,
  }) {
    final name = r['name'] as String? ?? '';
    final podName =
        ((r['podcastSeries'] as Map<String, dynamic>?)?['name'] as String?) ??
            '';
    final titleSim = scoreSimilarity(title, name);
    final artistSim = scoreSimilarity(artist, podName);
    final epM = _episodeNumberMatchScore(epNum, name);
    var composite = _compositeScore(
      titleSim: titleSim,
      artistSim: artistSim,
      episodeNumberMatch: epM,
    );
    if (taddyConfidence > 0) {
      composite = math.max(composite, (composite * 0.85 + taddyConfidence * 0.15));
    }
    return _ScoredEpisode(episode: r, composite: composite);
  }

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

    final epNum = _episodeNumberFromTitle(title);
    final minScore = requireStrongMatch ? 0.85 : 0.7;
    // #region agent log
    agentNdjsonLog(
      hypothesisId: 'H1',
      location: 'cloud_pipeline_service.dart:_resolveEpisode',
      message: 'resolveEpisode start',
      data: <String, Object?>{
        'requireStrongMatch': requireStrongMatch,
        'titleLen': title.length,
        'artistLen': artist.length,
        'hasEpNum': epNum != null,
      },
    );
    // #endregion
    final byUuid = <String, _ScoredEpisode>{};

    void absorb(Iterable<_ScoredEpisode> list) {
      for (final s in list) {
        final id = s.episode['uuid'] as String? ?? '';
        if (id.isEmpty) continue;
        final prev = byUuid[id];
        if (prev == null || s.composite > prev.composite) {
          byUuid[id] = s;
        }
      }
    }

    // ── Strategy A: exact-ish title + artist (ALL_TERMS on combined term) ──
    try {
      final termA = _truncateTaddyTerm('$title $artist'.trim());
      final resA = await _taddySearch(
        term: termA,
        limitPerPage: requireStrongMatch ? 15 : 25,
        matchBy: 'ALL_TERMS',
      );
      if (resA.episodes.isNotEmpty) {
        final ranked = _normalizeTaddyRanking(resA.rankingDetails);
        final scored = resA.episodes.map((r) {
          final uuid = r['uuid'] as String? ?? '';
          return _scoreTaddyRow(
            r,
            title,
            artist,
            epNum,
            taddyConfidence: ranked[uuid] ?? 0,
          );
        });
        absorb(scored);
        final bestA = scored.reduce(
          (a, b) => a.composite >= b.composite ? a : b,
        );
        final topRank = ranked[bestA.episode['uuid'] as String? ?? ''] ?? 0;
        if (bestA.composite >= 0.9 || topRank >= 0.9) {
          return _episodeMetadataFromTaddy(
            bestA.episode,
            title: title,
            artist: artist,
            requireStrongMatch: requireStrongMatch,
            preferredImageUrl: preferredImageUrl,
          );
        }
      }
    } on PipelineException catch (e) {
      if (e.retryable) rethrow;
      debugPrint('[Pipeline] Strategy A: $e');
    }

    // ── Strategy B: cleaned title only ──
    try {
      final termB = _truncateTaddyTerm(cleanTitle(title));
      if (termB.isNotEmpty) {
        final resB = await _taddySearch(
          term: termB,
          limitPerPage: 25,
          matchBy: 'MOST_TERMS',
        );
        if (resB.episodes.isNotEmpty) {
          final ranked = _normalizeTaddyRanking(resB.rankingDetails);
          final scored = resB.episodes.map((r) {
            final uuid = r['uuid'] as String? ?? '';
            return _scoreTaddyRow(
              r,
              title,
              artist,
              epNum,
              taddyConfidence: ranked[uuid] ?? 0,
            );
          }).toList();
          absorb(scored);
          scored.sort((a, b) => b.composite.compareTo(a.composite));
          final top = scored.first;
          final topTitleSim =
              scoreSimilarity(title, top.episode['name'] as String? ?? '');
          if (topTitleSim > 0.8 && top.composite >= 0.55) {
            return _episodeMetadataFromTaddy(
              top.episode,
              title: title,
              artist: artist,
              requireStrongMatch: requireStrongMatch,
              preferredImageUrl: preferredImageUrl,
            );
          }
        }
      }
    } on PipelineException catch (e) {
      if (e.retryable) rethrow;
      debugPrint('[Pipeline] Strategy B: $e');
    }

    // ── Strategy C: artist + episode number (3–4 digits in title) ──
    if (artist.trim().isNotEmpty && epNum != null) {
      try {
        final resC = await _taddySearch(
          term: _truncateTaddyTerm(artist),
          limitPerPage: 25,
          matchBy: 'MOST_TERMS',
        );
        final filtered = resC.episodes
            .where(
              (r) => _episodeNameContainsNumber(
                r['name'] as String? ?? '',
                epNum,
              ),
            )
            .map((r) => _scoreTaddyRow(r, title, artist, epNum))
            .where((s) => s.composite >= 0.5)
            .toList();
        absorb(filtered);
        if (filtered.isNotEmpty) {
          filtered.sort((a, b) => b.composite.compareTo(a.composite));
          final bestC = filtered.first;
          if (bestC.composite >= minScore) {
            return _episodeMetadataFromTaddy(
              bestC.episode,
              title: title,
              artist: artist,
              requireStrongMatch: requireStrongMatch,
              preferredImageUrl: preferredImageUrl,
            );
          }
        }
      } on PipelineException catch (e) {
        if (e.retryable) rethrow;
        debugPrint('[Pipeline] Strategy C: $e');
      }
    }

    // ── Strategy D: iTunes Search API → Taddy refinement or iTunes audio ──
    try {
      final itunes = await _itunesSearchPodcastEpisodes('$title $artist');
      if (itunes.isNotEmpty) {
        Map<String, dynamic>? bestIt;
        var bestItSim = 0.0;
        for (final m in itunes) {
          final trackName = m['trackName'] as String? ?? '';
          final sim = scoreSimilarity(title, trackName);
          if (sim > bestItSim) {
            bestItSim = sim;
            bestIt = m;
          }
        }
        if (bestIt != null && bestItSim >= 0.5) {
          final tn = bestIt['trackName'] as String? ?? '';
          final cn = bestIt['collectionName'] as String? ?? '';
          final termD = _truncateTaddyTerm('$tn $cn'.trim());
          final resD = await _taddySearch(
            term: termD,
            limitPerPage: 25,
            matchBy: 'MOST_TERMS',
          );
          if (resD.episodes.isNotEmpty) {
            final ranked = _normalizeTaddyRanking(resD.rankingDetails);
            final scored = resD.episodes.map((r) {
              final uuid = r['uuid'] as String? ?? '';
              return _scoreTaddyRow(
                r,
                title,
                artist,
                epNum,
                taddyConfidence: ranked[uuid] ?? 0,
              );
            }).toList();
            absorb(scored);
            scored.sort((a, b) => b.composite.compareTo(a.composite));
            final topD = scored.first;
            if (topD.composite >= minScore ||
                scoreSimilarity(tn, topD.episode['name'] as String? ?? '') >
                    0.75) {
              return _episodeMetadataFromTaddy(
                topD.episode,
                title: title,
                artist: artist,
                requireStrongMatch: requireStrongMatch,
                preferredImageUrl: preferredImageUrl,
              );
            }
          }
          if (!requireStrongMatch) {
            final itComp = _compositeScore(
              titleSim: scoreSimilarity(title, tn),
              artistSim: scoreSimilarity(artist, cn),
              episodeNumberMatch: _episodeNumberMatchScore(epNum, tn),
            );
            absorb([
              _ScoredEpisode(
                episode: _itunesRowToPseudoTaddy(bestIt),
                composite: itComp,
              ),
            ]);
          }
        }
      }
    } catch (e) {
      debugPrint('[Pipeline] Strategy D (iTunes): $e');
    }

    // ── Strategy E: Gemini-cleaned query → Taddy ──
    try {
      final cleaned = await _geminiCleanForSearch(title, artist);
      if (cleaned != null) {
        final termE =
            _truncateTaddyTerm('${cleaned.title} ${cleaned.show}'.trim());
        if (termE.isNotEmpty) {
          final resE = await _taddySearch(
            term: termE,
            limitPerPage: 25,
            matchBy: 'MOST_TERMS',
          );
          if (resE.episodes.isNotEmpty) {
            final ranked = _normalizeTaddyRanking(resE.rankingDetails);
            final scored = resE.episodes.map((r) {
              final uuid = r['uuid'] as String? ?? '';
              return _scoreTaddyRow(
                r,
                title,
                artist,
                epNum,
                taddyConfidence: ranked[uuid] ?? 0,
              );
            });
            absorb(scored);
          }
        }
      }
    } on PipelineException catch (e) {
      if (e.retryable) rethrow;
      debugPrint('[Pipeline] Strategy E: $e');
    }

    // ── Step 3: global best from accumulated candidates ──
    if (byUuid.isEmpty) {
      throw PipelineException(
        'Episode not found — try Manual Entry\n\n'
        'Searched episode: ${_ellipsisMessage(title, 120)}',
        retryable: false,
      );
    }

    final sortedAll = byUuid.values.toList()
      ..sort((a, b) => b.composite.compareTo(a.composite));
    final best = sortedAll.first;

    if (best.composite < minScore) {
      if (requireStrongMatch) {
        throw const PipelineException(
          'This episode is on Spotify but we could not find the same episode '
          'in our audio index. Try the Apple Podcasts share link for this show, '
          'or use Manual Entry.',
          retryable: false,
        );
      }
      throw PipelineException(
        'Episode not found — try Manual Entry\n\n'
        'Searched episode: ${_ellipsisMessage(title, 120)}',
        retryable: false,
      );
    }

    if (best.episode['_itunes'] == true) {
      return _episodeMetadataFromItunesPseudo(
        best.episode,
        preferredImageUrl: preferredImageUrl,
      );
    }

    return _episodeMetadataFromTaddy(
      best.episode,
      title: title,
      artist: artist,
      requireStrongMatch: requireStrongMatch,
      preferredImageUrl: preferredImageUrl,
    );
  }

  Future<({String title, String show})?> _geminiCleanForSearch(
    String title,
    String artist,
  ) async {
    if (_geminiKey.isEmpty || _geminiKey == 'placeholder') return null;
    final prompt = StringBuffer();
    prompt.writeln(
      'Clean and standardize this podcast episode title and show name for search.',
    );
    prompt.writeln('Reply with exactly two lines and nothing else:');
    prompt.writeln('TITLE: <standardized episode title only>');
    prompt.writeln('SHOW: <podcast/show name only>');
    prompt.writeln('Raw title: ');
    prompt.writeln(title);
    prompt.writeln('Raw show: ');
    prompt.writeln(artist);

    final text = await _geminiSingleShotPrompt(prompt.toString());
    if (text == null || text.isEmpty) return null;

    String? t;
    String? s;
    for (final line in text.split('\n')) {
      final l = line.trim();
      if (l.toUpperCase().startsWith('TITLE:')) {
        t = l.substring(l.indexOf(':') + 1).trim();
      } else if (l.toUpperCase().startsWith('SHOW:')) {
        s = l.substring(l.indexOf(':') + 1).trim();
      }
    }
    if (t == null || t.isEmpty) return null;
    return (title: t, show: s ?? artist);
  }

  /// Short Gemini completion (search cleanup). Returns null on failure.
  Future<String?> _geminiSingleShotPrompt(String prompt) async {
    if (_geminiKey.isEmpty || _geminiKey == 'placeholder') return null;

    final requestJson = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 256,
      },
    });

    for (final model in _geminiModelFallbacks.take(3)) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/$_geminiApiVersion/models/$model:generateContent',
      );
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _geminiKey,
        },
        body: requestJson,
      );
      if (response.statusCode == 200) {
        final out = _parseGeminiResponseText(response).trim();
        if (out.isNotEmpty) return out;
      }
      if (response.statusCode == 429) continue;
      if (_geminiResponseIsApiKeyProblem(response.statusCode, response.body)) {
        break;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _itunesSearchPodcastEpisodes(
    String term,
  ) async {
    final uri = Uri.https('itunes.apple.com', '/search', {
      'term': term,
      'media': 'podcast',
      'entity': 'podcastEpisode',
      'limit': '25',
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>? ?? [];
    return results.map((e) => e as Map<String, dynamic>).where((m) {
      final kind = (m['kind'] as String?)?.toLowerCase();
      return kind == 'podcast-episode';
    }).toList();
  }

  Map<String, dynamic> _itunesRowToPseudoTaddy(Map<String, dynamic> it) {
    final trackId = it['trackId'];
    final id = trackId?.toString() ?? '';
    final ms = (it['trackTimeMillis'] as num?)?.toInt();
    final secs = ms != null ? ms ~/ 1000 : null;
    final released = it['releaseDate'] as String?;
    final pubMillis = released != null
        ? (DateTime.tryParse(released)?.millisecondsSinceEpoch ?? 0) ~/ 1000
        : null;

    return {
      '_itunes': true,
      'uuid': id.isNotEmpty ? 'itunes_$id' : 'itunes_unknown',
      'name': it['trackName'] as String? ?? '',
      'audioUrl': it['episodeUrl'] as String? ?? it['previewUrl'] as String?,
      'duration': secs,
      'datePublished': pubMillis,
      'podcastSeries': {
        'name': it['collectionName'] as String? ?? '',
        'imageUrl': it['artworkUrl600'] as String? ?? it['artworkUrl100'] as String?,
      },
    };
  }

  EpisodeMetadata _episodeMetadataFromItunesPseudo(
    Map<String, dynamic> best, {
    String? preferredImageUrl,
  }) {
    final series = best['podcastSeries'] as Map<String, dynamic>?;
    return EpisodeMetadata(
      id: best['uuid'] as String? ?? '',
      title: best['name'] as String? ?? '',
      podcastName: series?['name'] as String? ?? '',
      imageUrl: preferredImageUrl ?? series?['imageUrl'] as String?,
      durationSeconds: (best['duration'] as num?)?.toInt(),
      publishedAt: best['datePublished'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (best['datePublished'] as num).toInt() * 1000,
            )
          : null,
      episodeUrl: best['audioUrl'] as String?,
    );
  }

  EpisodeMetadata _episodeMetadataFromTaddy(
    Map<String, dynamic> best, {
    required String title,
    required String artist,
    required bool requireStrongMatch,
    String? preferredImageUrl,
  }) {
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
              (best['datePublished'] as num).toInt() * 1000,
            )
          : null,
      episodeUrl: best['audioUrl'] as String?,
    );
  }

  Future<_TaddySearchResponse> _taddySearch({
    required String term,
    required int limitPerPage,
    String matchBy = 'MOST_TERMS',
  }) async {
    if (term.trim().isEmpty) {
      return _TaddySearchResponse(episodes: [], rankingDetails: []);
    }
    final q = '''
    {
      search(
        term: "${_escapeGraphQL(term)}"
        filterForTypes: PODCASTEPISODE
        limitPerPage: $limitPerPage
        matchBy: $matchBy
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
      body: jsonEncode({'query': q}),
    );

    if (response.statusCode != 200) {
      // #region agent log
      agentNdjsonLog(
        hypothesisId: 'H1',
        location: 'cloud_pipeline_service.dart:_taddySearch',
        message: 'Taddy HTTP non-200',
        data: <String, Object?>{
          'statusCode': response.statusCode,
          'bodyPreview': _agentTruncate(response.body, 400),
        },
      );
      // #endregion
      throw PipelineException(
        'Episode search failed (${response.statusCode})',
        retryable: true,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (body.containsKey('errors')) {
      final errors = body['errors'] as List<dynamic>?;
      final msg = (errors?.firstOrNull as Map<String, dynamic>?)?['message']
              as String? ??
          'Unknown error';
      debugPrint('[Pipeline] Taddy error: $msg');
      // #region agent log
      agentNdjsonLog(
        hypothesisId: 'H1',
        location: 'cloud_pipeline_service.dart:_taddySearch',
        message: 'Taddy GraphQL errors field present',
        data: <String, Object?>{
          'errorPreview': _agentTruncate(msg, 400),
          'limitPerPage': limitPerPage,
          'matchBy': matchBy,
        },
      );
      // #endregion
      throw PipelineException('Episode search failed: $msg', retryable: true);
    }

    final data = body['data'] as Map<String, dynamic>?;
    final search = data?['search'] as Map<String, dynamic>?;
    final episodes =
        search?['podcastEpisodes'] as List<dynamic>? ?? [];
    final rankRaw = search?['rankingDetails'] as List<dynamic>? ?? [];
    final rankingDetails =
        rankRaw.map((e) => e as Map<String, dynamic>).toList();

    return _TaddySearchResponse(
      episodes: episodes.map((e) => e as Map<String, dynamic>).toList(),
      rankingDetails: rankingDetails,
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // STEP 4: GENERATE SUMMARY (Gemini)
  // ═════════════════════════════════════════════════════════════════════════

  /// Ordered fallbacks for `generateContent`. Prefer **2.5** first: some accounts show
  /// `free_tier … limit: 0` on `gemini-2.0-flash` (429) while 2.5 still has quota.
  static const _geminiModelFallbacks = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.0-flash',
    'gemini-2.0-flash-001',
    'gemini-flash-latest',
  ];

  static String _ellipsisMessage(String s, [int max = 600]) {
    final t = s.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

  String _geminiApiErrorDetail(String responseBody) {
    try {
      final map = jsonDecode(responseBody) as Map<String, dynamic>?;
      final err = map?['error'] as Map<String, dynamic>?;
      final m = err?['message'] as String?;
      if (m != null && m.trim().isNotEmpty) return m.trim();
    } catch (_) {}
    return '';
  }

  /// When true, the failure is tied to the API key (Google returns the same for
  /// every model). Evidence: flutter run showed 403 "leaked" ×5, then 400
  /// "API key expired" / API_KEY_INVALID on first call only.
  static bool _geminiResponseIsApiKeyProblem(int statusCode, String body) {
    if (statusCode != 400 && statusCode != 403) return false;
    final lower = body.toLowerCase();
    if (lower.contains('api_key_invalid')) return true;
    if (lower.contains('reported as leaked')) return true;
    if (lower.contains('please use another api key')) return true;
    if (lower.contains('api key expired')) return true;
    if (lower.contains('please renew the api key')) return true;
    if (lower.contains('please pass a valid api key')) return true;
    try {
      final map = jsonDecode(body) as Map<String, dynamic>?;
      final err = map?['error'] as Map<String, dynamic>?;
      final details = err?['details'] as List<dynamic>?;
      if (details == null) return false;
      for (final d in details) {
        if (d is Map<String, dynamic> && d['reason'] == 'API_KEY_INVALID') {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Shown when Google says the key is invalid but the string is clearly not a Gemini key.
  static String _geminiKeyWrongFormatHint(String k) {
    if (k.isEmpty || k == 'placeholder') return '';
    if (k.startsWith('AIza')) return '';
    return '\n\nThis value does not look like a Google AI Studio Gemini key (those start with '
        '"AIza"). You may have put another API\'s key in GEMINI_API_KEY by mistake. '
        'Create one at https://aistudio.google.com/apikey — or for one debug run: '
        'flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY';
  }

  String _parseGeminiResponseText(http.Response response) {
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = map['candidates'] as List<dynamic>?;
    final content = (candidates?.firstOrNull
        as Map<String, dynamic>?)?['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    return (parts?.firstOrNull as Map<String, dynamic>?)?['text'] as String? ??
        '';
  }

  Future<String> _generateSummary(
    String transcript,
    SummaryStyle style, {
    required String segmentContext,
  }) async {
    if (_geminiKey.isEmpty || _geminiKey == 'placeholder') {
      throw const PipelineException(
        'Missing GEMINI_API_KEY. Add a Google AI Studio key to .env (starts with AIza), '
        'then fully restart the app — or: flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY',
        retryable: false,
      );
    }

    final built = _buildPromptBundle(
      transcript,
      style,
      segmentContext: segmentContext,
    );

    // REST shape matches https://ai.google.dev/api — explicit `role` avoids edge cases.
    final requestJson = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': built.prompt}
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.35,
        'maxOutputTokens': built.maxOutputTokens,
      },
    });

    PipelineException? lastFailure;

    for (final model in _geminiModelFallbacks) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/$_geminiApiVersion/models/$model:generateContent',
      );

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _geminiKey,
        },
        body: requestJson,
      );

      if (response.statusCode == 200) {
        final text = _parseGeminiResponseText(response);
        if (text.trim().isEmpty) {
          throw const PipelineException(
            'AI returned empty response — try again',
            retryable: true,
          );
        }
        return text;
      }

      final detail = _geminiApiErrorDetail(response.body);
      final msg = detail.isNotEmpty
          ? 'AI service (${response.statusCode}): $detail'
          : 'AI service error (${response.statusCode})';

      // 429 is often per-model quota (e.g. free tier limit:0 on 2.0-flash) — try next model.
      if (response.statusCode == 429) {
        lastFailure = PipelineException(
          _ellipsisMessage(msg),
          retryable: true,
        );
        continue;
      }

      // Key problems repeat for every model — don't burn 5 identical requests.
      if (_geminiResponseIsApiKeyProblem(response.statusCode, response.body)) {
        final k = _geminiKey;
        throw PipelineException(
          '$msg${_geminiKeyWrongFormatHint(k)}',
          retryable: false,
        );
      }

      lastFailure = PipelineException(
        msg,
        retryable: response.statusCode >= 500,
      );

      // Try another model if this key/model combo is rejected or unknown.
      if (response.statusCode == 403 || response.statusCode == 404) {
        continue;
      }

      throw lastFailure;
    }

    throw lastFailure ??
        const PipelineException(
          'AI service error — check Gemini API key and Generative Language API',
          retryable: false,
        );
  }

  /// Bracket marker at [absSec] in episode audio: [MM:SS] or [H:MM:SS] if ≥1h.
  static String _formatTranscriptTimeMarker(int absSec) {
    var sec = absSec;
    if (sec < 0) sec = 0;
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) {
      return '[$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}]';
    }
    return '[${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}]';
  }

  /// Word-level timestamps from Deepgram = absolute episode seconds. Markers every
  /// ~12s so the model can anchor citations accurately (was 30s).
  static const int _transcriptMarkerIntervalSec = 12;

  /// Builds a transcript with frequent [MM:SS] / [H:MM:SS] markers. If no word
  /// timestamps, returns plain text (model cannot copy ground-truth times).
  static String _buildTimestampedTranscript(TranscriptionResult transcription) {
    if (!transcription.hasWordTimestamps) return transcription.transcript;

    final buf = StringBuffer();
    var lastMarkerSec = -_transcriptMarkerIntervalSec;

    for (final w in transcription.wordTimestamps) {
      final absSec = w.startSec.round();
      if (absSec - lastMarkerSec >= _transcriptMarkerIntervalSec) {
        buf.write('${_formatTranscriptTimeMarker(absSec)} ');
        lastMarkerSec = absSec;
      }
      buf.write('${w.word} ');
    }

    return buf.toString().trimRight();
  }

  /// True if transcript has our bracket time markers (Deepgram path).
  static bool _transcriptHasTimeMarkers(String transcript) {
    return RegExp(r'\[\d{1,4}:\d{2}(?::\d{2})?\]').hasMatch(transcript);
  }

  /// Strict instructions: copy times from markers only (reduces hallucinated timestamps).
  static String _timestampAccuracyNote(String capped) {
    if (_transcriptHasTimeMarkers(capped)) {
      return '**Timestamp accuracy (required):**\n'
          '- The transcript contains bracket markers like [05:12] or [1:05:12] at the start of stretches of dialogue. '
          'Each marker is the **exact** time in the episode when the following words were spoken.\n'
          '- For **every** block below, the TIME field must be copied **exactly** from the **most recent […] marker that appears in the transcript immediately before** the passage you summarize or the sentence you use as QUOTE. Do not round, guess, or interpolate to “nice” times.\n'
          '- If one block covers multiple ideas, pick the marker for where that block **starts** in the transcript (earliest relevant marker).\n'
          '- **Never** invent a time that does not appear as a bracket marker near that text. If unsure, use the closest **earlier** marker you see in the transcript before that content.\n'
          '- The QUOTE line must be **verbatim** from the transcript text that follows that marker (same wording).\n\n';
    }
    return '**Timestamps:** This transcript has no embedded time markers. '
        'For TIME fields, give your best estimate as MM:SS **within the saved segment only**, '
        'or use the segment start time from the instructions above. Label clearly if approximate.\n\n';
  }

  /// Matches TIME: [MM:SS], TIME: MM:SS, TIME: [H:MM:SS], etc.
  static final RegExp _geminiTimeFieldPattern = RegExp(
    r'TIME:\s*\[?(\d{1,4}:\d{2}(?::\d{2})?)\]?',
    caseSensitive: false,
  );

  /// Episode clock for prompts, e.g. 1:05:03 or 12:34 (positions in full episode).
  static String _formatEpisodeClock(int totalSeconds) {
    var sec = totalSeconds;
    if (sec < 0) sec = 0;
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// early / middle / late using segment midpoint vs known episode duration.
  static String _segmentEarlyMiddleLate({
    required int startSec,
    required int endSec,
    int? episodeDurationSec,
  }) {
    if (episodeDurationSec == null || episodeDurationSec <= 0) {
      return 'unknown (episode duration unavailable — rely only on transcript text and timestamps)';
    }
    final mid = (startSec + endSec) / 2.0;
    final r = (mid / episodeDurationSec).clamp(0.0, 1.0);
    if (r < 0.34) return 'early';
    if (r < 0.67) return 'middle';
    return 'late';
  }

  /// Rich context so the model anchors on show, episode, and time range (reduces hallucination).
  String _buildSegmentContextForPrompt({
    required EpisodeMetadata episode,
    required ListeningSession session,
    required bool isFullEpisode,
  }) {
    final show = episode.podcastName.trim().isNotEmpty
        ? episode.podcastName.trim()
        : session.artist.trim();
    final epTitle = episode.title.trim().isNotEmpty
        ? episode.title.trim()
        : session.title.trim();
    final startLabel = _formatEpisodeClock(session.startTimeSec);
    final dur = episode.durationSeconds;

    final String timeRangeParagraph;
    final String positionParagraph;

    final String strictWindowRule;
    if (isFullEpisode) {
      timeRangeParagraph =
          'The transcript below covers audio from **$startLabel** through the **end of the episode** '
          '(everything in the transcript is within that span).';
      positionParagraph =
          'Context: Coverage runs from the user’s start position to the episode end; earlier parts of the show are **not** in this transcript.';
      strictWindowRule =
          '**USER-SELECTED WINDOW (strict):** The user asked to summarize **only** from **$startLabel** to the **end of the episode**. '
          'Do not summarize or reference content that would occur **before** $startLabel in the full episode. '
          'Stay within the transcript text below.';
    } else {
      final endSec = session.endTimeSec ?? session.startTimeSec;
      final endLabel = _formatEpisodeClock(endSec);
      timeRangeParagraph =
          'The transcript below is **only** the audio from **$startLabel** through **$endLabel** '
          'in the episode timeline (absolute positions in the episode, not wall-clock).';
      if (dur != null && dur > 0) {
        final pos = _segmentEarlyMiddleLate(
          startSec: session.startTimeSec,
          endSec: endSec,
          episodeDurationSec: dur,
        );
        positionParagraph =
            'Context: Relative to the full episode (about ${_formatEpisodeClock(dur)} total), '
            'this segment is approximately in the **$pos** part of the episode.';
      } else {
        positionParagraph =
            'Context: Total episode length is unknown, so early/middle/late cannot be estimated — '
            'use transcript timestamps and the segment start/end above only.';
      }
      strictWindowRule =
          '**USER-SELECTED WINDOW (strict):** The user chose **exactly** the span **$startLabel → $endLabel**. '
          'Summarize **only** what appears in the transcript for that span. '
          'Do **not** discuss content from before $startLabel or after $endLabel. '
          'Every TIME you output must be a timestamp from this transcript and must fall **between** $startLabel and $endLabel (inclusive).';
    }

    return '''
You are summarizing a **specific segment** of a podcast.

Show (podcast): $show
Episode title: $epTitle

$timeRangeParagraph

$positionParagraph

$strictWindowRule

The user saved this segment because they found it valuable. They want a **substantial** summary of what was discussed—main points and what to remember—not a one-sentence teaser. They will use **timestamps to jump back** in the episode, so every summary point must carry a **precise, transcript-grounded** time when markers are present. Extract **only** content clearly grounded in the transcript below. Do not invent guests, topics, or facts. Ignore content outside this time range. If something is ambiguous, omit it rather than guessing.

Transcript segment:
'''.trim();
  }

  /// Max transcript characters sent to Gemini (large context models).
  static const int _maxTranscriptPromptChars = 120000;

  static int _maxGeminiOutputTokensForLength(int transcriptChars) {
    if (transcriptChars > 45000) return 8192;
    if (transcriptChars > 15000) return 6144;
    return 4096;
  }

  /// Tells the model not to compress long episodes into a tiny teaser.
  static String _richnessBlockForTranscriptLength(int charCount) {
    if (charCount > 60000) {
      return '**Length expectation:** This transcript is very long (roughly a multi-hour conversation). '
          'The user wants a **full, proper summary**: major themes, arguments, conclusions, examples, names, numbers, and what is worth remembering. '
          'This is NOT a teaser—cover the substance across the whole transcript. '
          'Use every output block below to cover **different** parts of the discussion; do not repeat the same idea.\n\n';
    }
    if (charCount > 20000) {
      return '**Length expectation:** This is a long segment. Provide **substantial** coverage: main points, how they connect, and key takeaways—not one-line summaries. '
          'Spread detail across all requested blocks.\n\n';
    }
    return '**Length expectation:** Be thorough: each point should be concrete and useful, not a vague one-liner.\n\n';
  }

  /// Prompt text + dynamic output budget for Gemini.
  ({String prompt, int maxOutputTokens}) _buildPromptBundle(
    String transcript,
    SummaryStyle style, {
    required String segmentContext,
  }) {
    final capped = transcript.length > _maxTranscriptPromptChars
        ? transcript.substring(0, _maxTranscriptPromptChars)
        : transcript;
    final n = capped.length;
    final richness = _richnessBlockForTranscriptLength(n);
    final maxOut = _maxGeminiOutputTokensForLength(n);

    final timeNote = _timestampAccuracyNote(capped);

    const insightFormat = 'For EACH block use exactly this shape (TIME must be on its own line after the insight):\n'
        'INSIGHT: [2–6 sentences: one major theme, story arc, or argument from the transcript—concrete details, not fluff]\n'
        'TIME: [copy exactly from the nearest transcript bracket marker before this content—format MM:SS or H:MM:SS]\n'
        'QUOTE: [one supporting verbatim sentence from the transcript immediately after that marker]\n'
        '**The TIME line for a block applies to both the INSIGHT and the QUOTE in that block—use the same value twice if needed; it must match the bracket marker before the quoted words.**\n\n';

    final String taskBody;
    switch (style) {
      case SummaryStyle.insights:
        taskBody = 'You are summarizing a podcast for someone who will **not** re-listen. '
            'They need the **main ideas, reasoning, and what to remember** from this segment.\n\n'
            '$richness'
            '$timeNote'
            'Return **exactly 5** blocks (we store up to five). Each INSIGHT must be a **dense mini-summary** of a different major part of the discussion—'
            'not a single short sentence. Cover the transcript broadly (beginning, middle, end / distinct topics).\n\n'
            '$insightFormat'
            'Transcript:\n$capped';
        break;
      case SummaryStyle.deepNotes:
        taskBody = 'You are producing **deep notes** for a long-form podcast segment. '
            'The reader wants detail: how ideas connect, nuances, examples, and conclusions.\n\n'
            '$richness'
            '$timeNote'
            'Return **exactly 5** blocks. Each INSIGHT should be **longer and richer** than a normal bullet—'
            'several sentences, sub-points if needed—while staying grounded in the transcript.\n\n'
            '$insightFormat'
            'Transcript:\n$capped';
        break;
      case SummaryStyle.actionItems:
        taskBody = 'You extract actionable takeaways from this podcast segment only.\n\n'
            '$richness'
            '$timeNote'
            'Return **up to 5** action items (use 5 if the transcript is long and rich enough). '
            'Each ACTION should be specific. Each CONTEXT should be **1–3 sentences** explaining why and what was said.\n'
            'Format:\n'
            'ACTION: [do X]\n'
            'TIME: [exact copy from nearest […] marker before this action was discussed]\n'
            'CONTEXT: [substantial context from transcript]\n\n'
            'Only include actions grounded in this segment.\n\n'
            'Transcript:\n$capped';
        break;
      case SummaryStyle.smartChapters:
        final chapterCount = n > 60000 ? '10–14' : (n > 20000 ? '6–10' : '4–6');
        taskBody = 'You are a podcast chapter detector for this segment only.\n\n'
            '$richness'
            '$timeNote'
            'Detect topic changes. For long transcripts, return **$chapterCount chapters** so the whole arc is represented.\n'
            'Each SUMMARY must be **3–5 sentences** (real substance, not labels).\n'
            'Format each:\n'
            'CHAPTER: [title]\n'
            'TIME: [start time—copy from the […] marker where this chapter begins in the transcript]\n'
            'SUMMARY: [3-5 sentences]\n\n'
            'Transcript:\n$capped';
        break;
      case SummaryStyle.keyQuotes:
        final quoteCount = n > 40000 ? '5' : '4';
        taskBody = 'You extract the strongest verbatim quotes from this segment only.\n\n'
            '$richness'
            '$timeNote'
            'Return **$quoteCount** verbatim quotes (long transcript → more quotes). '
            'Each CONTEXT: **2–3 sentences** on why it matters.\n'
            'Format (TIME must be the marker immediately before this QUOTE in the transcript):\n'
            'QUOTE: [exact words]\n'
            'TIME: [exact copy from the […] marker before this quote]\n'
            'CONTEXT: [why this matters]\n\n'
            'Transcript:\n$capped';
        break;
    }

    return (
      prompt: '$segmentContext\n\n$taskBody',
      maxOutputTokens: maxOut,
    );
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
    // Multiline INSIGHT blocks (2–6 sentences) until TIME: on a new line.
    final insightPattern = RegExp(
      r'INSIGHT:\s*(.+?)(?=\n\s*TIME:\s*|\n\s*INSIGHT:\s*|\Z)',
      caseSensitive: false,
      dotAll: true,
    );
    final quotePattern = RegExp(r'QUOTE:\s*(.+)', caseSensitive: false);

    final insights = insightPattern
        .allMatches(raw)
        .map((m) => m.group(1)!.trim().replaceAll(RegExp(r'\n+'), ' '))
        .where((s) => s.isNotEmpty)
        .take(5)
        .toList();
    final times = _geminiTimeFieldPattern
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

    // Prepend timestamp to each insight if available; pair same TIME with each quote.
    final bullets = <String>[];
    final quotesWithTime = <String>[];
    for (var i = 0; i < insights.length; i++) {
      final time = i < times.length ? '[${times[i]}] ' : '';
      bullets.add('$time${insights[i]}');
      if (i < quotes.length) {
        final q = quotes[i];
        quotesWithTime.add(
          i < times.length ? '[${times[i]}] $q' : q,
        );
      }
    }

    return ParsedSummary(
      bullets: bullets,
      quotes: quotesWithTime,
      style: style,
    );
  }

  ParsedSummary _parseActionItems(String raw, SummaryStyle style) {
    final actionPattern = RegExp(r'ACTION:\s*(.+)', caseSensitive: false);
    final contextPattern = RegExp(
      r'CONTEXT:\s*(.+?)(?=\n\s*ACTION:\s*|\n\s*TIME:\s*|\Z)',
      caseSensitive: false,
      dotAll: true,
    );

    final actions = actionPattern
        .allMatches(raw)
        .map((m) => m.group(1)!.trim())
        .take(5)
        .toList();
    final times = _geminiTimeFieldPattern
        .allMatches(raw)
        .map((m) => m.group(1)!.trim())
        .take(5)
        .toList();
    final contexts = contextPattern
        .allMatches(raw)
        .map((m) => m.group(1)!.trim().replaceAll(RegExp(r'\n+'), ' '))
        .take(5)
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
    final summaryPattern = RegExp(
      r'SUMMARY:\s*(.+?)(?=\n\s*CHAPTER:\s*|\Z)',
      caseSensitive: false,
      dotAll: true,
    );

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
        .map((m) => m.group(1)!.trim().replaceAll(RegExp(r'\n+'), ' '))
        .toList();

    final chapters = <ChapterInfo>[];
    final bullets = <String>[];
    const maxChapters = 12;
    for (var i = 0; i < titles.length && i < maxChapters; i++) {
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
    final contextPattern = RegExp(
      r'CONTEXT:\s*(.+?)(?=\n\s*QUOTE:\s*|\Z)',
      caseSensitive: false,
      dotAll: true,
    );

    final quotes = quotePattern
        .allMatches(raw)
        .map((m) => m.group(1)!.trim())
        .take(5)
        .toList();
    final times = _geminiTimeFieldPattern
        .allMatches(raw)
        .map((m) => m.group(1)!.trim())
        .take(5)
        .toList();
    final contexts = contextPattern
        .allMatches(raw)
        .map((m) => m.group(1)!.trim().replaceAll(RegExp(r'\n+'), ' '))
        .take(5)
        .toList();

    final bullets = <String>[];
    final quotesWithTime = <String>[];
    for (var i = 0; i < quotes.length; i++) {
      final time = i < times.length ? '[${times[i]}] ' : '';
      final ctx = i < contexts.length ? ' — ${contexts[i]}' : '';
      bullets.add('$time"${quotes[i]}"$ctx');
      quotesWithTime.add(
        i < times.length ? '[${times[i]}] ${quotes[i]}' : quotes[i],
      );
    }

    return ParsedSummary(
      bullets: bullets.take(5).toList(),
      quotes: quotesWithTime,
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
        sourceShareUrl: Value(fields['sourceShareUrl']),
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

  static String _agentTruncate(String s, int max) {
    final t = s.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

  /// Maps user-facing pipeline text to debug hypotheses (H1 resolve, H2 transcript, H3 Gemini).
  static String _agentHypothesisForMessage(String m) {
    final l = m.toLowerCase();
    if (l.contains('transcript')) return 'H2';
    if (l.contains('gemini') ||
        l.contains('ai service') ||
        l.contains('api key') ||
        l.contains('generative')) {
      return 'H3';
    }
    if (l.contains('episode') ||
        l.contains('search') ||
        l.contains('manual entry') ||
        l.contains('taddy') ||
        l.contains('spotify') ||
        l.contains('itunes')) {
      return 'H1';
    }
    return 'H_UNK';
  }
}

class _ScoredEpisode {
  _ScoredEpisode({required this.episode, required this.composite});

  final Map<String, dynamic> episode;
  final double composite;
}

class _TaddySearchResponse {
  _TaddySearchResponse({
    required this.episodes,
    required this.rankingDetails,
  });

  final List<Map<String, dynamic>> episodes;
  final List<Map<String, dynamic>> rankingDetails;
}
