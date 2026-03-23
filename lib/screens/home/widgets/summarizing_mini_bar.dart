import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/snipd_style.dart';
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
    final tt = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Material(
          color: SnipdStyle.miniBarBg,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: SnipdStyle.borderSubtle),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 64,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Tokens.spaceSm + 4,
                      ),
                      child: Row(
                        children: [
                          PodcastArtwork(
                            imageUrl: session.artworkUrl,
                            labelForInitials: session.artist,
                            size: 44,
                            borderRadius: 10,
                          ),
                          const SizedBox(width: Tokens.spaceSm + 4),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.title,
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: SnipdStyle.title,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  session.artist,
                                  style: tt.bodySmall?.copyWith(
                                    color: SnipdStyle.meta,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: SnipdStyle.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Summarizing',
                              style: tt.labelSmall?.copyWith(
                                color: SnipdStyle.accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 2,
                    child: LinearProgressIndicator(
                      backgroundColor: SnipdStyle.card,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        SnipdStyle.accent,
                      ),
                      minHeight: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
