import 'dart:async';
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/haptics.dart';
import '../../core/podcast_home_colors.dart';
import '../../core/podcast_dark_tokens.dart';
import '../../core/tokens.dart';
import '../../debug/agent_ndjson_log.dart';
import '../../database/database.dart';
import '../../models/summary_style.dart';
import '../../providers/session_provider.dart';
import '../../services/clipboard_podcast_service.dart';
import '../../services/notification_service.dart';
import '../../services/now_playing_banner_coordinator.dart';
import '../../services/now_playing_service.dart';
import '../../services/siri_service.dart';
import '../../widgets/confirm_delete_session_sheet.dart';
import '../../widgets/psn_bottom_sheet.dart';
import '../../widgets/psn_button.dart';
import '../../widgets/smart_home_empty_state.dart';
import 'widgets/podcast_artwork.dart';
import 'widgets/recording_indicator.dart';
import 'widgets/session_card.dart';

const _kEdgePadding = Tokens.spaceMd;
const _kCardSpacing = 4.0;

/// Wall-clock position inside an episode (not time of day).
String _formatEpisodePosition(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
  return '$m:${sec.toString().padLeft(2, '0')}';
}

String _humanClipDuration(int start, int end) {
  final d = end - start;
  if (d <= 0) return '—';
  if (d < 60) return '$d sec';
  final h = d ~/ 3600;
  final m = (d % 3600) ~/ 60;
  final s = d % 60;
  if (h > 0) {
    if (m == 0 && s == 0) return '${h}h';
    if (s == 0) return '${h}h ${m}m';
    return '${h}h ${m}m ${s}s';
  }
  if (m > 0 && s == 0) return m == 1 ? '1 min' : '$m min';
  if (m > 0) return '$m min $s sec';
  return '$s sec';
}

/// Parses typed episode positions: `42` (seconds), `5:30`, `1:05:30`.
int? _parseEpisodePositionInput(String raw) {
  final t = raw.trim().replaceAll(RegExp(r'\s+'), '');
  if (t.isEmpty) return null;
  final parts = t.split(':');
  if (parts.length == 1) {
    final n = int.tryParse(parts[0]);
    if (n == null || n < 0) return null;
    return n;
  }
  if (parts.length == 2) {
    final m = int.tryParse(parts[0]);
    final s = int.tryParse(parts[1]);
    if (m == null || s == null || m < 0 || s < 0 || s >= 60) return null;
    return m * 60 + s;
  }
  if (parts.length == 3) {
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final s = int.tryParse(parts[2]);
    if (h == null || m == null || s == null) return null;
    if (h < 0 || m < 0 || s < 0 || m >= 60 || s >= 60) return null;
    return h * 3600 + m * 60 + s;
  }
  return null;
}

/// Pre-build off-screen rows for smoother fling on long lists.
const _kScrollCacheExtent = 500.0;

