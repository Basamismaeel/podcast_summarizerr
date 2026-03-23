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

import '../../core/haptics.dart';
import '../../core/moments_stats_service.dart';
import '../../core/summary_export.dart';
import '../../core/tokens.dart';
import '../../database/database.dart';
import '../../models/summary_style.dart';
import '../../providers/session_provider.dart';
import '../../services/podcast_player_links.dart';
import '../../widgets/confirm_delete_session_sheet.dart';
import '../../widgets/liquid_loader.dart';
import '../../widgets/typewrite_text.dart';
import 'widgets/share_card_generator.dart';

final _kBulletTsRe =
    RegExp(r'^\[(\d{1,4}:\d{2}(?::\d{2})?)\]\s*');

/// Leading `[MM:SS]` / `[H:MM:SS]` from pipeline (episode position).
({String? at, String body}) _splitEpisodeTimestamp(String raw) {
  final t = raw.trimLeft();
  final m = _kBulletTsRe.firstMatch(t);
  if (m == null) return (at: null, body: t);
  return (at: m.group(1), body: t.substring(m.end).trimLeft());
}

/// Small pill: “seek to this moment” cue next to summary text.
class _EpisodeTimestampPill extends StatelessWidget {
  const _EpisodeTimestampPill({required this.at});

  /// Display form (same as transcript markers).
  final String at;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Episode timestamp $at',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule,
              size: 14,
              color: Colors.white.withValues(alpha: 0.88),
            ),
            const SizedBox(width: 6),
            Text(
              at,
              style: GoogleFonts.dmMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.92),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
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

