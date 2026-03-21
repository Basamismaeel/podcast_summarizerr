import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/haptics.dart';
import '../../core/tokens.dart';
import '../../database/database.dart';
import '../../models/summary_style.dart';
import '../../providers/session_provider.dart';
import '../../widgets/confirm_delete_session_sheet.dart';
import '../../widgets/psn_skeleton.dart';

class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      ref.invalidate(sessionByIdProvider(widget.sessionId));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _deleteMoment(BuildContext context, ListeningSession session) async {
    higLightTap();
    final ok = await showConfirmDeleteSessionSheet(context, session.title);
    if (ok != true || !context.mounted) return;
    await ref.read(sessionDaoProvider).deleteSession(session.id);
    ref.invalidate(sessionByIdProvider(widget.sessionId));
    ref.invalidate(allSessionsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed “${session.title}”'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionByIdProvider(widget.sessionId));
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final deleteActions = <Widget>[
      ...switch (sessionAsync) {
        AsyncData(:final value) when value != null => [
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Delete summary',
              color: cs.error,
              onPressed: () => _deleteMoment(context, value),
            ),
          ],
        _ => <Widget>[],
      },
    ];

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Summary'),
        leading: const BackButton(),
        actions: deleteActions,
      ),
      body: sessionAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Tokens.spaceMd),
          child: PSNSkeleton(lines: 5),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (session) {
          if (session == null) {
            return const Center(child: Text('Session not found'));
          }

          final status = SessionStatus.fromJson(session.status);
          final style = SummaryStyle.fromJson(session.summaryStyle);
          final bullets = [
            session.bullet1,
            session.bullet2,
            session.bullet3,
            session.bullet4,
            session.bullet5,
          ].whereType<String>().toList();
          final quotes = [
            session.quote1,
            session.quote2,
            session.quote3,
          ].whereType<String>().toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Tokens.spaceMd,
              0,
              Tokens.spaceMd,
              Tokens.spaceXl,
            ),
            children: [
              Text(
                session.title,
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: Tokens.spaceXs),
              Text(
                session.artist,
                style: tt.bodyLarge,
              ),
              if (session.rangeLabel != null) ...[
                const SizedBox(height: Tokens.spaceXs),
                Text(
                  session.rangeLabel!,
                  style: tt.bodyMedium?.copyWith(color: cs.primary),
                ),
              ],

              const SizedBox(height: Tokens.spaceLg),

              if (status == SessionStatus.queued ||
                  status == SessionStatus.summarizing)
                _StatusCard(status: status),

              if (status == SessionStatus.error)
                _ErrorCard(
                  message: session.errorMessage ??
                      'Something went wrong — tap to retry',
                  onRetry: () {
                    ref.read(sessionActionsProvider).retrySummary(
                          widget.sessionId,
                          style: style,
                        );
                    ref.invalidate(sessionByIdProvider(widget.sessionId));
                  },
                ),

              if (status == SessionStatus.done && bullets.isNotEmpty) ...[
                if (style != null) ...[
                  _SectionLabel(text: '${style.icon}  ${style.label}'),
                  const SizedBox(height: Tokens.spaceSm),
                ],
                ...bullets.asMap().entries.map((e) => _BulletCard(
                      index: e.key + 1,
                      text: e.value,
                    )),
                if (quotes.isNotEmpty) ...[
                  const SizedBox(height: Tokens.spaceLg),
                  const _SectionLabel(text: 'Key Quotes'),
                  const SizedBox(height: Tokens.spaceSm),
                  ...quotes.map((q) => _QuoteCard(text: q)),
                ],
              ],

              if (status == SessionStatus.done && bullets.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Tokens.spaceLg),
                  child: Text(
                    'No summary content available.',
                    style: tt.bodyLarge,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});
  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isSummarizing = status == SessionStatus.summarizing;
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.spaceLg),
      padding: const EdgeInsets.all(Tokens.spaceMd),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          if (isSummarizing)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            )
          else
            Icon(Icons.hourglass_top_rounded, color: cs.primary, size: 20),
          const SizedBox(width: Tokens.spaceSm + 4),
          Expanded(
            child: Text(
              isSummarizing
                  ? 'Summarizing your podcast moment...'
                  : 'Queued — will start summarizing shortly',
              style: tt.bodyLarge?.copyWith(color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.spaceLg),
      padding: const EdgeInsets.all(Tokens.spaceMd),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: cs.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, color: cs.error, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.spaceSm + 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Text(
      text.toUpperCase(),
      style: tt.labelLarge?.copyWith(
        color: cs.primary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _BulletCard extends StatelessWidget {
  const _BulletCard({required this.index, required this.text});
  final int index;
  final String text;

  static final _timestampRe = RegExp(r'^\[(\d{1,2}:\d{2})\]\s*');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final match = _timestampRe.firstMatch(text);
    final timestamp = match?.group(1);
    final cleanText = match != null ? text.substring(match.end) : text;

    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.spaceSm),
      padding: const EdgeInsets.all(Tokens.spaceSm + 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: tt.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (timestamp != null) ...[
                const SizedBox(height: Tokens.spaceXs + 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Tokens.radiusXs + 2),
                  ),
                  child: Text(
                    timestamp,
                    style: tt.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: Tokens.spaceSm + 4),
          Expanded(
            child: Text(
              cleanText,
              style: tt.bodyLarge?.copyWith(
                color: cs.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.spaceSm),
      padding: const EdgeInsets.all(Tokens.spaceSm + 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"',
            style: tt.headlineSmall?.copyWith(
              color: cs.primary,
              height: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: tt.bodyLarge?.copyWith(
                color: cs.onSurface,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
