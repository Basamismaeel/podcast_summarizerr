import '../database/database.dart';

/// Markdown suitable for Notion / Obsidian / notes apps.
String buildSummaryMarkdown(
  ListeningSession session, {
  required List<String> bullets,
  List<String> quotes = const [],
}) {
  final buf = StringBuffer();
  buf.writeln('# ${session.title}');
  buf.writeln();
  buf.writeln('**Show:** ${session.artist}  ');
  buf.writeln(
      '**Segment:** ${_segmentLine(session)}  ');
  final listen = session.sourceShareUrl?.trim();
  final link = (listen != null && listen.isNotEmpty)
      ? listen
      : session.episodeUrl?.trim();
  if (link != null && link.isNotEmpty) {
    buf.writeln('**Link:** $link  ');
  }
  buf.writeln();
  buf.writeln('## Summary');
  buf.writeln();
  for (var i = 0; i < bullets.length; i++) {
    buf.writeln('- ${bullets[i]}');
  }
  if (quotes.isNotEmpty) {
    buf.writeln();
    buf.writeln('## Quotes');
    buf.writeln();
    for (final q in quotes) {
      buf.writeln('> $q');
      buf.writeln();
    }
  }
  buf.writeln();
  buf.writeln('---');
  buf.writeln('*Exported from Podcast Safety Net*');
  return buf.toString();
}

String _segmentLine(ListeningSession session) {
  final end = session.endTimeSec;
  if (end != null) {
    return '${_fmt(session.startTimeSec)} – ${_fmt(end)} (episode clock)';
  }
  if (session.rangeLabel != null && session.rangeLabel!.isNotEmpty) {
    return '${_fmt(session.startTimeSec)} → end · ${session.rangeLabel}';
  }
  return '${_fmt(session.startTimeSec)} → end of episode';
}

String _fmt(int sec) {
  final m = sec ~/ 60;
  final s = sec % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
