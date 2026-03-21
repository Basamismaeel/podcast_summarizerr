import 'package:flutter/material.dart';

import '../core/tokens.dart';
import '../models/summary_style.dart';

export '../models/summary_style.dart' show SessionStatus;

class PSNStatusBadge extends StatelessWidget {
  const PSNStatusBadge({super.key, required this.status});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final config = _configFor(status, cs);

    return Container(
      constraints: const BoxConstraints(minHeight: Tokens.minTap / 2),
      padding: const EdgeInsets.symmetric(horizontal: Tokens.spaceSm),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
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
            const SizedBox(width: 6),
          ],
          Text(
            config.label,
            style: tt.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: config.fg,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  static _BadgeConfig _configFor(SessionStatus status, ColorScheme cs) =>
      switch (status) {
        SessionStatus.recording => _BadgeConfig(
            bg: cs.errorContainer,
            border: cs.error,
            fg: cs.onErrorContainer,
            label: 'Recording',
          ),
        SessionStatus.queued => _BadgeConfig(
            bg: cs.surfaceContainerHighest,
            border: cs.outlineVariant,
            fg: cs.onSurfaceVariant,
            label: 'Queued',
          ),
        SessionStatus.summarizing => _BadgeConfig(
            bg: cs.primaryContainer,
            border: cs.primary,
            fg: cs.onPrimaryContainer,
            label: 'Summarizing…',
          ),
        SessionStatus.done => _BadgeConfig(
            bg: cs.tertiaryContainer,
            border: cs.tertiary,
            fg: cs.onTertiaryContainer,
            label: 'Done',
          ),
        SessionStatus.error => _BadgeConfig(
            bg: cs.errorContainer,
            border: cs.error,
            fg: cs.onErrorContainer,
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