/// User-facing explanation of which audio window the summary reflects.
String _summaryTrustLine(ListeningSession s) {
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
String? _listenUrlForPlayer(ListeningSession s) {
  final a = s.sourceShareUrl?.trim();
  if (a != null && a.isNotEmpty) return a;
  final b = s.episodeUrl?.trim();
  if (b != null && b.isNotEmpty) return b;
  return null;
}

TextStyle _summaryBulletStyle(int index) {
  if (index <= 1) {
    return const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.white,
      height: 1.65,
    );
  }
  if (index == 2) {
    return TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: Colors.white.withValues(alpha: 0.9),
      height: 1.65,
    );
  }
  return TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Colors.white.withValues(alpha: 0.8),
    height: 1.65,
  );
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
  final TextEditingController _askController = TextEditingController();
  OverlayEntry? _firstSummaryOverlay;
  bool _quotesUnlocked = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      ref.invalidate(sessionByIdProvider(widget.sessionId));
    });
    _liquidProgress = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _liquidProgress.dispose();
    _confetti.dispose();
    _askController.dispose();
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

  Future<void> _sharePlainText(ListeningSession session, List<String> bullets) async {
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

  Future<void> _shareAsImage(ListeningSession session, List<String> bullets) async {
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
      final boundary = key.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      if (!mounted) return;
      final bytes =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null || !mounted) return;
      final dir = await getTemporaryDirectory();
      if (!mounted) return;
      final file =
          File('${dir.path}/moment-${session.id.substring(0, 8)}.png');
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
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: child,
            ),
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
                  const Text('🎉 Your first summary!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      )),
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
      loading: () => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(title: const Text('Summary')),
        body: const Padding(
          padding: EdgeInsets.all(Tokens.spaceMd),
          child: _SummaryLayoutSkeleton(),
        ),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (session) {
        if (session == null) {
          return const Scaffold(body: Center(child: Text('Session not found')));
        }

        final status = SessionStatus.fromJson(session.status);
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

        final combined = bullets.join(' ');
        final wc = combined.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        final readMin = (wc / 200).ceil().clamp(1, 999);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: Tokens.bgPrimary,
            body: Stack(
              children: [
                CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
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
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      title: Text(
                        'Summary',
                        style: GoogleFonts.syne(
                          color: Colors.white,
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
                                color: Colors.black.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.ios_share,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            onSelected: (v) {
                              switch (v) {
                                case 'text':
                                  unawaited(_sharePlainText(session, bullets));
                                  break;
                                case 'md':
                                  unawaited(_shareMarkdownFile(
                                      session, bullets, quotes));
                                  break;
                                case 'copy':
                                  unawaited(
                                      _copyMarkdown(session, bullets, quotes));
                                  break;
                                case 'img':
                                  unawaited(_shareAsImage(session, bullets));
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
                              color: Colors.black.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: _CinematicHero(session: session),
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
                                          accentColor: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                      const SizedBox(height: Tokens.spaceLg),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(
                                            Tokens.radiusMd,
                                          ),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.1),
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
                                message: session.errorMessage ??
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
                                16,
                                16,
                                16,
                                0,
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  if (style != null)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Tokens.accentDim,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Tokens.accentBorder,
                                          ),
                                        ),
                                        child: Text(
                                          '${style.icon}  ${style.label}'
                                              .toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Tokens.accent,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (style != null)
                                    const SizedBox(height: Tokens.spaceSm),
                                  Text(
                                    _summaryTrustLine(session),
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: Colors.white.withValues(alpha: 0.62),
                                    ),
                                  ),
                                  const SizedBox(height: Tokens.spaceSm),
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
                                            color: Colors.amber
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: Colors.amber
                                                  .withValues(alpha: 0.35),
                                            ),
                                          ),
                                          child: const Text(
                                            'Timestamps may be approximate (plain transcript)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (PodcastPlayerLinks.looksLikeSpotify(
                                          _listenUrlForPlayer(session)))
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            unawaited(
                                              PodcastPlayerLinks.openSpotifyAt(
                                                _listenUrlForPlayer(session),
                                                session.startTimeSec,
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.open_in_new,
                                              size: 16, color: Colors.white70),
                                          label: const Text(
                                            'Open in Spotify',
                                            style:
                                                TextStyle(color: Colors.white70),
                                          ),
                                        ),
                                      if (PodcastPlayerLinks.looksLikeApplePodcasts(
                                          _listenUrlForPlayer(session)))
                                        OutlinedButton.icon(
                                          onPressed: () async {
                                            higLightTap();
                                            final ok =
                                                await PodcastPlayerLinks
                                                    .openApplePodcasts(
                                              _listenUrlForPlayer(session),
                                            );
                                            if (!context.mounted) return;
                                            if (!ok) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Could not open Podcasts. '
                                                    'Install the Apple Podcasts app, or open the link in Safari.',
                                                  ),
                                                  behavior: SnackBarBehavior
                                                      .floating,
                                                ),
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.podcasts,
                                              size: 16, color: Colors.white70),
                                          label: const Text(
                                            'Open in Apple Podcasts',
                                            style:
                                                TextStyle(color: Colors.white70),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (!PodcastPlayerLinks.looksLikeSpotify(
                                          _listenUrlForPlayer(session)) &&
                                      !PodcastPlayerLinks.looksLikeApplePodcasts(
                                          _listenUrlForPlayer(session)))
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        'Open in Spotify / Apple Podcasts appears when you save using a podcast link from Home, or when we can derive a show link.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          height: 1.35,
                                          color: Colors.white
                                              .withValues(alpha: 0.45),
                                        ),
                                      ),
                                    ),
                                  if (style != null) ...[
                                    const SizedBox(height: Tokens.spaceSm),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: () async {
                                          higLightTap();
                                          await ref
                                              .read(sessionActionsProvider)
                                              .rememberSummaryStyleForShow(
                                                session.artist,
                                                style,
                                              );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Future saves from “${session.artist}” will use ${style.label}.',
                                                ),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.bookmark_added_outlined,
                                          size: 18,
                                          color: Colors.white70,
                                        ),
                                        label: Text(
                                          'Always use ${style.label} for this show',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  _TagsRow(session: session),
                                  const SizedBox(height: Tokens.spaceSm),
                                  _TypingOrInstantBullets(
                                    sessionId: session.id,
                                    bullets: bullets,
                                    accent: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    onAllBulletsComplete: () {
                                      if (mounted) {
                                        setState(
                                          () => _quotesUnlocked = true,
                                        );
                                      }
                                    },
                                  ),
                                  if (quotes.isNotEmpty && _quotesUnlocked) ...[
                                    const SizedBox(height: Tokens.spaceLg),
                                    Text(
                                      'KEY QUOTES',
                                      style: TextStyle(
                                        fontSize: 11,
                                        letterSpacing: 1.2,
                                        fontWeight: FontWeight.w600,
                                        color: Tokens.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: Tokens.spaceSm),
                                    ...quotes.map(
                                      (q) => TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 0, end: 1),
                                        duration: const Duration(
                                          milliseconds: 450,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        builder: (context, t, child) =>
                                            Opacity(
                                          opacity: t,
                                          child: Transform.translate(
                                            offset: Offset(0, 8 * (1 - t)),
                                            child: child,
                                          ),
                                        ),
                                        child: _MagazineQuoteCard(
                                          text: q,
                                          accent: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: Tokens.spaceSm),
                                  Text(
                                    '$wc words · ~$readMin min read',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Tokens.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (status == SessionStatus.done &&
                              bullets.isEmpty)
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
                              child: Text(
                                'No summary content available.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'JUMP & SUMMARIZE',
                                style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w600,
                                  color: Tokens.textMuted,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _EpisodeTimelineSection(session: session),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'WHAT ELSE DO YOU WANT TO KNOW?',
                                style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w600,
                                  color: Tokens.textMuted,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Tokens.bgElevated,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Tokens.borderLight),
                            ),
                            child: TextField(
                              controller: _askController,
                              style: const TextStyle(color: Colors.white),
                              cursorColor: Colors.white,
                              decoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.auto_awesome,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  size: 22,
                                ),
                                hintText: 'Ask the episode…',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                                border: InputBorder.none,
                                filled: false,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 14,
                                ),
                              ),
                              onSubmitted: (q) {
                                if (q.trim().isEmpty) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '“$q” — deeper Q&A is coming soon.',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(
                            height: MediaQuery.paddingOf(context).bottom + 32,
                          ),
                        ],
                      ),
                    ),
                  ],
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

