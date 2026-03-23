import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/tokens.dart';

class SearchPlaceholderScreen extends StatelessWidget {
  const SearchPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(Tokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Search your moments',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Tokens.spaceSm),
            Text(
              'Full-text search across titles and summaries is coming soon.',
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: Tokens.spaceLg),
            FilledButton.tonal(
              onPressed: () => context.pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
