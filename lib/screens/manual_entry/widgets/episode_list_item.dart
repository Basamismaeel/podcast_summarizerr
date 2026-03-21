import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../models/episode_metadata.dart';
import '../../../widgets/psn_card.dart';

class EpisodeListItem extends StatelessWidget {
  const EpisodeListItem({
    super.key,
    required this.episode,
    this.onTap,
  });

  final EpisodeMetadata episode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PSNCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.spaceSm + 4,
        vertical: 10,
      ),
      child: Row(
        children: [
          Container(
            width: Tokens.minTap,
            height: Tokens.minTap,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
            ),
            child: Icon(Icons.podcasts, color: cs.primary, size: 22),
          ),
          const SizedBox(width: Tokens.spaceSm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  episode.title,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  episode.podcastName,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
        ],
      ),
    );
  }
}
