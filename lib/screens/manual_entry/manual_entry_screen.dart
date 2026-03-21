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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Episode'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.spaceMd),
        children: [
          Text('What were you listening to?', style: Tokens.headingM),
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
          Text('Approximate time range', style: Tokens.headingS),
          const SizedBox(height: Tokens.spaceSm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
            label: 'Save & Summarize',
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Tokens.durationFast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Tokens.accentDim : Tokens.bgElevated,
          borderRadius: BorderRadius.circular(Tokens.radiusFull),
          border: Border.all(
            color: selected ? Tokens.accent : Tokens.borderLight,
          ),
        ),
        child: Text(
          label,
          style: Tokens.bodyS.copyWith(
            color: selected ? Tokens.accent : Tokens.textSecond,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
