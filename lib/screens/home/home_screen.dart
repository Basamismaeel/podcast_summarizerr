import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/tokens.dart';
import '../../database/database.dart';
import '../../models/summary_style.dart';
import '../../providers/session_provider.dart';
import '../../services/clipboard_podcast_service.dart';
import '../../services/notification_service.dart';
import '../../services/now_playing_banner_coordinator.dart';
import '../../services/now_playing_service.dart';
import '../../services/siri_service.dart';
import '../../widgets/psn_bottom_sheet.dart';
import '../../widgets/psn_button.dart';
import '../../widgets/psn_empty_state.dart';
import 'widgets/recording_indicator.dart';
import 'widgets/session_card.dart';
import 'widgets/summarizing_mini_bar.dart';

// Apple Podcasts–style home chrome (true black OLED, system-adjacent type on iOS).
const _kAppleBlack = Color(0xFF000000);
const _kAppleNavBg = Color(0xFF1C1C1E);
const _kEdgePadding = 20.0;
const _kCardSpacing = 12.0;
const _kFabAccent = Color(0xFF6366F1);

ListeningSession? _firstSummarizingSession(List<ListeningSession> sessions) {
  for (final s in sessions) {
    if (SessionStatus.fromJson(s.status) == SessionStatus.summarizing) {
      return s;
    }
  }
  return null;
}

TextStyle _appleSectionHeader(BuildContext context) {
  final useSf = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  return TextStyle(
    fontFamily: useSf ? '.SF Pro Text' : null,
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: useSf ? -0.4 : -0.2,
  );
}

TextStyle _appleAppBarTitle(BuildContext context, {required bool collapsed}) {
  final useSf = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  return TextStyle(
    fontFamily: useSf ? '.SF Pro Text' : null,
    fontSize: collapsed ? 17 : 34,
    fontWeight: collapsed ? FontWeight.w600 : FontWeight.bold,
    color: Colors.white,
    letterSpacing: collapsed ? 0 : -0.5,
  );
}

