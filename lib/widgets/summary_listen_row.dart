import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Inline “Listen” control: speaks [plainText] with [FlutterTts]; pause toggles stop.
class SummaryListenControl extends StatefulWidget {
  const SummaryListenControl({super.key, required this.plainText});

  final String plainText;

  @override
  State<SummaryListenControl> createState() => _SummaryListenControlState();
}

class _SummaryListenControlState extends State<SummaryListenControl> {
  final FlutterTts _tts = FlutterTts();
  var _playing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_tts.setLanguage('en-US'));
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    unawaited(_tts.stop());
    super.dispose();
  }

  Future<void> _toggle() async {
    final t = widget.plainText.trim();
    if (t.isEmpty) return;
    if (_playing) {
      await _tts.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    await _tts.stop();
    setState(() => _playing = true);
    try {
      await _tts.speak(t);
    } catch (_) {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: widget.plainText.trim().isEmpty ? null : _toggle,
      icon: Icon(
        _playing ? Icons.pause_rounded : Icons.volume_up_rounded,
        size: 20,
        color: Colors.white.withValues(alpha: 0.9),
      ),
      label: Text(
        'Listen',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.88),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
