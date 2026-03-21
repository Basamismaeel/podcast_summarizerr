import 'package:flutter/material.dart';

import '../core/tokens.dart';

class PSNTextField extends StatefulWidget {
  const PSNTextField({
    super.key,
    required this.placeholder,
    this.controller,
    this.onChanged,
    this.prefixIcon,
    this.suffix,
    this.autofocus = false,
  });

  final String placeholder;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool autofocus;

  @override
  State<PSNTextField> createState() => _PSNTextFieldState();
}

class _PSNTextFieldState extends State<PSNTextField> {
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      style: tt.bodyLarge?.copyWith(color: cs.onSurface),
      cursorColor: cs.primary,
      decoration: InputDecoration(
        hintText: widget.placeholder,
        hintStyle: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, color: cs.onSurfaceVariant, size: 22)
            : null,
        suffixIcon: widget.suffix != null
            ? Padding(
                padding: const EdgeInsets.only(right: Tokens.spaceSm),
                child: widget.suffix,
              )
            : null,
        suffixIconConstraints: const BoxConstraints(
          minHeight: Tokens.minTap,
          minWidth: Tokens.minTap,
        ),
      ),
    );
  }
}
