import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/tokens.dart';
import '../../../widgets/psn_card.dart';

class QuoteReveal extends StatelessWidget {
  const QuoteReveal({
    super.key,
    required this.quote,
    this.delay = Duration.zero,
  });

  final String quote;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PSNCard.glass(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"',
            style: tt.displaySmall?.copyWith(
              color: cs.primary,
              height: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: Tokens.spaceSm),
          Expanded(
            child: Text(
              quote,
              style: tt.bodyLarge?.copyWith(
                fontStyle: FontStyle.italic,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    )
        .animate(delay: delay)
        .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
        .slideY(
          begin: 0.1,
          end: 0,
          duration: 400.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
