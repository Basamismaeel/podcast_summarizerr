import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:string_similarity/string_similarity.dart';

/// Project Gutenberg via [Gutendex](https://gutendex.com/) + plain-text ebooks.
class GutenbergBookService {
  GutenbergBookService._();

  static const _gutendexBase = 'https://gutendex.com';
  static const _userAgent = 'PodcastSafetyNet/1.0 (Gutenberg reader; +https://www.gutenberg.org/policy/robot_access)';

  /// GET https://gutendex.com/books/?search={query}
  static Future<List<GutenbergBookSearchHit>> searchBooks(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final uri = Uri.parse('$_gutendexBase/books/').replace(
      queryParameters: {'search': q},
    );

    final res = await http
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) return [];

    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final results = map['results'] as List<dynamic>? ?? [];
    final out = <GutenbergBookSearchHit>[];

    for (final raw in results) {
      if (raw is! Map<String, dynamic>) continue;
      final idVal = raw['id'];
      final id = idVal is int
          ? idVal
          : idVal is num
              ? idVal.toInt()
              : int.tryParse('$idVal');
      if (id == null) continue;
      final title = (raw['title'] as String? ?? '').trim();
      if (title.isEmpty) continue;

      final authors = raw['authors'] as List<dynamic>? ?? [];
      var author = '';
      if (authors.isNotEmpty && authors.first is Map<String, dynamic>) {
        author =
            ((authors.first as Map<String, dynamic>)['name'] as String? ?? '')
                .trim();
      }
      if (author.isEmpty) author = 'Unknown';

      final fmRaw = raw['formats'];
      if (fmRaw is! Map) continue;
      final formats = Map<String, dynamic>.from(fmRaw);
      final textUrl = formats['text/plain; charset=utf-8'] as String? ??
          formats['text/plain'] as String?;
      if (textUrl == null || textUrl.isEmpty) continue;

      out.add(
        GutenbergBookSearchHit(
          id: id,
          title: title,
          author: author,
          textUrl: textUrl,
        ),
      );
    }

