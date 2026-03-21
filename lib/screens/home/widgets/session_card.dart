import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/tokens.dart';
import '../../../database/database.dart';
import '../../../models/summary_style.dart';
import '../../../widgets/psn_button.dart';
import 'podcast_artwork.dart';

/// Apple Podcasts–inspired row card: artwork, typography from [TextTheme], shadow (no border).
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    this.onTap,
    this.onDelete,
    this.onSummarizeAgain,
    this.onChangeStyle,
  });

  final ListeningSession session;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onSummarizeAgain;
  final VoidCallback? onChangeStyle;

  static const _metaGray = Color(0xFF8E8E93);
  static const _cardBg = Color(0xFF1C1C1E);
  static const _cardShadow = BoxShadow(
    color: Colors.black54,
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  TextStyle _sfText(BuildContext context, {
    required double fontSize,
    FontWeight? weight,
    Color? color,
    double? height,
  }) {
    final useSf = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS;
    return TextStyle(
      fontFamily: useSf ? '.SF Pro Text' : null,
      fontSize: fontSize,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = SessionStatus.fromJson(session.status);
    final saveMethod = SaveMethod.fromJson(session.saveMethod);
    final bulletPreview = session.bullet1;
    final hasPreview = status == SessionStatus.done && bulletPreview != null;
    final isQueued = status == SessionStatus.queued;

    return GestureDetector(
      onLongPress: () => _showContextMenu(context, status),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [_cardShadow],
        ),
        child: Material(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PodcastArtwork(
                    imageUrl: session.artworkUrl,
                    labelForInitials: session.artist,
                    size: 56,
                    borderRadius: 12,
                  ),
                  const SizedBox(width: 14),
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
                                style: _sfText(
                                  context,
                                  fontSize: 17,
                                  weight: FontWeight.w600,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _SessionStatusIndicator(status: status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          session.artist,
                          style: _sfText(
                            context,
                            fontSize: 13,
                            weight: FontWeight.w400,
                            color: _metaGray,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _metadataLine(session, saveMethod),
                          style: _sfText(
                            context,
                            fontSize: 13,
                            weight: FontWeight.w400,
                            color: _metaGray,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasPreview) ...[
                          const SizedBox(height: 8),
                          Text(
                            '“$bulletPreview”',
                            style: _sfText(
                              context,
                              fontSize: 13,
                              weight: FontWeight.w400,
                              color: _metaGray,
                              height: 1.25,
                            ).copyWith(fontStyle: FontStyle.italic),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (isQueued) ...[
                          const SizedBox(height: 10),
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
      ),
    );
  }

  String _metadataLine(ListeningSession s, SaveMethod method) {
    final date = DateFormat.MMMd().format(
      DateTime.fromMillisecondsSinceEpoch(s.createdAt),
    );
    final dur = _durationMinutes(s);
    final durationPart = dur > 0 ? '$dur min' : '—';
    final range = _rangeLabel(s);
    return '$date · $durationPart · ${_saveMethodGlyph(method)} $range';
  }

  String _saveMethodGlyph(SaveMethod method) {
    switch (method) {
      case SaveMethod.notification:
        return '🔔';
      case SaveMethod.shake:
        return '📳';
      case SaveMethod.siri:
        return '🍎';
      case SaveMethod.googleAssistant:
        return '🎤';
      case SaveMethod.manual:
        return '✏️';
    }
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

  int _durationMinutes(ListeningSession s) {
    if (s.endTimeSec == null) return 0;
    return ((s.endTimeSec! - s.startTimeSec) / 60).round();
  }

  void _showContextMenu(BuildContext context, SessionStatus status) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: Tokens.bgSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(Tokens.radiusLg),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Tokens.borderMedium,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
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

/// Subtle status: Done = checkmark only; Queued = gray dot; Summarizing = indigo spinner; etc.
class _SessionStatusIndicator extends StatelessWidget {
  const _SessionStatusIndicator({required this.status});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case SessionStatus.done:
        return const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: Color(0xFF8E8E93),
          ),
        );
      case SessionStatus.queued:
        return const Padding(
          padding: EdgeInsets.only(top: 6, right: 2),
          child: SizedBox(
            width: 8,
            height: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF8E8E93),
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
              color: Tokens.accent,
            ),
          ),
        );
      case SessionStatus.recording:
        return const Padding(
          padding: EdgeInsets.only(top: 6),
          child: SizedBox(
            width: 8,
            height: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Tokens.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      case SessionStatus.error:
        return const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: Color(0xFF8E8E93),
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
    return ListTile(
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: isDestructive ? Tokens.error : Tokens.textPrimary,
            ),
      ),
      onTap: onTap,
    );
  }
}
