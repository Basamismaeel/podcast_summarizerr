import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/tokens.dart';

class PSNDivider extends StatelessWidget {
  const PSNDivider({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return const Divider(
        height: 1,
        thickness: 1,
        color: Tokens.borderSubtle,
      );
    }

    return Row(
      children: [
        const Expanded(child: _Line()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label!.toUpperCase(),
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Tokens.textMuted,
            ),
          ),
        ),
        const Expanded(child: _Line()),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: Tokens.borderSubtle);
  }
}