/// Full-bleed ~320px cinema hero: blurred artwork, palette tint, cover, title stack.
class _CinematicHero extends StatefulWidget {
  const _CinematicHero({required this.session});

  final ListeningSession session;

  @override
  State<_CinematicHero> createState() => _CinematicHeroState();
}

class _CinematicHeroState extends State<_CinematicHero> {
  Color? _tint;

  static const double _heroHeight = 320;

  @override
  void initState() {
    super.initState();
    unawaited(_extractPalette());
  }

  @override
  void didUpdateWidget(covariant _CinematicHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.id != widget.session.id ||
        oldWidget.session.artworkUrl != widget.session.artworkUrl) {
      unawaited(_extractPalette());
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
      final gen =
          await PaletteGenerator.fromImageProvider(NetworkImage(raw));
      final c = gen.darkVibrantColor?.color ??
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
    final hasUrl = raw != null &&
        raw.isNotEmpty &&
        (raw.startsWith('http://') || raw.startsWith('https://'));

    final showTimePill =
        session.startTimeSec > 0 || session.endTimeSec != null;

    final letter = session.artist.trim().isNotEmpty
        ? session.artist.trim()[0].toUpperCase()
        : '?';

    final blurredLayer = hasUrl
        ? ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: _heroHeight,
              color: Colors.black.withValues(alpha: 0.35),
              colorBlendMode: BlendMode.darken,
              placeholder: (context, _) => Container(
                color: Tokens.bgSurface,
              ),
              errorWidget: (context, url, err) => Container(
                color: Tokens.bgSurface,
              ),
            ),
          )
        : Container(
            width: double.infinity,
            height: _heroHeight,
            color: Tokens.bgSurface,
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
              color: _tint != null
                  ? _tint!.withValues(alpha: 0.15)
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
                    Tokens.bgPrimary.withValues(alpha: 0.7),
                    Tokens.bgPrimary,
                  ],
                ),
              ),
            ),
          ),
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
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
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
                          placeholder: (context, _) => Container(
                            color: Tokens.bgElevated,
                            alignment: Alignment.center,
                            child: Text(
                              letter,
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Tokens.textMuted,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, err) => Container(
                            color: Tokens.bgElevated,
                            alignment: Alignment.center,
                            child: Text(
                              letter,
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Tokens.textMuted,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: Tokens.bgElevated,
                          alignment: Alignment.center,
                          child: Text(
                            letter,
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Tokens.textMuted,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
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
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
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
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                if (showTimePill)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _summaryDurationLabel(session),
                      style: GoogleFonts.dmMono(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
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

/// Typewriter bullets only the first time this summary is viewed; then instant.
class _TypingOrInstantBullets extends StatefulWidget {
  const _TypingOrInstantBullets({
    required this.sessionId,
    required this.bullets,
    required this.accent,
    required this.onAllBulletsComplete,
  });

  final String sessionId;
  final List<String> bullets;
  final Color accent;
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
    _playedFuture =
        MomentsStatsService.hasSummaryTypewriterPlayed(widget.sessionId);
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
              instantChildren.add(const SizedBox(height: Tokens.spaceSm));
            }
            final parts = _splitEpisodeTimestamp(widget.bullets[j]);
            instantChildren.add(
              _GlassBulletCard(
                index: j + 1,
                accent: widget.accent,
                timestampAt: parts.at,
                child: Text(
                  parts.body,
                  style: _summaryBulletStyle(j + 1),
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: instantChildren,
          );
        }

        return _SequentialTypeBullets(
          bullets: widget.bullets,
          accent: widget.accent,
          onAllBulletsComplete: () {
            MomentsStatsService.markSummaryTypewriterPlayed(widget.sessionId)
                .then((_) {
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
    this.onAllBulletsComplete,
  });

  final List<String> bullets;
  final Color accent;
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
        children.add(const SizedBox(height: Tokens.spaceSm));
      }
      final parts = _splitEpisodeTimestamp(widget.bullets[j]);
      children.add(
        _GlassBulletCard(
          index: j + 1,
          accent: widget.accent,
          timestampAt: parts.at,
          child: Text(
            parts.body,
            style: _summaryBulletStyle(j + 1),
          ),
        ),
      );
    }
    if (_completed < widget.bullets.length) {
      if (_completed > 0) {
        children.add(const SizedBox(height: Tokens.spaceSm));
      }
      final cur = _splitEpisodeTimestamp(widget.bullets[_completed]);
      children.add(
        _GlassBulletCard(
          index: _completed + 1,
          accent: widget.accent,
          timestampAt: cur.at,
          child: TypewriteText(
            key: ValueKey('tw-$_completed-${widget.bullets[_completed]}'),
            text: cur.body,
            charsPerSecond: 30,
            style: _summaryBulletStyle(_completed + 1),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _GlassBulletCard extends StatelessWidget {
  const _GlassBulletCard({
    required this.index,
    required this.accent,
    required this.child,
    this.timestampAt,
  });

  final int index;
  final Color accent;
  final Widget child;

  /// Episode clock for this bullet (shown above [child], next to the text block).
  final String? timestampAt;

  double get _circle {
    if (index <= 1) return 24;
    if (index == 2) return 20;
    return 18;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(Tokens.spaceSm + 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: _circle,
                height: _circle,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: _circle < 22 ? 11 : 12,
                  ),
                ),
              ),
              const SizedBox(width: Tokens.spaceSm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (timestampAt != null && timestampAt!.isNotEmpty) ...[
                      _EpisodeTimestampPill(at: timestampAt!),
                      const SizedBox(height: 8),
                    ],
                    child,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MagazineQuoteCard extends StatelessWidget {
  const _MagazineQuoteCard({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final parts = _splitEpisodeTimestamp(text);
    final body = parts.body;
    final heardAt = parts.at;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Tokens.bgSurface,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (heardAt != null) ...[
            _EpisodeTimestampPill(at: heardAt),
            const SizedBox(height: 10),
          ],
          Text(
            '"',
            style: TextStyle(
              fontSize: 48,
              height: 0.8,
              color: accent.withValues(alpha: 0.3),
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 15,
              height: 1.7,
              letterSpacing: 0.2,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            heardAt != null
                ? 'Heard at $heardAt in this episode'
                : '— direct quote',
            style: TextStyle(
              fontSize: 11,
              color: Tokens.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
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
    return Row(
      children: [
        Icon(
          isSummarizing ? Icons.auto_awesome : Icons.hourglass_top_rounded,
          color: Colors.white70,
          size: 22,
        ),
        const SizedBox(width: Tokens.spaceSm + 4),
        Expanded(
          child: Text(
            isSummarizing
                ? 'Summarizing your podcast moment...'
                : 'Queued — will start summarizing shortly',
            style: const TextStyle(color: Colors.white, fontSize: 16),
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
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Tokens.bgElevated,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
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
              const Text(
                'Tags',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Comma-separated (e.g. work, ideas, health)',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'work, ideas',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final v = controller.text.trim();
                  await ref.read(sessionActionsProvider).updateSessionTags(
                        session.id,
                        v.isEmpty ? null : v,
                      );
                  ref.invalidate(sessionByIdProvider(session.id));
                  ref.invalidate(allSessionsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                color: Tokens.textMuted,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _edit(context, ref, session),
              child: const Text('Edit'),
            ),
          ],
        ),
        if (parts.isEmpty)
          Text(
            'Add tags to organize in your library.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: parts
                .map(
                  (t) => Chip(
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
        border: Border.all(
          color: Tokens.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.white70, size: 20),
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

class _EpisodeTimelineSectionState extends ConsumerState<_EpisodeTimelineSection> {
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
            value: _rangeStart.clamp(absMin, startMax <= absMin ? absMin : startMax),
            min: absMin,
            max: startMax <= absMin ? absMin + 1 : startMax,
            onChanged: (v) => setState(() {
              _rangeStart = v;
              if (_rangeEnd <= _rangeStart + 60) {
                _rangeEnd =
                    (_rangeStart + 60).clamp(endMin, absMax).toDouble();
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
            await ref.read(sessionActionsProvider).retrySummary(
                  widget.session.id,
                  style: st,
                );
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
                    width: MediaQuery.sizeOf(context).width * (i == 0 ? 0.7 : 0.5),
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
