// In-app summary display helpers (no Markdown rendering).

/// Removes common Markdown markers so text reads cleanly in plain [Text] widgets.
String stripMarkdownForDisplay(String input) {
  var s = input;
  while (true) {
    final next = s.replaceFirstMapped(
      RegExp(r'\*\*([^*]+)\*\*'),
      (m) => m.group(1)!,
    );
    if (identical(next, s)) break;
    s = next;
  }
  s = s.replaceAllMapped(
    RegExp(r'__(.+?)__'),
    (m) => m.group(1)!.trim(),
  );
  s = s.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
  s = s.replaceAll('`', '');
  return s.trim();
}

/// Splits a stored bullet like `**The Core Idea**\nSentence…` into title + body.
({String? title, String body}) parseSummaryBulletSections(String raw) {
  final t = raw.trim();
  final m = RegExp(
    r'^\*\*(.+?)\*\*\s*\n+',
    dotAll: true,
  ).firstMatch(t);
  if (m != null) {
    final title = stripMarkdownForDisplay(m.group(1)!);
    final body = stripMarkdownForDisplay(t.substring(m.end));
    return (title: title.isEmpty ? null : title, body: body);
  }
  return (title: null, body: stripMarkdownForDisplay(t));
}
