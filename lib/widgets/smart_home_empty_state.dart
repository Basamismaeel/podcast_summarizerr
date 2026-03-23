import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/moments_stats_service.dart';
import '../core/tokens.dart';
import 'psn_button.dart';

/// Empty home content driven by [totalMomentsSaved] (lifetime counter).
class SmartHomeEmptyState extends StatelessWidget {
  const SmartHomeEmptyState({
    super.key,
    required this.totalMomentsSaved,
    required this.onSeeHowItWorks,
  });

  final int totalMomentsSaved;
  final VoidCallback onSeeHowItWorks;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final c = totalMomentsSaved;

    late final String icon;
    late final String title;
    late final String subtitle;
    Widget? action;

    if (c == 0) {
      icon = '🎙';
      title = 'Your podcast library starts here';
      subtitle =
          'Open Spotify and listen to anything. When you hear something worth '
          'remembering, save it. We\'ll do the rest.';
      action = PSNButton(
        label: 'See how it works',
        variant: ButtonVariant.secondary,
        fullWidth: true,
        onTap: onSeeHowItWorks,
      );
    } else if (c == 1) {
      icon = '✨';
      title = 'First moment saved!';
      subtitle =
          'Keep listening. Every insight you save becomes part of your knowledge library.';
    } else if (c >= 2 && c < 10) {
      icon = '📚';
      title = 'Building your library';
      subtitle =
          'You have saved $c insights. They\'re all searchable and waiting for you.';
      action = PSNButton(
        label: 'Browse your saves',
        variant: ButtonVariant.secondary,
        fullWidth: true,
        onTap: () => context.push('/manual-entry'),
      );
    } else {
      icon = '🧠';
      title = 'Your podcast brain';
      subtitle =
          '$c insights saved across your listening history.';
      action = PSNButton(
        label: 'Search your library',
        variant: ButtonVariant.secondary,
        fullWidth: true,
        onTap: () => context.push('/search'),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, textAlign: TextAlign.center, style: tt.displaySmall),
            const SizedBox(height: Tokens.spaceSm),
            Text(
              title,
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Tokens.spaceSm),
            Text(
              subtitle,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: Tokens.spaceMd),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

/// Async wrapper that loads prefs count then shows [SmartHomeEmptyState].
class SmartHomeEmptyStateLoader extends StatefulWidget {
  const SmartHomeEmptyStateLoader({
    super.key,
    required this.onSeeHowItWorks,
  });

  final VoidCallback onSeeHowItWorks;

  @override
  State<SmartHomeEmptyStateLoader> createState() =>
      _SmartHomeEmptyStateLoaderState();
}

class _SmartHomeEmptyStateLoaderState extends State<SmartHomeEmptyStateLoader> {
  late Future<int> _future;

  @override
  void initState() {
    super.initState();
    _future = MomentsStatsService.getTotalMomentsSaved();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _future,
      builder: (context, snap) {
        final n = snap.data ?? 0;
        return SmartHomeEmptyState(
          totalMomentsSaved: n,
          onSeeHowItWorks: widget.onSeeHowItWorks,
        );
      },
    );
  }
}
