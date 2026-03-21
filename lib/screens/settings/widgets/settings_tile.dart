import 'package:flutter/material.dart';

import '../../../core/tokens.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.spaceMd,
          vertical: 14,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Tokens.borderSubtle, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Tokens.bodyL.copyWith(color: Tokens.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: Tokens.bodyS.copyWith(color: Tokens.textMuted)),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!
            else if (onTap != null)
              const Icon(Icons.chevron_right, color: Tokens.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
