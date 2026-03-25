import 'dart:convert';

import 'package:http/http.dart' as http;

import '../debug/agent_ndjson_log.dart';

/// ASIN extraction, Audnexus (metadata + chapters), and optional Google Books text.
class AudibleBookService {
  AudibleBookService._();

  static const _audnexusBase = 'https://api.audnex.us';

  /// Audnexus stores per-region catalogs; try others if US has no book/chapters.
  static const List<String> audnexusRegions = [
    'us',
    'uk',
    'de',
    'au',
    'ca',
    'es',
    'fr',
    'in',
    'it',
    'jp',
  ];

  /// `B` + 9 alphanumeric, Audible book ASIN shape (case-insensitive).
  static final _asinOnly = RegExp(r'^B[0-9A-Z]{9}$', caseSensitive: false);

  /// When [s] is exactly a book ASIN, returns normalized uppercase form.
  static String? parseStandaloneAsin(String? s) {
    final t = s?.trim() ?? '';
    if (t.isEmpty || !_asinOnly.hasMatch(t)) return null;
    return t.toUpperCase();
  }

  /// Extract Audible ASIN from common URL shapes.
  static String? extractAsin(String url) {
    final u = url.trim();
    if (u.isEmpty) return null;

    final uri = Uri.tryParse(u);
    if (uri != null && uri.hasAuthority) {
      for (final e in uri.queryParameters.entries) {
        if (e.key.toLowerCase() == 'asin') {
          final v = parseStandaloneAsin(e.value);
          if (v != null) return v;
        }
      }
      for (final seg in uri.pathSegments) {
        if (seg.isEmpty) continue;
        final core = seg.split('?').first;
        final exact = parseStandaloneAsin(core);
        if (exact != null) return exact;
        final tail = RegExp(
          r'(B[0-9A-Z]{9})$',
          caseSensitive: false,
        ).firstMatch(core);
        if (tail != null) return tail.group(1)!.toUpperCase();
      }
    }

    final patterns = <RegExp>[
      RegExp(r'/pd/[^/]+/(B[A-Z0-9]{9})', caseSensitive: false),
      RegExp(r'/pd/(B[A-Z0-9]{9})(?:/|\?|#|$)', caseSensitive: false),
      RegExp(r'/e/(B[A-Z0-9]{9})', caseSensitive: false),
      RegExp(r'/dp/(B[A-Z0-9]{9})', caseSensitive: false),
      RegExp(r'adbl\.co/(B[A-Z0-9]{9})', caseSensitive: false),
      RegExp(r'asin=(B[A-Z0-9]{9})', caseSensitive: false),
      RegExp(r'[-_/](B[0-9A-Z]{9})(?:\?|/|#|$)', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(u);
      if (match != null) return match.group(1)!.toUpperCase();
    }
    return null;
  }

  /// Ordered ASINs from Audible HTML: meta URLs first, then product JSON, etc.
  /// (The first `"asin"` in HTML is often a carousel item — not the PDP — so we
  /// collect several and let the caller probe Audnexus.)
  static List<String> extractAsinCandidatesFromAudibleHtml(String html) {
    final out = <String>[];

    void push(String? code) {
      final v = parseStandaloneAsin(code);
      if (v == null) return;
      if (!out.contains(v)) out.add(v);
    }

    String? asinFromMetaUrl(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      final decoded = raw.replaceAll('&amp;', '&').trim();
      return extractAsin(decoded);
    }

    final ogUrlPatterns = <RegExp>[
      RegExp(
        r'<meta\s+[^>]*property="og:url"[^>]*content="([^"]+)"',
        caseSensitive: false,
      ),
      RegExp(
        r"<meta\s+[^>]*property='og:url'[^>]*content='([^']+)'",
        caseSensitive: false,
      ),
      RegExp(
        r'<meta\s+[^>]*content="([^"]+)"[^>]*property="og:url"',
        caseSensitive: false,
      ),
      RegExp(
        r"<meta\s+[^>]*content='([^']+)'[^>]*property='og:url'",
        caseSensitive: false,
      ),
    ];
    for (final re in ogUrlPatterns) {
      final m = re.firstMatch(html);
      if (m != null) push(asinFromMetaUrl(m.group(1)));
    }

    final canonicalPatterns = <RegExp>[
      RegExp(
        r'<link\s+[^>]*rel="canonical"[^>]*href="([^"]+)"',
        caseSensitive: false,
      ),
      RegExp(
        r"<link\s+[^>]*rel='canonical'[^>]*href='([^']+)'",
        caseSensitive: false,
      ),
      RegExp(
        r'<link\s+[^>]*href="([^"]+)"[^>]*rel="canonical"',
        caseSensitive: false,
      ),
      RegExp(
        r"<link\s+[^>]*href='([^']+)'[^>]*rel='canonical'",
        caseSensitive: false,
      ),
    ];
    for (final re in canonicalPatterns) {
      final m = re.firstMatch(html);
      if (m != null) push(asinFromMetaUrl(m.group(1)));
    }

    final twPatterns = <RegExp>[
      RegExp(
        r'<meta\s+[^>]*name="twitter:url"[^>]*content="([^"]+)"',
        caseSensitive: false,
      ),
      RegExp(
        r"<meta\s+[^>]*name='twitter:url'[^>]*content='([^']+)'",
        caseSensitive: false,
      ),
    ];
    for (final re in twPatterns) {
      final m = re.firstMatch(html);
      if (m != null) push(asinFromMetaUrl(m.group(1)));
    }

    final productRe = RegExp(
      r'"productAsin"\s*:\s*"(B[0-9A-Z]{9})"',
      caseSensitive: false,
    );
    for (final m in productRe.allMatches(html)) {
      push(m.group(1));
    }

    final asinJsonRe = RegExp(
      r'"asin"\s*:\s*"(B[0-9A-Z]{9})"',
      caseSensitive: false,
    );
    // Pages embed many carousel / recommendation ASINs — cap after meta URLs.
    var looseAsin = 0;
    const maxLooseJsonAsin = 12;
    for (final m in asinJsonRe.allMatches(html)) {
      if (looseAsin >= maxLooseJsonAsin) break;
      push(m.group(1));
      looseAsin++;
    }

    final dataAsinRe = RegExp(
      r'''data-asin=["'](B[0-9A-Z]{9})["']''',
      caseSensitive: false,
    );
    for (final m in dataAsinRe.allMatches(html)) {
      push(m.group(1));
    }

    final asinEqRe = RegExp(
      r'asin[/=](B[0-9A-Z]{9})(?:["\s&<]|$)',
      caseSensitive: false,
    );
    for (final m in asinEqRe.allMatches(html)) {
      push(m.group(1));
    }

    return out;
  }

  /// First ASIN from [extractAsinCandidatesFromAudibleHtml], or null.
  static String? extractAsinFromAudibleHtml(String html) {
    final c = extractAsinCandidatesFromAudibleHtml(html);
    if (c.isEmpty) {
      // #region agent log
      final lowerHtml = html.toLowerCase();
      agentNdjsonLog(
        hypothesisId: 'H3',
        location: 'audible_book_service.dart:extractAsinFromAudibleHtml',
        message: 'No ASIN matched in HTML patterns',
        data: <String, Object?>{
          'htmlLen': html.length,
          'hasOgUrl': lowerHtml.contains('og:url'),
          'hasCanonical': lowerHtml.contains('canonical'),
          'hasJsonAsin': html.contains('"asin"'),
          'hasDataAsin': lowerHtml.contains('data-asin'),
          'asinLikeCount': RegExp(r'B[0-9A-Z]{9}', caseSensitive: false)
              .allMatches(html)
              .length,
        },
        runId: 'asin-debug-v2',
      );
      // #endregion
      return null;
    }
    return c.first;
  }

  /// Fetches an Audible page and returns ordered ASIN candidates from HTML.
  static Future<List<String>> scrapeAsinCandidatesFromAudiblePage(
    String url,
  ) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return const [];
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return const [];
    }
    final host = uri.host.toLowerCase();
    if (!host.contains('audible.') && !host.contains('adbl.co')) {
      return const [];
    }

