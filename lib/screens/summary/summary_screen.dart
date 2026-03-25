import 'dart:async' show Future, Timer, unawaited;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/content_chat_prompts.dart';
import '../../core/image_decode_cache.dart';
import '../../core/haptics.dart';
import '../../core/moments_stats_service.dart';
import '../../core/session_display_kind.dart';
import '../../core/summary_export.dart';
import '../../core/summary_theme_colors.dart';
import '../../core/summary_text_display.dart';
import '../../core/tokens.dart';
import '../../database/database.dart';
import '../../models/summary_style.dart';
import '../../providers/session_provider.dart';
import '../../services/audible_book_service.dart';
import '../../services/gutenberg_book_service.dart';
import '../../services/podcast_player_links.dart';
import '../../widgets/confirm_delete_session_sheet.dart';
import '../../widgets/content_chat.dart';
import '../../widgets/liquid_loader.dart';
import '../../widgets/summary_listen_row.dart';
import '../../widgets/summary_episode_chrome.dart';
import '../../widgets/typewrite_text.dart';
import 'widgets/share_card_generator.dart';

final _kBulletTsRe = RegExp(r'^\[(\d{1,4}:\d{2}(?::\d{2})?)\]\s*');

/// Comfortable reading measure for summary body (phones fill width; tablets cap).
const double _kSummaryContentMaxWidth = 560;

const Color _kSummaryCyan = Color(0xFF00D4FF);
const Color _kSummaryOnWhiteFg = Color(0xFF0D0F0A);

/// Compact white / near-black control (Listen row, Open in Spotify/Apple, chips).
ButtonStyle _summaryWhitePrimaryButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: _kSummaryOnWhiteFg,
    disabledBackgroundColor: Colors.white.withValues(alpha: 0.35),
    disabledForegroundColor: _kSummaryOnWhiteFg.withValues(alpha: 0.45),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    minimumSize: const Size(0, 40),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}

/// `[MM:SS]` / `[H:MM:SS]` label → seconds (for player deep links).
int? _parseTimestampLabelToSec(String at) {
  final p = at.split(':');
  if (p.length == 2) {
    final m = int.tryParse(p[0].trim());
    final s = int.tryParse(p[1].trim());
    if (m != null && s != null) return m * 60 + s;
  } else if (p.length == 3) {
    final h = int.tryParse(p[0].trim());
    final m = int.tryParse(p[1].trim());
    final s = int.tryParse(p[2].trim());
    if (h != null && m != null && s != null) return h * 3600 + m * 60 + s;
  }
  return null;
}

