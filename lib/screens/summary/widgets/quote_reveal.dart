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
    return PSNCard(
      glowColor: Tokens.accent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"',
            style: Tokens.headingXL.copyWith(
              color: Tokens.accent,
              height: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              quote,
              style: Tokens.bodyL.copyWith(
                fontStyle: FontStyle.italic,
                color: Tokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
    )
        .animate(delay: delay)
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, end: 0, duration: 400.ms);
  }
}
