import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// Extracts a background-friendly accent from podcast artwork (cached per URL).
class ArtworkColorService {
  ArtworkColorService._();

  static final Map<String, Color> _cache = {};

  static Future<Color> getDominantColor(
    String? imageUrl, {
    Color fallback = const Color(0xFF6366F1),
  }) async {
    final url = imageUrl?.trim();
    if (url == null ||
        url.isEmpty ||
        (!url.startsWith('http://') && !url.startsWith('https://'))) {
      return fallback;
    }

    if (_cache.containsKey(url)) {
      return _cache[url]!;
    }

    try {
      final provider = NetworkImage(url);
      final generator = await PaletteGenerator.fromImageProvider(
        provider,
        size: const Size(64, 64),
        maximumColorCount: 12,
      );

      final color = generator.darkVibrantColor?.color ??
          generator.vibrantColor?.color ??
          generator.dominantColor?.color ??
          fallback;

      final darkened = Color.lerp(color, Colors.black, 0.7)!;
      _cache[url] = darkened;
      return darkened;
    } catch (_) {
      return fallback;
    }
  }

  static void clearCacheForUrl(String url) => _cache.remove(url);
}