    try {
      final res = await http
          .get(
            uri,
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
                  'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
                  'Mobile/15E148 Safari/604.1',
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'en-US,en;q=0.9',
            },
          )
          .timeout(const Duration(seconds: 14));
      // #region agent log
      if (res.statusCode < 200 || res.statusCode >= 400) {
        agentNdjsonLog(
          hypothesisId: 'H2',
          location: 'audible_book_service.dart:scrapeAsinCandidatesFromAudiblePage',
          message: 'HTTP non-success for Audible scrape',
          data: <String, Object?>{
            'status': res.statusCode,
            'bodyLen': res.body.length,
            'host': uri.host,
          },
          runId: 'asin-debug-v2',
        );
        return const [];
      }
      // #endregion
      final list = extractAsinCandidatesFromAudibleHtml(res.body);
      // #region agent log
      if (list.isEmpty) {
        agentNdjsonLog(
          hypothesisId: 'H3',
          location: 'audible_book_service.dart:scrapeAsinCandidatesFromAudiblePage',
          message: 'HTTP 200 but no ASIN candidates in HTML',
          data: <String, Object?>{
            'status': res.statusCode,
            'bodyLen': res.body.length,
            'host': uri.host,
          },
          runId: 'asin-debug-v2',
        );
      } else {
        agentNdjsonLog(
          hypothesisId: 'H5',
          location: 'audible_book_service.dart:scrapeAsinCandidatesFromAudiblePage',
          message: 'ASIN candidates from page fetch',
          data: <String, Object?>{
            'host': uri.host,
            'n': list.length,
          },
          runId: 'asin-debug-v2',
        );
      }
      // #endregion
      return list;
    } catch (e, _) {
      // #region agent log
      agentNdjsonLog(
        hypothesisId: 'H2',
        location: 'audible_book_service.dart:scrapeAsinCandidatesFromAudiblePage',
        message: 'scrape exception',
        data: <String, Object?>{
          'errType': e.runtimeType.toString(),
          'host': uri.host,
        },
        runId: 'asin-debug-v2',
      );
      // #endregion
      return const [];
    }
  }

  /// First candidate only — prefer [scrapeAsinCandidatesFromAudiblePage] in pipeline.
  static Future<String?> scrapeAsinFromAudiblePage(String url) async {
    final c = await scrapeAsinCandidatesFromAudiblePage(url);
    return c.isEmpty ? null : c.first;
  }

  static int chapterStartSec(Map<String, dynamic> c) {
    final sec = c['startOffsetSec'];
    if (sec is num) return sec.toInt();
    final ms = c['startOffsetMs'];
    if (ms is num) return ms ~/ 1000;
    return 0;
  }

  /// Last chapter whose start ≤ [targetSec], else first chapter.
  static Map<String, dynamic> chapterForTimestamp(
    List<Map<String, dynamic>> chapters,
    int targetSec,
  ) {
    if (chapters.isEmpty) return {};
    Map<String, dynamic>? chosen;
    for (final c in chapters) {
      if (chapterStartSec(c) <= targetSec) {
        chosen = c;
      } else {
        break;
      }
    }
    return chosen ?? chapters.first;
  }

  static Uri _audnexusBookUri(String asin, String region) =>
      Uri.parse('$_audnexusBase/books/$asin').replace(
        queryParameters: {'region': region},
      );

  static Uri _audnexusChaptersUri(String asin, String region) =>
      Uri.parse('$_audnexusBase/books/$asin/chapters').replace(
        queryParameters: {'region': region},
      );

  static Future<Map<String, dynamic>> _audnexusGetJson(
    Uri uri, {
    required String errorLabel,
  }) async {
    final res = await http.get(uri).timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) {
      throw AudibleApiException('$errorLabel (${res.statusCode})');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Metadata for [asin], trying several Audible regions until one succeeds.
  static Future<Map<String, dynamic>> fetchBook(String asin) async {
    AudibleApiException? last;
    for (final region in audnexusRegions) {
      try {
        final uri = _audnexusBookUri(asin, region);
        return await _audnexusGetJson(uri, errorLabel: 'Audnexus book failed');
      } on AudibleApiException catch (e) {
        last = e;
      }
    }
    throw last ?? AudibleApiException('Audnexus book failed (all regions)');
  }

  /// Chapter markers (titles + start times) for [asin], trying regions until
  /// a non-empty list is returned.
  static Future<List<Map<String, dynamic>>> fetchChapters(String asin) async {
    AudibleApiException? last;
    for (final region in audnexusRegions) {
      try {
        final uri = _audnexusChaptersUri(asin, region);
        final map =
            await _audnexusGetJson(uri, errorLabel: 'Audnexus chapters failed');
        final raw = map['chapters'] as List<dynamic>? ?? [];
        if (raw.isEmpty) {
          last = AudibleApiException('Audnexus chapters empty ($region)');
          continue;
        }
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } on AudibleApiException catch (e) {
        last = e;
      }
    }
    throw last ?? AudibleApiException('Audnexus chapters failed (all regions)');
  }

  /// JSON stored in [ListeningSession.chaptersJson] for Audible sessions.
  static String buildChaptersStorageJson({
    required String asin,
    required List<Map<String, dynamic>> chapters,
  }) {
    return jsonEncode({
      'source': 'audible',
      'asin': asin,
      'chapters': chapters,
    });
  }

  /// Extra keys on [chaptersJson] when the Audible pipeline used Open Library text.
  static void attachOpenLibraryCompanionFields(
    Map<String, dynamic> chaptersMap, {
    required String companionOpenLibraryId,
    required String openLibraryTitle,
  }) {
    chaptersMap['companionOpenLibraryId'] = companionOpenLibraryId;
    chaptersMap['openLibraryTitle'] = openLibraryTitle;
  }

  static AudibleChaptersPayload? parseChaptersPayload(String? chaptersJson) {
    if (chaptersJson == null || chaptersJson.trim().isEmpty) return null;
    try {
      final map = jsonDecode(chaptersJson) as Map<String, dynamic>;
      if (map['source'] != 'audible') return null;
      final asin = map['asin'] as String? ?? '';
      final raw = map['chapters'] as List<dynamic>? ?? [];
      final chapters = raw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return AudibleChaptersPayload(asin: asin, chapters: chapters);
    } catch (_) {
      return null;
    }
  }

  static String formatChapterClock(int totalSeconds) {
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

  /// Optional: richer book text from Google Books (requires API key).
  static Future<String> fetchGoogleBooksDescription({
    required String title,
    required String author,
    required String apiKey,
  }) async {
    if (apiKey.trim().isEmpty) return '';
    final q =
        'intitle:${Uri.encodeComponent(title)}+inauthor:${Uri.encodeComponent(author)}';
    final searchUri = Uri.https(
      'www.googleapis.com',
      '/books/v1/volumes',
      {'q': q, 'maxResults': '3', 'key': apiKey.trim()},
    );
    final searchRes =
        await http.get(searchUri).timeout(const Duration(seconds: 20));
    if (searchRes.statusCode != 200) return '';
    final searchBody = jsonDecode(searchRes.body) as Map<String, dynamic>;
    final items = searchBody['items'] as List<dynamic>? ?? [];
    if (items.isEmpty) return '';
    final first = items.first as Map<String, dynamic>;
    final id = first['id'] as String?;
    if (id == null || id.isEmpty) return '';

    final volUri = Uri.https(
      'www.googleapis.com',
      '/books/v1/volumes/$id',
      {'key': apiKey.trim()},
    );
    final volRes = await http.get(volUri).timeout(const Duration(seconds: 20));
    if (volRes.statusCode != 200) return '';
    final vol = jsonDecode(volRes.body) as Map<String, dynamic>;
    final vi = vol['volumeInfo'] as Map<String, dynamic>?;
    if (vi == null) return '';
    final desc = vi['description'] as String? ?? '';
    return desc.trim();
  }

  static String primaryAuthorName(Map<String, dynamic> book) {
    final authors = book['authors'] as List<dynamic>? ?? [];
    if (authors.isEmpty) return '';
    final first = authors.first;
    if (first is Map<String, dynamic>) {
      return (first['name'] as String? ?? '').trim();
    }
    return first.toString();
  }

  static String allAuthorNames(Map<String, dynamic> book) {
    final authors = book['authors'] as List<dynamic>? ?? [];
    return authors
        .map((a) {
          if (a is Map<String, dynamic>) {
            return (a['name'] as String? ?? '').trim();
          }
          return a.toString().trim();
        })
        .where((s) => s.isNotEmpty)
        .join(', ');
  }

  static String narratorsLine(Map<String, dynamic> book) {
    final narrators = book['narrators'] as List<dynamic>? ?? [];
    return narrators
        .map((n) {
          if (n is Map<String, dynamic>) {
            return (n['name'] as String? ?? '').trim();
          }
          return n.toString().trim();
        })
        .where((s) => s.isNotEmpty)
        .join(', ');
  }

  static String genresLine(Map<String, dynamic> book) {
    final genres = book['genres'] as List<dynamic>? ?? [];
    return genres
        .map((g) {
          if (g is Map<String, dynamic>) {
            return (g['name'] as String? ?? '').trim();
          }
          return g.toString().trim();
        })
        .where((s) => s.isNotEmpty)
        .take(12)
        .join(', ');
  }

  /// [description] + [summary] from Audnexus when both exist (more text without Google Books).
  static String mergeDescriptionAndSummary(Map<String, dynamic> book) {
    final d = (book['description'] as String? ?? '').trim();
    final s = (book['summary'] as String? ?? '').trim();
    if (d.isEmpty) return s;
    if (s.isEmpty) return d;
    if (d == s) return d;
    if (s.contains(d) && s.length >= d.length) return s;
    if (d.contains(s) && d.length >= s.length) return d;
    return '$d\n\n---\n\n$s';
  }

  static int? indexOfChapterWithStart(
    List<Map<String, dynamic>> chapters,
    Map<String, dynamic> active,
  ) {
    final ts = chapterStartSec(active);
    for (var i = 0; i < chapters.length; i++) {
      if (chapterStartSec(chapters[i]) == ts) return i;
    }
    return null;
  }

  /// Structured metadata + chapter neighborhood for Gemini (no audio).
  static String buildStructuredMetadata({
    required Map<String, dynamic> book,
    required List<Map<String, dynamic>> chapters,
    required Map<String, dynamic> activeChapter,
  }) {
    final buf = StringBuffer();
    final title = (book['title'] as String? ?? '').trim();
    final subtitle = (book['subtitle'] as String? ?? '').trim();
    if (title.isNotEmpty) buf.writeln('Title: $title');
    if (subtitle.isNotEmpty) buf.writeln('Subtitle: $subtitle');

    final authors = allAuthorNames(book);
    if (authors.isNotEmpty) buf.writeln('Authors: $authors');

    final narr = narratorsLine(book);
    if (narr.isNotEmpty) buf.writeln('Narrators: $narr');

    final pub = (book['publisherName'] as String? ?? '').trim();
    if (pub.isNotEmpty) buf.writeln('Publisher: $pub');

    final genres = genresLine(book);
    if (genres.isNotEmpty) buf.writeln('Genres/tags: $genres');

    final sp = book['seriesPrimary'];
    if (sp is Map<String, dynamic>) {
      final sn = (sp['name'] as String? ?? '').trim();
      final pos = sp['position'];
      if (sn.isNotEmpty) {
        buf.writeln(
          'Series: $sn${pos != null ? ' (book #$pos)' : ''}',
        );
      }
    }

    final runtimeMin = book['runtimeLengthMin'];
    if (runtimeMin is num) {
      buf.writeln('Runtime (metadata): ~${runtimeMin.toInt()} min');
    }

    final idx = indexOfChapterWithStart(chapters, activeChapter);
    if (idx != null) {
      if (idx > 0) {
        final p = chapters[idx - 1];
        buf.writeln(
          'Previous chapter: "${p['title']}" @ ${formatChapterClock(chapterStartSec(p))}',
        );
      }
      final c = chapters[idx];
      buf.writeln(
        '**Target chapter:** "${c['title']}" @ ${formatChapterClock(chapterStartSec(c))}',
      );
      if (idx + 1 < chapters.length) {
        final n = chapters[idx + 1];
        buf.writeln(
          'Next chapter: "${n['title']}" @ ${formatChapterClock(chapterStartSec(n))}',
        );
      }
    } else {
      buf.writeln(
        '**Target chapter:** "${activeChapter['title']}" @ ${formatChapterClock(chapterStartSec(activeChapter))}',
      );
    }

    return buf.toString().trim();
  }
}

class AudibleChaptersPayload {
  const AudibleChaptersPayload({
    required this.asin,
    required this.chapters,
  });

  final String asin;
  final List<Map<String, dynamic>> chapters;
}

class AudibleApiException implements Exception {
  AudibleApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
