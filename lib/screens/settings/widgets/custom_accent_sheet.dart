import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../widgets/psn_bottom_sheet.dart';
import '../../../widgets/psn_button.dart';

/// Lets the user pick any RGB accent (alpha fixed to FF).
Future<Color?> showCustomAccentSheet(
  BuildContext context, {
  required Color initial,
}) {
  return showModalBottomSheet<Color>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return _CustomAccentBody(initial: initial);
    },
  );
}

class _CustomAccentBody extends StatefulWidget {
  const _CustomAccentBody({required this.initial});

  final Color initial;

  @override
  State<_CustomAccentBody> createState() => _CustomAccentBodyState();
}

class _CustomAccentBodyState extends State<_CustomAccentBody> {
  late double _r;
  late double _g;
  late double _b;

  @override
  void initState() {
    super.initState();
    _r = widget.initial.r;
    _g = widget.initial.g;
    _b = widget.initial.b;
  }

  Color get _color => Color.fromARGB(
        255,
        (_r * 255).round().clamp(0, 255),
        (_g * 255).round().clamp(0, 255),
        (_b * 255).round().clamp(0, 255),
      );

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: PSNBottomSheet(
        title: 'Custom accent',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _color.withValues(alpha: 0.45),
                      blurRadius: 16,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Tokens.spaceMd),
            _sliderRow('Red', _r, (v) => setState(() => _r = v)),
            _sliderRow('Green', _g, (v) => setState(() => _g = v)),
            _sliderRow('Blue', _b, (v) => setState(() => _b = v)),
            const SizedBox(height: Tokens.spaceMd),
            Text(
              'Applies to buttons, links, and highlights in light and dark mode.',
              style: tt.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Tokens.spaceLg),
            PSNButton(
              label: 'Use this color',
              fullWidth: true,
              onTap: () => Navigator.of(context).pop(_color),
            ),
            const SizedBox(height: Tokens.spaceSm),
            PSNButton(
              label: 'Cancel',
              variant: ButtonVariant.ghost,
              fullWidth: true,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sliderRow(String label, double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
