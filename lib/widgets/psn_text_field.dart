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
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _hasFocus = _focus.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(
          color: _hasFocus ? Tokens.accent : Tokens.borderLight,
          width: _hasFocus ? 1.5 : 1.0,
        ),
        color: Tokens.bgElevated,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        style: Tokens.bodyL.copyWith(color: Tokens.textPrimary),
        cursorColor: Tokens.accent,
        decoration: InputDecoration(
          hintText: widget.placeholder,
          hintStyle: const TextStyle(color: Tokens.textMuted),
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon, color: Tokens.textMuted, size: 20)
              : null,
          suffixIcon: widget.suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: widget.suffix,
                )
              : null,
          suffixIconConstraints:
              const BoxConstraints(minHeight: 20, minWidth: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
