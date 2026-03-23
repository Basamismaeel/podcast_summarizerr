import 'dart:async';
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/haptics.dart';
import '../../core/snipd_style.dart';
import '../../core/tokens.dart';
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
/// Pre-build off-screen rows for smoother fling on long lists.
const _kScrollCacheExtent = 400.0;

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

    final range = await _showClipboardRangePrompt(info);
    if (range != null && mounted) {
      final actions = ref.read(sessionActionsProvider);
      // Pass iTunes/Spotify IDs so the pipeline can do an exact lookup
      // instead of fuzzy text search.
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
      await actions.createAndSummarize(
        title: info.episodeTitle,
        artist: info.podcastName,
        saveMethod: SaveMethod.notification,
        startTimeSec: range.start,
        endTimeSec: range.end,
        rangeLabel:
            '${_formatRangeTimestamp(range.start)} – ${_formatRangeTimestamp(range.end)}',
        sourceApp: info.source,
        sourceShareUrl: info.sourceUrl,
        episodeHint: episodeHint.isEmpty ? null : episodeHint,
      );
      if (mounted) await PSNHaptics.momentSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved "${info.episodeTitle}" (${_formatRangeTimestamp(range.start)} – ${_formatRangeTimestamp(range.end)})',
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

  int _clampNonNegative(int v) => v < 0 ? 0 : v;

  String _formatRangeTimestamp(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<({int start, int end})?> _showClipboardRangePrompt(
    ClipboardPodcastInfo info,
  ) {
    return showModalBottomSheet<({int start, int end})?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        var start = info.timestampSeconds;
        var end = info.timestampSeconds + 60;
        var errorText = '';

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            void validateAndSet({required bool fromStart}) {
              start = _clampNonNegative(start);
              end = _clampNonNegative(end);
              if (end <= start) {
                errorText = 'End time must be after start time.';
              } else {
                errorText = '';
              }
              setModalState(() {});
            }

            final sheetCs = Theme.of(ctx).colorScheme;
            final sheetTt = Theme.of(ctx).textTheme;
            return PSNBottomSheet(
              title: 'Save moment range?',
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(Tokens.spaceSm + 6),
                      decoration: BoxDecoration(
                        color: sheetCs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(Tokens.radiusMd),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: sheetCs.primaryContainer,
                              borderRadius: BorderRadius.circular(Tokens.radiusSm),
                            ),
                            child: Icon(
                              Icons.podcasts_rounded,
                              color: sheetCs.primary,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: Tokens.spaceSm + 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  info.episodeTitle,
                                  style: sheetTt.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (info.podcastName.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    info.podcastName,
                                    style: sheetTt.bodyMedium?.copyWith(
                                      color: sheetCs.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 3),
                                Text(
                                  '${_formatRangeTimestamp(start)} – ${_formatRangeTimestamp(end)}',
                                  style: sheetTt.bodyMedium?.copyWith(
                                    color: sheetCs.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: Tokens.spaceSm + 2),
                    Text(
                      'Choose start and end times (from clipboard start).',
                      style: sheetTt.bodySmall?.copyWith(
                        color: sheetCs.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 14),
                    _RangePickerRow(
                      label: 'Start',
                      valueText: _formatRangeTimestamp(start),
                      onMinus: () {
                        start -= 15;
                        validateAndSet(fromStart: true);
                      },
                      onPlus: () {
                        start += 15;
                        validateAndSet(fromStart: true);
                      },
                    ),
                    _RangePickerRow(
                      label: 'End',
                      valueText: _formatRangeTimestamp(end),
                      onMinus: () {
                        end -= 15;
                        validateAndSet(fromStart: false);
                      },
                      onPlus: () {
                        end += 15;
                        validateAndSet(fromStart: false);
                      },
                    ),

                    if (errorText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        errorText,
                        style: sheetTt.bodySmall?.copyWith(
                          color: sheetCs.error,
                        ),
                      ),
                    ],

                    const SizedBox(height: Tokens.spaceLg),
                    PSNButton(
                      label: 'Save range',
                      icon: const Icon(Icons.bookmark_rounded, size: 20),
                      fullWidth: true,
                      onTap: () {
                        if (end <= start) {
                          setModalState(() {
                            errorText = 'End time must be after start time.';
                          });
                          return;
                        }
                        Navigator.of(ctx).pop((start: start, end: end));
                      },
                    ),
                    const SizedBox(height: Tokens.spaceSm),
                    PSNButton(
                      label: 'Dismiss',
                      variant: ButtonVariant.ghost,
                      fullWidth: true,
                      onTap: () => Navigator.of(ctx).pop(null),
                    ),
                  ],
                ),
              ),
            );
          },
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
        await NotificationService.instance.updateBanner(info.title, info.artist);
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

  Widget _snipdHomeTheme(BuildContext context, Widget child) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: SnipdStyle.bgDeep,
        colorScheme: base.colorScheme.copyWith(
          surface: SnipdStyle.bgDeep,
          onSurface: SnipdStyle.title,
          onSurfaceVariant: SnipdStyle.meta,
          primary: SnipdStyle.accent,
          outline: SnipdStyle.borderSubtle,
        ),
        textTheme: base.textTheme.apply(
          bodyColor: SnipdStyle.label,
          displayColor: SnipdStyle.title,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(allSessionsProvider);

    return sessionsAsync.when(
      loading: () => _snipdHomeTheme(
        context,
        Scaffold(
          backgroundColor: SnipdStyle.bgDeep,
          body: _HomeSkeleton(
            onMorePressed: () => _showHomeActionsMenu(context),
          ),
        ),
      ),
      error: (e, _) => _snipdHomeTheme(
        context,
        Scaffold(
          backgroundColor: SnipdStyle.bgDeep,
          body: Center(
            child: Text(
              'Error: $e',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: SnipdStyle.meta,
                  ),
            ),
          ),
        ),
      ),
      data: (sessions) {
        return _snipdHomeTheme(
          context,
          Scaffold(
            backgroundColor: SnipdStyle.bgDeep,
            body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: sessions.isEmpty
                    ? CustomScrollView(
                        cacheExtent: _kScrollCacheExtent,
                        slivers: [
                          SliverToBoxAdapter(
                            child: _SnipdHomeHeader(
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
                              child: _SnipdQuickNavGrid(
                                inProgressCount: 0,
                                onAddMoment: () => _showFabSheet(context),
                                onBrowsePodcasts: () =>
                                    context.push('/manual-entry'),
                                onSearch: () => context.push('/search'),
                                onInProgress: () => setState(() =>
                                    _momentFilter = _MomentFilter.inProgress),
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
        .where((s) =>
            SessionStatus.fromJson(s.status) == SessionStatus.recording)
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
        child: _SnipdHomeHeader(
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
          child: _SnipdQuickNavGrid(
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
            child: _SnipdCoverStrip(sessions: sessions),
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
                      color: SnipdStyle.meta,
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
                          color: SnipdStyle.label,
                          fontSize: 18,
                        ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: SnipdStyle.meta.withValues(alpha: 0.6),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      );
      slivers.add(
        SliverList.separated(
          itemBuilder: (ctx, index) {
            final session = items[index];
            final card = SessionCard(
              session: session,
              snipdListingStyle: true,
              onTap: () => context.push('/summary/${session.id}'),
              onDelete: () =>
                  ref.read(sessionDaoProvider).deleteSession(session.id),
              onSummarizeAgain: () => ref
                  .read(sessionActionsProvider)
                  .retrySummary(session.id),
              onChangeStyle: () {},
              selectionMode: _selectionMode,
              isSelected: _selectedSessionIds.contains(session.id),
              onSelectionToggle: () => _toggleSessionSelection(session.id),
            );
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kEdgePadding),
              child: card,
            );
          },
          separatorBuilder: (_, _) => const SizedBox.shrink(),
          itemCount: items.length,
        ),
      );
    });

    slivers.add(
      SliverToBoxAdapter(
        child: SizedBox(height: _selectionMode ? 88 : 24),
      ),
    );

    return CustomScrollView(
      cacheExtent: _kScrollCacheExtent,
      slivers: slivers,
    );
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
                leading: Icon(Icons.add_circle_outline_rounded, color: cs.primary),
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
                leading: Icon(Icons.content_paste_go_rounded, color: cs.primary),
                title: const Text('Paste copied link'),
                subtitle: const Text('Spotify / Apple Podcasts URL from clipboard'),
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

class _SnipdHomeHeader extends StatelessWidget {
  const _SnipdHomeHeader({
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
                        color: SnipdStyle.title,
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
                  foregroundColor: SnipdStyle.label,
                  minimumSize: const Size(Tokens.minTap, Tokens.minTap),
                ),
              ),
              const _CreditsChip(snipdChrome: true),
              IconButton(
                onPressed: () {
                  higLightTap();
                  context.go('/settings');
                },
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                style: IconButton.styleFrom(
                  foregroundColor: SnipdStyle.label,
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
                  foregroundColor: SnipdStyle.label,
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
                    color: SnipdStyle.meta,
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

class _SnipdQuickNavGrid extends StatelessWidget {
  const _SnipdQuickNavGrid({
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
            decoration: SnipdStyle.quickNavCardDecoration.copyWith(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
              child: Row(
                children: [
                  Icon(icon, color: SnipdStyle.accent, size: 13),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: SnipdStyle.label,
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
                          color: SnipdStyle.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: SnipdStyle.accent,
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

class _SnipdCoverStrip extends StatelessWidget {
  const _SnipdCoverStrip({required this.sessions});

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
        behavior: const _SnipdNoScrollbarBehavior(),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: _kEdgePadding),
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

class _SnipdNoScrollbarBehavior extends ScrollBehavior {
  const _SnipdNoScrollbarBehavior();

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
  const _CreditsChip({this.snipdChrome = false});

  final bool snipdChrome;

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
    final color = widget.snipdChrome
        ? (empty
            ? SnipdStyle.accent
            : (low ? SnipdStyle.accent : SnipdStyle.label))
        : (empty
            ? cs.error
            : (low ? cs.tertiary : cs.onSurfaceVariant));

    return Semantics(
      button: true,
      label: 'Credits, $remainingMinutes minutes remaining',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Material(
            color: widget.snipdChrome
                ? SnipdStyle.card.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.06),
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
    );
  }
}

class _RangePickerRow extends StatelessWidget {
  const _RangePickerRow({
    required this.label,
    required this.valueText,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String valueText;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () {
                    higLightTap();
                    onMinus();
                  },
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  color: cs.primary,
                  tooltip: 'Decrease $label',
                ),
                const SizedBox(width: Tokens.spaceSm + 2),
                Text(
                  valueText,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: Tokens.spaceSm + 2),
                IconButton(
                  onPressed: () {
                    higLightTap();
                    onPlus();
                  },
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  color: cs.primary,
                  tooltip: 'Increase $label',
                ),
              ],
            ),
          ),
        ],
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
  const _MomentFilterBar({
    required this.value,
    required this.onChanged,
  });

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
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
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
                color: selected ? Colors.white : SnipdStyle.card,
                borderRadius: BorderRadius.circular(50),
                border: selected
                    ? null
                    : Border.all(color: SnipdStyle.borderSubtle, width: 1),
              ),
              child: Text(
                _label(f),
                style: tt.labelLarge?.copyWith(
                  color: selected ? SnipdStyle.bgDeep : SnipdStyle.label,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _MomentFilter.values.map(pill).toList(),
            ),
          ),
        ),
        PopupMenuButton<_MomentFilter>(
          tooltip: 'Filter',
          icon: Icon(
            Icons.tune_rounded,
            color: SnipdStyle.label,
            size: 22,
          ),
          color: SnipdStyle.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: SnipdStyle.borderSubtle),
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
                      color: value == f ? SnipdStyle.accent : SnipdStyle.label,
                      fontWeight:
                          value == f ? FontWeight.w700 : FontWeight.w400,
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
          child: _SnipdHomeHeader(
            totalCount: 0,
            onMorePressed: onMorePressed,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: _kEdgePadding),
          sliver: SliverList.separated(
            itemBuilder: (_, _) => const _AppleSessionSkeletonCard(),
            separatorBuilder: (_, _) =>
                const SizedBox(height: _kCardSpacing),
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
