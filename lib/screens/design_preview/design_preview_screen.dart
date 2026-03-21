import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import '../../widgets/psn_button.dart';
import '../../widgets/psn_card.dart';
import '../../widgets/psn_divider.dart';
import '../../widgets/psn_empty_state.dart';
import '../../widgets/psn_snackbar.dart';
import '../../widgets/psn_status_badge.dart';
import '../../widgets/psn_text_field.dart';

/// Debug-only preview of HIG-aligned system typography and components.
class DesignPreviewScreen extends StatelessWidget {
  const DesignPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Design system')),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.spaceMd),
        children: [
          _section(context, 'Typography'),
          Text('Display small', style: tt.displaySmall),
          const SizedBox(height: Tokens.spaceSm),
          Text('Headline medium', style: tt.headlineMedium),
          const SizedBox(height: Tokens.spaceSm),
          Text('Title large — semibold',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: Tokens.spaceSm),
          Text('Title medium', style: tt.titleMedium),
          const SizedBox(height: Tokens.spaceSm),
          Text('Body large', style: tt.bodyLarge),
          const SizedBox(height: Tokens.spaceSm),
          Text('Body medium', style: tt.bodyMedium),
          const SizedBox(height: Tokens.spaceSm),
          Text('Body small', style: tt.bodySmall),
          const SizedBox(height: Tokens.spaceSm),
          Text('Label small',
              style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: Tokens.spaceSm),
          Text('Monospace time',
              style: tt.bodySmall?.copyWith(fontFamily: 'monospace')),

          const SizedBox(height: Tokens.spaceXl),
          _section(context, 'Primary buttons'),
          PSNButton(label: 'Primary', onTap: () {}),
          const SizedBox(height: Tokens.spaceSm),
          PSNButton(
            label: 'With icon',
            icon: Icon(Icons.mic_rounded, size: 20, color: cs.onPrimary),
            onTap: () {},
          ),
          const SizedBox(height: Tokens.spaceSm),
          const PSNButton(label: 'Disabled'),
          const SizedBox(height: Tokens.spaceSm),
          const PSNButton(label: 'Loading…', isLoading: true, onTap: _noop),
          const SizedBox(height: Tokens.spaceSm),
          PSNButton(label: 'Full width', onTap: () {}, fullWidth: true),

          const SizedBox(height: Tokens.spaceLg),
          _section(context, 'Variants'),
          PSNButton(
            label: 'Secondary',
            variant: ButtonVariant.secondary,
            onTap: () {},
          ),
          const SizedBox(height: Tokens.spaceSm),
          PSNButton(
            label: 'Ghost',
            variant: ButtonVariant.ghost,
            onTap: () {},
          ),
          const SizedBox(height: Tokens.spaceSm),
          PSNButton(
            label: 'Danger',
            variant: ButtonVariant.danger,
            onTap: () {},
          ),

          const SizedBox(height: Tokens.spaceXl),
          _section(context, 'Status badges'),
          const Wrap(
            spacing: Tokens.spaceSm,
            runSpacing: Tokens.spaceSm,
            children: [
              PSNStatusBadge(status: SessionStatus.recording),
              PSNStatusBadge(status: SessionStatus.queued),
              PSNStatusBadge(status: SessionStatus.summarizing),
              PSNStatusBadge(status: SessionStatus.done),
              PSNStatusBadge(status: SessionStatus.error),
            ],
          ),

          const SizedBox(height: Tokens.spaceXl),
          _section(context, 'Cards'),
          PSNCard(
            onTap: () {},
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Episode #142',
                          style: tt.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Tap to expand',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                const PSNStatusBadge(status: SessionStatus.done),
              ],
            ),
          ),
          const SizedBox(height: Tokens.spaceSm),
          PSNCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Grouped card',
                    style: tt.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Surface container, no heavy shadow',
                    style: tt.bodyMedium),
              ],
            ),
          ),

          const SizedBox(height: Tokens.spaceXl),
          _section(context, 'Text fields'),
          PSNTextField(
            placeholder: 'Search episodes…',
            prefixIcon: Icons.search,
          ),
          const SizedBox(height: Tokens.spaceSm),
          PSNTextField(
            placeholder: 'Enter podcast URL',
            suffix: Icon(Icons.link, color: cs.onSurfaceVariant, size: 20),
          ),

          const SizedBox(height: Tokens.spaceXl),
          _section(context, 'Dividers'),
          const PSNDivider(),
          const SizedBox(height: Tokens.spaceMd),
          const PSNDivider(label: 'or continue with'),

          const SizedBox(height: Tokens.spaceXl),
          _section(context, 'Snackbars'),
          Wrap(
            spacing: Tokens.spaceSm,
            runSpacing: Tokens.spaceSm,
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

          const SizedBox(height: Tokens.spaceXl),
          _section(context, 'Empty state'),
          SizedBox(
            height: 280,
            child: PSNEmptyState(
              icon: '🎙️',
              title: 'No episodes yet',
              subtitle:
                  'Start recording or add a podcast URL to see summaries here.',
              action: PSNButton(
                label: 'Add episode',
                icon: Icon(Icons.add_rounded, size: 20, color: cs.onPrimary),
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

  Widget _section(BuildContext context, String title) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.spaceMd),
      child: Text(
        title.toUpperCase(),
        style: tt.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
