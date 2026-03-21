import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/tokens.dart';
import '../models/summary_style.dart';

export '../models/summary_style.dart' show SessionStatus;

class PSNStatusBadge extends StatelessWidget {
  const PSNStatusBadge({super.key, required this.status});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final config = _configFor(status);

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(Tokens.radiusFull),
        border: Border.all(color: config.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == SessionStatus.summarizing) ...[
            SizedBox(
              width: 8,
              height: 8,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: config.fg,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            config.label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: config.fg,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  static _BadgeConfig _configFor(SessionStatus status) => switch (status) {
        SessionStatus.recording => _BadgeConfig(
            bg: Tokens.errorDim,
            border: Tokens.error,
            fg: Tokens.error,
            label: '● Recording',
          ),
        SessionStatus.queued => _BadgeConfig(
            bg: Tokens.bgElevated,
            border: Tokens.borderLight,
            fg: Tokens.textMuted,
            label: 'Queued',
          ),
        SessionStatus.summarizing => _BadgeConfig(
            bg: Tokens.accentDim,
            border: Tokens.accentBorder,
            fg: Tokens.accent,
            label: 'Summarizing…',
          ),
        SessionStatus.done => _BadgeConfig(
            bg: Tokens.successDim,
            border: Tokens.success.withValues(alpha: 0.3),
            fg: Tokens.success,
            label: 'Done',
          ),
        SessionStatus.error => _BadgeConfig(
            bg: Tokens.errorDim,
            border: Tokens.error.withValues(alpha: 0.3),
            fg: Tokens.error,
            label: 'Failed',
          ),
      };
}

class _BadgeConfig {
  const _BadgeConfig({
    required this.bg,
    required this.border,
    required this.fg,
    required this.label,
  });

  final Color bg;
  final Color border;
  final Color fg;
  final String label;
}
