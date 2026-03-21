import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/tokens.dart';

/// Placeholder for future playlists / collections. Same tab shell as Home.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Library'),
        automaticallyImplyLeading: false,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.spaceMd),
        children: [
          Text(
            'Organize your moments',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Tokens.spaceSm),
          Text(
            'Collections, playlists, and exports are on the way. '
            'For now, all saved moments live on the Home tab.',
            style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
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