enum _MomentFilter { all, inProgress, ready }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  Timer? _bannerPollTimer;
  _MomentFilter _momentFilter = _MomentFilter.all;
  bool _selectionMode = false;
  final Set<String> _selectedSessionIds = {};

  /// Prevents overlapping clipboard imports (resume + post-frame, etc.) from
  /// creating duplicate sessions before [ClipboardPodcastService] marks the URL processed.
  Future<void>? _clipboardImportInFlight;

  Future<void> _ingestSiriPendingSessions() async {
    final pending = await SiriService.getPendingSessions();
    if (!mounted || pending.isEmpty) return;
    final actions = ref.read(sessionActionsProvider);
    for (final m in pending) {
      if (!mounted) return;
      final title = m['title'] as String? ?? 'Unknown Episode';
      final artist = m['artist'] as String? ?? 'Unknown Podcast';
      final position = (m['position'] as num?)?.toInt() ?? 0;
      await actions.createAndSummarize(
        title: title,
        artist: artist,
        saveMethod: SaveMethod.siri,
        startTimeSec: position,
        sourceApp: 'Siri',
      );
      if (mounted) await PSNHaptics.momentSaved();
    }
  }

  Future<void> _checkClipboardForPodcast({bool userInitiated = false}) async {
    if (_clipboardImportInFlight != null) {
      await _clipboardImportInFlight;
      if (!userInitiated) {
        // #region agent log
        agentNdjsonLog(
          hypothesisId: 'H_HOME_SKIP',
          location: 'home_screen.dart:_checkClipboardForPodcast',
          message: 'skipped duplicate clipboard import after await',
          data: const {},
          runId: 'post-dup-fix',
        );
        // #endregion
        return;
      }
    }

    final done = Completer<void>();
    _clipboardImportInFlight = done.future;
    try {
      await _checkClipboardForPodcastImpl(userInitiated: userInitiated);
    } finally {
      if (!done.isCompleted) done.complete();
      _clipboardImportInFlight = null;
    }
  }

  Future<void> _checkClipboardForPodcastImpl({
    bool userInitiated = false,
  }) async {
    // #region agent log
    agentNdjsonLog(
      hypothesisId: 'H_HOME',
      location: 'home_screen.dart:_checkClipboardForPodcastImpl',
      message: 'clipboard check started',
      data: {'userInitiated': userInitiated},
      runId: 'dup-summary',
    );
    // #endregion
    final info = await ClipboardPodcastService.instance.checkClipboard();
    if (info == null || !mounted) {
      if (userInitiated && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No podcast link on the clipboard. In Spotify: Share → Copy link, '
              'then open this app and tap “Paste copied link” here (or ⋯ → Paste copied link).',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    // Unsupported sources — show a message and bail.
    if (!info.supportsPipeline) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Source not supported'),
          content: const Text(
            'This source uses DRM-protected audio that cannot be transcribed.\n\n'
            'If this title is also on Apple Podcasts or Spotify, share that link '
            'instead, or use Manual Entry.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) {
        ClipboardPodcastService.instance.markProcessed(info.sourceUrl);
      }
      return;
    }

    final episodeHint = <String, String>{};
    if (info.itunesEpisodeId != null) {
      episodeHint['itunesEpisodeId'] = info.itunesEpisodeId!;
    }
    if (info.itunesPodcastId != null) {
      episodeHint['itunesPodcastId'] = info.itunesPodcastId!;
    }
    if (info.spotifyEpisodeId != null) {
      episodeHint['spotifyEpisodeId'] = info.spotifyEpisodeId!;
    }
    if (info.source == 'gutenberg') {
      episodeHint['gutenbergTextUrl'] = info.sourceUrl;
    }

    /// Audible / Gutenberg: chapter-based summaries — no wall-clock range sheet.
    final skipRangeSheet =
        info.source == 'audible' || info.source == 'gutenberg';

    if (skipRangeSheet && mounted) {
      final actions = ref.read(sessionActionsProvider);
      // #region agent log
      agentNdjsonLog(
        hypothesisId: 'H_HOME',
        location: 'home_screen.dart:_checkClipboardForPodcastImpl',
        message: 'createAndSummarize skipRangeSheet branch',
        data: {'source': info.source, 'shareUrlLen': info.sourceUrl.length},
        runId: 'dup-summary',
      );
      // #endregion
      await actions.createAndSummarize(
        title: info.episodeTitle,
        artist: info.podcastName.isNotEmpty ? info.podcastName : 'Audible',
        saveMethod: SaveMethod.notification,
        startTimeSec: 0,
        endTimeSec: null,
        rangeLabel: null,
        sourceApp: info.source,
        sourceShareUrl: info.sourceUrl,
        episodeHint: episodeHint.isEmpty ? null : episodeHint,
        artworkUrl: info.artworkUrl,
      );
      if (mounted) await PSNHaptics.momentSaved();
      if (mounted) {
        final kind = info.source == 'gutenberg' ? 'E-book' : 'Audiobook';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved “${info.episodeTitle}” ($kind — pick a chapter on the summary).',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final range = await _showClipboardRangePrompt(info);
    if (range != null && mounted) {
      final actions = ref.read(sessionActionsProvider);
      await actions.createAndSummarize(
        title: info.episodeTitle,
        artist: info.podcastName.isNotEmpty
            ? info.podcastName
            : (info.source == 'spotify' ? 'Spotify' : info.podcastName),
        saveMethod: SaveMethod.notification,
        startTimeSec: range.start,
        endTimeSec: range.end,
        rangeLabel:
            '${_formatEpisodePosition(range.start)} – ${_formatEpisodePosition(range.end)}',
        sourceApp: info.source,
        sourceShareUrl: info.sourceUrl,
        episodeHint: episodeHint.isEmpty ? null : episodeHint,
        artworkUrl: info.artworkUrl,
      );
      if (mounted) await PSNHaptics.momentSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved "${info.episodeTitle}" (${_formatEpisodePosition(range.start)} – ${_formatEpisodePosition(range.end)})',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      ClipboardPodcastService.instance.markProcessed(info.sourceUrl);
    }
  }

  Future<({int start, int end})?> _showClipboardRangePrompt(
    ClipboardPodcastInfo info,
  ) {
    return showModalBottomSheet<({int start, int end})?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: PSNBottomSheet(
            title: null,
            maxHeightFraction: 0.78,
            child: _ClipboardRangeSheetBody(info: info),
          ),
        );
      },
    );
  }

  Future<void> _fetchAndShowNowPlayingBanner() async {
    final info = await NowPlayingService.instance.getCurrentNowPlaying();
    if (info != null) {
      await NotificationService.instance.showNowPlayingBanner(
        info.title,
        info.artist,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NowPlayingBannerCoordinator.instance.startIfEnabled();

    unawaited(_fetchAndShowNowPlayingBanner());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_ingestSiriPendingSessions());
      if (mounted) unawaited(_checkClipboardForPodcast());
    });

    _bannerPollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final info = await NowPlayingService.instance.getCurrentNowPlaying();
      if (info != null) {
        await NotificationService.instance.updateBanner(
          info.title,
          info.artist,
        );
      }
    });

    Future.delayed(const Duration(seconds: 2), () async {
      await NotificationService.instance.requestPermission();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerPollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      unawaited(_ingestSiriPendingSessions());
      unawaited(_checkClipboardForPodcast());
    }
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedSessionIds.clear();
    });
  }

  void _toggleSessionSelection(String id) {
    setState(() {
      if (_selectedSessionIds.contains(id)) {
        _selectedSessionIds.remove(id);
      } else {
        _selectedSessionIds.add(id);
      }
    });
  }

  Future<void> _deleteSelectedSessions(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final n = _selectedSessionIds.length;
    if (n == 0) return;
    higLightTap();
    final ok = await showConfirmDeleteMultipleSessionsSheet(context, count: n);
    if (ok != true || !context.mounted) return;
    await PSNHaptics.delete();
    final ids = List<String>.from(_selectedSessionIds);
    final dao = ref.read(sessionDaoProvider);
    for (final id in ids) {
      await dao.deleteSession(id);
    }
    _exitSelectionMode();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(n == 1 ? 'Deleted 1 moment' : 'Deleted $n moments'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _selectAllVisible(List<ListeningSession> sessions) {
    final filtered = _applyMomentFilter(sessions);
    setState(() {
      _selectedSessionIds
        ..clear()
        ..addAll(filtered.map((e) => e.id));
    });
  }

  List<ListeningSession> _applyMomentFilter(List<ListeningSession> sessions) {
    switch (_momentFilter) {
      case _MomentFilter.all:
        return sessions;
      case _MomentFilter.inProgress:
        return sessions.where((s) {
          final st = SessionStatus.fromJson(s.status);
          return st == SessionStatus.queued ||
              st == SessionStatus.summarizing ||
              st == SessionStatus.recording;
        }).toList();
      case _MomentFilter.ready:
        return sessions
            .where(
              (s) => SessionStatus.fromJson(s.status) == SessionStatus.done,
            )
            .toList();
    }
  }

  Widget _podcastDarkShellTheme(BuildContext context, Widget child) {
    final base = Theme.of(context);
    if (base.brightness == Brightness.light) {
      return child;
    }
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: PodcastDarkTokens.bgDeep,
        colorScheme: base.colorScheme.copyWith(
          surface: PodcastDarkTokens.bgDeep,
          onSurface: PodcastHomeColors.title(context),
          onSurfaceVariant: PodcastHomeColors.meta(context),
          primary: PodcastHomeColors.accent(context),
          outline: PodcastHomeColors.borderSubtle(context),
        ),
        textTheme: base.textTheme.apply(
          bodyColor: PodcastHomeColors.label(context),
          displayColor: PodcastHomeColors.title(context),
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(allSessionsProvider);

    return sessionsAsync.when(
      loading: () => _podcastDarkShellTheme(
        context,
        Scaffold(
          backgroundColor: PodcastHomeColors.scaffold(context),
          body: _HomeSkeleton(
            onMorePressed: () => _showHomeActionsMenu(context),
          ),
        ),
      ),
      error: (e, _) => _podcastDarkShellTheme(
        context,
        Scaffold(
          backgroundColor: PodcastHomeColors.scaffold(context),
          body: Center(
            child: Text(
              'Error: $e',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: PodcastHomeColors.meta(context),
              ),
            ),
          ),
        ),
      ),
      data: (sessions) {
        return _podcastDarkShellTheme(
          context,
          Scaffold(
            backgroundColor: PodcastHomeColors.scaffold(context),
            body: Stack(
              children: [
                SafeArea(
                  bottom: false,
                  child: sessions.isEmpty
                      ? CustomScrollView(
                          cacheExtent: _kScrollCacheExtent,
                          slivers: [
                            SliverToBoxAdapter(
                              child: _PodcastHomeHeader(
                                totalCount: 0,
                                onMorePressed: () =>
                                    _showHomeActionsMenu(context),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  _kEdgePadding,
                                  0,
                                  _kEdgePadding,
                                  Tokens.spaceMd,
                                ),
                                child: _PodcastQuickNavGrid(
                                  inProgressCount: 0,
                                  onAddMoment: () => _showFabSheet(context),
                                  onBrowsePodcasts: () =>
                                      context.push('/manual-entry'),
                                  onSearch: () => context.push('/search'),
                                  onInProgress: () => setState(
                                    () => _momentFilter =
                                        _MomentFilter.inProgress,
                                  ),
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  _kEdgePadding,
                                  0,
                                  _kEdgePadding,
                                  Tokens.spaceMd,
                                ),
                                child: _MomentFilterBar(
                                  value: _momentFilter,
                                  onChanged: (v) =>
                                      setState(() => _momentFilter = v),
                                ),
                              ),
                            ),
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: _kEdgePadding,
                                ),
                                child: SmartHomeEmptyStateLoader(
                                  onSeeHowItWorks: () =>
                                      context.push('/onboarding'),
                                ),
                              ),
                            ),
                          ],
                        )
                      : _buildSessionList(context, ref, sessions),
                ),
                if (_selectionMode)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _SelectionBottomBar(
                      selectedCount: _selectedSessionIds.length,
                      onDone: _exitSelectionMode,
                      onSelectAll: () => _selectAllVisible(sessions),
                      onDelete: () => _deleteSelectedSessions(context, ref),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSessionList(
    BuildContext context,
    WidgetRef ref,
    List<ListeningSession> sessions,
  ) {
    final recordingSessions = sessions
        .where(
          (s) => SessionStatus.fromJson(s.status) == SessionStatus.recording,
        )
        .toList();

    final filtered = _applyMomentFilter(sessions);
    final grouped = _groupByDate(filtered);

    final inProgressCount = sessions.where((s) {
      final st = SessionStatus.fromJson(s.status);
      return st == SessionStatus.queued ||
          st == SessionStatus.summarizing ||
          st == SessionStatus.recording;
    }).length;

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: _PodcastHomeHeader(
          totalCount: sessions.length,
          onMorePressed: () => _showHomeActionsMenu(context),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            _kEdgePadding,
            0,
            _kEdgePadding,
            Tokens.spaceMd,
          ),
          child: _PodcastQuickNavGrid(
            inProgressCount: inProgressCount,
            onAddMoment: () => _showFabSheet(context),
            onBrowsePodcasts: () => context.push('/manual-entry'),
            onSearch: () => context.push('/search'),
            onInProgress: () =>
                setState(() => _momentFilter = _MomentFilter.inProgress),
          ),
        ),
      ),
      if (sessions.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: Tokens.spaceMd),
            child: _PodcastCoverStrip(sessions: sessions),
          ),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            _kEdgePadding,
            Tokens.spaceSm,
            _kEdgePadding,
            Tokens.spaceMd,
          ),
          child: _MomentFilterBar(
            value: _momentFilter,
            onChanged: (v) => setState(() => _momentFilter = v),
          ),
        ),
      ),
      if (_selectionMode)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _kEdgePadding,
              0,
              _kEdgePadding,
              Tokens.spaceSm,
            ),
            child: _SelectionHintBanner(),
          ),
        ),
      if (recordingSessions.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _kEdgePadding,
              0,
              _kEdgePadding,
              _kCardSpacing,
            ),
            child: RecordingIndicator(
              session: recordingSessions.first,
              onStop: () {},
            ),
          ),
        ),
    ];

    if (filtered.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(Tokens.spaceLg),
            child: Center(
              child: Text(
                'No moments match this filter.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: PodcastHomeColors.meta(context),
                ),
              ),
            ),
          ),
        ),
      );
      return CustomScrollView(
        cacheExtent: _kScrollCacheExtent,
        slivers: slivers,
      );
    }

    grouped.forEach((section, items) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _kEdgePadding,
              28,
              _kEdgePadding,
              10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    section,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: PodcastHomeColors.label(context),
                      fontSize: 18,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: PodcastHomeColors.meta(context).withValues(alpha: 0.6),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      );
      slivers.add(
        SliverList.separated(
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          itemBuilder: (ctx, index) {
            final session = items[index];
            final card = SessionCard(
              session: session,
              homeRowCompactStyle: true,
              onTap: () => context.push('/summary/${session.id}'),
              onDelete: () =>
                  ref.read(sessionDaoProvider).deleteSession(session.id),
              onSummarizeAgain: () =>
                  ref.read(sessionActionsProvider).retrySummary(session.id),
              onChangeStyle: () {},
              selectionMode: _selectionMode,
              isSelected: _selectedSessionIds.contains(session.id),
              onSelectionToggle: () => _toggleSessionSelection(session.id),
            );
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kEdgePadding),
              child: RepaintBoundary(child: card),
            );
          },
          separatorBuilder: (_, _) => const SizedBox.shrink(),
          itemCount: items.length,
        ),
      );
    });

    slivers.add(
      SliverToBoxAdapter(child: SizedBox(height: _selectionMode ? 88 : 24)),
    );

    return CustomScrollView(cacheExtent: _kScrollCacheExtent, slivers: slivers);
  }

  Future<void> _showFabSheet(BuildContext context) async {
    await PSNBottomSheet.show(
      context: context,
      title: 'Add moment',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PSNButton(
            label: 'Add manually',
            icon: const Icon(Icons.edit_outlined, size: 20),
            fullWidth: true,
            variant: ButtonVariant.secondary,
            onTap: () {
              Navigator.of(context).pop();
              context.push('/manual-entry');
            },
          ),
          const SizedBox(height: Tokens.spaceSm),
          PSNButton(
            label: 'Browse podcasts',
            icon: const Icon(Icons.podcasts_outlined, size: 20),
            fullWidth: true,
            onTap: () {
              Navigator.of(context).pop();
              context.push('/manual-entry');
            },
          ),
        ],
      ),
    );
  }

  /// Apple-style “⋯” menu: add, manual entry, select to delete.
  Future<void> _showHomeActionsMenu(BuildContext context) async {
    higLightTap();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return PSNBottomSheet(
          title: 'More',
          showHandle: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: Icon(
                  Icons.add_circle_outline_rounded,
                  color: cs.primary,
                ),
                title: const Text('Add moment'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showFabSheet(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.edit_note_rounded, color: cs.primary),
                title: const Text('Manual entry'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.push('/manual-entry');
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.content_paste_go_rounded,
                  color: cs.primary,
                ),
                title: const Text('Paste copied link'),
                subtitle: const Text(
                  'Spotify / Apple Podcasts URL from clipboard',
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  unawaited(_checkClipboardForPodcast(userInitiated: true));
                },
              ),
              ListTile(
                leading: Icon(
                  _selectionMode
                      ? Icons.check_circle_outline_rounded
                      : Icons.checklist_rounded,
                  color: _selectionMode ? cs.error : cs.primary,
                ),
                title: Text(
                  _selectionMode ? 'Done selecting' : 'Select to delete',
                  style: tt.bodyLarge?.copyWith(
                    color: _selectionMode ? cs.error : cs.onSurface,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    if (_selectionMode) {
                      _selectionMode = false;
                      _selectedSessionIds.clear();
                    } else {
                      _selectionMode = true;
                    }
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PodcastHomeHeader extends StatelessWidget {
  const _PodcastHomeHeader({
    required this.totalCount,
    required this.onMorePressed,
  });

  final int totalCount;
  final VoidCallback onMorePressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _kEdgePadding,
        MediaQuery.paddingOf(context).top > 0 ? 8 : 16,
        _kEdgePadding,
        4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Home',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 34,
                    height: 1.05,
                    color: PodcastHomeColors.title(context),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  higLightTap();
                  context.push('/search');
                },
                icon: const Icon(Icons.search_rounded),
                tooltip: 'Search',
                style: IconButton.styleFrom(
                  foregroundColor: PodcastHomeColors.label(context),
                  minimumSize: const Size(Tokens.minTap, Tokens.minTap),
                ),
              ),
              const _CreditsChip(useDarkCreditsStyle: true),
              IconButton(
                onPressed: () {
                  higLightTap();
                  context.go('/settings');
                },
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                style: IconButton.styleFrom(
                  foregroundColor: PodcastHomeColors.label(context),
                  minimumSize: const Size(Tokens.minTap, Tokens.minTap),
                ),
              ),
              IconButton(
                onPressed: () {
                  higLightTap();
                  onMorePressed();
                },
                icon: const Icon(Icons.more_horiz_rounded),
                tooltip: 'More',
                style: IconButton.styleFrom(
                  foregroundColor: PodcastHomeColors.label(context),
                  minimumSize: const Size(Tokens.minTap, Tokens.minTap),
                ),
              ),
            ],
          ),
          if (totalCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Your library has $totalCount moments',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: PodcastHomeColors.meta(context),
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _PodcastQuickNavGrid extends StatelessWidget {
  const _PodcastQuickNavGrid({
    required this.inProgressCount,
    required this.onAddMoment,
    required this.onBrowsePodcasts,
    required this.onSearch,
    required this.onInProgress,
  });

  final int inProgressCount;
  final VoidCallback onAddMoment;
  final VoidCallback onBrowsePodcasts;
  final VoidCallback onSearch;
  final VoidCallback onInProgress;

  /// Tight rows; tall enough for 13px icon + 10px text without overflow.
  static const double _rowH = 34;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _quickNavCard(
                context,
                icon: Icons.add_circle_outline_rounded,
                label: 'Add moment',
                onTap: onAddMoment,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: _quickNavCard(
                context,
                icon: Icons.podcasts_outlined,
                label: 'Browse podcasts',
                onTap: onBrowsePodcasts,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _quickNavCard(
                context,
                icon: Icons.search_rounded,
                label: 'Search',
                onTap: onSearch,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: _quickNavCard(
                context,
                icon: Icons.hourglass_top_rounded,
                label: 'In progress',
                onTap: onInProgress,
                badge: inProgressCount > 0 ? '$inProgressCount' : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickNavCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? badge,
  }) {
    return SizedBox(
      height: _rowH,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            higLightTap();
            onTap();
          },
          borderRadius: BorderRadius.circular(8),
          child: DecoratedBox(
            decoration: PodcastHomeColors.quickNavCardDecoration(
              context,
            ).copyWith(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: PodcastHomeColors.accent(context),
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: PodcastHomeColors.label(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                        height: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (badge != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: PodcastHomeColors.accent(
                            context,
                          ).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: PodcastHomeColors.accent(context),
                                fontWeight: FontWeight.w700,
                                fontSize: 9,
                                height: 1.0,
                              ),
                        ),
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

class _PodcastCoverStrip extends StatelessWidget {
  const _PodcastCoverStrip({required this.sessions});

  final List<ListeningSession> sessions;

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final ordered = <ListeningSession>[];
    for (final s in sessions) {
      final u = s.artworkUrl?.trim() ?? '';
      if (u.isEmpty) continue;
      if (seen.contains(u)) continue;
      seen.add(u);
      ordered.add(s);
      if (ordered.length >= 18) break;
    }
    if (ordered.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 76,
      child: ScrollConfiguration(
        behavior: const _HiddenScrollbarScrollBehavior(),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: _kEdgePadding),
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          cacheExtent: 500,
          itemCount: ordered.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final s = ordered[i];
            return PodcastArtwork(
              imageUrl: s.artworkUrl,
              labelForInitials: s.artist,
              size: 76,
              borderRadius: 12,
            );
          },
        ),
      ),
    );
  }
}

class _HiddenScrollbarScrollBehavior extends ScrollBehavior {
  const _HiddenScrollbarScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _CreditsChip extends StatefulWidget {
  const _CreditsChip({this.useDarkCreditsStyle = false});

  final bool useDarkCreditsStyle;

  @override
  State<_CreditsChip> createState() => _CreditsChipState();
}

class _CreditsChipState extends State<_CreditsChip>
    with SingleTickerProviderStateMixin {
  static const remainingMinutes = 342;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (remainingMinutes < 10 && remainingMinutes > 0) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final low = remainingMinutes < 50 && remainingMinutes > 0;
    final empty = remainingMinutes == 0;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = widget.useDarkCreditsStyle
        ? (empty
              ? PodcastHomeColors.accent(context)
              : (low
                    ? PodcastHomeColors.accent(context)
                    : PodcastHomeColors.label(context)))
        : (empty ? cs.error : (low ? cs.tertiary : cs.onSurfaceVariant));

    return Semantics(
      button: true,
      label: 'Credits, $remainingMinutes minutes remaining',
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Tokens.radiusLg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Material(
              color: widget.useDarkCreditsStyle
                  ? PodcastHomeColors.card(context).withValues(alpha: 0.95)
                  : Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.55),
              child: InkWell(
                onTap: () {
                  higLightTap();
                  PSNBottomSheet.show(
                    context: context,
                    title: 'Credits',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '$remainingMinutes minutes left this month.',
                          style: tt.bodyLarge,
                        ),
                        const SizedBox(height: Tokens.spaceMd),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(Tokens.radiusSm),
                          child: LinearProgressIndicator(
                            value: (remainingMinutes / 500).clamp(0.0, 1.0),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: Tokens.spaceMd),
                        PSNButton(
                          label: 'Upgrade plan',
                          fullWidth: true,
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(Tokens.radiusLg),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Tokens.spaceSm + 4,
                    vertical: Tokens.spaceSm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (remainingMinutes < 10 && remainingMinutes > 0)
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (context, child) => Opacity(
                            opacity: 0.35 + 0.65 * _pulse.value,
                            child: Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      Text(
                        '$remainingMinutes min',
                        style: tt.labelLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: color,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClipboardRangeSheetBody extends StatefulWidget {
  const _ClipboardRangeSheetBody({required this.info});

  final ClipboardPodcastInfo info;

  /// Jump size options in **minutes** (converted to seconds when nudging).
  static const List<int> stepChoicesMinutes = [10, 20, 30, 40, 50];

  @override
  State<_ClipboardRangeSheetBody> createState() =>
      _ClipboardRangeSheetBodyState();
}

class _ClipboardRangeSheetBodyState extends State<_ClipboardRangeSheetBody> {
  late int _start;
  late int _end;
  late int _stepMinutes;
  late final TextEditingController _startC;
  late final TextEditingController _endC;

  bool _startValid = true;
  bool _endValid = true;

  int get _stepSec => _stepMinutes * 60;

  @override
  void initState() {
    super.initState();
    _start = widget.info.timestampSeconds;
    _end = widget.info.timestampSeconds + 90;
    _stepMinutes = _ClipboardRangeSheetBody.stepChoicesMinutes.first;
    _startC = TextEditingController(text: _formatEpisodePosition(_start));
    _endC = TextEditingController(text: _formatEpisodePosition(_end));
  }

  @override
  void dispose() {
    _startC.dispose();
    _endC.dispose();
    super.dispose();
  }

  void _coerceRange() {
    _start = _clampNonNegative(_start);
    _end = _clampNonNegative(_end);
    if (_end <= _start) {
      _end = _start + _stepSec;
    }
  }

  int _clampNonNegative(int v) => v < 0 ? 0 : v;

  void _syncFieldsFromValues() {
    _startC.text = _formatEpisodePosition(_start);
    _endC.text = _formatEpisodePosition(_end);
  }

  void _bumpStart(int delta) {
    higLightTap();
    setState(() {
      _start += delta;
      _coerceRange();
      _syncFieldsFromValues();
      _startValid = true;
      _endValid = true;
    });
  }

  void _bumpEnd(int delta) {
    higLightTap();
    setState(() {
      _end += delta;
      _coerceRange();
      _syncFieldsFromValues();
      _startValid = true;
      _endValid = true;
    });
  }

  void _commitStartField() {
    final a = _parseEpisodePositionInput(_startC.text);
    setState(() {
      if (a != null) {
        _start = _clampNonNegative(a);
        _startValid = true;
        _coerceRange();
        _syncFieldsFromValues();
      } else {
        _startValid = false;
      }
    });
  }

  void _commitEndField() {
    final b = _parseEpisodePositionInput(_endC.text);
    setState(() {
      if (b != null) {
        _end = _clampNonNegative(b);
        _endValid = true;
        _coerceRange();
        _syncFieldsFromValues();
      } else {
        _endValid = false;
      }
    });
  }

  void _save() {
    FocusScope.of(context).unfocus();
    final a = _parseEpisodePositionInput(_startC.text);
    final b = _parseEpisodePositionInput(_endC.text);
    setState(() {
      _startValid = a != null;
      _endValid = b != null;
      if (a != null) _start = _clampNonNegative(a);
      if (b != null) _end = _clampNonNegative(b);
    });
    if (a == null || b == null) return;

    setState(() {
      _coerceRange();
      if (_end <= _start) {
        _end = _start + _stepSec;
      }
      _syncFieldsFromValues();
    });
    Navigator.of(context).pop((start: _start, end: _end));
  }

  static String _stepLabelMinutes(int min) => '$min min';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? PodcastHomeColors.accent(context) : cs.primary;
    final cardBg = isDark
        ? PodcastHomeColors.card(context)
        : cs.surfaceContainerLow.withValues(alpha: 0.65);
    final borderOuter = isDark
        ? PodcastHomeColors.borderSubtle(context)
        : cs.outlineVariant.withValues(alpha: 0.45);
    final onSurface = isDark ? PodcastHomeColors.label(context) : cs.onSurface;
    final onVar = isDark
        ? PodcastHomeColors.meta(context)
        : cs.onSurfaceVariant;
    final fieldFill = isDark
        ? PodcastHomeColors.chipFill(context)
        : cs.surfaceContainerLow;
    final iconBg = isDark
        ? PodcastHomeColors.card(context)
        : cs.surfaceContainerHighest;

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      borderSide: BorderSide(
        color: isDark
            ? Colors.white.withValues(alpha: 0.14)
            : cs.outlineVariant.withValues(alpha: 0.5),
      ),
    );

    Widget compactTimeRow({
      required String label,
      required TextEditingController controller,
      required bool valid,
      required VoidCallback onMinus,
      required VoidCallback onPlus,
      required VoidCallback onFieldDone,
    }) {
      final iconStyle = IconButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.all(4),
        minimumSize: const Size(36, 36),
        fixedSize: const Size(36, 36),
        foregroundColor: accent,
        backgroundColor: iconBg,
      );
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                label,
                style: tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: onVar,
                ),
              ),
            ),
          ),
          IconButton.filledTonal(
            style: iconStyle,
            onPressed: onMinus,
            icon: const Icon(Icons.remove_rounded, size: 18),
            tooltip: 'Earlier',
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.text,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
              ],
              style: tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                hintText: '5:30',
                hintStyle: tt.bodySmall?.copyWith(color: onVar),
                filled: true,
                fillColor: fieldFill,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: inputBorder,
                enabledBorder: inputBorder,
                focusedBorder: inputBorder.copyWith(
                  borderSide: BorderSide(color: accent, width: 1.5),
                ),
                errorBorder: inputBorder.copyWith(
                  borderSide: BorderSide(color: cs.error),
                ),
                focusedErrorBorder: inputBorder.copyWith(
                  borderSide: BorderSide(color: cs.error, width: 1.5),
                ),
                errorText: valid ? null : 'Use 5:30 or 1:05:30',
                errorStyle: tt.labelSmall?.copyWith(
                  color: cs.error,
                  fontSize: 10,
                ),
                errorMaxLines: 1,
              ),
              maxLines: 1,
              onChanged: (_) {
                if (!valid) {
                  setState(() {
                    if (controller == _startC) {
                      _startValid = true;
                    } else {
                      _endValid = true;
                    }
                  });
                }
              },
              onEditingComplete: onFieldDone,
            ),
          ),
          IconButton.filledTonal(
            style: iconStyle,
            onPressed: onPlus,
            icon: const Icon(Icons.add_rounded, size: 18),
            tooltip: 'Later',
          ),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderOuter),
        color: cardBg,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Save moment',
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.info.episodeTitle,
              style: tt.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.info.podcastName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                widget.info.podcastName,
                style: tt.labelSmall?.copyWith(color: onVar, height: 1.15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Jump (min)',
              style: tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: onVar,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final m in _ClipboardRangeSheetBody.stepChoicesMinutes)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FilterChip(
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _stepLabelMinutes(m),
                            maxLines: 1,
                            style: tt.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        selected: _stepMinutes == m,
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        onSelected: (_) {
                          higLightTap();
                          setState(() => _stepMinutes = m);
                        },
                        selectedColor: isDark
                            ? accent.withValues(alpha: 0.28)
                            : cs.primaryContainer,
                        backgroundColor: isDark
                            ? PodcastHomeColors.card(context)
                            : cs.surfaceContainerHighest,
                        side: BorderSide(
                          color: _stepMinutes == m
                              ? accent.withValues(alpha: isDark ? 0.75 : 0.35)
                              : (isDark
                                    ? PodcastHomeColors.borderSubtle(context)
                                    : cs.outlineVariant.withValues(alpha: 0.4)),
                        ),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _stepMinutes == m
                              ? (isDark ? Colors.white : cs.onPrimaryContainer)
                              : onVar,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            compactTimeRow(
              label: 'Start',
              controller: _startC,
              valid: _startValid,
              onMinus: () => _bumpStart(-_stepSec),
              onPlus: () => _bumpStart(_stepSec),
              onFieldDone: _commitStartField,
            ),
            const SizedBox(height: 6),
            compactTimeRow(
              label: 'End',
              controller: _endC,
              valid: _endValid,
              onMinus: () => _bumpEnd(-_stepSec),
              onPlus: () => _bumpEnd(_stepSec),
              onFieldDone: _commitEndField,
            ),
            const SizedBox(height: 6),
            Text(
              'Length: ${_humanClipDuration(_parseEpisodePositionInput(_startC.text) ?? _start, _parseEpisodePositionInput(_endC.text) ?? _end)}',
              textAlign: TextAlign.center,
              style: tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: onVar,
              ),
            ),
            const SizedBox(height: 10),
            if (isDark)
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded, size: 20),
                label: const Text('Save moment'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                ),
              )
            else
              PSNButton(
                label: 'Save moment',
                variant: ButtonVariant.primaryDark,
                size: ButtonSize.md,
                icon: const Icon(Icons.check_rounded, size: 20),
                fullWidth: true,
                onTap: _save,
              ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? onVar : cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionHintBanner extends StatelessWidget {
  const _SelectionHintBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.primaryContainer.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(Tokens.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.spaceMd,
          vertical: Tokens.spaceSm + 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.touch_app_outlined, color: cs.primary, size: 22),
            const SizedBox(width: Tokens.spaceSm),
            Expanded(
              child: Text(
                'Tap moments to select, then tap Delete. Swipe-to-delete is off while selecting.',
                style: tt.bodySmall?.copyWith(color: cs.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionBottomBar extends StatelessWidget {
  const _SelectionBottomBar({
    required this.selectedCount,
    required this.onDone,
    required this.onSelectAll,
    required this.onDelete,
  });

  final int selectedCount;
  final VoidCallback onDone;
  final VoidCallback onSelectAll;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      elevation: 8,
      shadowColor: Colors.black26,
      color: cs.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.spaceMd,
            vertical: Tokens.spaceSm,
          ),
          child: Row(
            children: [
              TextButton(
                onPressed: () {
                  higLightTap();
                  onDone();
                },
                child: const Text('Done'),
              ),
              const Spacer(),
              Text(
                selectedCount == 0
                    ? 'Select moments'
                    : '$selectedCount selected',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (selectedCount > 0) ...[
                TextButton(
                  onPressed: () {
                    higLightTap();
                    onSelectAll();
                  },
                  child: const Text('All'),
                ),
                const SizedBox(width: Tokens.spaceXs),
                FilledButton(
                  onPressed: () {
                    higLightTap();
                    onDelete();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MomentFilterBar extends StatelessWidget {
  const _MomentFilterBar({required this.value, required this.onChanged});

  final _MomentFilter value;
  final ValueChanged<_MomentFilter> onChanged;

  static String _label(_MomentFilter f) {
    switch (f) {
      case _MomentFilter.all:
        return 'All';
      case _MomentFilter.inProgress:
        return 'In progress';
      case _MomentFilter.ready:
        return 'Ready';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    Widget pill(_MomentFilter f) {
      final selected = value == f;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            higLightTap();
            onChanged(f);
          },
          borderRadius: BorderRadius.circular(50),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Theme.of(context).colorScheme.primary)
                  : PodcastHomeColors.card(context),
              borderRadius: BorderRadius.circular(50),
              border: selected
                  ? null
                  : Border.all(
                      color: PodcastHomeColors.borderSubtle(context),
                      width: 1,
                    ),
            ),
            child: Text(
              _label(f),
              style: tt.labelLarge?.copyWith(
                color: selected
                    ? (Theme.of(context).brightness == Brightness.dark
                          ? PodcastDarkTokens.bgDeep
                          : Theme.of(context).colorScheme.onPrimary)
                    : PodcastHomeColors.label(context),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          // perf: Horizontal ListView needs a *bounded* cross-axis height here; inside
          // CustomScrollView → SliverToBoxAdapter the Row can get infinite maxHeight,
          // which breaks layout and can make the feed (and “summary” rows) disappear.
          child: SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _MomentFilter.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => pill(_MomentFilter.values[i]),
            ),
          ),
        ),
        PopupMenuButton<_MomentFilter>(
          tooltip: 'Filter',
          icon: Icon(
            Icons.tune_rounded,
            color: PodcastHomeColors.label(context),
            size: 22,
          ),
          color: PodcastHomeColors.card(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: PodcastHomeColors.borderSubtle(context)),
          ),
          onSelected: (f) {
            higLightTap();
            onChanged(f);
          },
          itemBuilder: (context) => _MomentFilter.values
              .map(
                (f) => PopupMenuItem<_MomentFilter>(
                  value: f,
                  child: Text(
                    _label(f),
                    style: TextStyle(
                      color: value == f
                          ? PodcastHomeColors.accent(context)
                          : PodcastHomeColors.label(context),
                      fontWeight: value == f
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton({required this.onMorePressed});

  final VoidCallback onMorePressed;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      cacheExtent: _kScrollCacheExtent,
      slivers: [
        SliverToBoxAdapter(
          child: _PodcastHomeHeader(
            totalCount: 0,
            onMorePressed: onMorePressed,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: _kEdgePadding),
          sliver: SliverList.separated(
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: false,
            itemBuilder: (_, _) => const _AppleSessionSkeletonCard(),
            separatorBuilder: (_, _) => const SizedBox(height: _kCardSpacing),
            itemCount: 3,
          ),
        ),
      ],
    );
  }
}

class _AppleSessionSkeletonCard extends StatelessWidget {
  const _AppleSessionSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.surfaceContainerHighest;
    final hi = cs.surfaceContainerHigh;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      child: Container(
        padding: const EdgeInsets.all(Tokens.spaceMd),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: MediaQuery.sizeOf(context).width * 0.7,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(Tokens.radiusXs),
                    ),
                  ),
                  const SizedBox(height: Tokens.spaceSm),
                  Container(
                    height: 12,
                    width: MediaQuery.sizeOf(context).width * 0.4,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(Tokens.radiusXs),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 10,
                    width: MediaQuery.sizeOf(context).width * 0.3,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(Tokens.radiusXs),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Map<String, List<ListeningSession>> _groupByDate(
  List<ListeningSession> sessions,
) {
  final Map<String, List<ListeningSession>> buckets = {
    'Today': [],
    'Yesterday': [],
    'This Week': [],
    'Earlier': [],
  };

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

  for (final s in sessions) {
    final created = DateTime.fromMillisecondsSinceEpoch(s.createdAt);
    final day = DateTime(created.year, created.month, created.day);

    if (day == today) {
      buckets['Today']!.add(s);
    } else if (day == today.subtract(const Duration(days: 1))) {
      buckets['Yesterday']!.add(s);
    } else if (day.isAfter(startOfWeek)) {
      buckets['This Week']!.add(s);
    } else {
      buckets['Earlier']!.add(s);
    }
  }

  buckets.removeWhere((_, list) => list.isEmpty);
  return buckets;
}
