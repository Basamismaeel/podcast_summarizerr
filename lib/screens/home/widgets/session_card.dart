import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/tokens.dart';
import '../../../database/database.dart';
import '../../../models/summary_style.dart';
import '../../../widgets/psn_button.dart';
import 'podcast_artwork.dart';

/// Grouped list row: theme surfaces, system typography, no heavy shadows.
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    this.onTap,
    this.onDelete,
    this.onSummarizeAgain,
    this.onChangeStyle,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectionToggle,
  });

  final ListeningSession session;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onSummarizeAgain;
  final VoidCallback? onChangeStyle;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onSelectionToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final status = SessionStatus.fromJson(session.status);
    final saveMethod = SaveMethod.fromJson(session.saveMethod);
    final bulletPreview = session.bullet1;
    final hasPreview = status == SessionStatus.done && bulletPreview != null;
    final isQueued = status == SessionStatus.queued;

    return GestureDetector(
      onLongPress:
          selectionMode ? null : () => _showContextMenu(context, status),
      child: Material(
        color: cs.surfaceContainerLow,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          side: BorderSide(
            color: selectionMode && isSelected
                ? cs.primary
                : cs.outlineVariant.withValues(alpha: 0.5),
            width: selectionMode && isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: selectionMode ? onSelectionToggle : onTap,
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(Tokens.spaceMd),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectionMode) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: Tokens.spaceSm),
                    child: Checkbox.adaptive(
                      value: isSelected,
                      onChanged: (_) => onSelectionToggle?.call(),
                    ),
                  ),
                ],
                PodcastArtwork(
                  imageUrl: session.artworkUrl,
                  labelForInitials: session.artist,
                  size: 56,
                  borderRadius: Tokens.radiusMd,
                ),
                const SizedBox(width: Tokens.spaceSm + 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              session.title,
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: Tokens.spaceSm),
                          _SessionStatusIndicator(status: status),
                        ],
                      ),
                      const SizedBox(height: Tokens.spaceXs),
                      Text(
                        session.artist,
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: Tokens.spaceXs + 2),
                      _MetadataRow(
                        session: session,
                        saveMethod: saveMethod,
                        textStyle: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (hasPreview) ...[
                        const SizedBox(height: Tokens.spaceSm),
                        Text(
                          '“$bulletPreview”',
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.25,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (isQueued) ...[
                        const SizedBox(height: Tokens.spaceSm + 2),
                        Align(
                          alignment: Alignment.centerRight,
                          child: PSNButton(
                            label: 'Summarize',
                            size: ButtonSize.sm,
                            variant: ButtonVariant.secondary,
                            onTap: onSummarizeAgain,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, SessionStatus status) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      enableDrag: true,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(Tokens.radiusLg),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: Tokens.spaceSm + 4),
                Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: Tokens.spaceSm),
                if (status == SessionStatus.done)
                  _ActionTile(
                    label: 'Summarize again',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onSummarizeAgain?.call();
                    },
                  ),
                _ActionTile(
                  label: 'Change summary style',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onChangeStyle?.call();
                  },
                ),
                _ActionTile(
                  label: 'Delete',
                  isDestructive: true,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onDelete?.call();
                  },
                ),
                const SizedBox(height: Tokens.spaceSm),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.session,
    required this.saveMethod,
    this.textStyle,
  });

  final ListeningSession session;
  final SaveMethod saveMethod;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = DateFormat.MMMd().format(
      DateTime.fromMillisecondsSinceEpoch(session.createdAt),
    );
    final dur = _durationMinutes(session);
    final durationPart = dur > 0 ? '$dur min' : '—';
    final range = _rangeLabel(session);

    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              style: textStyle,
              children: [
                TextSpan(text: '$date · $durationPart · '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Icon(
                    _saveMethodIcon(saveMethod),
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                TextSpan(text: ' $range'),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  int _durationMinutes(ListeningSession s) {
    if (s.endTimeSec == null) return 0;
    return ((s.endTimeSec! - s.startTimeSec) / 60).round();
  }

  String _rangeLabel(ListeningSession s) {
    if (s.rangeLabel != null) return s.rangeLabel!;
    if (s.endTimeSec != null) {
      final start = _fmt(s.startTimeSec);
      final end = _fmt(s.endTimeSec!);
      return '$start – $end';
    }
    return 'Full episode';
  }

  String _fmt(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final sec = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  IconData _saveMethodIcon(SaveMethod method) {
    switch (method) {
      case SaveMethod.notification:
        return Icons.notifications_outlined;
      case SaveMethod.shake:
        return Icons.vibration_rounded;
      case SaveMethod.siri:
        return Icons.mic_none_rounded;
      case SaveMethod.googleAssistant:
        return Icons.graphic_eq_rounded;
      case SaveMethod.manual:
        return Icons.edit_outlined;
    }
  }
}

class _SessionStatusIndicator extends StatelessWidget {
  const _SessionStatusIndicator({required this.status});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (status) {
      case SessionStatus.done:
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: cs.onSurfaceVariant,
          ),
        );
      case SessionStatus.queued:
        return Padding(
          padding: const EdgeInsets.only(top: 6, right: 2),
          child: SizedBox(
            width: 8,
            height: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      case SessionStatus.summarizing:
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: cs.primary,
            ),
          ),
        );
      case SessionStatus.recording:
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: SizedBox(
            width: 8,
            height: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      case SessionStatus.error:
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: cs.onSurfaceVariant,
          ),
        );
    }
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    this.onTap,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: isDestructive ? cs.error : cs.onSurface,
            ),
      ),
      onTap: onTap,
    );
  }
}
