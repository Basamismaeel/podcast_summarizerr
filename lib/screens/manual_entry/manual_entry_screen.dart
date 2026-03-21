import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  String? _selectedRange;

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
        children: [
          Text(
            'What were you listening to?',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Tokens.spaceMd),
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
    await actions.createAndSummarize(
      title: _titleController.text.trim(),
      artist: _artistController.text.trim(),
      saveMethod: SaveMethod.manual,
      startTimeSec: 0,
      rangeLabel: _selectedRange,
    );
    if (mounted) context.pop();
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