Future<void> _shareInsightCard(BuildContext context, String text) async {
  final t = text.trim();
  if (t.isEmpty) return;
  try {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final res = await Share.share(t, sharePositionOrigin: origin);
    if (res.status == ShareResultStatus.unavailable) {
      await Clipboard.setData(ClipboardData(text: t));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copied!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: t));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

Future<void> _openListenUrlAtTimestamp(
  BuildContext context,
  ListeningSession session,
  String? at,
) async {
  final sec = at != null ? _parseTimestampLabelToSec(at) : null;
  if (sec == null) return;
  final url = _listenUrlForPlayer(session);
  if (url == null || url.trim().isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No podcast link is saved for this moment — add a Spotify or Apple Podcasts URL when saving.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }
  var ok = false;
  if (PodcastPlayerLinks.looksLikeApplePodcasts(url)) {
    ok = await PodcastPlayerLinks.openApplePodcastsAt(url, sec);
  } else if (PodcastPlayerLinks.looksLikeSpotify(url)) {
    ok = await PodcastPlayerLinks.openSpotifyAt(url, sec);
  } else {
    final uri = Uri.tryParse(url.trim());
    if (uri != null) {
      final q = Map<String, String>.from(uri.queryParameters);
      q['t'] = '$sec';
      try {
        ok = await launchUrl(
          uri.replace(queryParameters: q),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        ok = false;
      }
    }
  }
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open the player at this time.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

String _summaryPlainTextForListen(List<String> bullets, List<String> quotes) {
  final b = bullets.map((x) => _splitEpisodeTimestamp(x).body).join(' ');
  final q = quotes.join(' ');
  return [b, q].where((s) => s.trim().isNotEmpty).join(' ');
}

String _bookSectionSharePlain(String? title, int sectionIndex, String body) {
  final head = (title != null && title.trim().isNotEmpty)
      ? title.trim()
      : 'Section $sectionIndex';
  return '$head\n\n$body';
}

TextStyle _summarySectionLabelStyle(BuildContext context) => TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.4,
  color:
      EpisodeArtworkThemeScope.maybeOf(context)?.meta ??
      SummaryThemeColors.textMuted(context),
);

/// Leading `[MM:SS]` / `[H:MM:SS]` from pipeline (episode position).
({String? at, String body}) _splitEpisodeTimestamp(String raw) {
  final t = raw.trimLeft();
  final m = _kBulletTsRe.firstMatch(t);
  if (m == null) return (at: null, body: t);
  return (at: m.group(1), body: t.substring(m.end).trimLeft());
}

String _summaryBulletRailLabel(String bullet, int index, bool structured) {
  final parts = _splitEpisodeTimestamp(bullet);
  if (structured) {
    final p = parseSummaryBulletSections(parts.body);
    final t = p.title?.trim();
    if (t != null && t.isNotEmpty) {
      if (t.length > 28) return '${t.substring(0, 26)}…';
      return t;
    }
    final line = parts.body.split(RegExp(r'\n')).first.trim();
    final plain = stripMarkdownForDisplay(line);
    if (plain.length > 22) return '${plain.substring(0, 20)}…';
    return plain.isEmpty ? '${index + 1}' : plain;
  }
  // Podcast episodes: keep tabs tiny — full text stays in the panel below.
  return '${index + 1}';
}

/// Small pill: “seek to this moment” cue next to summary text.
class _EpisodeTimestampPill extends StatelessWidget {
  const _EpisodeTimestampPill({required this.at});

  /// Display form (same as transcript markers).
  final String at;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final fg = isDark ? _kSummaryOnWhiteFg : cs.onSurface;
    final bg = isDark
        ? Colors.white
        : cs.surfaceContainerHighest.withValues(alpha: 0.9);
    final border = isDark ? null : Border.all(color: cs.outlineVariant);
    return Semantics(
      label: 'Episode timestamp $at',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: border,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 13, color: fg),
            const SizedBox(width: 5),
            Text(
              at,
              style: GoogleFonts.dmMono(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: fg,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Timestamp pill that jumps to this position in Apple Podcasts / Spotify when possible.
class _TappableEpisodeTimestampPill extends StatefulWidget {
  const _TappableEpisodeTimestampPill({
    required this.at,
    required this.session,
  });

  final String at;
  final ListeningSession session;

  @override
  State<_TappableEpisodeTimestampPill> createState() =>
      _TappableEpisodeTimestampPillState();
}

class _TappableEpisodeTimestampPillState
    extends State<_TappableEpisodeTimestampPill> {
  Future<void> _onTap() async {
    higLightTap();
    await _openListenUrlAtTimestamp(context, widget.session, widget.at);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: _kSummaryOnWhiteFg.withValues(alpha: 0.08),
        highlightColor: _kSummaryOnWhiteFg.withValues(alpha: 0.04),
        child: _EpisodeTimestampPill(at: widget.at),
      ),
    );
  }
}

String _summaryDurationLabel(ListeningSession session) {
  final end = session.endTimeSec;
  if (end != null) {
    return '${_summaryFmtTimestamp(session.startTimeSec)} – ${_summaryFmtTimestamp(end)}';
  }
  return session.rangeLabel ?? 'Full Episode';
}

String _summaryFmtTimestamp(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String _chapterHeroSubtitle(ListeningSession session) {
  final ap = AudibleBookService.parseChaptersPayload(session.chaptersJson);
  if (ap != null && ap.chapters.isNotEmpty) {
    final ch = AudibleBookService.chapterForTimestamp(
      ap.chapters,
      session.startTimeSec,
    );
    final t = ch['title'] as String?;
    if (t != null && t.trim().isNotEmpty) return t.trim();
  }
  final gp = GutenbergBookService.parseStoredChaptersPayload(
    session.chaptersJson,
  );
  if (gp != null && gp.chapters.isNotEmpty) {
    final i = gp.selectedChapterIndex.clamp(0, gp.chapters.length - 1);
    final t = gp.chapters[i].chapterTitle.trim();
    if (t.isNotEmpty) return t;
  }
  return 'Chapter summary';
}

/// User-facing explanation of which audio window the summary reflects.
String _summaryTrustLine(ListeningSession s) {
  final gutenbergPayload = GutenbergBookService.parseStoredChaptersPayload(
    s.chaptersJson,
  );
  final isGutenberg =
      s.transcriptSource == 'gutenberg' || gutenbergPayload != null;
  if (isGutenberg) {
    var chapterName = 'the selected chapter';
    if (gutenbergPayload != null && gutenbergPayload.chapters.isNotEmpty) {
      final i = gutenbergPayload.selectedChapterIndex.clamp(
        0,
        gutenbergPayload.chapters.length - 1,
      );
      final t = gutenbergPayload.chapters[i].chapterTitle.trim();
      if (t.isNotEmpty) chapterName = t;
    }
    return 'This summary follows “$chapterName” from your Project Gutenberg '
        'chapter list. Gemini summarizes the full text of that chapter only.';
  }

  final audiblePayload = AudibleBookService.parseChaptersPayload(
    s.chaptersJson,
  );
  if (s.transcriptSource == 'audible_pg') {
    var chapterName = 'the selected catalog chapter';
    if (audiblePayload != null && audiblePayload.chapters.isNotEmpty) {
      final ch = AudibleBookService.chapterForTimestamp(
        audiblePayload.chapters,
        s.startTimeSec,
      );
      final t = ch['title'] as String?;
      if (t != null && t.trim().isNotEmpty) chapterName = t.trim();
    }
    return 'This summary uses full chapter text from Project Gutenberg '
        '(auto-matched to this audiobook). Your chapter is “$chapterName” from '
        'the Audible catalog; the written text may differ slightly from what you hear.';
  }

  if (s.transcriptSource == 'audible_openlibrary') {
    return "Summary based on full chapter text from Open Library's free "
        'edition. Text may differ slightly from your audiobook\'s narration.';
  }

  final isAudible =
      s.transcriptSource == 'audible' ||
      audiblePayload != null ||
      (s.sourceApp?.toLowerCase() == 'audible');
  if (isAudible) {
    var chapterName = 'the selected catalog chapter';
    if (audiblePayload != null && audiblePayload.chapters.isNotEmpty) {
      final ch = AudibleBookService.chapterForTimestamp(
        audiblePayload.chapters,
        s.startTimeSec,
      );
      final t = ch['title'] as String?;
      if (t != null && t.trim().isNotEmpty) chapterName = t.trim();
    }
    return 'This summary follows “$chapterName” (retailer chapter list). '
        'It uses store text and metadata — not a transcript of the audiobook.';
  }

  final end = s.endTimeSec;
  if (end != null && end > s.startTimeSec) {
    return 'This summary is based on ${_summaryFmtTimestamp(s.startTimeSec)}–${_summaryFmtTimestamp(end)} in “${s.title}” (${s.artist}).';
  }
  if (s.rangeLabel != null && s.rangeLabel!.trim().isNotEmpty) {
    return 'This summary is based on your saved range (${s.rangeLabel}) starting at ${_summaryFmtTimestamp(s.startTimeSec)}.';
  }
  return 'This summary is based on audio from ${_summaryFmtTimestamp(s.startTimeSec)} through the end of the episode.';
}

List<String> _bulletsPlainForShare(List<String> bullets) =>
    bullets.map((b) => _splitEpisodeTimestamp(b).body).toList();

/// Spotify / Apple **page** link for opening the player app (not the RSS MP3 URL).
String _summaryShortDuration(ListeningSession s) {
  final end = s.endTimeSec;
  if (end == null || end <= s.startTimeSec) return '';
  final m = ((end - s.startTimeSec) / 60).round();
  if (m <= 0) return '';
  final h = m ~/ 60;
  final r = m % 60;
  if (h > 0) return '${h}h ${r}min';
  return '${m}min';
}

String? _listenUrlForPlayer(ListeningSession s) {
  final a = s.sourceShareUrl?.trim();
  if (a != null && a.isNotEmpty) return a;
  final b = s.episodeUrl?.trim();
  if (b != null && b.isNotEmpty) return b;
  return null;
}

TextStyle _summaryBulletStyle(BuildContext context, int index) {
  final lead = index <= 1;
  final art = EpisodeArtworkThemeScope.maybeOf(context);
  if (art != null) {
    return TextStyle(
      fontSize: lead ? 18 : 17,
      fontWeight: lead ? FontWeight.w500 : FontWeight.w400,
      color: lead ? Colors.white.withValues(alpha: 0.96) : art.meta,
      height: 1.7,
    );
  }
  final c = SummaryThemeColors.onBody(context);
  return TextStyle(
    fontSize: lead ? 18 : 17,
    fontWeight: lead ? FontWeight.w500 : FontWeight.w400,
    color: c.withValues(alpha: lead ? 1 : 0.96),
    height: 1.7,
  );
}

/// Podcast: Points · Quotes · Chat · Tags · More. Audiobook: Points · Chat · Tags.
class _AdaptiveSummaryTabs extends StatelessWidget {
  const _AdaptiveSummaryTabs({
    required this.selectedIndex,
    required this.accent,
    required this.onSelect,
    required this.audiobookMode,
    this.episodeChromeTabStyle = false,
  });

  final int selectedIndex;
  final Color accent;
  final ValueChanged<int> onSelect;

  /// Chapter-based session (Audible / Gutenberg): hide Quotes & More.
  final bool audiobookMode;

  /// Icon row + underline (cinematic dark summary layout).
  final bool episodeChromeTabStyle;

  static const _podcastLabels = ['Points', 'Quotes', 'Chat', 'Tags', 'More'];
  static const _bookLabels = ['Points', 'Chat', 'Tags'];
  static const _podcastIcons = [
    Icons.auto_stories_outlined,
    Icons.format_quote_rounded,
    Icons.chat_bubble_outline_rounded,
    Icons.label_outline_rounded,
    Icons.more_horiz_rounded,
  ];
  static const _bookIcons = [
    Icons.auto_stories_outlined,
    Icons.chat_bubble_outline_rounded,
    Icons.label_outline_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final labels = audiobookMode ? _bookLabels : _podcastLabels;
    final icons = audiobookMode ? _bookIcons : _podcastIcons;
    final n = labels.length;
    final artworkThemeScope = EpisodeArtworkThemeScope.maybeOf(context);
    final tabAccentColor = episodeChromeTabStyle
        ? (artworkThemeScope?.accent ?? EpisodeChromeDefaults.fallbackAccent)
        : accent;
    final inactive = episodeChromeTabStyle
        ? (artworkThemeScope?.meta ?? EpisodeChromeDefaults.meta)
        : SummaryThemeColors.textMuted(context);
    final activeFg = episodeChromeTabStyle ? Colors.white : accent;
    return Container(
      decoration: episodeChromeTabStyle
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            )
          : null,
      padding: episodeChromeTabStyle
          ? const EdgeInsets.symmetric(horizontal: 12)
          : EdgeInsets.zero,
      child: Row(
        children: List.generate(n, (i) {
          final on = selectedIndex == i;
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  higLightTap();
                  onSelect(i);
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 2,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (episodeChromeTabStyle) ...[
                        Icon(
                          icons[i],
                          size: 22,
                          color: on ? activeFg : inactive,
                        ),
                        const SizedBox(height: 4),
                      ] else ...[
                        Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: on
                                ? accent
                                : SummaryThemeColors.onBodySoft(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: episodeChromeTabStyle ? 11 : 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.15,
                          color: on
                              ? (episodeChromeTabStyle
                                    ? activeFg
                                    : accent.withValues(alpha: 0.95))
                              : inactive,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 2,
                        decoration: BoxDecoration(
                          color: on ? tabAccentColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _QuotesTabPanel extends StatelessWidget {
  const _QuotesTabPanel({
    required this.quotes,
    required this.unlocked,
    required this.session,
    required this.accent,
  });

  final List<String> quotes;
  final bool unlocked;
  final ListeningSession session;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final art = EpisodeArtworkThemeScope.maybeOf(context);
    final soft = art?.meta ?? SummaryThemeColors.onBodySoft(context);
    if (!unlocked) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(
          'Key quotes appear when the summary finishes.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.45, color: soft),
        ),
      );
    }
    if (quotes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(
          'No key quotes for this summary.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.45, color: soft),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Key quotes', style: _summarySectionLabelStyle(context)),
        const SizedBox(height: 14),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: false,
          cacheExtent: 500,
          itemCount: quotes.length,
          itemBuilder: (context, i) {
            final q = quotes[i];
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - t)),
                  child: child,
                ),
              ),
              child: _MagazineQuoteCard(
                text: q,
                accent: accent,
                session: session,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Chapters + transcript hints + Open in Spotify / Apple Podcasts (always above tabs).
class _SummaryChaptersAndPlayerLinks extends ConsumerWidget {
  const _SummaryChaptersAndPlayerLinks({
    required this.session,
    required this.status,
    required this.style,
    required this.sessionId,
  });

  final ListeningSession session;
  final SessionStatus status;
  final SummaryStyle? style;
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent =
        EpisodeArtworkThemeScope.maybeOf(context)?.accent ??
        Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (AudibleBookService.parseChaptersPayload(session.chaptersJson) !=
            null) ...[
          Builder(
            builder: (context) {
              final payload = AudibleBookService.parseChaptersPayload(
                session.chaptersJson,
              )!;
              if (payload.chapters.isEmpty) {
                return const SizedBox.shrink();
              }
              final current = AudibleBookService.chapterForTimestamp(
                payload.chapters,
                session.startTimeSec,
              );
              final currentStart = AudibleBookService.chapterStartSec(current);
              return _CollapsibleChapterTray(
                leadingIcon: Icons.headphones_rounded,
                accent: accent,
                title: 'Chapters',
                subtitle:
                    '${payload.chapters.length} in this title · expand to pick another',
                expandedBody: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: payload.chapters.map((c) {
                    final start = AudibleBookService.chapterStartSec(c);
                    final title = c['title'] as String? ?? 'Chapter';
                    final isHere = start == currentStart;
                    final busy =
                        status == SessionStatus.summarizing ||
                        status == SessionStatus.queued;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        color: isHere
                            ? accent.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: busy
                              ? null
                              : () async {
                                  if (start == session.startTimeSec) return;
                                  higLightTap();
                                  await ref
                                      .read(sessionActionsProvider)
                                      .requeueAudibleChapterAndSummarize(
                                        sessionId,
                                        start,
                                        style: style,
                                      );
                                  ref.invalidate(
                                    sessionByIdProvider(sessionId),
                                  );
                                },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    color: isHere
                                        ? accent
                                        : Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.25,
                                      fontWeight: isHere
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: Colors.white.withValues(
                                        alpha: isHere ? 0.96 : 0.72,
                                      ),
                                    ),
                                  ),
                                ),
                                if (isHere)
                                  Text(
                                    'Now',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: accent.withValues(alpha: 0.95),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
        if (GutenbergBookService.parseStoredChaptersPayload(
              session.chaptersJson,
            ) !=
            null) ...[
          Builder(
            builder: (context) {
              final gp = GutenbergBookService.parseStoredChaptersPayload(
                session.chaptersJson,
              )!;
              return _CollapsibleChapterTray(
                leadingIcon: Icons.auto_stories_rounded,
                accent: accent,
                title: 'Chapters',
                subtitle:
                    '${gp.chapters.length} in this book · expand to pick another',
                expandedBody: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: gp.chapters.asMap().entries.map((e) {
                    final i = e.key;
                    final row = e.value;
                    final title = row.chapterTitle.isNotEmpty
                        ? row.chapterTitle
                        : 'Chapter ${row.chapterNumber}';
                    final isHere = i == gp.selectedChapterIndex;
                    final busy =
                        status == SessionStatus.summarizing ||
                        status == SessionStatus.queued;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        color: isHere
                            ? accent.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: busy
                              ? null
                              : () async {
                                  if (i == gp.selectedChapterIndex) return;
                                  higLightTap();
                                  await ref
                                      .read(sessionActionsProvider)
                                      .requeueGutenbergChapterAndSummarize(
                                        sessionId,
                                        i,
                                        style: style,
                                      );
                                  ref.invalidate(
                                    sessionByIdProvider(sessionId),
                                  );
                                },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    color: isHere
                                        ? accent
                                        : Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.25,
                                      fontWeight: isHere
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: Colors.white.withValues(
                                        alpha: isHere ? 0.96 : 0.72,
                                      ),
                                    ),
                                  ),
                                ),
                                if (isHere)
                                  Text(
                                    'Now',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: accent.withValues(alpha: 0.95),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
        if (session.transcriptSource == 'taddy')
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.35),
                  ),
                ),
                child: const Text(
                  'Timestamps may be approximate (plain transcript)',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ),
            ),
          ),
        if (session.transcriptSource == 'audible' ||
            session.transcriptSource == 'audible_pg' ||
            session.transcriptSource == 'audible_openlibrary')
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.deepPurple.withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  'Audible: Pick a chapter above; summary uses that catalog title + store blurb — not spoken audio',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ),
            ),
          ),
        if (session.transcriptSource == 'gutenberg' ||
            GutenbergBookService.parseStoredChaptersPayload(
                  session.chaptersJson,
                ) !=
                null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.teal.withValues(alpha: 0.45),
                  ),
                ),
                child: const Text(
                  'Gutenberg: Chapter title is from the book text split — tap another chapter to re-summarize',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (PodcastPlayerLinks.looksLikeSpotify(
              _listenUrlForPlayer(session),
            ))
              FilledButton.icon(
                style: _summaryWhitePrimaryButtonStyle(),
                onPressed: () {
                  unawaited(
                    PodcastPlayerLinks.openSpotifyAt(
                      _listenUrlForPlayer(session),
                      session.startTimeSec,
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text(
                  'Open in Spotify',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            if (PodcastPlayerLinks.looksLikeApplePodcasts(
              _listenUrlForPlayer(session),
            ))
              FilledButton.icon(
                style: _summaryWhitePrimaryButtonStyle(),
                onPressed: () async {
                  higLightTap();
                  final ok = await PodcastPlayerLinks.openApplePodcasts(
                    _listenUrlForPlayer(session),
                  );
                  if (!context.mounted) return;
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not open Podcasts. '
                          'Install the Apple Podcasts app, or open the link in Safari.',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.podcasts, size: 18),
                label: const Text(
                  'Open in Apple Podcasts',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
          ],
        ),
        if (!PodcastPlayerLinks.looksLikeSpotify(
              _listenUrlForPlayer(session),
            ) &&
            !PodcastPlayerLinks.looksLikeApplePodcasts(
              _listenUrlForPlayer(session),
            ))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Open in Spotify / Apple Podcasts appears when you save using a podcast link from Home, or when we can derive a show link.',
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryMoreTab extends ConsumerWidget {
  const _SummaryMoreTab({
    required this.session,
    required this.style,
    required this.bullets,
    required this.quotes,
    required this.wc,
    required this.readMin,
  });

  final ListeningSession session;
  final SummaryStyle? style;
  final List<String> bullets;
  final List<String> quotes;
  final int wc;
  final int readMin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final art = EpisodeArtworkThemeScope.maybeOf(context);
    final secondary = art?.meta ?? SummaryThemeColors.textMuted(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (style != null) ...[
          const SizedBox(height: Tokens.spaceSm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                higLightTap();
                await ref
                    .read(sessionActionsProvider)
                    .rememberSummaryStyleForShow(session.artist, style!);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Future saves from “${session.artist}” will use ${style!.label}.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: art != null
                  ? TextButton.styleFrom(foregroundColor: art.accent)
                  : null,
              icon: Icon(
                Icons.bookmark_added_outlined,
                size: 18,
                color: art?.accent ?? Colors.white70,
              ),
              label: Text(
                'Always use ${style!.label} for this show',
                style: TextStyle(
                  color: art?.accent ?? Colors.white70,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                '$wc words · ~$readMin min read',
                style: TextStyle(fontSize: 12, height: 1.4, color: secondary),
              ),
            ),
            SummaryListenControl(
              plainText: _summaryPlainTextForListen(bullets, quotes),
            ),
          ],
        ),
      ],
    );
  }
}

class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen>
    with TickerProviderStateMixin {
  Timer? _pollTimer;
  SessionStatus? _lastHeardStatus;
  late AnimationController _liquidProgress;
  late ConfettiController _confetti;
  OverlayEntry? _firstSummaryOverlay;
  bool _quotesUnlocked = false;
  int _summaryMainTab = 0;
  late final ValueNotifier<bool> _mainBottomFadeVisible;
  int _lastBottomFadeEvalMs = 0;
  late final ScrollController _summaryMainScroll;
  EpisodeArtworkTheme _episodeArtworkTheme = EpisodeArtworkTheme.fallback;
  String? _episodeArtworkPaletteUrl;
  int _episodePaletteLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _mainBottomFadeVisible = ValueNotifier<bool>(true);
    _summaryMainScroll = ScrollController(
      onAttach: (pos) {
        pos.isScrollingNotifier.addListener(_onSummaryScrollSettled);
      },
      onDetach: (pos) {
        pos.isScrollingNotifier.removeListener(_onSummaryScrollSettled);
      },
    );
    _summaryMainScroll.addListener(_onSummaryMainScroll);
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final asyncSession = ref.read(sessionByIdProvider(widget.sessionId));
      final session = asyncSession.asData?.value;
      if (session == null) {
        if (asyncSession.isLoading || asyncSession.hasError) {
          ref.invalidate(sessionByIdProvider(widget.sessionId));
        }
        return;
      }
      final st = SessionStatus.fromJson(session.status);
      if (st == SessionStatus.queued ||
          st == SessionStatus.summarizing ||
          st == SessionStatus.recording) {
        ref.invalidate(sessionByIdProvider(widget.sessionId));
      }
    });
    _liquidProgress = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
  }

  void _applyMainBottomFadeFromMetrics(ScrollMetrics m) {
    if (!m.hasContentDimensions) return;
    if (m.maxScrollExtent <= m.viewportDimension * 0.06) {
      if (_mainBottomFadeVisible.value) {
        _mainBottomFadeVisible.value = false;
      }
    } else {
      final atBottom = m.pixels >= m.maxScrollExtent - 40;
      final show = !atBottom;
      if (show != _mainBottomFadeVisible.value) {
        _mainBottomFadeVisible.value = show;
      }
    }
  }

  void _onSummaryMainScroll() {
    if (!_summaryMainScroll.hasClients) return;
    final m = _summaryMainScroll.position;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBottomFadeEvalMs < 50) return;
    _lastBottomFadeEvalMs = now;
    _applyMainBottomFadeFromMetrics(m);
  }

  void _onSummaryScrollSettled() {
    if (!mounted || !_summaryMainScroll.hasClients) return;
    final pos = _summaryMainScroll.position;
    if (pos.isScrollingNotifier.value) return;
    _applyMainBottomFadeFromMetrics(pos);
  }

  void _stopLiquidProgress() {
    if (_liquidProgress.isAnimating) {
      _liquidProgress.stop();
      _liquidProgress.reset();
    }
  }

  void _syncLiquidProgressForStatus(SessionStatus st) {
    final want = st == SessionStatus.queued || st == SessionStatus.summarizing;
    if (want) {
      if (!_liquidProgress.isAnimating) _liquidProgress.repeat();
    } else {
      _stopLiquidProgress();
    }
  }

  @override
  void didUpdateWidget(covariant SummaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      _summaryMainTab = 0;
      _quotesUnlocked = false;
      _mainBottomFadeVisible.value = true;
      _episodeArtworkTheme = EpisodeArtworkTheme.fallback;
      _episodeArtworkPaletteUrl = null;
      _episodePaletteLoadGeneration++;
      _stopLiquidProgress();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_summaryMainScroll.hasClients) return;
        _summaryMainScroll.jumpTo(0);
      });
    }
  }

  Future<void> _loadEpisodeArtworkTheme(String artUrl) async {
    final gen = ++_episodePaletteLoadGeneration;
    final theme = await EpisodeArtworkTheme.fromArtworkUrl(artUrl);
    if (!mounted || gen != _episodePaletteLoadGeneration) return;
    setState(() => _episodeArtworkTheme = theme);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _summaryMainScroll.removeListener(_onSummaryMainScroll);
    _summaryMainScroll.dispose();
    _mainBottomFadeVisible.dispose();
    _liquidProgress.dispose();
    _confetti.dispose();
    _firstSummaryOverlay?.remove();
    _firstSummaryOverlay = null;
    super.dispose();
  }

  Future<void> _deleteMoment(
    BuildContext context,
    ListeningSession session,
  ) async {
    higLightTap();
    final ok = await showConfirmDeleteSessionSheet(context, session.title);
    if (ok != true || !context.mounted) return;
    await ref.read(sessionDaoProvider).deleteSession(session.id);
    ref.invalidate(sessionByIdProvider(widget.sessionId));
    ref.invalidate(allSessionsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed “${session.title}”'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.pop();
  }

  Future<void> _sharePlainText(
    ListeningSession session,
    List<String> bullets,
  ) async {
    higLightTap();
    final plain = _bulletsPlainForShare(bullets);
    final text = StringBuffer()
      ..writeln(session.title)
      ..writeln(session.artist)
      ..writeln()
      ..writeAll(plain, '\n');
    await Share.share(text.toString(), subject: session.title);
  }

  Future<void> _shareMarkdownFile(
    ListeningSession session,
    List<String> bullets,
    List<String> quotes,
  ) async {
    higLightTap();
    final md = buildSummaryMarkdown(session, bullets: bullets, quotes: quotes);
    final dir = await getTemporaryDirectory();
    final safe = session.title.replaceAll(RegExp(r'[^\w\- ]'), '').trim();
    final file = File('${dir.path}/$safe-summary.md');
    await file.writeAsString(md);
    await Share.shareXFiles([XFile(file.path)], subject: session.title);
  }

  Future<void> _copyMarkdown(
    ListeningSession session,
    List<String> bullets,
    List<String> quotes,
  ) async {
    higLightTap();
    final md = buildSummaryMarkdown(session, bullets: bullets, quotes: quotes);
    await Clipboard.setData(ClipboardData(text: md));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Markdown copied'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareAsImage(
    ListeningSession session,
    List<String> bullets,
  ) async {
    higLightTap();
    if (!mounted) return;
    final plain = _bulletsPlainForShare(bullets);
    final overlay = Overlay.of(context);
    final key = GlobalKey();
    final entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: -900,
        top: 0,
        width: 400,
        child: Material(
          color: const Color(0xFF121218),
          child: RepaintBoundary(
            key: key,
            child: ShareCardGenerator(
              title: session.title,
              artist: session.artist,
              bullets: plain.take(5).toList(),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    try {
      if (!mounted) return;
      // Overlay entry context; not the State's [context].
      // ignore: use_build_context_synchronously
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      if (!mounted) return;
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null || !mounted) return;
      final dir = await getTemporaryDirectory();
      if (!mounted) return;
      final file = File('${dir.path}/moment-${session.id.substring(0, 8)}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], subject: session.title);
    } catch (e, st) {
      debugPrint('[SummaryScreen] share image: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not create image: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      entry.remove();
    }
  }

  void _maybeCelebrateFirstSummary() {
    Future<void>.microtask(() async {
      final already = await MomentsStatsService.isFirstSummaryDone();
      if (!mounted || already) return;
      await MomentsStatsService.markFirstSummaryDone();
      if (!mounted) return;
      _confetti.play();
      _showFirstSummaryCelebration();
      Future.delayed(const Duration(seconds: 4), () {
        _firstSummaryOverlay?.remove();
        _firstSummaryOverlay = null;
      });
    });
  }

  void _showFirstSummaryCelebration() {
    final overlay = Overlay.of(context);
    _firstSummaryOverlay?.remove();
    _firstSummaryOverlay = OverlayEntry(
      builder: (ctx) => Material(
        color: Colors.black54,
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 400),
            builder: (context, t, child) => Opacity(opacity: t, child: child),
            child: Container(
              margin: const EdgeInsets.all(Tokens.spaceLg),
              padding: const EdgeInsets.all(Tokens.spaceLg),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(Tokens.radiusLg),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🎉 Your first summary!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Tokens.spaceSm),
                  Text(
                    'Share it with someone',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: Tokens.spaceMd),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            _firstSummaryOverlay?.remove();
                            _firstSummaryOverlay = null;
                          },
                          child: const Text('Dismiss'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_firstSummaryOverlay!);
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionByIdProvider(widget.sessionId));

    ref.listen(sessionByIdProvider(widget.sessionId), (prev, next) {
      next.whenData((session) {
        if (session == null) return;
        final st = SessionStatus.fromJson(session.status);
        if (st != SessionStatus.done && _quotesUnlocked) {
          setState(() => _quotesUnlocked = false);
        }
        if (_lastHeardStatus == SessionStatus.summarizing &&
            st == SessionStatus.done) {
          unawaited(PSNHaptics.summaryComplete());
          _maybeCelebrateFirstSummary();
        }
        if (st == SessionStatus.error) {
          unawaited(PSNHaptics.error());
        }
        _lastHeardStatus = st;
      });
    });

    return sessionAsync.when(
      loading: () {
        _stopLiquidProgress();
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(title: const Text('Summary')),
          body: const Padding(
            padding: EdgeInsets.all(Tokens.spaceMd),
            child: _SummaryLayoutSkeleton(),
          ),
        );
      },
      error: (e, _) {
        _stopLiquidProgress();
        return Scaffold(body: Center(child: Text('Error: $e')));
      },
      data: (session) {
        if (session == null) {
          _stopLiquidProgress();
          return const Scaffold(body: Center(child: Text('Session not found')));
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cs = Theme.of(context).colorScheme;
        final appBarChipBg = isDark
            ? Colors.black.withValues(alpha: 0.4)
            : cs.surfaceContainerHighest;
        final appBarIconFg = isDark ? Colors.white : cs.onSurface;

        final status = SessionStatus.fromJson(session.status);
        _syncLiquidProgressForStatus(status);
        final style = SummaryStyle.fromJson(session.summaryStyle);
        final bullets = [
          session.bullet1,
          session.bullet2,
          session.bullet3,
          session.bullet4,
          session.bullet5,
        ].whereType<String>().toList();
        final quotes = [
          session.quote1,
          session.quote2,
          session.quote3,
        ].whereType<String>().toList();

        final contentChatContext = contentChatContextBlock(bullets, quotes);
        final isBookContentChat = useBookContentChatPrompt(session);
        final chapterBased = SessionDisplayKind.isChapterBased(session);
        final summaryTabIndex = chapterBased
            ? (_summaryMainTab > 2 ? 0 : _summaryMainTab)
            : (_summaryMainTab > 4 ? 0 : _summaryMainTab);

        final combined = bullets.join(' ');
        final wc = combined
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .length;
        final readMin = (wc / 200).ceil().clamp(1, 999);

        final useEpisodeChromeLayout =
            isDark && status == SessionStatus.done && bullets.isNotEmpty;
        if (useEpisodeChromeLayout) {
          final artUrl = session.artworkUrl?.trim() ?? '';
          if (_episodeArtworkPaletteUrl != artUrl) {
            _episodeArtworkPaletteUrl = artUrl;
            unawaited(_loadEpisodeArtworkTheme(artUrl));
          }
        }
        final pageBg = useEpisodeChromeLayout
            ? _episodeArtworkTheme.pageBg
            : SummaryThemeColors.bgPrimary(context);
        final chatTabIndex = chapterBased ? 1 : 2;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: Scaffold(
            backgroundColor: pageBg,
            body: Stack(
              children: [
                () {
                  final scroll = CustomScrollView(
                    controller: _summaryMainScroll,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      if (!useEpisodeChromeLayout)
                        SliverAppBar(
                          pinned: false,
                          floating: true,
                          backgroundColor: Colors.transparent,
                          surfaceTintColor: Colors.transparent,
                          scrolledUnderElevation: 0,
                          elevation: 0,
                          expandedHeight: 0,
                          automaticallyImplyLeading: false,
                          leading: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => context.pop(),
                            icon: Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: appBarChipBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_back_ios_new,
                                size: 16,
                                color: appBarIconFg,
                              ),
                            ),
                          ),
                          title: Text(
                            'Summary',
                            style: GoogleFonts.syne(
                              color: appBarIconFg,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          actions: [
                            if (status == SessionStatus.done &&
                                bullets.isNotEmpty)
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: appBarChipBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.ios_share,
                                    size: 16,
                                    color: appBarIconFg,
                                  ),
                                ),
                                onSelected: (v) {
                                  switch (v) {
                                    case 'text':
                                      unawaited(
                                        _sharePlainText(session, bullets),
                                      );
                                      break;
                                    case 'md':
                                      unawaited(
                                        _shareMarkdownFile(
                                          session,
                                          bullets,
                                          quotes,
                                        ),
                                      );
                                      break;
                                    case 'copy':
                                      unawaited(
                                        _copyMarkdown(session, bullets, quotes),
                                      );
                                      break;
                                    case 'img':
                                      unawaited(
                                        _shareAsImage(session, bullets),
                                      );
                                      break;
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'text',
                                    child: Text('Share as text'),
                                  ),
                                  PopupMenuItem(
                                    value: 'md',
                                    child: Text('Share Markdown file'),
                                  ),
                                  PopupMenuItem(
                                    value: 'copy',
                                    child: Text('Copy Markdown'),
                                  ),
                                  PopupMenuItem(
                                    value: 'img',
                                    child: Text('Share image card'),
                                  ),
                                ],
                              ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _deleteMoment(context, session),
                              icon: Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: appBarChipBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: appBarIconFg,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      SliverToBoxAdapter(
                        child: _CinematicHero(
                          session: session,
                          bottomBlendColor: useEpisodeChromeLayout
                              ? _episodeArtworkTheme.pageBg
                              : null,
                          externalHeroWash: useEpisodeChromeLayout
                              ? _episodeArtworkTheme.heroWash
                              : null,
                          topOverlay: useEpisodeChromeLayout
                              ? EpisodeHeroActionBar(
                                  onClose: () => context.pop(),
                                  trailing: [
                                    if (status == SessionStatus.done &&
                                        bullets.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: PopupMenuButton<String>(
                                          offset: const Offset(0, 48),
                                          padding: EdgeInsets.zero,
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.38,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.ios_share,
                                              size: 20,
                                              color: Colors.white.withValues(
                                                alpha: 0.95,
                                              ),
                                            ),
                                          ),
                                          onSelected: (v) {
                                            switch (v) {
                                              case 'text':
                                                unawaited(
                                                  _sharePlainText(
                                                    session,
                                                    bullets,
                                                  ),
                                                );
                                                break;
                                              case 'md':
                                                unawaited(
                                                  _shareMarkdownFile(
                                                    session,
                                                    bullets,
                                                    quotes,
                                                  ),
                                                );
                                                break;
                                              case 'copy':
                                                unawaited(
                                                  _copyMarkdown(
                                                    session,
                                                    bullets,
                                                    quotes,
                                                  ),
                                                );
                                                break;
                                              case 'img':
                                                unawaited(
                                                  _shareAsImage(
                                                    session,
                                                    bullets,
                                                  ),
                                                );
                                                break;
                                            }
                                          },
                                          itemBuilder: (context) => const [
                                            PopupMenuItem(
                                              value: 'text',
                                              child: Text('Share as text'),
                                            ),
                                            PopupMenuItem(
                                              value: 'md',
                                              child: Text(
                                                'Share Markdown file',
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'copy',
                                              child: Text('Copy Markdown'),
                                            ),
                                            PopupMenuItem(
                                              value: 'img',
                                              child: Text('Share image card'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    EpisodeHeroIconButton(
                                      icon: Icons.delete_outline_rounded,
                                      onPressed: () =>
                                          _deleteMoment(context, session),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ),
                      if (useEpisodeChromeLayout)
                        SliverToBoxAdapter(
                          child: SummaryEpisodeInfoHeader(
                            theme: _episodeArtworkTheme,
                            title: session.title,
                            showName: session.artist,
                            artworkUrl: session.artworkUrl,
                            createdAt: session.createdAt,
                            momentCount: bullets.length,
                            durationLabel: _summaryShortDuration(session),
                            trustLine: _summaryTrustLine(session),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (status == SessionStatus.queued ||
                                status == SessionStatus.summarizing)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: AnimatedBuilder(
                                  animation: _liquidProgress,
                                  builder: (context, _) {
                                    return Column(
                                      children: [
                                        Center(
                                          child: LiquidLoader(
                                            progress: _liquidProgress.value,
                                            artworkUrl: session.artworkUrl,
                                            labelForInitials: session.artist,
                                            accentColor: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: Tokens.spaceLg),
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.05,
                                                  )
                                                : cs.surfaceContainerHighest
                                                      .withValues(alpha: 0.65),
                                            borderRadius: BorderRadius.circular(
                                              Tokens.radiusMd,
                                            ),
                                            border: Border.all(
                                              color: isDark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.1,
                                                    )
                                                  : cs.outlineVariant,
                                            ),
                                          ),
                                          child: _StatusCard(status: status),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            if (status == SessionStatus.error)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: _ErrorCard(
                                  message:
                                      session.errorMessage ??
                                      'Something went wrong — tap to retry',
                                  onRetry: () {
                                    ref
                                        .read(sessionActionsProvider)
                                        .retrySummary(
                                          widget.sessionId,
                                          style: style,
                                        );
                                    ref.invalidate(
                                      sessionByIdProvider(widget.sessionId),
                                    );
                                  },
                                ),
                              ),
                            if (status == SessionStatus.done &&
                                bullets.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  22,
                                  28,
                                  22,
                                  0,
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: _kSummaryContentMaxWidth,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (!useEpisodeChromeLayout) ...[
                                          Text(
                                            'Summary',
                                            style: _summarySectionLabelStyle(
                                              context,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            _summaryTrustLine(session),
                                            style: TextStyle(
                                              fontSize: 13,
                                              height: 1.55,
                                              color:
                                                  SummaryThemeColors.onBodySoft(
                                                    context,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 22),
                                        ],
                                        _SummaryChaptersAndPlayerLinks(
                                          session: session,
                                          status: status,
                                          style: style,
                                          sessionId: widget.sessionId,
                                        ),
                                        const SizedBox(height: 18),
                                        if (useEpisodeChromeLayout) ...[
                                          SummaryAskAiBar(
                                            theme: _episodeArtworkTheme,
                                            onTap: () {
                                              setState(
                                                () => _summaryMainTab =
                                                    chatTabIndex,
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                        _AdaptiveSummaryTabs(
                                          audiobookMode: chapterBased,
                                          selectedIndex: summaryTabIndex,
                                          accent:
                                              EpisodeArtworkThemeScope.maybeOf(
                                                context,
                                              )?.accent ??
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                          episodeChromeTabStyle:
                                              useEpisodeChromeLayout,
                                          onSelect: (i) {
                                            setState(() => _summaryMainTab = i);
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        Builder(
                                          builder: (context) {
                                            final episodeArt =
                                                EpisodeArtworkThemeScope.maybeOf(
                                                  context,
                                                );
                                            final t = summaryTabIndex;
                                            final showPoints = t == 0;
                                            final showQuotes =
                                                !chapterBased && t == 1;
                                            final showChat = chapterBased
                                                ? t == 1
                                                : t == 2;
                                            final showTags = chapterBased
                                                ? t == 2
                                                : t == 3;
                                            final showMore =
                                                !chapterBased && t == 4;
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                if (showPoints) ...[
                                                  Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: SummaryListenControl(
                                                      plainText:
                                                          _summaryPlainTextForListen(
                                                            bullets,
                                                            quotes,
                                                          ),
                                                      filledPrimaryListenButton:
                                                          useEpisodeChromeLayout,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  _TypingOrInstantBullets(
                                                    sessionId: session.id,
                                                    listenSession: session,
                                                    bullets: bullets,
                                                    accent:
                                                        episodeArt?.accent ??
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                                    useStructuredBookCards:
                                                        chapterBased,
                                                    useVerticalStack: true,
                                                    insightCardsUseArtworkTheme:
                                                        useEpisodeChromeLayout,
                                                    onAllBulletsComplete: () {
                                                      if (mounted) {
                                                        setState(
                                                          () =>
                                                              _quotesUnlocked =
                                                                  true,
                                                        );
                                                      }
                                                    },
                                                  ),
                                                ],
                                                if (showQuotes)
                                                  _QuotesTabPanel(
                                                    quotes: quotes,
                                                    unlocked: _quotesUnlocked,
                                                    session: session,
                                                    accent:
                                                        episodeArt?.accent ??
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                                  ),
                                                Visibility(
                                                  visible: showChat,
                                                  maintainState: true,
                                                  maintainAnimation: true,
                                                  maintainSize: false,
                                                  child: ContentChat(
                                                    key: ValueKey(
                                                      '${session.id}-tab-chat',
                                                    ),
                                                    systemPrompt:
                                                        isBookContentChat
                                                        ? buildBookContentChatSystemPrompt(
                                                            bookTitle:
                                                                session.title,
                                                            authorName:
                                                                session.artist,
                                                            allChapterSummaries:
                                                                contentChatContext,
                                                          )
                                                        : buildPodcastContentChatSystemPrompt(
                                                            podcastTitle:
                                                                session.title,
                                                            podcastTranscriptOrSummary:
                                                                contentChatContext,
                                                          ),
                                                    title: session.title,
                                                    starterChips:
                                                        isBookContentChat
                                                        ? kBookContentChatStarterChips
                                                        : kPodcastContentChatStarterChips,
                                                    embedInTab: true,
                                                  ),
                                                ),
                                                if (showTags)
                                                  _TagsRow(session: session),
                                                if (showMore)
                                                  _SummaryMoreTab(
                                                    session: session,
                                                    style: style,
                                                    bullets: bullets,
                                                    quotes: quotes,
                                                    wc: wc,
                                                    readMin: readMin,
                                                  ),
                                                if (chapterBased) ...[
                                                  const SizedBox(height: 24),
                                                  if (style != null) ...[
                                                    Align(
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      child: TextButton.icon(
                                                        onPressed: () async {
                                                          higLightTap();
                                                          await ref
                                                              .read(
                                                                sessionActionsProvider,
                                                              )
                                                              .rememberSummaryStyleForShow(
                                                                session.artist,
                                                                style!,
                                                              );
                                                          if (context.mounted) {
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  'Future saves from “${session.artist}” will use ${style!.label}.',
                                                                ),
                                                                behavior:
                                                                    SnackBarBehavior
                                                                        .floating,
                                                              ),
                                                            );
                                                          }
                                                        },
                                                        style:
                                                            episodeArt != null
                                                            ? TextButton.styleFrom(
                                                                foregroundColor:
                                                                    episodeArt
                                                                        .accent,
                                                              )
                                                            : null,
                                                        icon: Icon(
                                                          Icons
                                                              .bookmark_added_outlined,
                                                          size: 18,
                                                          color:
                                                              episodeArt
                                                                  ?.accent ??
                                                              Colors.white70,
                                                        ),
                                                        label: Text(
                                                          'Always use ${style!.label} for this show',
                                                          style: TextStyle(
                                                            color:
                                                                episodeArt
                                                                    ?.accent ??
                                                                Colors.white70,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          '$wc words · ~$readMin min read',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            height: 1.4,
                                                            color:
                                                                episodeArt
                                                                    ?.meta ??
                                                                Tokens
                                                                    .textMuted,
                                                          ),
                                                        ),
                                                      ),
                                                      if (!showPoints)
                                                        SummaryListenControl(
                                                          plainText:
                                                              _summaryPlainTextForListen(
                                                                bullets,
                                                                quotes,
                                                              ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (status == SessionStatus.done && bullets.isEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  24,
                                  16,
                                  0,
                                ),
                                child: Text(
                                  'No summary content available.',
                                  style: TextStyle(
                                    color: SummaryThemeColors.onBodySoft(
                                      context,
                                    ),
                                  ),
                                ),
                              ),
                            if (!SessionDisplayKind.isChapterBased(
                              session,
                            )) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  22,
                                  32,
                                  22,
                                  10,
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: _kSummaryContentMaxWidth,
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Jump & summarize',
                                        style: _summarySectionLabelStyle(
                                          context,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: _kSummaryContentMaxWidth,
                                    ),
                                    child: _EpisodeTimelineSection(
                                      session: session,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            SizedBox(
                              height: MediaQuery.paddingOf(context).bottom + 32,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  return useEpisodeChromeLayout
                      ? EpisodeArtworkThemeScope(
                          theme: _episodeArtworkTheme,
                          child: scroll,
                        )
                      : scroll;
                }(),
                ValueListenableBuilder<bool>(
                  valueListenable: _mainBottomFadeVisible,
                  builder: (context, showFade, _) {
                    if (!showFade) return const SizedBox.shrink();
                    return Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 60,
                      child: SafeArea(
                        top: false,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [pageBg.withValues(alpha: 0), pageBg],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confetti,
                    blastDirection: math.pi / 2,
                    emissionFrequency: 0.08,
                    numberOfParticles: 18,
                    maxBlastForce: 12,
                    minBlastForce: 4,
                    gravity: 0.15,
                    colors: const [
                      Color(0xFF6366F1),
                      Color(0xFF10B981),
                      Colors.white,
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Collapsed by default; header tap expands the chapter list.
class _CollapsibleChapterTray extends StatefulWidget {
  const _CollapsibleChapterTray({
    required this.leadingIcon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.expandedBody,
  });

  final IconData leadingIcon;
  final Color accent;
  final String title;
  final String subtitle;
  final Widget expandedBody;

  @override
  State<_CollapsibleChapterTray> createState() =>
      _CollapsibleChapterTrayState();
}

class _CollapsibleChapterTrayState extends State<_CollapsibleChapterTray> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : cs.surfaceContainerHighest.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              higLightTap();
              setState(() => _open = !_open);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      widget.leadingIcon,
                      color: widget.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.95)
                                : cs.onSurface,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.55)
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: Tokens.durationFast,
                    curve: Tokens.springCurve,
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.65)
                          : cs.onSurfaceVariant,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.045)
                    : cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.09)
                      : cs.outlineVariant,
                ),
              ),
              child: widget.expandedBody,
            ),
          ),
          crossFadeState: _open
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 240),
          sizeCurve: Curves.easeOutCubic,
        ),
      ],
    );
  }
}

/// Full-bleed ~320px cinema hero: blurred artwork, palette tint, cover, title stack.
class _CinematicHero extends StatefulWidget {
  const _CinematicHero({
    required this.session,
    this.topOverlay,
    this.bottomBlendColor,
    this.externalHeroWash,
  });

  final ListeningSession session;
  final Widget? topOverlay;

  /// Bottom gradient merge color (e.g. cinematic summary page background).
  final Color? bottomBlendColor;

  /// When set, tints the hero from podcast palette; internal extraction is skipped.
  final Color? externalHeroWash;

  @override
  State<_CinematicHero> createState() => _CinematicHeroState();
}

class _CinematicHeroState extends State<_CinematicHero> {
  Color? _tint;

  static const double _heroHeight = 320;

  @override
  void initState() {
    super.initState();
    if (widget.externalHeroWash != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_extractPalette());
    });
  }

  @override
  void didUpdateWidget(covariant _CinematicHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.externalHeroWash != null) return;
    if (oldWidget.externalHeroWash != null && widget.externalHeroWash == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_extractPalette());
      });
      return;
    }
    if (oldWidget.session.id != widget.session.id ||
        oldWidget.session.artworkUrl != widget.session.artworkUrl) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_extractPalette());
      });
    }
  }

  Future<void> _extractPalette() async {
    final raw = widget.session.artworkUrl?.trim();
    if (raw == null ||
        raw.isEmpty ||
        !(raw.startsWith('http://') || raw.startsWith('https://'))) {
      if (mounted) setState(() => _tint = null);
      return;
    }
    try {
      // perf: Match episode chrome — bounded decode for hero tint extraction.
      final gen = await PaletteGenerator.fromImageProvider(
        ResizeImage(NetworkImage(raw), width: 88, height: 88),
        size: const Size(88, 88),
        maximumColorCount: 16,
      );
      final c =
          gen.darkVibrantColor?.color ??
          gen.vibrantColor?.color ??
          gen.dominantColor?.color ??
          Tokens.bgPrimary;
      if (mounted) setState(() => _tint = c);
    } catch (_) {
      if (mounted) setState(() => _tint = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final url = session.artworkUrl ?? '';
    final raw = session.artworkUrl?.trim();
    final hasUrl =
        raw != null &&
        raw.isNotEmpty &&
        (raw.startsWith('http://') || raw.startsWith('https://'));

    // perf: memCache* keeps decoded textures near on-screen pixel size.
    final heroMemW = decodeCacheExtent(
      context,
      MediaQuery.sizeOf(context).width,
    );
    final heroMemH = decodeCacheExtent(context, _heroHeight);
    const coverLogical = 120.0;
    final coverMem = decodeCacheExtent(context, coverLogical);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final heroFg = isDark ? Colors.white : cs.onSurface;
    final heroFgSoft = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : cs.onSurfaceVariant;

    final chapterBased = SessionDisplayKind.isChapterBased(session);
    final showTimePill =
        !chapterBased &&
        (session.startTimeSec > 0 || session.endTimeSec != null);

    final letter = session.artist.trim().isNotEmpty
        ? session.artist.trim()[0].toUpperCase()
        : '?';

    final blendBottom =
        widget.bottomBlendColor ?? SummaryThemeColors.bgPrimary(context);

    final wash = widget.externalHeroWash ?? _tint;

    final blurredLayer = hasUrl
        ? RepaintBoundary(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: _heroHeight,
                memCacheWidth: heroMemW,
                memCacheHeight: heroMemH,
                color: Colors.black.withValues(alpha: 0.35),
                colorBlendMode: BlendMode.darken,
                placeholder: (context, _) =>
                    Container(color: SummaryThemeColors.bgSurface(context)),
                errorWidget: (context, url, err) =>
                    Container(color: SummaryThemeColors.bgSurface(context)),
              ),
            ),
          )
        : Container(
            width: double.infinity,
            height: _heroHeight,
            color: SummaryThemeColors.bgSurface(context),
          );

    return SizedBox(
      height: _heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          blurredLayer,
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              color: wash != null
                  ? wash.withValues(alpha: 0.15)
                  : Colors.transparent,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.45, 0.75, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.transparent,
                    blendBottom.withValues(alpha: 0.7),
                    blendBottom,
                  ],
                ),
              ),
            ),
          ),
          if (widget.topOverlay != null)
            Positioned(top: 0, left: 0, right: 0, child: widget.topOverlay!),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 60,
            child: Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.62),
                      blurRadius: 36,
                      spreadRadius: 1,
                      offset: const Offset(0, 14),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: hasUrl
                      ? CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                          memCacheWidth: coverMem,
                          memCacheHeight: coverMem,
                          placeholder: (context, _) => Container(
                            color: SummaryThemeColors.bgElevated(context),
                            alignment: Alignment.center,
                            child: Text(
                              letter,
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: SummaryThemeColors.textMuted(context),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, err) => Container(
                            color: SummaryThemeColors.bgElevated(context),
                            alignment: Alignment.center,
                            child: Text(
                              letter,
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: SummaryThemeColors.textMuted(context),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: SummaryThemeColors.bgElevated(context),
                          alignment: Alignment.center,
                          child: Text(
                            letter,
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: SummaryThemeColors.textMuted(context),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
          if (widget.topOverlay == null)
            Positioned(
              bottom: 0,
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    session.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.syne(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: heroFg,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.5 : 0.12,
                          ),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    session.artist,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: heroFgSoft),
                  ),
                  const SizedBox(height: 8),
                  if (chapterBased)
                    Container(
                      constraints: const BoxConstraints(maxWidth: 320),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.42)
                            : cs.surfaceContainerHighest.withValues(
                                alpha: 0.92,
                              ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.18)
                              : cs.outlineVariant,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.menu_book_outlined,
                            size: 17,
                            color: heroFg,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _chapterHeroSubtitle(session),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                                color: heroFg,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (showTimePill)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white
                            : cs.surfaceContainerHighest.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: isDark
                            ? null
                            : Border.all(color: cs.outlineVariant, width: 1),
                      ),
                      child: Text(
                        _summaryDurationLabel(session),
                        style: GoogleFonts.dmMono(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? _kSummaryOnWhiteFg : heroFg,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Multi-part summaries: horizontal section “tabs” on top; content switches below.
class _SummarySectionTabsView extends StatefulWidget {
  const _SummarySectionTabsView({
    required this.bullets,
    required this.accent,
    required this.useStructuredBookCards,
    required this.listenSession,
    this.insightCardsUseArtworkTheme = false,
    required this.onAllBulletsComplete,
  });

  final List<String> bullets;
  final Color accent;
  final bool useStructuredBookCards;
  final ListeningSession listenSession;
  final bool insightCardsUseArtworkTheme;
  final VoidCallback onAllBulletsComplete;

  @override
  State<_SummarySectionTabsView> createState() =>
      _SummarySectionTabsViewState();
}

class _SummarySectionTabsViewState extends State<_SummarySectionTabsView> {
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onAllBulletsComplete();
    });
  }

  Widget _panelBody() {
    final raw = widget.bullets[_selected];
    final parts = _splitEpisodeTimestamp(raw);
    if (widget.useStructuredBookCards) {
      final parsed = parseSummaryBulletSections(parts.body);
      // Title is shown on the tab; panel is body only.
      return Text(
        parsed.body,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w400,
          height: 1.7,
          color: SummaryThemeColors.onBody(context),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: _GlassBulletCard(
        accent: widget.accent,
        listenSession: widget.listenSession,
        timestampAt: parts.at,
        showInsightBannerRow: widget.insightCardsUseArtworkTheme,
        onShare: () => _shareInsightCard(context, parts.body),
        child: Text(
          parts.body,
          style: _summaryBulletStyle(context, _selected + 1),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = (MediaQuery.sizeOf(context).height * 0.52).clamp(340.0, 600.0);
    final accent = widget.accent;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: h,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 8),
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false,
              cacheExtent: 500,
              itemCount: widget.bullets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      higLightTap();
                      setState(() => _selected = i);
                    },
                    borderRadius: BorderRadius.circular(22),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.useStructuredBookCards ? 16 : 12,
                        vertical: 11,
                      ),
                      constraints: widget.useStructuredBookCards
                          ? null
                          : const BoxConstraints(minWidth: 40),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: i == _selected
                            ? accent.withValues(alpha: 0.22)
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : cs.surfaceContainerHighest.withValues(
                                      alpha: 0.85,
                                    )),
                        border: Border.all(
                          color: i == _selected
                              ? accent.withValues(alpha: 0.65)
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.14)
                                    : cs.outlineVariant),
                          width: i == _selected ? 1.5 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _summaryBulletRailLabel(
                          widget.bullets[i],
                          i,
                          widget.useStructuredBookCards,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: widget.useStructuredBookCards ? 13 : 14,
                          fontWeight: i == _selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontFeatures: widget.useStructuredBookCards
                              ? null
                              : const [ui.FontFeature.tabularFigures()],
                          color: i == _selected
                              ? (isDark
                                    ? Colors.white.withValues(alpha: 0.96)
                                    : cs.onSurface)
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.65)
                                    : cs.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(Tokens.radiusLg),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.09)
                      : cs.outlineVariant,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Tokens.radiusLg),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 22, 80),
                      child: _panelBody(),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 60,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                SummaryThemeColors.bgPrimary(
                                  context,
                                ).withValues(alpha: 0),
                                SummaryThemeColors.bgPrimary(context),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Typewriter bullets only the first time this summary is viewed; then instant.
class _TypingOrInstantBullets extends StatefulWidget {
  const _TypingOrInstantBullets({
    required this.sessionId,
    required this.listenSession,
    required this.bullets,
    required this.accent,
    this.useStructuredBookCards = false,
    this.useVerticalStack = false,
    this.insightCardsUseArtworkTheme = false,
    required this.onAllBulletsComplete,
  });

  final String sessionId;
  final ListeningSession listenSession;
  final List<String> bullets;
  final Color accent;

  /// Audiobook / Gutenberg: section titles + plain body (no markdown / no # chips).
  final bool useStructuredBookCards;

  /// When true, never use horizontal 1–5 point tabs (main summary uses section tabs).
  final bool useVerticalStack;

  /// INSIGHT banner row on glass bullet cards (cinematic layout).
  final bool insightCardsUseArtworkTheme;
  final VoidCallback onAllBulletsComplete;

  @override
  State<_TypingOrInstantBullets> createState() =>
      _TypingOrInstantBulletsState();
}

class _TypingOrInstantBulletsState extends State<_TypingOrInstantBullets> {
  late final Future<bool> _playedFuture;
  bool _instantUnlockScheduled = false;

  @override
  void initState() {
    super.initState();
    _playedFuture = MomentsStatsService.hasSummaryTypewriterPlayed(
      widget.sessionId,
    );
  }

  void _scheduleInstantQuotesUnlock() {
    if (_instantUnlockScheduled) return;
    _instantUnlockScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onAllBulletsComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bullets.length > 1 && !widget.useVerticalStack) {
      return _SummarySectionTabsView(
        bullets: widget.bullets,
        accent: widget.accent,
        useStructuredBookCards: widget.useStructuredBookCards,
        listenSession: widget.listenSession,
        insightCardsUseArtworkTheme: widget.insightCardsUseArtworkTheme,
        onAllBulletsComplete: widget.onAllBulletsComplete,
      );
    }

    return FutureBuilder<bool>(
      future: _playedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 100,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final alreadyPlayed = snapshot.data ?? false;

        if (alreadyPlayed) {
          _scheduleInstantQuotesUnlock();
          final instantChildren = <Widget>[];
          for (var j = 0; j < widget.bullets.length; j++) {
            if (j > 0) {
              instantChildren.add(const SizedBox(height: 20));
            }
            final parts = _splitEpisodeTimestamp(widget.bullets[j]);
            if (widget.useStructuredBookCards) {
              final parsed = parseSummaryBulletSections(parts.body);
              instantChildren.add(
                _BookSummarySectionCard(
                  accent: widget.accent,
                  title: parsed.title,
                  sectionIndex: j + 1,
                  sharePlain: _bookSectionSharePlain(
                    parsed.title,
                    j + 1,
                    parsed.body,
                  ),
                  body: Text(
                    parsed.body,
                    style: TextStyle(
                      fontSize: j == 0 ? 17 : 16,
                      fontWeight: j == 0 ? FontWeight.w500 : FontWeight.w400,
                      height: 1.72,
                      color: SummaryThemeColors.onBody(
                        context,
                      ).withValues(alpha: j == 0 ? 0.94 : 0.88),
                    ),
                  ),
                ),
              );
            } else {
              instantChildren.add(
                _GlassBulletCard(
                  accent: widget.accent,
                  listenSession: widget.listenSession,
                  timestampAt: parts.at,
                  showInsightBannerRow: widget.insightCardsUseArtworkTheme,
                  onShare: () => _shareInsightCard(context, parts.body),
                  child: Text(
                    parts.body,
                    style: _summaryBulletStyle(context, j + 1),
                  ),
                ),
              );
            }
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: instantChildren,
          );
        }

        return _SequentialTypeBullets(
          bullets: widget.bullets,
          accent: widget.accent,
          listenSession: widget.listenSession,
          useStructuredBookCards: widget.useStructuredBookCards,
          insightCardsUseArtworkTheme: widget.insightCardsUseArtworkTheme,
          onAllBulletsComplete: () {
            MomentsStatsService.markSummaryTypewriterPlayed(
              widget.sessionId,
            ).then((_) {
              if (mounted) widget.onAllBulletsComplete();
            });
          },
        );
      },
    );
  }
}

class _SequentialTypeBullets extends StatefulWidget {
  const _SequentialTypeBullets({
    required this.bullets,
    required this.accent,
    required this.listenSession,
    this.useStructuredBookCards = false,
    this.insightCardsUseArtworkTheme = false,
    this.onAllBulletsComplete,
  });

  final List<String> bullets;
  final Color accent;
  final ListeningSession listenSession;
  final bool useStructuredBookCards;
  final bool insightCardsUseArtworkTheme;
  final VoidCallback? onAllBulletsComplete;

  @override
  State<_SequentialTypeBullets> createState() => _SequentialTypeBulletsState();
}

class _SequentialTypeBulletsState extends State<_SequentialTypeBullets> {
  /// Number of bullets fully typed; next one animates.
  int _completed = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.bullets.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    for (var j = 0; j < _completed; j++) {
      if (j > 0) {
        children.add(SizedBox(height: widget.useStructuredBookCards ? 20 : 16));
      }
      final parts = _splitEpisodeTimestamp(widget.bullets[j]);
      if (widget.useStructuredBookCards) {
        final parsed = parseSummaryBulletSections(parts.body);
        children.add(
          _BookSummarySectionCard(
            accent: widget.accent,
            title: parsed.title,
            sectionIndex: j + 1,
            sharePlain: _bookSectionSharePlain(
              parsed.title,
              j + 1,
              parsed.body,
            ),
            body: Text(
              parsed.body,
              style: TextStyle(
                fontSize: j == 0 ? 17 : 16,
                fontWeight: j == 0 ? FontWeight.w500 : FontWeight.w400,
                height: 1.72,
                color: SummaryThemeColors.onBody(
                  context,
                ).withValues(alpha: j == 0 ? 0.94 : 0.88),
              ),
            ),
          ),
        );
      } else {
        children.add(
          _GlassBulletCard(
            accent: widget.accent,
            listenSession: widget.listenSession,
            timestampAt: parts.at,
            showInsightBannerRow: widget.insightCardsUseArtworkTheme,
            onShare: () => _shareInsightCard(context, parts.body),
            child: Text(parts.body, style: _summaryBulletStyle(context, j + 1)),
          ),
        );
      }
    }
    if (_completed < widget.bullets.length) {
      if (_completed > 0) {
        children.add(SizedBox(height: widget.useStructuredBookCards ? 20 : 16));
      }
      final cur = _splitEpisodeTimestamp(widget.bullets[_completed]);
      final parsed = parseSummaryBulletSections(cur.body);
      if (widget.useStructuredBookCards) {
        children.add(
          _BookSummarySectionCard(
            accent: widget.accent,
            title: parsed.title,
            sectionIndex: _completed + 1,
            sharePlain: _bookSectionSharePlain(
              parsed.title,
              _completed + 1,
              parsed.body,
            ),
            body: TypewriteText(
              key: ValueKey('tw-$_completed-${widget.bullets[_completed]}'),
              text: parsed.body,
              charsPerSecond: 200,
              style: TextStyle(
                fontSize: _completed == 0 ? 17 : 16,
                fontWeight: _completed == 0 ? FontWeight.w500 : FontWeight.w400,
                height: 1.72,
                color: SummaryThemeColors.onBody(
                  context,
                ).withValues(alpha: _completed == 0 ? 0.94 : 0.88),
              ),
              onComplete: () {
                setState(() {
                  _completed++;
                  if (_completed >= widget.bullets.length) {
                    widget.onAllBulletsComplete?.call();
                  }
                });
              },
            ),
          ),
        );
      } else {
        children.add(
          _GlassBulletCard(
            accent: widget.accent,
            listenSession: widget.listenSession,
            timestampAt: cur.at,
            showInsightBannerRow: widget.insightCardsUseArtworkTheme,
            onShare: () => _shareInsightCard(context, cur.body),
            child: TypewriteText(
              key: ValueKey('tw-$_completed-${widget.bullets[_completed]}'),
              text: cur.body,
              charsPerSecond: 200,
              style: _summaryBulletStyle(context, _completed + 1),
              onComplete: () {
                setState(() {
                  _completed++;
                  if (_completed >= widget.bullets.length) {
                    widget.onAllBulletsComplete?.call();
                  }
                });
              },
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// Rich card for audiobook / ebook section summaries (plain typography, no markdown).
class _BookSummarySectionCard extends StatelessWidget {
  const _BookSummarySectionCard({
    required this.accent,
    required this.title,
    required this.sectionIndex,
    required this.body,
    this.sharePlain,
  });

  final Color accent;
  final String? title;
  final int sectionIndex;
  final Widget body;
  final String? sharePlain;

  @override
  Widget build(BuildContext context) {
    final label = (title != null && title!.trim().isNotEmpty)
        ? title!.trim()
        : 'Section $sectionIndex';

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 20, 22),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(Tokens.radiusLg),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3,
                    constraints: const BoxConstraints(minHeight: 52),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accent.withValues(alpha: 0.85),
                          accent.withValues(alpha: 0.32),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 36),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.15,
                                  height: 1.35,
                                  color: accent.withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(height: 14),
                              body,
                            ],
                          ),
                        ),
                        if (sharePlain != null && sharePlain!.trim().isNotEmpty)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              icon: Icon(
                                Icons.north_east_rounded,
                                size: 18,
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                              onPressed: () =>
                                  _shareInsightCard(context, sharePlain!),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassBulletCard extends StatelessWidget {
  const _GlassBulletCard({
    required this.accent,
    required this.listenSession,
    required this.child,
    required this.onShare,
    this.timestampAt,
    this.showInsightBannerRow = false,
  });

  final Color accent;
  final ListeningSession listenSession;
  final Widget child;
  final VoidCallback onShare;

  /// Episode clock for this bullet (shown above [child], next to the text block).
  final String? timestampAt;

  /// Gold “INSIGHT” label row above the bullet (cinematic layout).
  final bool showInsightBannerRow;

  @override
  Widget build(BuildContext context) {
    final artworkTheme = EpisodeArtworkThemeScope.maybeOf(context);
    final cardBg = showInsightBannerRow
        ? (artworkTheme?.cardRaised ?? EpisodeChromeDefaults.cardRaised)
              .withValues(alpha: 0.94)
        : (artworkTheme != null
              ? artworkTheme.cardRaised.withValues(alpha: 0.78)
              : Colors.white.withValues(alpha: 0.045));
    final borderC = showInsightBannerRow
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.1);
    final insightColor =
        artworkTheme?.insightAccent ?? EpisodeChromeDefaults.insightHighlight;
    final railAccent = showInsightBannerRow
        ? insightColor
        : (artworkTheme?.accent ?? _kSummaryCyan);
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: showInsightBannerRow ? 14 : 20,
            sigmaY: showInsightBannerRow ? 14 : 20,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(Tokens.radiusLg),
              border: Border.all(color: borderC),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: railAccent,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(Tokens.radiusLg),
                        bottomLeft: Radius.circular(Tokens.radiusLg),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 12, 44),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showInsightBannerRow) ...[
                                Row(
                                  children: [
                                    Icon(
                                      Icons.show_chart_rounded,
                                      size: 16,
                                      color: insightColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'INSIGHT',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.1,
                                        color: insightColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ],
                              if (timestampAt != null &&
                                  timestampAt!.isNotEmpty) ...[
                                if (SessionDisplayKind.isChapterBased(
                                  listenSession,
                                ))
                                  _EpisodeTimestampPill(at: timestampAt!)
                                else
                                  _TappableEpisodeTimestampPill(
                                    at: timestampAt!,
                                    session: listenSession,
                                  ),
                                const SizedBox(height: 10),
                              ],
                              child,
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            icon: Icon(
                              Icons.north_east_rounded,
                              size: 18,
                              color:
                                  artworkTheme?.meta.withValues(alpha: 0.9) ??
                                  Colors.white.withValues(alpha: 0.45),
                            ),
                            onPressed: onShare,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MagazineQuoteCard extends StatelessWidget {
  const _MagazineQuoteCard({
    required this.text,
    required this.accent,
    required this.session,
  });

  final String text;
  final Color accent;
  final ListeningSession session;

  @override
  Widget build(BuildContext context) {
    final parts = _splitEpisodeTimestamp(text);
    final body = parts.body;
    final heardAt = parts.at;
    final art = EpisodeArtworkThemeScope.maybeOf(context);

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        decoration: BoxDecoration(
          color: art?.cardRaised ?? SummaryThemeColors.bgSurface(context),
          borderRadius: BorderRadius.circular(Tokens.radiusLg),
          border: Border.all(
            color: art != null
                ? Colors.white.withValues(alpha: 0.12)
                : SummaryThemeColors.borderLight(context),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (heardAt != null) ...[
                    _TappableEpisodeTimestampPill(
                      at: heardAt,
                      session: session,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    '"',
                    style: TextStyle(
                      fontSize: 40,
                      height: 0.85,
                      color: accent.withValues(alpha: 0.25),
                      fontFamily: 'Georgia',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 16,
                      height: 1.72,
                      letterSpacing: 0.15,
                      color: SummaryThemeColors.onBody(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    heardAt != null
                        ? 'Heard at $heardAt in this episode'
                        : 'Direct quote',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: art?.meta ?? SummaryThemeColors.textMuted(context),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              right: 2,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(
                  Icons.north_east_rounded,
                  size: 18,
                  color: art?.meta ?? SummaryThemeColors.onBodySoft(context),
                ),
                onPressed: () => _shareInsightCard(context, body),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});
  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final isSummarizing = status == SessionStatus.summarizing;
    final meta = SummaryThemeColors.textMuted(context);
    final body = SummaryThemeColors.onBody(context);
    return Row(
      children: [
        Icon(
          isSummarizing ? Icons.auto_awesome : Icons.hourglass_top_rounded,
          color: meta,
          size: 22,
        ),
        const SizedBox(width: Tokens.spaceSm + 4),
        Expanded(
          child: Text(
            isSummarizing
                ? 'Summarizing your podcast moment...'
                : 'Queued — will start summarizing shortly',
            style: TextStyle(color: body, fontSize: 16),
          ),
        ),
      ],
    );
  }
}

class _TagsRow extends ConsumerWidget {
  const _TagsRow({required this.session});

  final ListeningSession session;

  static Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    ListeningSession session,
  ) async {
    final controller = TextEditingController(text: session.tags ?? '');
    final sheetArt = EpisodeArtworkThemeScope.maybeOf(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          sheetArt?.cardRaised ?? SummaryThemeColors.bgElevated(context),
      isScrollControlled: true,
      builder: (ctx) {
        final onBody = SummaryThemeColors.onBody(ctx);
        final onSoft = SummaryThemeColors.onBodySoft(ctx);
        final accent = sheetArt?.accent;
        Widget sheetBody = Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tags',
                style: TextStyle(
                  color: sheetArt?.meta ?? onBody,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Comma-separated (e.g. work, ideas, health)',
                style: TextStyle(color: sheetArt?.meta ?? onSoft, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: TextStyle(color: onBody),
                decoration: InputDecoration(
                  hintText: 'work, ideas',
                  hintStyle: TextStyle(color: onSoft.withValues(alpha: 0.65)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color:
                          accent?.withValues(alpha: 0.28) ??
                          SummaryThemeColors.borderLight(ctx),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color:
                          accent?.withValues(alpha: 0.28) ??
                          SummaryThemeColors.borderLight(ctx),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: accent ?? Theme.of(ctx).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: accent != null
                    ? FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: _kSummaryOnWhiteFg,
                      )
                    : null,
                onPressed: () async {
                  final v = controller.text.trim();
                  await ref
                      .read(sessionActionsProvider)
                      .updateSessionTags(session.id, v.isEmpty ? null : v);
                  ref.invalidate(sessionByIdProvider(session.id));
                  ref.invalidate(allSessionsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
        if (sheetArt != null) {
          sheetBody = EpisodeArtworkThemeScope(
            theme: sheetArt,
            child: sheetBody,
          );
        }
        return sheetBody;
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final art = EpisodeArtworkThemeScope.maybeOf(context);
    final raw = session.tags?.trim();
    final parts = raw == null || raw.isEmpty
        ? <String>[]
        : raw
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'TAGS',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: art?.meta ?? SummaryThemeColors.textMuted(context),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _edit(context, ref, session),
              style: art != null
                  ? TextButton.styleFrom(foregroundColor: art.accent)
                  : null,
              child: const Text('Edit'),
            ),
          ],
        ),
        if (parts.isEmpty)
          Text(
            'Add tags to organize in your library.',
            style: TextStyle(
              fontSize: 12,
              color: art?.meta ?? SummaryThemeColors.onBodySoft(context),
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: parts
                .map(
                  (t) => art != null
                      ? Chip(
                          label: Text(
                            t,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: art.chipFill,
                          side: BorderSide(
                            color: art.accent.withValues(alpha: 0.38),
                          ),
                        )
                      : Chip(
                          label: Text(t),
                          visualDensity: VisualDensity.compact,
                          labelStyle: const TextStyle(fontSize: 12),
                        ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.spaceLg),
      padding: const EdgeInsets.all(Tokens.spaceMd),
      decoration: BoxDecoration(
        color: Tokens.errorDim,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.spaceSm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeTimelineSection extends ConsumerStatefulWidget {
  const _EpisodeTimelineSection({required this.session});

  final ListeningSession session;

  @override
  ConsumerState<_EpisodeTimelineSection> createState() =>
      _EpisodeTimelineSectionState();
}

class _EpisodeTimelineSectionState
    extends ConsumerState<_EpisodeTimelineSection> {
  late double _rangeStart;
  late double _rangeEnd;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _rangeStart = s.startTimeSec.toDouble();
    final absMax = ((s.startTimeSec + _windowPad).toDouble())
        .clamp(120.0, 1e7)
        .toDouble();
    _rangeEnd = ((s.endTimeSec ?? (s.startTimeSec + 900)).toDouble())
        .clamp(_rangeStart + 60, absMax)
        .toDouble();
  }

  @override
  void didUpdateWidget(covariant _EpisodeTimelineSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.id != widget.session.id) {
      final s = widget.session;
      _rangeStart = s.startTimeSec.toDouble();
      final absMax = ((s.startTimeSec + _windowPad).toDouble())
          .clamp(120.0, 1e7)
          .toDouble();
      _rangeEnd = ((s.endTimeSec ?? (s.startTimeSec + 900)).toDouble())
          .clamp(_rangeStart + 60, absMax)
          .toDouble();
    }
  }

  static const double _windowPad = 7200;

  String _fmt(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final absMin = 0.0;
    final absMax = ((widget.session.startTimeSec + _windowPad).toDouble())
        .clamp(120.0, 1e7)
        .toDouble();
    final endMin = (_rangeStart + 60).clamp(absMin + 60, absMax).toDouble();
    final startMax = (_rangeEnd - 60).clamp(absMin, absMax - 60).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Start: ${_fmt(_rangeStart.round())}',
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'monospace',
            fontSize: 13,
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white70,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: Colors.white24,
          ),
          child: Slider(
            value: _rangeStart.clamp(
              absMin,
              startMax <= absMin ? absMin : startMax,
            ),
            min: absMin,
            max: startMax <= absMin ? absMin + 1 : startMax,
            onChanged: (v) => setState(() {
              _rangeStart = v;
              if (_rangeEnd <= _rangeStart + 60) {
                _rangeEnd = (_rangeStart + 60).clamp(endMin, absMax).toDouble();
              }
            }),
          ),
        ),
        Text(
          'End: ${_fmt(_rangeEnd.round())}',
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'monospace',
            fontSize: 13,
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.cyanAccent.withValues(alpha: 0.5),
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.cyanAccent,
            overlayColor: Colors.cyanAccent.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: _rangeEnd.clamp(endMin, absMax),
            min: endMin,
            max: absMax,
            onChanged: (v) => setState(() => _rangeEnd = v),
          ),
        ),
        const SizedBox(height: Tokens.spaceSm),
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
          ),
          onPressed: () async {
            higLightTap();
            final startR = _rangeStart.round();
            final endR = _rangeEnd.round();
            final dao = ref.read(sessionDaoProvider);
            await dao.requeueWithTimeRange(
              widget.session.id,
              startTimeSec: startR,
              endTimeSec: endR,
              rangeLabel: '${_fmt(startR)} – ${_fmt(endR)}',
            );
            final st = SummaryStyle.fromJson(widget.session.summaryStyle);
            await ref
                .read(sessionActionsProvider)
                .retrySummary(widget.session.id, style: st);
            ref.invalidate(sessionByIdProvider(widget.session.id));
            ref.invalidate(allSessionsProvider);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Re-summarizing the selected range…'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: const Text('Re-summarize this range'),
        ),
      ],
    );
  }
}

class _SummaryLayoutSkeleton extends StatelessWidget {
  const _SummaryLayoutSkeleton();

  @override
  Widget build(BuildContext context) {
    const base = Color(0xFF1A1A2E);
    return ShimmerPlaceholder(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(Tokens.radiusMd),
            ),
          ),
          const SizedBox(height: Tokens.spaceLg),
          Container(
            height: 20,
            width: MediaQuery.sizeOf(context).width * 0.6,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 14,
            width: MediaQuery.sizeOf(context).width * 0.4,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: Tokens.spaceLg),
          ...List.generate(3, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: MediaQuery.sizeOf(context).width * 0.9,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    width:
                        MediaQuery.sizeOf(context).width * (i == 0 ? 0.7 : 0.5),
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class ShimmerPlaceholder extends StatelessWidget {
  const ShimmerPlaceholder({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF2A2A4E), Color(0xFF1A1A2E)],
          stops: [0.0, 0.5, 1],
          begin: Alignment(-1, 0),
          end: Alignment(1, 0),
        ).createShader(bounds);
      },
      child: child,
    );
  }
}
