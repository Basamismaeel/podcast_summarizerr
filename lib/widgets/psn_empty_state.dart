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

  final String icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 48)),
            SizedBox(height: Tokens.spaceSm),
            Text(
              title,
              style: Tokens.headingM,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Tokens.spaceSm),
            Text(
              subtitle,
              style: Tokens.bodyM,
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
