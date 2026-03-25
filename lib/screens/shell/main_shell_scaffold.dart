import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/haptics.dart';
import '../../core/podcast_home_colors.dart';
import '../../core/moments_stats_service.dart';
import '../../database/database.dart';
import '../../models/summary_style.dart';
import '../../providers/session_provider.dart';
import '../home/widgets/summarizing_mini_bar.dart';

ListeningSession? _firstSummarizingSession(List<ListeningSession> sessions) {
  for (final s in sessions) {
    if (SessionStatus.fromJson(s.status) == SessionStatus.summarizing) {
      return s;
    }
  }
  return null;
}

/// Root tabs: Home, Library, Settings — bottom navigation always visible.
class MainShellScaffold extends ConsumerStatefulWidget {
  const MainShellScaffold({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShellScaffold> createState() => _MainShellScaffoldState();
}

class _MainShellScaffoldState extends ConsumerState<MainShellScaffold> {
  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(allSessionsProvider);
    final summarizingSession = sessionsAsync.hasValue
        ? _firstSummarizingSession(sessionsAsync.requireValue)
        : null;

    ref.listen(allSessionsProvider, (prev, next) {
      next.whenData((list) {
        final c = list.where((s) {
          final st = SessionStatus.fromJson(s.status);
          return st == SessionStatus.queued || st == SessionStatus.summarizing;
        }).length;
        unawaited(
          MomentsStatsService.syncBadgeFromSessionCounts(
            queuedOrSummarizingCount: c,
          ),
        );
      });
    });

    return Scaffold(
      backgroundColor: PodcastHomeColors.scaffold(context),
      body: widget.navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (summarizingSession != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SummarizingMiniBar(
                session: summarizingSession,
                onTap: () => context.push('/summary/${summarizingSession.id}'),
              ),
            ),
          RepaintBoundary(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: PodcastHomeColors.bottomNavBg(context),
                    border: Border(
                      top: BorderSide(
                        color: PodcastHomeColors.borderSubtle(context),
                      ),
                    ),
                  ),
                  child: _MainBottomNav(
                    currentIndex: widget.navigationShell.currentIndex,
                    onSelect: (index) {
                      higLightTap();
                      widget.navigationShell.goBranch(
                        index,
                        initialLocation:
                            index == widget.navigationShell.currentIndex,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MainBottomNav extends StatelessWidget {
  const _MainBottomNav({
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const _tooltips = ['Home', 'Library', 'Settings'];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _item(
                context,
                tt: tt,
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                index: 0,
              ),
              _item(
                context,
                tt: tt,
                icon: Icons.bookmarks_outlined,
                selectedIcon: Icons.bookmarks_rounded,
                index: 1,
              ),
              _item(
                context,
                tt: tt,
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings_rounded,
                index: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required TextTheme tt,
    required IconData icon,
    required IconData selectedIcon,
    required int index,
  }) {
    final selected = currentIndex == index;
    final color = selected
        ? PodcastHomeColors.accent(context)
        : PodcastHomeColors.meta(context);
    return Expanded(
      child: Tooltip(
        message: _tooltips[index],
        child: InkWell(
          onTap: () => onSelect(index),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Column(
              key: ValueKey('$index-$selected'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 24,
                  color: color,
                ),
                const SizedBox(height: 4),
                Text(
                  _tooltips[index],
                  style: tt.labelSmall?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 11,
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