TextStyle _appleSubtitle(BuildContext context) {
  final useSf = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  return TextStyle(
    fontFamily: useSf ? '.SF Pro Text' : null,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: const Color(0xFF8E8E93),
  );
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  Timer? _bannerPollTimer;

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

  Future<void> _checkClipboardForPodcast() async {
    final info = await ClipboardPodcastService.instance.checkClipboard();
    if (info == null || !mounted) return;

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
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: _kFabAccent,
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

            return PSNBottomSheet(
              title: 'Save moment range?',
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _kFabAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.podcasts,
                              color: _kFabAccent,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  info.episodeTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (info.podcastName.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    info.podcastName,
                                    style: const TextStyle(
                                      color: Color(0xFF8E8E93),
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 3),
                                Text(
                                  '${_formatRangeTimestamp(start)} – ${_formatRangeTimestamp(end)}',
                                  style: const TextStyle(
                                    color: _kFabAccent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),
                    Text(
                      'Choose start and end times (from clipboard start).',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 13,
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
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],

                    const SizedBox(height: Tokens.spaceLg),
                    PSNButton(
                      label: '🔖 Save Range',
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
    // ignore: avoid_print
    print('[Banner] Attempting to show banner');
    final info = await NowPlayingService.instance.getCurrentNowPlaying();
    // ignore: avoid_print
    print('[Banner] NowPlaying result: $info');
    if (info != null) {
      await NotificationService.instance.showNowPlayingBanner(
        info.title,
        info.artist,
      );
      // ignore: avoid_print
      print('[Banner] Banner shown successfully');
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
      // ignore: avoid_print
      print('[Banner] Attempting to show banner');
      final info = await NowPlayingService.instance.getCurrentNowPlaying();
      // ignore: avoid_print
      print('[Banner] NowPlaying result: $info');
      if (info != null) {
        await NotificationService.instance.updateBanner(info.title, info.artist);
        // ignore: avoid_print
        print('[Banner] Banner shown successfully');
      }
    });

    Future.delayed(const Duration(seconds: 3), () async {
      // ignore: avoid_print
      print('[Banner] Attempting to show banner');
      // ignore: avoid_print
      print('[Banner] NowPlaying result: null (3s test — hardcoded episode)');
      await NotificationService.instance.showNowPlayingBanner(
        'Test Episode',
        'Test Podcast',
      );
      // ignore: avoid_print
      print('[Banner] Banner shown successfully');
    });

    Future.delayed(const Duration(seconds: 2), () async {
      final status = await Permission.notification.request();
      // ignore: avoid_print
      print('Notification permission: $status');
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

  double _fabBottomInset(bool showMiniBar) {
    final viewPadding = MediaQuery.paddingOf(context).bottom;
    const navH = 60.0;
    final miniH = showMiniBar ? 64.0 : 0.0;
    return viewPadding + navH + miniH + 12;
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(allSessionsProvider);
    final actions = ref.watch(sessionActionsProvider);

    final summarizingSession = sessionsAsync.hasValue
        ? _firstSummarizingSession(sessionsAsync.requireValue)
        : null;
    final showMiniBar = summarizingSession != null;

    return sessionsAsync.when(
      loading: () => Scaffold(
        backgroundColor: _kAppleBlack,
        body: const _HomeSkeleton(),
        bottomNavigationBar: const _BottomNav(currentIndex: 0),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: _kAppleBlack,
        body: Center(
          child: Text(
            'Error: $e',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
          ),
        ),
        bottomNavigationBar: const _BottomNav(currentIndex: 0),
      ),
      data: (sessions) {
        return Scaffold(
          backgroundColor: _kAppleBlack,
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: sessions.isEmpty
                    ? CustomScrollView(
                        slivers: [
                          _HomeSliverAppBar(totalCount: 0),
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
                                  label: 'Browse Podcasts',
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
              Positioned(
                right: _kEdgePadding,
                bottom: _fabBottomInset(showMiniBar),
                child: Material(
                  color: _kFabAccent,
                  borderRadius: BorderRadius.circular(14),
                  elevation: 6,
                  shadowColor: Colors.black54,
                  child: InkWell(
                    onTap: () => _showFabSheet(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add, color: Colors.white, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            '+ Add Moment',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              fontFamily: !kIsWeb &&
                                      defaultTargetPlatform ==
                                          TargetPlatform.iOS
                                  ? '.SF Pro Text'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (kDebugMode)
                Positioned(
                  left: _kEdgePadding,
                  bottom: _fabBottomInset(showMiniBar),
                  child: Opacity(
                    opacity: 0.85,
                    child: Material(
                      color: _kAppleNavBg,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => _showDebugSheet(context, actions),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('🛠', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (summarizingSession != null)
                SummarizingMiniBar(
                  session: summarizingSession,
                  onTap: () =>
                      context.push('/summary/${summarizingSession.id}'),
                ),
              const _BottomNav(currentIndex: 0),
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

    final grouped = _groupByDate(sessions);

    final slivers = <Widget>[
      _HomeSliverAppBar(totalCount: sessions.length),
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
                    style: _appleSectionHeader(context),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.35),
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
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kEdgePadding),
              child: Dismissible(
                key: ValueKey('session-${session.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  decoration: BoxDecoration(
                    color: Tokens.errorDim,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: _kEdgePadding),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Tokens.error,
                  ),
                ),
                confirmDismiss: (_) async {
                  final confirmed =
                      await _confirmDelete(context, session.title);
                  if (confirmed == true) {
                    await ref.read(sessionDaoProvider).deleteSession(session.id);
                  }
                  return confirmed ?? false;
                },
                child: SessionCard(
                  session: session,
                  onTap: () => context.push('/summary/${session.id}'),
                  onDelete: () =>
                      ref.read(sessionDaoProvider).deleteSession(session.id),
                  onSummarizeAgain: () {},
                  onChangeStyle: () {},
                ),
              ),
            );
          },
          separatorBuilder: (_, _) => const SizedBox(height: _kCardSpacing),
          itemCount: items.length,
        ),
      );
    });

    return CustomScrollView(slivers: slivers);
  }

  Future<void> _showFabSheet(BuildContext context) async {
    await PSNBottomSheet.show(
      context: context,
      title: 'Add moment',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PSNButton(
            label: '✏️  Add Manually',
            fullWidth: true,
            variant: ButtonVariant.secondary,
            onTap: () {
              Navigator.of(context).pop();
              context.push('/manual-entry');
            },
          ),
          const SizedBox(height: Tokens.spaceSm),
          PSNButton(
            label: '🎙  Browse Podcasts',
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

  Future<void> _showDebugSheet(
    BuildContext context,
    SessionActions actions,
  ) async {
    await PSNBottomSheet.show(
      context: context,
      title: 'Debug tools',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _debugTile(
            context,
            label: 'Add Queued Session',
            onTap: () async {
              await _insertFakeSession(actions, status: SessionStatus.queued);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          _debugTile(
            context,
            label: 'Add Recording Session',
            onTap: () async {
              await _insertFakeSession(actions,
                  status: SessionStatus.recording);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          _debugTile(
            context,
            label: 'Add Summarizing Session',
            onTap: () async {
              await _insertFakeSession(actions,
                  status: SessionStatus.summarizing);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          _debugTile(
            context,
            label: 'Add Done Session',
            onTap: () async {
              await _insertFakeSession(actions,
                  status: SessionStatus.done, withSummary: true);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          _debugTile(
            context,
            label: 'Clear All Sessions',
            isDestructive: true,
            onTap: () async {
              await ref.read(sessionDaoProvider).deleteAllSessions();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          _debugTile(
            context,
            label: 'Go to Design Preview',
            onTap: () {
              Navigator.of(context).pop();
              context.push('/design-preview');
            },
          ),
        ],
      ),
    );
  }

  ListTile _debugTile(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      title: Text(
        label,
        style: Tokens.bodyM.copyWith(
          color: isDestructive ? Tokens.error : Tokens.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }

  Future<void> _insertFakeSession(
    SessionActions actions, {
    required SessionStatus status,
    bool withSummary = false,
  }) async {
    const cover =
        'https://picsum.photos/seed/podcast_safety_net/300/300';
    final id = await actions.createSession(
      title: 'Deep Work & Focus',
      artist: 'Mindful Productivity',
      saveMethod: SaveMethod.notification,
      startTimeSec: 12 * 60,
      endTimeSec: 31 * 60,
      rangeLabel: '12:00 – 31:00',
      summaryStyle: SummaryStyle.insights,
      artworkUrl: cover,
    );

    if (withSummary || status != SessionStatus.queued) {
      final db = ref.read(sessionDaoProvider);
      final row = await db.getSessionById(id);
      if (row != null) {
        await db.updateSession(
          row.toCompanion(true).copyWith(
                status: Value(status.name),
                bullet1: const Value(
                  'Why your brain treats podcasts like background noise — and how to capture ideas anyway.',
                ),
              ),
        );
      }
    }
  }
}

Future<bool?> _confirmDelete(BuildContext context, String title) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return PSNBottomSheet(
        title: 'Delete session?',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently remove “$title” and its summary.',
              style: Tokens.bodyM,
            ),
            const SizedBox(height: Tokens.spaceLg),
            PSNButton(
              label: 'Delete',
              variant: ButtonVariant.danger,
              fullWidth: true,
              onTap: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: Tokens.spaceSm),
            PSNButton(
              label: 'Cancel',
              variant: ButtonVariant.ghost,
              fullWidth: true,
              onTap: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      );
    },
  );
}

class _HomeSliverAppBar extends StatelessWidget {
  const _HomeSliverAppBar({required this.totalCount});

  final int totalCount;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 120,
      backgroundColor: _kAppleBlack,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final collapsed =
              constraints.biggest.height <= kToolbarHeight + 16;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kEdgePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        collapsed ? 'Podcast Safety Net' : _greeting,
                        style: _appleAppBarTitle(context, collapsed: collapsed),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const _CreditsChip(),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: Colors.white,
                      ),
                      onPressed: () => GoRouter.of(context).push('/settings'),
                    ),
                  ],
                ),
                if (!collapsed) ...[
                  const SizedBox(height: 6),
                  Text(
                    '$totalCount moments saved',
                    style: _appleSubtitle(context),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
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
    final color = empty
        ? Tokens.error
        : (low ? Tokens.warning : const Color(0xFF8E8E93));

    return GestureDetector(
      onTap: () {
        PSNBottomSheet.show(
          context: context,
          title: 'Credits',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$remainingMinutes minutes left this month.',
                style: Tokens.bodyL,
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _kAppleNavBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$remainingMinutes min',
          style: TextStyle(
            fontFamily: !kIsWeb &&
                    defaultTargetPlatform == TargetPlatform.iOS
                ? '.SF Pro Text'
                : null,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: IconButton(
                      onPressed: onMinus,
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      color: _kFabAccent,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  valueText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: IconButton(
                      onPressed: onPlus,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      color: _kFabAccent,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);

    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: _kAppleNavBg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navItem(
            context,
            icon: Icons.home_rounded,
            index: 0,
            onTap: () => router.go('/'),
          ),
          _navItem(
            context,
            icon: Icons.bookmarks_rounded,
            index: 1,
            onTap: () => router.go('/library'),
          ),
          _navItem(
            context,
            icon: Icons.settings_rounded,
            index: 2,
            onTap: () => router.go('/settings'),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    BuildContext context, {
    required IconData icon,
    required int index,
    required VoidCallback onTap,
  }) {
    final selected = currentIndex == index;
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: selected ? _kFabAccent : const Color(0xFF8E8E93),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const _HomeSliverAppBar(totalCount: 0),
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

  static const _cardBg = Color(0xFF1C1C1E);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2C2C2E),
      highlightColor: const Color(0xFF3A3A3C),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3C),
                borderRadius: BorderRadius.circular(12),
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
                      color: const Color(0xFF3A3A3C),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 16,
                    width: 180,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3A3C),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 12,
                    width: 220,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3A3C),
                      borderRadius: BorderRadius.circular(4),
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
