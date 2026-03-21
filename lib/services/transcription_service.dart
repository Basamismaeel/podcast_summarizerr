import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/pipeline_models.dart';

/// Abstracts transcription between Deepgram (primary) and Taddy (preferred).
/// Uses TRANSCRIPTION_PROVIDER from .env to pick the default.
class TranscriptionService {
  TranscriptionService._();
  static final instance = TranscriptionService._();

  /// In-memory cache keyed by "episodeId:start:end".
  final Map<String, TranscriptionResult> _memCache = {};

  String get _provider =>
      dotenv.env['TRANSCRIPTION_PROVIDER']?.toLowerCase() ?? 'deepgram';
  String get _deepgramKey => dotenv.env['DEEPGRAM_API_KEY'] ?? '';
  String get _taddyKey => dotenv.env['TADDY_API_KEY'] ?? '';
  String get _taddyUserId => dotenv.env['TADDY_USER_ID'] ?? '';

  /// Main entry point. Returns a transcription for the given episode segment.
  Future<TranscriptionResult> fetchTranscript({
    required String episodeId,
    required String audioUrl,
    required int startSec,
    required int endSec,
  }) async {
    final cacheKey = '$episodeId:$startSec:$endSec';

    // 1. Check in-memory cache
    if (_memCache.containsKey(cacheKey)) {
      debugPrint('[Transcription] cache hit for $cacheKey');
      return _memCache[cacheKey]!;
    }

    // 2. Try preferred provider
    if (_provider == 'taddy') {
      try {
        final result = await _fetchFromTaddy(episodeId, startSec, endSec);
        _memCache[cacheKey] = result;
        return result;
      } catch (e) {
        debugPrint('[Transcription] Taddy failed, falling back to Deepgram: $e');
      }
    }

    // 3. Deepgram (primary fallback or default)
    final result =
        await _fetchFromDeepgram(audioUrl, startSec, endSec);
    _memCache[cacheKey] = result;
    return result;
  }

  // ── Taddy ──────────────────────────────────────────────────────────────

  Future<TranscriptionResult> _fetchFromTaddy(
    String episodeId,
    int startSec,
    int endSec,
  ) async {
    if (_taddyKey.isEmpty || _taddyKey == 'placeholder') {
      throw const PipelineException(
        'Taddy API key not configured',
        retryable: false,
      );
    }

    final query = '''
    {
      getPodcastEpisode(uuid: "$episodeId") {
        uuid
        name
        transcript
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
        'Taddy returned ${response.statusCode}',
        retryable: true,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>?;
    final episode = data?['getPodcastEpisode'] as Map<String, dynamic>?;

    if (episode == null) {
      throw const PipelineException(
        'Transcript not available for this episode',
        retryable: false,
      );
    }

    final rawText = episode['transcript'] as String? ?? '';
    // Taddy's transcript field is plain text, no word-level timestamps
    final rawWords = <dynamic>[];

    final words = rawWords
        .map((e) => WordTimestamp.fromJson(e as Map<String, dynamic>))
        .toList();

    // Slice to the requested time range
    final full = TranscriptionResult(
      transcript: rawText,
      wordTimestamps: words,
      source: 'taddy',
    );

    if (startSec == 0 && endSec == -1) return full;

    final effectiveEnd = endSec == -1 ? 999999 : endSec;
    final slicedText = full.sliceByTimestamp(startSec, effectiveEnd);
    final slicedWords = words
        .where((w) => w.startSec >= startSec && w.endSec <= effectiveEnd)
        .toList();

    return TranscriptionResult(
      transcript: slicedText.isEmpty ? rawText : slicedText,
      wordTimestamps: slicedWords,
      source: 'taddy',
    );
  }

  // ── Deepgram ───────────────────────────────────────────────────────────

  Future<TranscriptionResult> _fetchFromDeepgram(
    String audioUrl,
    int startSec,
    int endSec,
  ) async {
    if (_deepgramKey.isEmpty || _deepgramKey == 'placeholder') {
      throw const PipelineException(
        'Deepgram API key not configured',
        retryable: false,
      );
    }

    final queryParams = <String, String>{
      'model': 'nova-3',
      'punctuate': 'true',
      'diarize': 'false',
      'smart_format': 'true',
    };

    final uri = Uri.parse('https://api.deepgram.com/v1/listen')
        .replace(queryParameters: queryParams);

    final bodyPayload = <String, dynamic>{'url': audioUrl};
    // Deepgram supports pre-recorded audio URL with time range via keywords
    // but the most reliable way is to pass the full URL and slice after.
    // For partial episodes we pass the URL and slice the result.

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Token $_deepgramKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(bodyPayload),
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const PipelineException(
        'AI service unavailable — try again in a moment',
        retryable: false,
      );
    }

    if (response.statusCode != 200) {
      throw PipelineException(
        'Transcription service error (${response.statusCode})',
        retryable: true,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = body['results'] as Map<String, dynamic>?;
    final channels = results?['channels'] as List<dynamic>?;
    final alt = (channels?.firstOrNull as Map<String, dynamic>?)?['alternatives']
        as List<dynamic>?;
    final best = alt?.firstOrNull as Map<String, dynamic>?;

    final rawTranscript = best?['transcript'] as String? ?? '';
    final rawWords = best?['words'] as List<dynamic>? ?? [];

    final words = rawWords.map((w) {
      final m = w as Map<String, dynamic>;
      return WordTimestamp(
        word: m['punctuated_word'] as String? ?? m['word'] as String? ?? '',
        startSec: (m['start'] as num?)?.toDouble() ?? 0,
        endSec: (m['end'] as num?)?.toDouble() ?? 0,
      );
    }).toList();

    final full = TranscriptionResult(
      transcript: rawTranscript,
      wordTimestamps: words,
      source: 'deepgram',
    );

    // Slice to the requested range if not full-episode
    if (startSec == 0 && endSec == -1) return full;

    final effectiveEnd = endSec == -1 ? 999999 : endSec;
    final sliced = full.sliceByTimestamp(startSec, effectiveEnd);
    final slicedWords = words
        .where((w) => w.startSec >= startSec && w.endSec <= effectiveEnd)
        .toList();

    return TranscriptionResult(
      transcript: sliced.isEmpty ? rawTranscript : sliced,
      wordTimestamps: slicedWords,
      source: 'deepgram',
    );
  }
}
