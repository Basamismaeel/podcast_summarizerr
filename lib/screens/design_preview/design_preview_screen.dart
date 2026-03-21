import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import '../../widgets/psn_button.dart';
import '../../widgets/psn_card.dart';
import '../../widgets/psn_divider.dart';
import '../../widgets/psn_empty_state.dart';
import '../../widgets/psn_snackbar.dart';
import '../../widgets/psn_status_badge.dart';
import '../../widgets/psn_text_field.dart';

class DesignPreviewScreen extends StatelessWidget {
  const DesignPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design System')),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.spaceMd),
        children: [
          _section('Typography'),
          Text('Heading XL — Syne 28', style: Tokens.headingXL),
          SizedBox(height: Tokens.spaceSm),
          Text('Heading L — Syne 22', style: Tokens.headingL),
          SizedBox(height: Tokens.spaceSm),
          Text('Heading M — Syne 18', style: Tokens.headingM),
          SizedBox(height: Tokens.spaceSm),
          Text('Heading S — Syne 15', style: Tokens.headingS),
          SizedBox(height: Tokens.spaceSm),
          Text('Body L — DM Sans 16', style: Tokens.bodyL),
          SizedBox(height: Tokens.spaceSm),
          Text('Body M — DM Sans 14', style: Tokens.bodyM),
          SizedBox(height: Tokens.spaceSm),
          Text('Body S — DM Sans 12', style: Tokens.bodyS),
          SizedBox(height: Tokens.spaceSm),
          Text('LABEL — DM SANS 11', style: Tokens.label),
          SizedBox(height: Tokens.spaceSm),
          Text('00:42:13 — DM Mono 13', style: Tokens.mono),

          SizedBox(height: Tokens.spaceXl),
          _section('Primary Buttons'),
          PSNButton(label: 'Primary', onTap: () {}),
          SizedBox(height: Tokens.spaceSm),
          PSNButton(
            label: 'With Icon',
            icon: const Icon(Icons.mic, size: 18, color: Colors.white),
            onTap: () {},
          ),
          SizedBox(height: Tokens.spaceSm),
          const PSNButton(label: 'Disabled'),
          SizedBox(height: Tokens.spaceSm),
          const PSNButton(label: 'Loading...', isLoading: true, onTap: _noop),
          SizedBox(height: Tokens.spaceSm),
          PSNButton(label: 'Full Width', onTap: () {}, fullWidth: true),

          SizedBox(height: Tokens.spaceLg),
          _section('Button Variants'),
          PSNButton(
            label: 'Secondary',
            variant: ButtonVariant.secondary,
            onTap: () {},
          ),
          SizedBox(height: Tokens.spaceSm),
          PSNButton(
            label: 'Ghost',
            variant: ButtonVariant.ghost,
            onTap: () {},
          ),
          SizedBox(height: Tokens.spaceSm),
          PSNButton(
            label: 'Danger',
            variant: ButtonVariant.danger,
            onTap: () {},
          ),

          SizedBox(height: Tokens.spaceXl),
          _section('Status Badges'),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PSNStatusBadge(status: SessionStatus.recording),
              PSNStatusBadge(status: SessionStatus.queued),
              PSNStatusBadge(status: SessionStatus.summarizing),
              PSNStatusBadge(status: SessionStatus.done),
              PSNStatusBadge(status: SessionStatus.error),
            ],
          ),

          SizedBox(height: Tokens.spaceXl),
          _section('Cards'),
          PSNCard(
            onTap: () {},
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Episode #142', style: Tokens.headingS),
                      const SizedBox(height: 4),
                      Text('Tap to expand', style: Tokens.bodyS),
                    ],
                  ),
                ),
                const PSNStatusBadge(status: SessionStatus.done),
              ],
            ),
          ),
          SizedBox(height: Tokens.spaceSm),
          PSNCard(
            glowColor: Tokens.accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Accent Glow Card', style: Tokens.headingS),
                const SizedBox(height: 4),
                Text('With indigo glow shadow', style: Tokens.bodyM),
              ],
            ),
          ),

          SizedBox(height: Tokens.spaceXl),
          _section('Text Fields'),
          PSNTextField(
            placeholder: 'Search episodes…',
            prefixIcon: Icons.search,
          ),
          SizedBox(height: Tokens.spaceSm),
          PSNTextField(
            placeholder: 'Enter podcast URL',
            suffix: Icon(Icons.link, color: Tokens.textMuted, size: 18),
          ),

          SizedBox(height: Tokens.spaceXl),
          _section('Dividers'),
          const PSNDivider(),
          SizedBox(height: Tokens.spaceMd),
          const PSNDivider(label: 'or continue with'),

          SizedBox(height: Tokens.spaceXl),
          _section('Snackbars'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PSNButton(
                label: 'Success',
                size: ButtonSize.sm,
                onTap: () => PSNSnackbar.show(
                  context,
                  'Episode saved successfully',
                  PSNSnackbarType.success,
                ),
              ),
              PSNButton(
                label: 'Error',
                size: ButtonSize.sm,
                variant: ButtonVariant.danger,
                onTap: () => PSNSnackbar.show(
                  context,
                  'Failed to process audio',
                  PSNSnackbarType.error,
                ),
              ),
              PSNButton(
                label: 'Info',
                size: ButtonSize.sm,
                variant: ButtonVariant.secondary,
                onTap: () => PSNSnackbar.show(
                  context,
                  'Summarization in progress…',
                  PSNSnackbarType.info,
                ),
              ),
            ],
          ),

          SizedBox(height: Tokens.spaceXl),
          _section('Empty State'),
          SizedBox(
            height: 280,
            child: PSNEmptyState(
              icon: '🎙️',
              title: 'No Episodes Yet',
              subtitle:
                  'Start recording or add a podcast URL to see summaries here.',
              action: PSNButton(
                label: 'Add Episode',
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                onTap: () {},
              ),
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  static void _noop() {}

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.spaceMd),
      child: Text(title.toUpperCase(), style: Tokens.label),
    );
  }
}
