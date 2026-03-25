import 'dart:convert';

import 'package:http/http.dart' as http;

/// Free [Open Library](https://openlibrary.org) search — titles, authors, ISBNs.
/// Does **not** replace Audnexus: timed audiobook chapters still need an
/// Audible **ASIN** (from a product/share URL).
class OpenLibraryBookService {
  OpenLibraryBookService._();

  static const _searchPath = '/search.json';

  static Future<List<OpenLibraryBookHit>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];

    final uri = Uri.https(
      'openlibrary.org',
      _searchPath,
      <String, String>{
        'q': q,
        'limit': '20',
        'fields': 'title,author_name,key,first_publish_year,isbn',
      },
    );

    final res = await http
        .get(
          uri,
          headers: {
            'User-Agent': 'PodcastSafetyNet/1.0 (book lookup; +https://github.com)',
          },
        )
        .timeout(const Duration(seconds: 22));

    if (res.statusCode != 200) return [];

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final docs = body['docs'] as List<dynamic>? ?? [];
    final out = <OpenLibraryBookHit>[];

    for (final raw in docs) {
      if (raw is! Map<String, dynamic>) continue;
      final title = (raw['title'] as String? ?? '').trim();
      if (title.isEmpty) continue;

      final key = raw['key'] as String? ?? '';
      if (key.isEmpty) continue;

      final authors = <String>[];
      final an = raw['author_name'];
      if (an is List) {
        for (final a in an) {
          if (a is String && a.trim().isNotEmpty) authors.add(a.trim());
        }
      }

      final year = raw['first_publish_year'];
      final firstYear = year is int ? year : (year is num ? year.toInt() : null);

      final isbns = <String>[];
      final isbnField = raw['isbn'];
      if (isbnField is List) {
        for (final x in isbnField) {
          if (x is String && x.trim().isNotEmpty) {
            isbns.add(x.trim());
          }
        }
      }

      out.add(
        OpenLibraryBookHit(
          title: title,
          authorNames: authors,
          workKey: key,
          firstPublishYear: firstYear,
          isbns: isbns,
        ),
      );
    }

    return out;
  }
}

class OpenLibraryBookHit {
  const OpenLibraryBookHit({
    required this.title,
    required this.authorNames,
    required this.workKey,
    this.firstPublishYear,
    required this.isbns,
  });

  final String title;
  final List<String> authorNames;
  final String workKey;
  final int? firstPublishYear;
  final List<String> isbns;

  String get authorsLabel =>
      authorNames.isEmpty ? 'Unknown author' : authorNames.join(', ');

  String get openLibraryUrl => 'https://openlibrary.org$workKey';
}
