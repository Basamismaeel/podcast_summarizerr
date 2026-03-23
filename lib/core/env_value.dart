/// Normalizes values from `.env` / dotenv (quotes, BOM leftovers, whitespace).
/// Strips leading invisible chars so e.g. `startsWith('AIza')` matches real Gemini keys.
String normalizeDotenvValue(String? raw) {
  if (raw == null) return '';
  var v = raw.trim().replaceFirst(RegExp(r'^\uFEFF'), '').trim();
  v = v.replaceFirst(RegExp(r'^[\u200B-\u200D\uFEFF]+'), '');
  if (v.length >= 2) {
    final q = v[0];
    if ((q == '"' || q == "'") && v.endsWith(q)) {
      v = v.substring(1, v.length - 1).trim();
    }
  }
  return v;
}

/// Google AI Studio keys start with `AIza`. A frequent typo is an extra `A`: `AAIza…`,
/// which makes the key invalid and breaks `startsWith('AIza')` checks.
String normalizeGeminiApiKey(String normalizedDotenvValue) {
  final k = normalizedDotenvValue;
  if (k.startsWith('AAIza') && k.length > 7) return k.substring(1);
  return k;
}
