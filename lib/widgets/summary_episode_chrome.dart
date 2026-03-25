import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:palette_generator/palette_generator.dart';

import '../core/image_decode_cache.dart';

/// Default colors for the cinematic summary episode layout (before artwork is sampled).
abstract final class EpisodeChromeDefaults {
  static const Color pageBg = Color(0xFF1A1C14);
  static const Color fallbackAccent = Color(0xFFC4F230);
  static const Color meta = Color(0xFFA4A79A);
  static const Color insightHighlight = Color(0xFFE8C547);
  static const Color chipFill = Color(0xFF243018);
  static const Color cardRaised = Color(0xFF23261C);
  static const Color askBarBorder = Color(0xFF3D4234);
}

/// Summary page theme derived from episode artwork ([fromPalette] / [fromArtworkUrl]).
@immutable
class EpisodeArtworkTheme {
  const EpisodeArtworkTheme({
    required this.pageBg,
    required this.accent,
    required this.meta,
    required this.chipFill,
    required this.cardRaised,
    required this.askBarBorder,
    required this.insightAccent,
    required this.heroWash,
  });

  final Color pageBg;
  final Color accent;
  final Color meta;
  final Color chipFill;
  final Color cardRaised;
  final Color askBarBorder;

  /// INSIGHT label + card rail (warm blend of [accent]).
  final Color insightAccent;

  /// Hero color wash (same family as artwork; low-alpha overlay on summary hero).
  final Color heroWash;

  static final EpisodeArtworkTheme fallback = EpisodeArtworkTheme(
    pageBg: EpisodeChromeDefaults.pageBg,
    accent: EpisodeChromeDefaults.fallbackAccent,
    meta: EpisodeChromeDefaults.meta,
    chipFill: EpisodeChromeDefaults.chipFill,
    cardRaised: EpisodeChromeDefaults.cardRaised,
    askBarBorder: EpisodeChromeDefaults.askBarBorder,
    insightAccent: EpisodeChromeDefaults.insightHighlight,
    heroWash: EpisodeChromeDefaults.fallbackAccent,
  );

  /// Builds a readable dark theme from [PaletteGenerator] swatches.
  factory EpisodeArtworkTheme.fromPalette(PaletteGenerator gen) {
    final vibrant =
        gen.vibrantColor?.color ??
        gen.lightVibrantColor?.color ??
        gen.darkVibrantColor?.color;
    final dominant = gen.dominantColor?.color ?? vibrant;
    final seed = vibrant ?? dominant ?? EpisodeChromeDefaults.fallbackAccent;
    final accent = _boostAccentForDarkBackground(seed);
    final pageBg =
        Color.lerp(dominant, const Color(0xFF060606), 0.88) ??
        EpisodeChromeDefaults.pageBg;
    final meta =
        Color.lerp(const Color(0xFFADAAA3), dominant, 0.18) ??
        EpisodeChromeDefaults.meta;
    final chipFill =
        Color.lerp(pageBg, accent, 0.24) ?? EpisodeChromeDefaults.chipFill;
    final cardRaised =
        Color.lerp(pageBg, Colors.white, 0.05) ??
        EpisodeChromeDefaults.cardRaised;
    final askBarBorder =
        Color.lerp(pageBg, accent, 0.32) ?? EpisodeChromeDefaults.askBarBorder;
    final insightAccent =
        Color.lerp(accent, const Color(0xFFE8C547), 0.38) ??
        EpisodeChromeDefaults.insightHighlight;
    return EpisodeArtworkTheme(
      pageBg: pageBg,
      accent: accent,
      meta: meta,
      chipFill: chipFill,
      cardRaised: cardRaised,
      askBarBorder: askBarBorder,
      insightAccent: insightAccent,
      heroWash: seed,
    );
  }

  static Future<EpisodeArtworkTheme> fromArtworkUrl(String? imageUrl) async {
    final u = imageUrl?.trim() ?? '';
    if (u.isEmpty || (!u.startsWith('http://') && !u.startsWith('https://'))) {
      return fallback;
    }
    try {
      // perf: ResizeImage keeps decode small; PaletteGenerator still samples at [size].
      final gen = await PaletteGenerator.fromImageProvider(
        ResizeImage(NetworkImage(u), width: 88, height: 88),
        size: const Size(88, 88),
        maximumColorCount: 16,
      );
      return EpisodeArtworkTheme.fromPalette(gen);
    } catch (_) {
      return fallback;
    }
  }
}

