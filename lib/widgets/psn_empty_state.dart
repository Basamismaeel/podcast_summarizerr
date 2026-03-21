import 'package:flutter/material.dart';

import '../core/tokens.dart';

class PSNEmptyState extends StatelessWidget {
  const PSNEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  /// Emoji or short string; uses [TextTheme.displaySmall] so it scales with Dynamic Type.
  final String icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              icon,
              textAlign: TextAlign.center,
              style: tt.displaySmall,
            ),
            SizedBox(height: Tokens.spaceSm),
            Text(
              title,
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Tokens.spaceSm),
            Text(
              subtitle,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              SizedBox(height: Tokens.spaceMd),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
