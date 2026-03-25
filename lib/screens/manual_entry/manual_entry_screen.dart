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

  String _selectedRange = '0–15 min';

  /// Audiobook / book-style saves skip time-range UI (chapters drive the summary).
  bool _audiobookMode = false;

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _entryRowFactories(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add episode'),
        leading: const BackButton(),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(Tokens.spaceMd),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: false,
        cacheExtent: 500,
        itemCount: rows.length,
        itemBuilder: (context, index) => rows[index](),
      ),
    );
  }

  bool get _canSubmit => _audiobookMode
      ? _titleController.text.isNotEmpty
      : _titleController.text.isNotEmpty && _artistController.text.isNotEmpty;

  List<Widget Function()> _entryRowFactories(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return [
      () => Text(
            'What were you listening to?',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
      () => const SizedBox(height: Tokens.spaceSm),
      () => SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                label: Text('Podcast'),
                icon: Icon(Icons.podcasts_outlined, size: 18),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('Audiobook'),
                icon: Icon(Icons.menu_book_outlined, size: 18),
              ),
            ],
            selected: {_audiobookMode},
            onSelectionChanged: (set) {
              higLightTap();
              setState(() => _audiobookMode = set.first);
            },
            showSelectedIcon: false,
          ),
      () => const SizedBox(height: Tokens.spaceMd),
      () => FutureBuilder<List<String>>(
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
                      color: cs.onSurfaceVariant,
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
                            backgroundColor: cs.surfaceContainerHighest,
                            side: BorderSide(
                              color: cs.outlineVariant.withValues(alpha: 0.5),
                            ),
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
      () => PSNTextField(
            placeholder: 'Episode title',
            controller: _titleController,
          ),
      () => const SizedBox(height: Tokens.spaceSm),
      () => PSNTextField(
            placeholder:
                _audiobookMode ? 'Author (optional)' : 'Podcast / show name',
            controller: _artistController,
          ),
      if (!_audiobookMode) ...[
        () => const SizedBox(height: Tokens.spaceMd),
        () => Text(
              'Approximate time range',
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
        () => const SizedBox(height: 6),
        () => Text(
              'Tap the waveform, then refine with a chip.',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
        () => const SizedBox(height: Tokens.spaceSm),
        () => Material(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(Tokens.radiusMd),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _WaveformScrubber(
                  onSegmentChosen: (label) {
                    setState(() => _selectedRange = label);
                  },
                ),
              ),
            ),
        () => const SizedBox(height: Tokens.spaceSm),
        () => Wrap(
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
      ] else ...[
        () => const SizedBox(height: Tokens.spaceMd),
        () => Text(
              'No time range — paste or open an Audible link from Home to match the catalog, or summarize from a book link.',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
      ],
      () => const SizedBox(height: Tokens.spaceXl),
      () => PSNButton(
            label: 'Save & summarize',
            fullWidth: true,
            onTap: _canSubmit ? _submit : null,
          ),
    ];
  }

  Future<void> _submit() async {
    final actions = ref.read(sessionActionsProvider);
    final artist = _artistController.text.trim();
    if (_audiobookMode) {
      await actions.createAndSummarize(
        title: _titleController.text.trim(),
        artist: artist.isNotEmpty ? artist : 'Audiobook',
        saveMethod: SaveMethod.manual,
        startTimeSec: 0,
        endTimeSec: null,
        rangeLabel: null,
        sourceApp: 'audible',
      );
    } else {
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
    }
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
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
            child: SizedBox(
              height: 44,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(48, (i) {
                  final h = 10.0 + (i % 7) * 3.0 + (i % 3) * 2.0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(
                            alpha: 0.18 + (i % 5) * 0.06,
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tokens.radiusFull),
        child: AnimatedContainer(
          duration: Tokens.durationFast,
          curve: Tokens.springCurve,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: selected
                ? cs.primaryContainer
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(Tokens.radiusFull),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.35)
                  : cs.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Text(
            label,
            style: tt.labelMedium?.copyWith(
              color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
