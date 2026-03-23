import 'dart:async';

import 'package:flutter/material.dart';

/// Types text in at ~[charsPerSecond] with optional blinking cursor.
class TypewriteText extends StatefulWidget {
  const TypewriteText({
    super.key,
    required this.text,
    this.style,
    this.charsPerSecond = 30,
    this.onComplete,
    this.showCursorWhileTyping = true,
  });

  final String text;
  final TextStyle? style;
  final double charsPerSecond;
  final VoidCallback? onComplete;
  final bool showCursorWhileTyping;

  @override
  State<TypewriteText> createState() => _TypewriteTextState();
}

class _TypewriteTextState extends State<TypewriteText>
    with TickerProviderStateMixin {
  late final AnimationController _typeController;
  late final AnimationController _cursorController;
  Timer? _completeTimer;

  @override
  void initState() {
    super.initState();
    final len = widget.text.length;
    final ms = len == 0
        ? 0
        : ((len / widget.charsPerSecond) * 1000).round().clamp(400, 12000);

    _typeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
    )..addListener(() => setState(() {}));

    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    if (len == 0) {
      widget.onComplete?.call();
    } else {
      _typeController.forward();
      if (widget.showCursorWhileTyping) {
        _cursorController.repeat(reverse: true);
      }
      _typeController.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _cursorController.stop();
          _cursorController.value = 0;
          setState(() {});
          _completeTimer?.cancel();
          _completeTimer = Timer(const Duration(milliseconds: 50), () {
            widget.onComplete?.call();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _completeTimer?.cancel();
    _typeController.dispose();
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final len = widget.text.length;
    final progress = len == 0 ? 1.0 : _typeController.value;
    final n = (progress * len).round().clamp(0, len);
    final visible = widget.text.substring(0, n);
    final done = n >= len;

    final base = widget.style ?? DefaultTextStyle.of(context).style;
    final showPipe = !done && widget.showCursorWhileTyping;
    final cursorOpacity = showPipe ? _cursorController.value : 0.0;

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: visible),
          if (showPipe)
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Opacity(
                opacity: cursorOpacity.clamp(0.15, 1.0),
                child: Text('|', style: base),
              ),
            ),
        ],
      ),
    );
  }
}
