import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/haptics.dart';
import '../../core/moments_stats_service.dart';
import '../../core/tokens.dart';
import '../../models/summary_style.dart';
import '../../providers/session_provider.dart';
import '../../widgets/psn_button.dart';
import '../../widgets/psn_text_field.dart';

class ManualEntryScreen extends ConsumerStatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  ConsumerState<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends ConsumerState<ManualEntryScreen> {
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();

  /// Coarse range → episode seconds (end `null` = from [start] to episode end).
  static ({int start, int? end}) _boundsForRangeLabel(String label) {
    switch (label) {
      case '0–15 min':
        return (start: 0, end: 15 * 60);
      case '15–30 min':
        return (start: 15 * 60, end: 30 * 60);
      case '30–60 min':
        return (start: 30 * 60, end: 60 * 60);
      case '60+ min':
        return (start: 60 * 60, end: null);
      default:
        return (start: 0, end: 15 * 60);
    }
  }

  /// Default so pipeline always gets an explicit window (not “whole episode from 0”).
  String _selectedRange = '0–15 min';

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add episode'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.spaceMd),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: [
          Text(
            'What were you listening to?',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Tokens.spaceMd),
          FutureBuilder<List<String>>(
            future: MomentsStatsService.getRecentManualPodcasts(),
            builder: (context, snap) {
              final recent = snap.data ?? [];
              if (recent.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recently searched',
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Tokens.spaceSm),
                  Wrap(
                    spacing: Tokens.spaceSm,
                    runSpacing: Tokens.spaceSm,
                    children: recent
                        .map(
                          (name) => ActionChip(
                            label: Text(name),
                            onPressed: () {
                              higLightTap();
                              setState(() {
                                _artistController.text = name;
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: Tokens.spaceLg),
                ],
              );
            },
          ),
          PSNTextField(
            placeholder: 'Episode title',
            controller: _titleController,
          ),
          const SizedBox(height: Tokens.spaceSm),
          PSNTextField(
            placeholder: 'Podcast / show name',
            controller: _artistController,
          ),
          const SizedBox(height: Tokens.spaceLg),
          Text(
            'Approximate time range',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Tokens.spaceSm),
          Text(
            'Tap the waveform to pick where you were in the episode.',
            style: tt.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Tokens.spaceSm),
          _WaveformScrubber(
            onSegmentChosen: (label) {
              setState(() => _selectedRange = label);
            },
          ),
          const SizedBox(height: Tokens.spaceMd),
          Wrap(
            spacing: Tokens.spaceSm,
            runSpacing: Tokens.spaceSm,
            children: ['0–15 min', '15–30 min', '30–60 min', '60+ min']
                .map((range) => _RangeChip(
                      label: range,
                      selected: _selectedRange == range,
                      onTap: () => setState(() => _selectedRange = range),
                    ))
                .toList(),
          ),
          const SizedBox(height: Tokens.spaceXl),
          PSNButton(
            label: 'Save & summarize',
            fullWidth: true,
            onTap: _canSubmit ? _submit : null,
          ),
        ],
      ),
    );
  }

  bool get _canSubmit =>
      _titleController.text.isNotEmpty && _artistController.text.isNotEmpty;

  Future<void> _submit() async {
    final actions = ref.read(sessionActionsProvider);
    final artist = _artistController.text.trim();
    final bounds = _boundsForRangeLabel(_selectedRange);
    await MomentsStatsService.recordManualPodcast(artist);
    await actions.createAndSummarize(
      title: _titleController.text.trim(),
      artist: artist,
      saveMethod: SaveMethod.manual,
      startTimeSec: bounds.start,
      endTimeSec: bounds.end,
      rangeLabel: _selectedRange,
    );
    if (mounted) await PSNHaptics.momentSaved();
    if (mounted) context.pop();
  }
}

/// Stylized waveform bar — tap maps to coarse time-range chips.
class _WaveformScrubber extends StatelessWidget {
  const _WaveformScrubber({required this.onSegmentChosen});

  final ValueChanged<String> onSegmentChosen;

  static const _segments = [
    ('0–15 min', 0.0, 0.25),
    ('15–30 min', 0.25, 0.5),
    ('30–60 min', 0.5, 0.75),
    ('60+ min', 0.75, 1.0),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, c) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            higLightTap();
            final x = d.localPosition.dx / c.maxWidth;
            for (final s in _segments) {
              if (x >= s.$2 && x < s.$3) {
                onSegmentChosen(s.$1);
                return;
              }
            }
            onSegmentChosen(_segments.last.$1);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
            child: SizedBox(
              height: 56,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(48, (i) {
                  final h = 12.0 + (i % 7) * 4.0 + (i % 3) * 3.0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(
                            alpha: 0.25 + (i % 5) * 0.08,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: SizedBox(height: h),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tokens.radiusFull),
      child: AnimatedContainer(
        duration: Tokens.durationFast,
        curve: Tokens.springCurve,
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.spaceMd,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Tokens.radiusFull),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: tt.bodySmall?.copyWith(
            color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
