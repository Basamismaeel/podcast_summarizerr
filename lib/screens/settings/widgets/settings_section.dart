import 'package:flutter/material.dart';

import '../../../core/tokens.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.spaceSm),
      child: Text(
        title.toUpperCase(),
        style: tt.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
