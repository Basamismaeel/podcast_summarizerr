import '../database/database.dart';

import 'session_display_kind.dart';

/// Starter chips for [ContentChat] on book summaries.
const kBookContentChatStarterChips = <String>[
  'What is the main theme?',
  'Who is the most important character?',
  "What's the key takeaway?",
];

/// Starter chips for [ContentChat] on podcast summaries.
const kPodcastContentChatStarterChips = <String>[
  'What was the main point?',
  'What were the most interesting moments?',
  'Summarize this in one sentence',
];

/// Plain-text block from on-screen summary bullets + quotes (no extra API).
String contentChatContextBlock(List<String> bullets, List<String> quotes) {
  final parts = <String>[];
  if (bullets.isNotEmpty) {
    final lines = bullets.map((b) => '• ${b.trim()}').join('\n');
    parts.add('Summary points:\n$lines');
  }
  if (quotes.isNotEmpty) {
    final lines = quotes.map((q) => '“${q.trim()}”').join('\n');
    parts.add('Key quotes:\n$lines');
  }
  if (parts.isEmpty) return '(No summary text available.)';
  return parts.join('\n\n');
}

/// System prompt for book / chapter-based sessions.
String buildBookContentChatSystemPrompt({
  required String bookTitle,
  required String authorName,
  required String allChapterSummaries,
}) {
  return "You are an expert on the book '$bookTitle' "
      "by '$authorName'.\n\n"
      'Here are the chapter summaries:\n'
      '$allChapterSummaries\n\n'
      "Answer the user's questions about this book.\n"
      'Be insightful, conversational, and concise.\n'
      "If something isn't covered in the summaries,\n"
      'say so honestly. Never make things up.';
}

/// System prompt for podcast (episode) sessions.
String buildPodcastContentChatSystemPrompt({
  required String podcastTitle,
  required String podcastTranscriptOrSummary,
}) {
  return 'You are an expert on this podcast episode:\n'
      "'$podcastTitle'\n\n"
      'Here is the transcript/summary of the episode:\n'
      '$podcastTranscriptOrSummary\n\n'
      "Answer the user's questions about this episode.\n"
      'Be conversational and concise. If something '
      "isn't covered in the transcript, say so honestly.\n"
      'Never make things up.';
}

/// Whether to use the book-style prompt (else podcast-style).
bool useBookContentChatPrompt(ListeningSession session) =>
    SessionDisplayKind.isChapterBased(session);
