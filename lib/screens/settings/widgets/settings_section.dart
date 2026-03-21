import 'package:flutter/material.dart';

import '../../../core/tokens.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.spaceSm),
      child: Text(title.toUpperCase(), style: Tokens.label),
    );
  }
}
