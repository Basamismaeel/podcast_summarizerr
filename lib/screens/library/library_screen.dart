import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/snipd_style.dart';
import '../../core/tokens.dart';

/// Placeholder for future playlists / collections. Same tab shell as Home.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: SnipdStyle.bgDeep,
      appBar: AppBar(
        title: const Text('Library'),
        automaticallyImplyLeading: false,
        backgroundColor: SnipdStyle.bgDeep,
        foregroundColor: SnipdStyle.title,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.spaceMd),
        children: [
          Text(
            'Organize your moments',
            style: tt.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: SnipdStyle.title,
            ),
          ),
          const SizedBox(height: Tokens.spaceSm),
          Text(
            'Collections, playlists, and exports are on the way. '
            'For now, all saved moments live on the Home tab.',
            style: tt.bodyLarge?.copyWith(color: SnipdStyle.meta),
          ),
          const SizedBox(height: Tokens.spaceLg),
          FilledButton.tonalIcon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home_rounded),
            label: const Text('Go to Home'),
          ),
        ],
      ),
    );
  }
}
