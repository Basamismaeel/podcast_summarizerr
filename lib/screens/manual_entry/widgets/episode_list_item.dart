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
    return PSNCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Tokens.bgElevated,
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
            ),
            child: const Icon(Icons.podcasts, color: Tokens.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  episode.title,
                  style: Tokens.headingS,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  episode.podcastName,
                  style: Tokens.bodyS.copyWith(color: Tokens.textMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Tokens.textMuted, size: 20),
        ],
      ),
    );
  }
}
