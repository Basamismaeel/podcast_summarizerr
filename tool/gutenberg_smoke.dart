// Quick check: Gutendex + download + strip + split (same as the app).
// From repo root:  dart run tool/gutenberg_smoke.dart
// (Use `flutter pub get` first if needed.)

import 'package:podcast_safety_net/services/gutenberg_book_service.dart';

Future<void> main() async {
  print('--- Gutenberg smoke test ---\n');

  print('1) searchBooks("pride and prejudice")');
  final hits = await GutenbergBookService.searchBooks('pride and prejudice');
  if (hits.isEmpty) {
    print('   FAIL: no results (network or API?)');
    return;
  }
  final first = hits.first;
  print(
    '   OK: ${hits.length} hit(s), first id=${first.id} title="${first.title}"',
  );
  print('   textUrl: ${first.textUrl}\n');

  print('2) fetchBookText (first ~200 chars after strip)');
  try {
    final text = await GutenbergBookService.fetchBookText(first.textUrl);
    final preview = text.length > 200 ? '${text.substring(0, 200)}…' : text;
    print('   OK: ${text.length} chars');
    print('   preview: $preview\n');
  } catch (e, st) {
    print('   FAIL: $e\n$st');
    return;
  }

  print('3) splitIntoChapters');
  final full = await GutenbergBookService.fetchBookText(first.textUrl);
  final chapters = GutenbergBookService.splitIntoChapters(full);
  print('   OK: ${chapters.length} chapter(s) (cap 50)');
  for (var i = 0; i < chapters.length && i < 3; i++) {
    final c = chapters[i];
    print(
      '   [$i] #${c.chapterNumber} "${c.chapterTitle}" '
      '(${c.content.length} chars)',
    );
  }
  if (chapters.length > 3) print('   …');
  print('\n--- done ---');
}