Color _boostAccentForDarkBackground(Color raw) {
  final hsv = HSVColor.fromColor(raw);
  return HSVColor.fromAHSV(
    1,
    hsv.hue,
    (hsv.saturation * 1.06).clamp(0.42, 1.0),
    (hsv.value * 1.22).clamp(0.52, 0.96),
  ).toColor();
}

/// Supplies artwork-derived colors to summary subtrees (tabs, insight cards).
class EpisodeArtworkThemeScope extends InheritedWidget {
  const EpisodeArtworkThemeScope({
    super.key,
    required this.theme,
    required super.child,
  });

  final EpisodeArtworkTheme theme;

  static EpisodeArtworkTheme? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<EpisodeArtworkThemeScope>()
        ?.theme;
  }

  @override
  bool updateShouldNotify(EpisodeArtworkThemeScope oldWidget) =>
      oldWidget.theme != theme;
}

/// Circular icon on hero (white glyph on translucent dark).
class EpisodeHeroIconButton extends StatelessWidget {
  const EpisodeHeroIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.38),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 20,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
      ),
    );
  }
}

/// Top overlay: close, spacer, trailing actions (share / delete).
class EpisodeHeroActionBar extends StatelessWidget {
  const EpisodeHeroActionBar({
    super.key,
    required this.onClose,
    required this.trailing,
  });

  final VoidCallback onClose;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        child: Row(
          children: [
            EpisodeHeroIconButton(
              icon: Icons.close_rounded,
              onPressed: onClose,
            ),
            const Spacer(),
            ...trailing,
          ],
        ),
      ),
    );
  }
}

String _formatRelativeCreatedDate(int createdAtMs) {
  final date = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final created = DateTime(date.year, date.month, date.day);

  if (created == today) return 'Today';
  if (created == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return DateFormat('MMM d').format(date);
}

/// Show logo row, title, moments chip, date, duration, trust line (under hero).
class SummaryEpisodeInfoHeader extends StatelessWidget {
  const SummaryEpisodeInfoHeader({
    super.key,
    required this.theme,
    required this.title,
    required this.showName,
    this.artworkUrl,
    required this.createdAt,
    required this.momentCount,
    required this.durationLabel,
    required this.trustLine,
  });

  final EpisodeArtworkTheme theme;
  final String title;
  final String showName;
  final String? artworkUrl;
  final int createdAt;
  final int momentCount;
  final String durationLabel;
  final String trustLine;

  @override
  Widget build(BuildContext context) {
    final artist = showName;
    final url = artworkUrl?.trim() ?? '';
    final hasArt = url.startsWith('http://') || url.startsWith('https://');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: hasArt
                    ? CachedNetworkImage(
                        imageUrl: url,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        memCacheWidth: decodeCacheExtent(context, 40),
                        memCacheHeight: decodeCacheExtent(context, 40),
                        errorWidget: (_, _, _) => _fallbackArt(artist),
                      )
                    : _fallbackArt(artist),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.meta.withValues(alpha: 0.85),
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 24,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: theme.chipFill,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.accent.withValues(alpha: 0.38),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 17,
                      color: theme.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$momentCount moments',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.accent,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatRelativeCreatedDate(createdAt),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.meta,
                ),
              ),
              if (durationLabel.isNotEmpty) ...[
                Text(
                  '•',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.meta.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  durationLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.meta,
                  ),
                ),
              ],
            ],
          ),
          if (trustLine.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              trustLine,
              style: TextStyle(fontSize: 14, height: 1.45, color: theme.meta),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fallbackArt(String artist) {
    final letter = artist.trim().isNotEmpty
        ? artist.trim()[0].toUpperCase()
        : '?';
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      color: theme.cardRaised,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: theme.meta,
        ),
      ),
    );
  }
}

/// Pill bar that jumps to the chat tab. Default label: “Ask AI”.
class SummaryAskAiBar extends StatelessWidget {
  const SummaryAskAiBar({
    super.key,
    required this.theme,
    required this.onTap,
    this.label = 'Ask AI',
  });

  final EpisodeArtworkTheme theme;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Material(
        color: theme.cardRaised,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: theme.askBarBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 22, color: theme.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
