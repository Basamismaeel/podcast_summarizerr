import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/haptics.dart';
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
import '../../widgets/psn_empty_state.dart';
import 'widgets/recording_indicator.dart';
import 'widgets/session_card.dart';

const _kEdgePadding = Tokens.spaceMd;
const _kCardSpacing = 12.0;
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
        episodeHint: episodeHint.isEmpty ? null : episodeHint,
      );
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
      await Permission.notification.request();
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

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(allSessionsProvider);

    return sessionsAsync.when(
      loading: () => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: _HomeSkeleton(
          onMorePressed: () => _showHomeActionsMenu(context),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Text(
            'Error: $e',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ),
      data: (sessions) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: sessions.isEmpty
                    ? CustomScrollView(
                        cacheExtent: _kScrollCacheExtent,
                        slivers: [
                          _HomeSliverAppBar(
                            totalCount: 0,
                            onMorePressed: () => _showHomeActionsMenu(context),
                          ),
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: _kEdgePadding,
                              ),
                              child: PSNEmptyState(
                                icon: '🎙',
                                title: 'No moments saved yet',
                                subtitle:
                                    'Pull down the notification bar and tap Save Moment while a podcast is playing.',
                                action: PSNButton(
                                  label: 'Browse podcasts',
                                  variant: ButtonVariant.secondary,
                                  onTap: () => context.push('/manual-entry'),
                                ),
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

    final slivers = <Widget>[
      _HomeSliverAppBar(
        totalCount: sessions.length,
        onMorePressed: () => _showHomeActionsMenu(context),
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.5),
                  size: 28,
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
              onTap: () => context.push('/summary/${session.id}'),
              onDelete: () =>
                  ref.read(sessionDaoProvider).deleteSession(session.id),
              onSummarizeAgain: () {},
              onChangeStyle: () {},
              selectionMode: _selectionMode,
              isSelected: _selectedSessionIds.contains(session.id),
              onSelectionToggle: () => _toggleSessionSelection(session.id),
            );
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kEdgePadding),
              child: _selectionMode
                  ? card
                  : Dismissible(
                      key: ValueKey('session-${session.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .errorContainer,
                          borderRadius:
                              BorderRadius.circular(Tokens.radiusMd),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: _kEdgePadding),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      confirmDismiss: (_) async {
                        final confirmed =
                            await showConfirmDeleteSessionSheet(
                          context,
                          session.title,
                        );
                        if (confirmed == true) {
                          await ref
                              .read(sessionDaoProvider)
                              .deleteSession(session.id);
                        }
                        return confirmed ?? false;
                      },
                      child: card,
                    ),
            );
          },
          separatorBuilder: (_, _) => const SizedBox(height: _kCardSpacing),
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

class _HomeSliverAppBar extends StatelessWidget {
  const _HomeSliverAppBar({
    required this.totalCount,
    required this.onMorePressed,
  });

  final int totalCount;
  final VoidCallback onMorePressed;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SliverAppBar(
      pinned: true,
      // Tall enough for greeting row + “N moments saved” + padding during expand.
      expandedHeight: 132,
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.biggest.height;
          final collapsed = h <= kToolbarHeight + 16;
          // During collapse, height can sit between toolbar and full expand — hiding
          // the subtitle in that band avoids “bottom overflowed by ~8px”.
          final showSubtitle = !collapsed && h >= 102;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kEdgePadding),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          collapsed ? 'Moments' : _greeting,
                          style: collapsed
                              ? tt.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                )
                              : tt.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const _CreditsChip(),
                      const SizedBox(width: Tokens.spaceXs),
                      IconButton(
                        onPressed: () {
                          higLightTap();
                          onMorePressed();
                        },
                        icon: const Icon(Icons.more_horiz_rounded),
                        tooltip: 'More',
                        style: IconButton.styleFrom(
                          foregroundColor: cs.onSurfaceVariant,
                          minimumSize: const Size(Tokens.minTap, Tokens.minTap),
                        ),
                      ),
                    ],
                  ),
                  if (showSubtitle) ...[
                    const SizedBox(height: 6),
                    Text(
                      '$totalCount moments saved',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Tokens.spaceSm + 4),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CreditsChip extends StatelessWidget {
  const _CreditsChip();

  @override
  Widget build(BuildContext context) {
    const remainingMinutes = 342;
    final low = remainingMinutes < 50 && remainingMinutes > 0;
    final empty = remainingMinutes == 0;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = empty
        ? cs.error
        : (low ? cs.tertiary : cs.onSurfaceVariant);

    return Semantics(
      button: true,
      label: 'Credits, $remainingMinutes minutes remaining',
      child: Material(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        child: InkWell(
          onTap: () {
            higLightTap();
            PSNBottomSheet.show(
              context: context,
              title: 'Credits',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$remainingMinutes minutes left this month.',
                    style: tt.bodyLarge,
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
            child: Text(
              '$remainingMinutes min',
              style: tt.labelLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Show',
          style: tt.titleSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: Tokens.spaceSm),
        Wrap(
          spacing: Tokens.spaceSm,
          runSpacing: Tokens.spaceSm,
          children: _MomentFilter.values.map((f) {
            final selected = value == f;
            return FilterChip(
              label: Text(_label(f)),
              selected: selected,
              onSelected: (_) {
                higLightTap();
                onChanged(f);
              },
              showCheckmark: false,
              selectedColor: cs.primaryContainer,
              labelStyle: tt.labelLarge?.copyWith(
                color: selected ? cs.onPrimaryContainer : cs.onSurface,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            );
          }).toList(),
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
        _HomeSliverAppBar(totalCount: 0, onMorePressed: onMorePressed),
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
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(Tokens.radiusMd),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(Tokens.radiusXs),
                    ),
                  ),
                  const SizedBox(height: Tokens.spaceSm),
                  Container(
                    height: 16,
                    width: 180,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(Tokens.radiusXs),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 12,
                    width: 220,
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
