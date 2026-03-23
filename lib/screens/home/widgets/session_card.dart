import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/artwork_color_service.dart';
import '../../../core/haptics.dart';
import '../../../core/snipd_style.dart';
import '../../../core/tokens.dart';
import '../../../database/database.dart';
import '../../../models/summary_style.dart';
import '../../../widgets/confirm_delete_session_sheet.dart';
import '../../../widgets/psn_button.dart';
import 'podcast_artwork.dart';

/// Session row with artwork accent, glass surface, Slidable summarize/delete, completion glow.
class SessionCard extends StatefulWidget {
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
    /// Snipd-style episode row (home list).
    this.snipdListingStyle = false,
  });

  final ListeningSession session;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onSummarizeAgain;
  final VoidCallback? onChangeStyle;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onSelectionToggle;
  final bool snipdListingStyle;

  @override
  State<SessionCard> createState() => _SessionCardState();
}

int _snipBulletCount(ListeningSession s) {
  var n = 0;
  for (final b in [s.bullet1, s.bullet2, s.bullet3, s.bullet4, s.bullet5]) {
    if (b != null && b.trim().isNotEmpty) n++;
  }
  return n;
}

class _SessionCardState extends State<SessionCard>
    with SingleTickerProviderStateMixin {
  Color? _dominant;
  SessionStatus? _prevStatus;
  late AnimationController _glowController;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _prevStatus = SessionStatus.fromJson(widget.session.status);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _glow = CurvedAnimation(
      parent: _glowController,
      curve: const Interval(0, 0.35, curve: Curves.easeOut),
    );
    _loadAccent();
  }

  @override
  void didUpdateWidget(covariant SessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.artworkUrl != widget.session.artworkUrl) {
      _loadAccent();
    }
    final now = SessionStatus.fromJson(widget.session.status);
    if (_prevStatus == SessionStatus.summarizing &&
        now == SessionStatus.done) {
      _glowController.forward(from: 0);
    }
    _prevStatus = now;
  }

  Future<void> _loadAccent() async {
    final c = await ArtworkColorService.getDominantColor(
      widget.session.artworkUrl,
    );
    if (mounted) setState(() => _dominant = c);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final status = SessionStatus.fromJson(widget.session.status);
    final saveMethod = SaveMethod.fromJson(widget.session.saveMethod);

    if (widget.snipdListingStyle) {
      return _buildSnipdListing(context, cs, tt, status);
    }
    final bulletPreview = widget.session.bullet1;
    final hasPreview = status == SessionStatus.done && bulletPreview != null;
    final isQueued = status == SessionStatus.queued;
    final accent = _dominant ?? cs.primary;

    final cardCore = _buildCardCore(
      context,
      cs: cs,
      tt: tt,
      status: status,
      saveMethod: saveMethod,
      hasPreview: hasPreview,
      isQueued: isQueued,
      bulletPreview: bulletPreview,
      accent: accent,
    );

    final shadowed = AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final t = _glow.value;
        final greenGlow = Color.lerp(
          Colors.transparent,
          const Color(0xFF10B981).withValues(alpha: 0.55),
          t,
        )!;
        // No grey/black card shadows — only a brief green glow when a summary completes.
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
            boxShadow: [
              if (t > 0.01)
                BoxShadow(
                  color: greenGlow,
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: child,
        );
      },
      child: cardCore,
    );

    if (widget.selectionMode) {
      return Transform.translate(
        offset: const Offset(0, -2),
        child: shadowed,
      );
    }

    return Transform.translate(
      offset: const Offset(0, -2),
      child: Slidable(
        key: ValueKey('slidable-${widget.session.id}'),
        startActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.28,
          children: [
            SlidableAction(
              onPressed: (ctx) {
                Slidable.of(ctx)?.close();
                PSNHaptics.select();
                widget.onSummarizeAgain?.call();
              },
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              icon: Icons.bolt_rounded,
              label: 'Summarize',
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.28,
          children: [
            SlidableAction(
              onPressed: (ctx) async {
                Slidable.of(ctx)?.close();
                PSNHaptics.select();
                final ok = await showConfirmDeleteSessionSheet(
                  context,
                  widget.session.title,
                );
                if (ok == true) {
                  await PSNHaptics.delete();
                  widget.onDelete?.call();
                }
              },
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
            ),
          ],
        ),
        child: shadowed,
      ),
    );
  }

  Widget _buildSnipdListing(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    SessionStatus status,
  ) {
    final s = widget.session;
    final bulletPreview = s.bullet1;
    final hasPreview = status == SessionStatus.done && bulletPreview != null;
    final isQueued = status == SessionStatus.queued;
    final bulletCount = _snipBulletCount(s);
    final snipLabel = switch (status) {
      SessionStatus.summarizing => '…',
      SessionStatus.done => '$bulletCount',
      _ => '—',
    };

    final row = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.selectionMode ? widget.onSelectionToggle : widget.onTap,
        onLongPress: widget.selectionMode
            ? null
            : () => _showContextMenu(context, status),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: SnipdStyle.borderSubtle),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.selectionMode) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 24),
                  child: Checkbox.adaptive(
                    value: widget.isSelected,
                    onChanged: (_) => widget.onSelectionToggle?.call(),
                    activeColor: SnipdStyle.accent,
                    checkColor: SnipdStyle.bgDeep,
                  ),
                ),
              ],
              PodcastArtwork(
                imageUrl: s.artworkUrl,
                labelForInitials: s.artist,
                size: 80,
                borderRadius: 12,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: SnipdStyle.accent.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.local_fire_department_rounded,
                                size: 11,
                                color: SnipdStyle.accent,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              snipLabel,
                              style: tt.labelSmall?.copyWith(
                                fontSize: 12,
                                color: SnipdStyle.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        _StatusDot(status: status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.title,
                      style: tt.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: SnipdStyle.title,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.artist,
                      style: tt.bodySmall?.copyWith(
                        color: SnipdStyle.meta,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (s.tags != null && s.tags!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: s.tags!
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .map(
                              (t) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: SnipdStyle.meta
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  t,
                                  style: tt.labelSmall?.copyWith(
                                    fontSize: 10,
                                    color: SnipdStyle.meta,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _SnipdMetaRow(session: s, status: status),
                    if (hasPreview) ...[
                      const SizedBox(height: 8),
                      Text(
                        bulletPreview,
                        style: tt.bodySmall?.copyWith(
                          color: SnipdStyle.meta,
                          height: 1.25,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (isQueued) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: PSNButton(
                          label: 'Summarize',
                          size: ButtonSize.sm,
                          variant: ButtonVariant.secondary,
                          onTap: widget.onSummarizeAgain,
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
    );

    if (widget.selectionMode) {
      return row;
    }

    return Slidable(
      key: ValueKey('slidable-snipd-${widget.session.id}'),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        children: [
          SlidableAction(
            onPressed: (ctx) {
              Slidable.of(ctx)?.close();
              PSNHaptics.select();
              widget.onSummarizeAgain?.call();
            },
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            icon: Icons.bolt_rounded,
            label: 'Summarize',
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        children: [
          SlidableAction(
            onPressed: (ctx) async {
              Slidable.of(ctx)?.close();
              PSNHaptics.select();
              final ok = await showConfirmDeleteSessionSheet(
                context,
                widget.session.title,
              );
              if (ok == true) {
                await PSNHaptics.delete();
                widget.onDelete?.call();
              }
            },
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
          ),
        ],
      ),
      child: row,
    );
  }

  Widget _buildCardCore(
    BuildContext context, {
    required ColorScheme cs,
    required TextTheme tt,
    required SessionStatus status,
    required SaveMethod saveMethod,
    required bool hasPreview,
    required bool isQueued,
    required String? bulletPreview,
    required Color accent,
  }) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: accent),
      duration: const Duration(milliseconds: 400),
      builder: (context, borderColor, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.06),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.selectionMode
                      ? widget.onSelectionToggle
                      : widget.onTap,
                  onLongPress: widget.selectionMode
                      ? null
                      : () => _showContextMenu(context, status),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 3,
                          color: borderColor ?? cs.primary,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(Tokens.spaceMd),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.selectionMode) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      right: Tokens.spaceSm,
                                    ),
                                    child: Checkbox.adaptive(
                                      value: widget.isSelected,
                                      onChanged: (_) =>
                                          widget.onSelectionToggle?.call(),
                                    ),
                                  ),
                                ],
                                PodcastArtwork(
                                  imageUrl: widget.session.artworkUrl,
                                  labelForInitials: widget.session.artist,
                                  size: 64,
                                  borderRadius: 10,
                                ),
                                const SizedBox(width: Tokens.spaceSm + 4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              widget.session.title,
                                              style: GoogleFonts.syne(
                                                textStyle: tt.titleMedium
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: cs.onSurface,
                                                  height: 1.2,
                                                ),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: Tokens.spaceSm),
                                          _StatusDot(status: status),
                                        ],
                                      ),
                                      const SizedBox(height: Tokens.spaceXs),
                                      Text(
                                        widget.session.artist,
                                        style: tt.bodySmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: Tokens.spaceXs + 2),
                                      _MetadataRowStyled(
                                        session: widget.session,
                                        saveMethod: saveMethod,
                                        cs: cs,
                                        tt: tt,
                                      ),
                                      if (hasPreview &&
                                          bulletPreview != null) ...[
                                        const SizedBox(height: Tokens.spaceSm),
                                        ShaderMask(
                                          shaderCallback: (bounds) {
                                            return LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.white,
                                                Colors.white
                                                    .withValues(alpha: 0),
                                              ],
                                              stops: const [0.55, 1],
                                            ).createShader(bounds);
                                          },
                                          blendMode: BlendMode.dstIn,
                                          child: Text(
                                            bulletPreview,
                                            style: tt.bodySmall?.copyWith(
                                              color: cs.onSurfaceVariant,
                                              height: 1.25,
                                              fontStyle: FontStyle.italic,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                      if (isQueued) ...[
                                        const SizedBox(height: Tokens.spaceSm),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: PSNButton(
                                            label: 'Summarize',
                                            size: ButtonSize.sm,
                                            variant: ButtonVariant.secondary,
                                            onTap: widget.onSummarizeAgain,
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
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
                      widget.onSummarizeAgain?.call();
                    },
                  ),
                _ActionTile(
                  label: 'Change summary style',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    widget.onChangeStyle?.call();
                  },
                ),
                _ActionTile(
                  label: 'Delete',
                  isDestructive: true,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    widget.onDelete?.call();
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

class _SnipdMetaRow extends StatelessWidget {
  const _SnipdMetaRow({
    required this.session,
    required this.status,
  });

  final ListeningSession session;
  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final date = DateFormat.MMMd().format(
      DateTime.fromMillisecondsSinceEpoch(session.createdAt),
    );
    final dur = session.endTimeSec == null
        ? 0
        : ((session.endTimeSec! - session.startTimeSec) / 60).round();
    final durationPart = dur > 0 ? '$dur min' : '—';

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: SnipdStyle.chipFill,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status.label,
            style: tt.labelSmall?.copyWith(
              color: SnipdStyle.accent,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
        Text(
          date,
          style: tt.labelSmall?.copyWith(
            color: SnipdStyle.meta,
            fontSize: 12,
          ),
        ),
        Text(
          '·',
          style: TextStyle(color: SnipdStyle.meta, fontSize: 12),
        ),
        Text(
          durationPart,
          style: tt.labelSmall?.copyWith(
            color: SnipdStyle.meta,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _MetadataRowStyled extends StatelessWidget {
  const _MetadataRowStyled({
    required this.session,
    required this.saveMethod,
    required this.cs,
    required this.tt,
  });

  final ListeningSession session;
  final SaveMethod saveMethod;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.MMMd().format(
      DateTime.fromMillisecondsSinceEpoch(session.createdAt),
    );
    final dur = _durationMinutes(session);
    final durationPart = dur > 0 ? '$dur min' : '—';
    final range = _rangeLabel(session);

    return Row(
      children: [
        Icon(_saveMethodIcon(saveMethod), size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Icon(Icons.schedule_rounded, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            range,
            style: tt.labelSmall?.copyWith(
              fontFamily: 'monospace',
              fontFeatures: const [FontFeature.tabularFigures()],
              color: cs.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(Tokens.radiusFull),
          ),
          child: Text(
            durationPart,
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          date,
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
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

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (status) {
      case SessionStatus.done:
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: const Color(0xFF10B981),
          ),
        );
      case SessionStatus.queued:
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant,
              shape: BoxShape.circle,
            ),
          ),
        );
      case SessionStatus.summarizing:
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: cs.primary,
            ),
          ),
        );
      case SessionStatus.recording:
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
        );
      case SessionStatus.error:
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: cs.error,
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
