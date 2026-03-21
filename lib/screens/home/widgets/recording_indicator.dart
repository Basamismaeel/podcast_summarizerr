import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../database/database.dart';
import '../../../widgets/psn_button.dart';

class RecordingIndicator extends StatefulWidget {
  const RecordingIndicator({
    super.key,
    required this.session,
    required this.onStop,
  });

  final ListeningSession session;
  final VoidCallback onStop;

  @override
  State<RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _elapsedLabel {
    final created =
        DateTime.fromMillisecondsSinceEpoch(widget.session.createdAt);
    final seconds =
        DateTime.now().difference(created).inSeconds.clamp(0, 24 * 60 * 60);
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: Tokens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: Tokens.errorDim,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          FadeTransition(
            opacity: _opacity,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Tokens.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '● Recording',
            style: Tokens.bodyS.copyWith(color: Tokens.error),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.session.title,
              style: Tokens.bodyS.copyWith(color: Tokens.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _elapsedLabel,
            style: Tokens.mono.copyWith(fontSize: 11),
          ),
          const SizedBox(width: 8),
          PSNButton(
            label: 'Stop',
            size: ButtonSize.sm,
            variant: ButtonVariant.danger,
            onTap: widget.onStop,
          ),
        ],
      ),
    );
  }
}
