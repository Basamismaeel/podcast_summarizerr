import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../database/database.dart';
import 'podcast_artwork.dart';

/// Slim “now playing” style bar when a session is summarizing (above bottom nav).
class SummarizingMiniBar extends StatelessWidget {
  const SummarizingMiniBar({
    super.key,
    required this.session,
    this.onTap,
  });

  final ListeningSession session;
  final VoidCallback? onTap;

  static const _barBg = Color(0xFF1C1C1E);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _barBg,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                PodcastArtwork(
                  imageUrl: session.artworkUrl,
                  labelForInitials: session.artist,
                  size: 40,
                  borderRadius: 8,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Summarizing…',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Tokens.accent,
                          fontFamily: !kIsWeb &&
                                  defaultTargetPlatform == TargetPlatform.iOS
                              ? '.SF Pro Text'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: !kIsWeb &&
                                  defaultTargetPlatform == TargetPlatform.iOS
                              ? '.SF Pro Text'
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(1.5),
                        child: const SizedBox(
                          height: 3,
                          child: LinearProgressIndicator(
                            backgroundColor: Color(0xFF3A3A3C),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Tokens.accent),
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
