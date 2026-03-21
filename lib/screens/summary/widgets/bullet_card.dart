import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../widgets/psn_card.dart';

class BulletCard extends StatelessWidget {
  const BulletCard({
    super.key,
    required this.index,
    required this.text,
  });

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PSNCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: tt.labelMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: tt.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
