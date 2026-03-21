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
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(Tokens.spaceLg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Tokens.bgSurface, Tokens.bgPrimary],
          ),
          borderRadius: BorderRadius.circular(Tokens.radiusLg),
          border: Border.all(color: Tokens.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Tokens.headingM),
            const SizedBox(height: 4),
            Text(artist, style: Tokens.bodyS.copyWith(color: Tokens.textMuted)),
            const SizedBox(height: Tokens.spaceMd),
            for (final bullet in bullets) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: Tokens.bodyM.copyWith(color: Tokens.accent)),
                  Expanded(child: Text(bullet, style: Tokens.bodyM)),
                ],
              ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: Tokens.spaceSm),
            Text(
              'podcast safety net',
              style: Tokens.label.copyWith(color: Tokens.accent),
            ),
          ],
        ),
      ),
    );
  }
}
