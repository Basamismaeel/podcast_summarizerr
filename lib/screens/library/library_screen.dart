import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/podcast_home_colors.dart';
import '../../core/tokens.dart';

/// Placeholder for future playlists / collections. Same tab shell as Home.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: PodcastHomeColors.scaffold(context),
      appBar: AppBar(
        title: const Text('Library'),
        automaticallyImplyLeading: false,
        backgroundColor: PodcastHomeColors.scaffold(context),
        foregroundColor: PodcastHomeColors.title(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(Tokens.spaceMd),
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: false,
        cacheExtent: 500,
        itemCount: 5,
        itemBuilder: (context, index) {
          switch (index) {
            case 0:
              return Text(
                'Organize your moments',
                style: tt.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: PodcastHomeColors.title(context),
                ),
              );
            case 1:
              return const SizedBox(height: Tokens.spaceSm);
            case 2:
              return Text(
                'Collections, playlists, and exports are on the way. '
                'For now, all saved moments live on the Home tab.',
                style: tt.bodyLarge?.copyWith(
                  color: PodcastHomeColors.meta(context),
                ),
              );
            case 3:
              return const SizedBox(height: Tokens.spaceLg);
            default:
              return FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Go to Home'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor:
                      isDark ? PodcastHomeColors.accent(context) : null,
                  foregroundColor: isDark ? Colors.white : null,
                ),
              );
          }
        },
      ),
    );
  }
}
