import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../database/database.dart';
import 'podcast_artwork.dart';

/// Slim bar when a session is summarizing (above bottom nav).
class SummarizingMiniBar extends StatelessWidget {
  const SummarizingMiniBar({
    super.key,
    required this.session,
    this.onTap,
  });

  final ListeningSession session;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surfaceContainerHigh,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.spaceSm + 4),
            child: Row(
              children: [
                PodcastArtwork(
                  imageUrl: session.artworkUrl,
                  labelForInitials: session.artist,
                  size: 40,
                  borderRadius: Tokens.radiusSm,
                ),
                const SizedBox(width: Tokens.spaceSm + 4),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Summarizing…',
                        style: tt.labelLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.title,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: SizedBox(
                          height: 3,
                          child: LinearProgressIndicator(
                            backgroundColor: cs.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                            minHeight: 3,
                          ),
                        ),
                      ),
                    ],
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
