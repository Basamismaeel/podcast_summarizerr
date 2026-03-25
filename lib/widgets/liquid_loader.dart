import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/image_decode_cache.dart';

/// Circular liquid-style progress with sine waves (premium “thinking” state).
class LiquidLoader extends StatefulWidget {
  const LiquidLoader({
    super.key,
    this.diameter = 120,
    this.progress = 0.35,
    this.artworkUrl,
    this.labelForInitials = '',
    this.accentColor = const Color(0xFF6366F1),
  });

  final double diameter;

  /// 0–1 simulated fill level (e.g. animates over summarization).
  final double progress;
  final String? artworkUrl;
  final String labelForInitials;
  final Color accentColor;

  @override
  State<LiquidLoader> createState() => _LiquidLoaderState();
}

class _LiquidLoaderState extends State<LiquidLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _wave,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.diameter, widget.diameter),
          painter: _LiquidPainter(
            progress: widget.progress.clamp(0.0, 1.0),
            wavePhase: _wave.value * 2 * math.pi,
            accent: widget.accentColor,
          ),
          child: SizedBox(
            width: widget.diameter,
            height: widget.diameter,
            child: Center(
              child: _CenterAvatar(
                url: widget.artworkUrl,
                label: widget.labelForInitials,
                size: widget.diameter * 0.38,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CenterAvatar extends StatelessWidget {
  const _CenterAvatar({
    required this.url,
    required this.label,
    required this.size,
  });

  final String? url;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final u = url?.trim();
    final has =
        u != null &&
        u.isNotEmpty &&
        (u.startsWith('http://') || u.startsWith('https://'));
    if (has) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: u,
          width: size,
          height: size,
          fit: BoxFit.cover,
          // perf: Small avatar — bound decode size to logical diameter.
          memCacheWidth: decodeCacheExtent(context, size),
          memCacheHeight: decodeCacheExtent(context, size),
          placeholder: (context, url) => Container(
            width: size,
            height: size,
            color: const Color(0xFF1A1A1A),
          ),
          errorWidget: (context, url, error) => _initials(),
        ),
      );
    }
    return _initials();
  }

  Widget _initials() {
    final letter = label.trim().isNotEmpty
        ? label.trim()[0].toUpperCase()
        : '?';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1A1A2E),
        ),
      ),
    );
  }
}

class _LiquidPainter extends CustomPainter {
  _LiquidPainter({
    required this.progress,
    required this.wavePhase,
    required this.accent,
  });

  final double progress;
  final double wavePhase;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));

    final fillH = size.height * progress;
    final baseY = size.height - fillH;

    final paint1 = Paint()
      ..color = accent.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    final paint2 = Paint()
      ..color = accent.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final w = size.width;
    for (final layer in [0, 1]) {
      final phase = wavePhase + layer * 1.7;
      final amp = 4.0 + layer * 2.0;
      final path = Path()..moveTo(0, size.height);
      for (double x = 0; x <= w; x += 2) {
        final y =
            baseY +
            math.sin((x / w * 4 * math.pi) + phase) * amp +
            math.sin((x / w * 2 * math.pi) - phase * 0.5) * (amp * 0.5);
        path.lineTo(x, y);
      }
      path.lineTo(w, size.height);
      path.close();
      canvas.drawPath(path, layer == 0 ? paint1 : paint2);
    }

    canvas.restore();

    final border = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(c, r - 1, border);
  }

  @override
  bool shouldRepaint(covariant _LiquidPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.accent != accent;
  }
}
