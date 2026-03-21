import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/haptics.dart';
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
class MainShellScaffold extends ConsumerWidget {
  const MainShellScaffold({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(allSessionsProvider);
    final summarizingSession = sessionsAsync.hasValue
        ? _firstSummarizingSession(sessionsAsync.requireValue)
        : null;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (summarizingSession != null)
            SummarizingMiniBar(
              session: summarizingSession,
              onTap: () => context.push('/summary/${summarizingSession.id}'),
            ),
          _MainBottomNav(
            currentIndex: navigationShell.currentIndex,
            onSelect: (index) {
              higLightTap();
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
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

  static const _labels = ['Home', 'Library', 'Settings'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainer,
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
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                index: 0,
              ),
              _item(
                context,
                icon: Icons.bookmarks_outlined,
                selectedIcon: Icons.bookmarks_rounded,
                index: 1,
              ),
              _item(
                context,
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
    required IconData icon,
    required IconData selectedIcon,
    required int index,
  }) {
    final cs = Theme.of(context).colorScheme;
    final selected = currentIndex == index;
    return IconButton(
      onPressed: () => onSelect(index),
      tooltip: _labels[index],
      icon: Icon(
        selected ? selectedIcon : icon,
        color: selected ? cs.primary : cs.onSurfaceVariant,
      ),
    );
  }
}
