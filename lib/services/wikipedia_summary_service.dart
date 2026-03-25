import 'dart:convert';

import 'package:http/http.dart' as http;

/// Best-effort Wikipedia extract for book title + author (English).
class WikipediaSummaryService {
  WikipediaSummaryService._();

  static const _userAgent =
      'PodcastSafetyNet/1.0 (audiobook context; +https://openlibrary.org)';

  /// Returns plain-text extract or empty string on failure.
  static Future<String> fetchBookSummary(String title, String author) async {
    final search = '${title.trim()} ${author.trim()}'.trim();
    if (search.length < 2) return '';

    try {
      final osUri = Uri.https(
        'en.wikipedia.org',
        '/w/api.php',
        <String, String>{
          'action': 'opensearch',
          'search': search,
          'limit': '2',
          'namespace': '0',
          'format': 'json',
        },
      );

      final osRes = await http
          .get(osUri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 14));
      if (osRes.statusCode != 200) return '';

      final osJson = jsonDecode(osRes.body);
      if (osJson is! List || osJson.length < 2) return '';
      final titles = osJson[1];
      if (titles is! List || titles.isEmpty) return '';

      final pageTitle = (titles.first as String).trim();
      if (pageTitle.isEmpty) return '';

      final pathTitle = pageTitle.replaceAll(' ', '_');
      final sumUri = Uri.parse(
        'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(pathTitle)}',
      );

      final sumRes = await http
          .get(sumUri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 14));
      if (sumRes.statusCode != 200) return '';

      final map = jsonDecode(sumRes.body) as Map<String, dynamic>;
      final extract = (map['extract'] as String? ?? '').trim();
      if (extract.length > 8000) {
        return '${extract.substring(0, 8000)}…';
      }
      return extract;
    } catch (_) {
      return '';
    }
  }
}
