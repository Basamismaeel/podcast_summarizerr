import 'dart:convert';

import 'package:http/http.dart' as http;

/// Open Library + Internet Archive plain text for public `ebook_access` editions.
///
/// Used as an Audible pipeline fallback when Project Gutenberg match fails.
class OpenLibraryService {
  OpenLibraryService();

  static const _userAgent =
      'PodcastSafetyNet/1.0 (Open Library reader; +https://openlibrary.org)';

  /// Calls Open Library search and returns every edition with
  /// `ebook_access == 'public'` and a non-empty `ia` list (Internet Archive id).
  ///
  /// Order follows search hits, then edition docs. Empty list if none.
  Future<List<OpenLibraryResult>> findReadableEdition(String title, String author) async {
    final q = '${title.trim()} ${author.trim()}'.trim();
    if (q.length < 2) return [];

    final uri = Uri.https(
      'openlibrary.org',
      '/search.json',
      <String, String>{
        'q': q,
        'limit': '5',
        'fields':
            'key,title,author_name,editions,editions.key,editions.ebook_access,editions.ia,editions.isbn',
      },
    );

    final res = await http
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 25));

    if (res.statusCode != 200) return [];

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final docs = body['docs'] as List<dynamic>? ?? [];

    final out = <OpenLibraryResult>[];
    for (final raw in docs) {
      if (raw is! Map<String, dynamic>) continue;
      final workTitle = (raw['title'] as String? ?? '').trim();
      final editionsRaw = raw['editions'];
      if (editionsRaw is! Map<String, dynamic>) continue;
      final edDocs = editionsRaw['docs'] as List<dynamic>? ?? [];
      for (final ed in edDocs) {
        if (ed is! Map<String, dynamic>) continue;
        final access = (ed['ebook_access'] as String? ?? '').trim().toLowerCase();
        if (access != 'public') continue;

        final iaList = _iaListFromEdition(ed);
        if (iaList.isEmpty) continue;

        final isbn = _firstIsbn(ed);
        for (final iaId in iaList) {
          if (iaId.isEmpty) continue;
          out.add(
            OpenLibraryResult(
              iaId: iaId,
              title: workTitle.isNotEmpty ? workTitle : title.trim(),
              isbn: isbn,
              isFree: true,
            ),
          );
        }
      }
    }
    return out;
  }

  static List<String> _iaListFromEdition(Map<String, dynamic> ed) {
    final ia = ed['ia'];
    if (ia is String && ia.trim().isNotEmpty) return [ia.trim()];
    if (ia is List) {
      return ia
          .map((e) => e is String ? e.trim() : '$e'.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static String? _firstIsbn(Map<String, dynamic> ed) {
    final isbnField = ed['isbn'];
    if (isbnField is String && isbnField.trim().isNotEmpty) {
      return isbnField.trim();
    }
    if (isbnField is List) {
      for (final x in isbnField) {
        if (x is String && x.trim().isNotEmpty) return x.trim();
      }
    }
    return null;
  }

  /// Tries `…/${iaId}_djvu.txt` then `…/${iaId}_text.txt` on Archive.org.
  Future<String?> fetchPlainText(String iaId) async {
    final id = iaId.trim();
    if (id.isEmpty) return null;

    final urls = <Uri>[
      Uri.parse('https://archive.org/download/$id/${id}_djvu.txt'),
      Uri.parse('https://archive.org/download/$id/${id}_text.txt'),
    ];

    for (final u in urls) {
      try {
        final res = await http
            .get(u, headers: {'User-Agent': _userAgent})
            .timeout(const Duration(seconds: 120));
        if (res.statusCode != 200) continue;
        final text = utf8.decode(res.bodyBytes, allowMalformed: true).trim();
        if (text.length >= 200 && !_looksLikeHtml404(text)) {
          return text;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static bool _looksLikeHtml404(String s) {
    final t = s.toLowerCase();
    return t.contains('<html') && t.contains('not found');
  }
}

class OpenLibraryResult {
  const OpenLibraryResult({
    required this.iaId,
    required this.title,
    this.isbn,
    required this.isFree,
  });

  final String iaId;
  final String title;
  final String? isbn;
  final bool isFree;
}
