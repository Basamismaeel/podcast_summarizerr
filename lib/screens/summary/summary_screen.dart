import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens.dart';
import '../../models/summary_style.dart';
import '../../providers/session_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionByIdProvider(widget.sessionId));

    return Scaffold(
      backgroundColor: Tokens.bgPrimary,
      appBar: AppBar(
        title: const Text('Summary'),
        leading: const BackButton(),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
              // ── Episode header ─────────────────────────────
              Text(session.title, style: Tokens.headingL),
              const SizedBox(height: 4),
              Text(session.artist, style: Tokens.bodyM),
              if (session.rangeLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  session.rangeLabel!,
                  style: Tokens.bodyS.copyWith(color: Tokens.accent),
                ),
              ],

              const SizedBox(height: Tokens.spaceLg),

              // ── Status banner ──────────────────────────────
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

              // ── Summary content ────────────────────────────
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
                    style: Tokens.bodyL,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PRIVATE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});
  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final isSummarizing = status == SessionStatus.summarizing;
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.spaceLg),
      padding: const EdgeInsets.all(Tokens.spaceMd),
      decoration: BoxDecoration(
        color: Tokens.accentDim,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.accentBorder),
      ),
      child: Row(
        children: [
          if (isSummarizing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Tokens.accent,
              ),
            )
          else
            const Icon(Icons.hourglass_top_rounded,
                color: Tokens.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isSummarizing
                  ? 'Summarizing your podcast moment...'
                  : 'Queued — will start summarizing shortly',
              style: Tokens.bodyM.copyWith(color: Tokens.textPrimary),
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
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.spaceLg),
      padding: const EdgeInsets.all(Tokens.spaceMd),
      decoration: BoxDecoration(
        color: Tokens.errorDim,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.error.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Tokens.error, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Tokens.bodyM.copyWith(color: Tokens.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Tokens.textPrimary,
                side: const BorderSide(color: Tokens.borderMedium),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                ),
              ),
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
    return Text(
      text.toUpperCase(),
      style: Tokens.label.copyWith(color: Tokens.accent),
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
    final match = _timestampRe.firstMatch(text);
    final timestamp = match?.group(1);
    final cleanText = match != null ? text.substring(match.end) : text;

    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.spaceSm),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Tokens.bgElevated,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.borderSubtle),
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
                  color: Tokens.accentDim,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: Tokens.bodyS.copyWith(
                    color: Tokens.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (timestamp != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Tokens.accent.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    timestamp,
                    style: Tokens.bodyS.copyWith(
                      color: Tokens.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              cleanText,
              style: Tokens.bodyM.copyWith(
                color: Tokens.textPrimary,
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
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.spaceSm),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Tokens.bgElevated,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"',
            style: Tokens.headingL.copyWith(
              color: Tokens.accent,
              height: 1,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Tokens.bodyM.copyWith(
                color: Tokens.textPrimary,
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
