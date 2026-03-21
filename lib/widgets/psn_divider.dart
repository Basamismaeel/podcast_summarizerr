import 'package:flutter/material.dart';

import '../core/tokens.dart';

class PSNDivider extends StatelessWidget {
  const PSNDivider({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (label == null) {
      return Divider(
        height: 1,
        thickness: 1,
        color: cs.outlineVariant,
      );
    }

    return Row(
      children: [
        Expanded(child: Divider(color: cs.outlineVariant, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.spaceSm),
          child: Text(
            label!.toUpperCase(),
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Divider(color: cs.outlineVariant, height: 1)),
      ],
    );
  }
}
