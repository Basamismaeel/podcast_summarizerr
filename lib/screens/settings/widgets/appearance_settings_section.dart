import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accent_presets.dart';
import '../../../core/haptics.dart';
import '../../../core/tokens.dart';
import '../../../models/app_theme_preference.dart';
import '../../../providers/settings_provider.dart';
import 'custom_accent_sheet.dart';
import 'settings_section.dart';

class AppearanceSettingsSection extends ConsumerWidget {
  const AppearanceSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final notifier = ref.read(settingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSection(title: 'Appearance'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Theme',
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Tokens.spaceSm),
            SegmentedButton<AppThemePreference>(
              segments: const [
                ButtonSegment<AppThemePreference>(
                  value: AppThemePreference.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto_outlined, size: 18),
                ),
                ButtonSegment<AppThemePreference>(
                  value: AppThemePreference.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined, size: 18),
                ),
                ButtonSegment<AppThemePreference>(
                  value: AppThemePreference.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined, size: 18),
                ),
              ],
              selected: {settings.themePreference},
              onSelectionChanged: (s) {
                if (s.isEmpty) return;
                notifier.setThemePreference(s.first);
              },
            ),
            const SizedBox(height: Tokens.spaceLg),
            const _ExpandableAccentPicker(),
          ],
        ),
      ],
    );
  }
}

class _ExpandableAccentPicker extends ConsumerStatefulWidget {
  const _ExpandableAccentPicker();

  @override
  ConsumerState<_ExpandableAccentPicker> createState() =>
      _ExpandableAccentPickerState();
}

class _ExpandableAccentPickerState extends ConsumerState<_ExpandableAccentPicker> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final notifier = ref.read(settingsProvider.notifier);

    final isCustom = !AccentPresets.colors.any(
      (c) => c.toARGB32() == settings.accentColorArgb,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accent color',
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Tokens.spaceXs),
                  Text(
                    'Used for buttons, links, and highlights in both themes.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: _expanded ? 'Hide colors' : 'Show all colors',
              onPressed: () {
                higLightTap();
                setState(() => _expanded = !_expanded);
              },
              icon: Icon(
                _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: cs.primary,
              ),
              style: IconButton.styleFrom(
                minimumSize: const Size(Tokens.minTap, Tokens.minTap),
              ),
            ),
          ],
        ),
        const SizedBox(height: Tokens.spaceSm),
        if (!_expanded)
          Row(
            children: [
              _AccentDot(
                color: settings.accentColor,
                selected: true,
                onTap: () {
                  higLightTap();
                  setState(() => _expanded = true);
                },
                semanticsLabel: 'Current accent, tap to show all colors',
              ),
              const SizedBox(width: Tokens.spaceSm),
              _AccentDot(
                color: settings.accentColor,
                selected: isCustom,
                onTap: () async {
                  higLightTap();
                  final picked = await showCustomAccentSheet(
                    context,
                    initial: settings.accentColor,
                  );
                  if (picked != null) {
                    await notifier.setAccentColor(picked);
                  }
                },
                child: Icon(
                  Icons.tune_rounded,
                  size: 22,
                  color: cs.onSurface,
                ),
              ),
            ],
          )
        else ...[
          Wrap(
            spacing: Tokens.spaceSm + 4,
            runSpacing: Tokens.spaceSm + 4,
            children: [
              for (final c in AccentPresets.colors)
                _AccentDot(
                  color: c,
                  selected: settings.accentColorArgb == c.toARGB32(),
                  onTap: () {
                    higLightTap();
                    notifier.setAccentColor(c);
                  },
                ),
              _AccentDot(
                color: settings.accentColor,
                selected: isCustom,
                onTap: () async {
                  higLightTap();
                  final picked = await showCustomAccentSheet(
                    context,
                    initial: settings.accentColor,
                  );
                  if (picked != null) {
                    await notifier.setAccentColor(picked);
                  }
                },
                child: Icon(
                  Icons.tune_rounded,
                  size: 22,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({
    required this.color,
    required this.selected,
    required this.onTap,
    this.child,
    this.semanticsLabel,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final Widget? child;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget ink = InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Ink(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: child == null ? color : cs.surfaceContainerHighest,
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );

    if (semanticsLabel != null) {
      return Semantics(
        button: true,
        label: semanticsLabel,
        child: Material(color: Colors.transparent, child: ink),
      );
    }

    return Material(color: Colors.transparent, child: ink);
  }
}
