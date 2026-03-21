import 'package:flutter/material.dart';

import '../../../core/tokens.dart';

class ShareCardGenerator extends StatelessWidget {
  const ShareCardGenerator({
    super.key,
    required this.title,
    required this.artist,
    required this.bullets,
  });

  final String title;
  final String artist;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(Tokens.spaceLg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.surfaceContainerLow,
              cs.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(Tokens.radiusLg),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Tokens.spaceXs),
            Text(
              artist,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: Tokens.spaceMd),
            for (final bullet in bullets) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•  ',
                    style: tt.bodyLarge?.copyWith(color: cs.primary),
                  ),
                  Expanded(child: Text(bullet, style: tt.bodyLarge)),
                ],
              ),
              const SizedBox(height: Tokens.spaceXs + 2),
            ],
            const SizedBox(height: Tokens.spaceSm),
            Text(
              'podcast safety net',
              style: tt.labelLarge?.copyWith(color: cs.primary),
            ),
          ],
        ),
      ),
    );
  }
}