    return out;
  }

  /// Tries to find a Project Gutenberg plain-text edition that matches an
  /// Audible book ([audibleTitle] / [audibleAuthor]) for **full chapter text**.
  ///
  /// Returns null if Gutendex has no plausible hit (wrong book is worse than
  /// no match). Only considers results that already include a `text/plain` URL.
  static Future<GutenbergBookSearchHit?> findPublicDomainCompanionForAudiobook({
    required String audibleTitle,
    required String audibleAuthor,
  }) async {
    final title = audibleTitle.trim();
    final auth = audibleAuthor.trim();
    if (title.isEmpty) return null;

    final qPrimary = '$title $auth'.trim();
    var hits = await searchBooks(
      qPrimary.length > 180 ? title : qPrimary,
    );
    if (hits.isEmpty) {
      hits = await searchBooks(title);
    }
    if (hits.isEmpty) return null;

    return _pickBestAudiobookCompanion(title, auth, hits);
  }

  static String _normBookMatch(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
        .trim();
  }

  static GutenbergBookSearchHit? _pickBestAudiobookCompanion(
    String audibleTitle,
    String audibleAuthor,
    List<GutenbergBookSearchHit> hits,
  ) {
    final nt = _normBookMatch(audibleTitle);
    final na = _normBookMatch(audibleAuthor);
    GutenbergBookSearchHit? best;
    var bestCombined = 0.0;
    const minCombined = 0.52;
    const minTitle = 0.38;

    for (final h in hits.take(8)) {
      final tScore =
          StringSimilarity.compareTwoStrings(nt, _normBookMatch(h.title));
      final aScore = na.isEmpty
          ? 0.55
          : StringSimilarity.compareTwoStrings(na, _normBookMatch(h.author));
      final combined = tScore * 0.72 + aScore * 0.28;
      if (combined > bestCombined &&
          combined >= minCombined &&
          tScore >= minTitle) {
        bestCombined = combined;
        best = h;
      }
    }
    return best;
  }

  /// Maps an **Audible** chapter title (from Audnexus) to an index into
  /// [GutenbergChapter] list from [splitIntoChapters].
  static int? indexMatchingAudibleChapterTitle(
    String audibleChapterTitle,
    List<GutenbergChapter> chapters,
  ) {
    final raw = audibleChapterTitle.trim();
    if (raw.isEmpty || chapters.isEmpty) return null;

    final lower = raw.toLowerCase();
    if ((lower.contains('opening') || lower.contains('end')) &&
        lower.contains('credit')) {
      return null;
    }

    int? parseLeadingInt(RegExp re) {
      final m = re.firstMatch(lower);
      if (m == null) return null;
      for (var g = 1; g <= m.groupCount; g++) {
        final v = m.group(g);
        if (v != null) {
          final n = int.tryParse(v);
          if (n != null && n > 0) return n;
        }
      }
      return null;
    }

    var n = parseLeadingInt(RegExp(r'chapter\s*(\d+)', caseSensitive: false));
    n ??= parseLeadingInt(RegExp(r'^(\d+)[\.\)]'));
    n ??= parseLeadingInt(RegExp(r'part\s*(\d+)', caseSensitive: false));

    if (n != null) {
      for (var i = 0; i < chapters.length; i++) {
        if (chapters[i].chapterNumber == n) return i;
      }
      if (n <= chapters.length) return n - 1;
    }

    final romanM =
        RegExp(r'chapter\s*([ivxlcdm]+)\b', caseSensitive: false).firstMatch(lower);
    if (romanM != null) {
      final rv = _parseRomanNumeral(romanM.group(1)!);
      if (rv != null) {
        for (var i = 0; i < chapters.length; i++) {
          if (chapters[i].chapterNumber == rv) return i;
        }
        if (rv <= chapters.length) return rv - 1;
      }
    }

    var bestI = -1;
    var bestS = 0.46;
    final normAudible = _normBookMatch(raw);
    for (var i = 0; i < chapters.length; i++) {
      final s = StringSimilarity.compareTwoStrings(
        normAudible,
        _normBookMatch(chapters[i].chapterTitle),
      );
      if (s > bestS) {
        bestS = s;
        bestI = i;
      }
    }
    return bestI >= 0 ? bestI : null;
  }

  static int? _parseRomanNumeral(String s) {
    final upper = s.trim().toUpperCase();
    if (upper.isEmpty || !RegExp(r'^[IVXLCDM]+$').hasMatch(upper)) {
      return null;
    }
    const map = {'I': 1, 'V': 5, 'X': 10, 'L': 50, 'C': 100, 'D': 500, 'M': 1000};
    var total = 0;
    var prev = 0;
    for (var i = upper.length - 1; i >= 0; i--) {
      final v = map[upper[i]];
      if (v == null) return null;
      if (v < prev) {
        total -= v;
      } else {
        total += v;
        prev = v;
      }
    }
    return total > 0 ? total : null;
  }

  /// Downloads plain text and strips Project Gutenberg boilerplate.
  static Future<String> fetchBookText(String textUrl) async {
    var uri = Uri.tryParse(textUrl.trim());
    if (uri == null || !uri.hasScheme) {
      throw GutenbergBookException('Invalid text URL');
    }
    // iOS ATS blocks plain HTTP; mirrors often redirect to http://gutenberg.org/...
    if (uri.scheme == 'http' &&
        uri.host.toLowerCase().contains('gutenberg.org')) {
      uri = uri.replace(scheme: 'https');
    }

    final res = await http
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 120));

    if (res.statusCode != 200) {
      throw GutenbergBookException('Download failed (${res.statusCode})');
    }

    final body = utf8.decode(res.bodyBytes, allowMalformed: true);

    final start = RegExp(
      r'\*{2,3}\s*START OF (THE|THIS) PROJECT GUTENBERG EBOOK',
      caseSensitive: false,
    );
    final end = RegExp(
      r'\*{2,3}\s*END OF (THE|THIS) PROJECT GUTENBERG EBOOK',
      caseSensitive: false,
    );

    var s = body;
    final sm = start.firstMatch(s);
    if (sm != null) {
      s = s.substring(sm.end);
    }
    final em = end.firstMatch(s);
    if (em != null) {
      s = s.substring(0, em.start);
    }

    return s.trim();
  }

  /// Splits full book text into chapters (max 50).
  static List<GutenbergChapter> splitIntoChapters(String text) {
    final t = text.trim();
    if (t.isEmpty) return [];

    final headerRe = RegExp(
      r'^(CHAPTER|Chapter|PART|Part)\s+([IVXLCDM]+|\d+)\b',
      multiLine: true,
    );

    var list = _splitAtMatches(t, headerRe);
    if (list.length < 2) {
      list = _splitRomanLineBreaks(t);
    }
    if (list.length < 2) {
      list = _chunkByWordCount(t, 3000);
    }

    return list.take(50).toList();
  }

  static List<GutenbergChapter> _splitAtMatches(String text, RegExp headerRe) {
    final matches = headerRe.allMatches(text).toList();
    if (matches.isEmpty) return [];

    final out = <GutenbergChapter>[];
    for (var i = 0; i < matches.length; i++) {
      final a = matches[i].start;
      final b = i + 1 < matches.length ? matches[i + 1].start : text.length;
      var chunk = text.substring(a, b).trim();
      if (chunk.isEmpty) continue;

      final nl = chunk.indexOf('\n');
      final title =
          nl >= 0 ? chunk.substring(0, nl).trim() : chunk;
      final content = nl >= 0 ? chunk.substring(nl + 1).trim() : '';

      out.add(
        GutenbergChapter(
          chapterNumber: out.length + 1,
          chapterTitle: title,
          content: content.isNotEmpty ? content : chunk,
        ),
      );
    }
    return out;
  }

  /// Roman numerals alone on a line (I … XX etc.).
  static final _romanLine = RegExp(r'^\s*[IVXLCDM]{1,15}\s*$', multiLine: true);

  static List<GutenbergChapter> _splitRomanLineBreaks(String text) {
    final matches = _romanLine.allMatches(text).toList();
    if (matches.length < 2) return [];

    final out = <GutenbergChapter>[];
    for (var i = 0; i < matches.length; i++) {
      final a = matches[i].start;
      final b = i + 1 < matches.length ? matches[i + 1].start : text.length;
      var chunk = text.substring(a, b).trim();
      if (chunk.isEmpty) continue;

      final nl = chunk.indexOf('\n');
      final title =
          nl >= 0 ? chunk.substring(0, nl).trim() : chunk.trim();
      final content = nl >= 0 ? chunk.substring(nl + 1).trim() : '';

      out.add(
        GutenbergChapter(
          chapterNumber: out.length + 1,
          chapterTitle: title,
          content: content.isNotEmpty ? content : chunk,
        ),
      );
    }
    return out;
  }

  static List<GutenbergChapter> _chunkByWordCount(String text, int wordsPer) {
    final words = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return [];

    final out = <GutenbergChapter>[];
    for (var i = 0; i < words.length && out.length < 50; i += wordsPer) {
      final end = (i + wordsPer > words.length) ? words.length : i + wordsPer;
      final slice = words.sublist(i, end).join(' ');
      out.add(
        GutenbergChapter(
          chapterNumber: out.length + 1,
          chapterTitle: 'Part ${out.length + 1}',
          content: slice,
        ),
      );
    }
    return out;
  }

  /// Session [chaptersJson] written by the pipeline (`source: gutenberg`).
  static GutenbergStoredChaptersPayload? parseStoredChaptersPayload(
    String? chaptersJson,
  ) {
    if (chaptersJson == null || chaptersJson.trim().isEmpty) return null;
    try {
      final m = jsonDecode(chaptersJson) as Map<String, dynamic>;
      if (m['source'] != 'gutenberg') return null;
      final textUrl = (m['textUrl'] as String? ?? '').trim();
      final rawList = m['chapters'] as List<dynamic>? ?? [];
      final selRaw = m['selectedChapterIndex'];
      var selected = 0;
      if (selRaw is int) {
        selected = selRaw;
      } else if (selRaw is num) {
        selected = selRaw.toInt();
      }
      final rows = <GutenbergStoredChapterRow>[];
      for (final e in rawList) {
        if (e is! Map<String, dynamic>) continue;
        final n = e['chapterNumber'];
        final t = (e['chapterTitle'] as String? ?? '').trim();
        final chapterNum = n is int
            ? n
            : (n is num ? n.toInt() : rows.length + 1);
        rows.add(GutenbergStoredChapterRow(
          chapterNumber: chapterNum,
          chapterTitle: t,
        ));
      }
      if (rows.isEmpty) return null;
      return GutenbergStoredChaptersPayload(
        textUrl: textUrl,
        chapters: rows,
        selectedChapterIndex: selected.clamp(0, rows.length - 1),
      );
    } catch (_) {
      return null;
    }
  }
}

class GutenbergBookSearchHit {
  const GutenbergBookSearchHit({
    required this.id,
    required this.title,
    required this.author,
    required this.textUrl,
  });

  final int id;
  final String title;
  final String author;
  final String textUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'textUrl': textUrl,
      };
}

class GutenbergChapter {
  const GutenbergChapter({
    required this.chapterNumber,
    required this.chapterTitle,
    required this.content,
  });

  final int chapterNumber;
  final String chapterTitle;
  final String content;
}

class GutenbergBookException implements Exception {
  GutenbergBookException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Rows stored in [ListeningSession.chaptersJson] for `source: gutenberg`.
class GutenbergStoredChapterRow {
  const GutenbergStoredChapterRow({
    required this.chapterNumber,
    required this.chapterTitle,
  });

  final int chapterNumber;
  final String chapterTitle;
}

class GutenbergStoredChaptersPayload {
  const GutenbergStoredChaptersPayload({
    required this.textUrl,
    required this.chapters,
    required this.selectedChapterIndex,
  });

  final String textUrl;
  final List<GutenbergStoredChapterRow> chapters;
  final int selectedChapterIndex;
}
