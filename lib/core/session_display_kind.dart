import '../database/database.dart';
import '../services/audible_book_service.dart';
import '../services/gutenberg_book_service.dart';

/// UI treatment for sessions summarized by **catalog chapter** (audiobook / ebook)
/// instead of a wall-clock episode range.
class SessionDisplayKind {
  SessionDisplayKind._();

  static bool isChapterBased(ListeningSession s) {
    final ts = s.transcriptSource?.trim();
    if (ts == 'audible' ||
        ts == 'audible_pg' ||
        ts == 'audible_openlibrary' ||
        ts == 'gutenberg') {
      return true;
    }
    if (GutenbergBookService.parseStoredChaptersPayload(s.chaptersJson) !=
        null) {
      return true;
    }
    if (AudibleBookService.parseChaptersPayload(s.chaptersJson) != null) {
      return true;
    }
    final app = s.sourceApp?.toLowerCase().trim();
    if (app == 'audible' || app == 'gutenberg') return true;
    return false;
  }

  static String shortMetaLabel(ListeningSession s) {
    final ts = s.transcriptSource?.trim();
    if (ts == 'gutenberg' ||
        GutenbergBookService.parseStoredChaptersPayload(s.chaptersJson) !=
            null) {
      return 'E-book';
    }
    return 'Audiobook';
  }
}
