import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';

/// 56×56 (list) or 40×40 (mini bar) podcast artwork with network / gradient fallback.
class PodcastArtwork extends StatelessWidget {
  const PodcastArtwork({
    super.key,
    required this.imageUrl,
    required this.labelForInitials,
    this.size = 56,
    this.borderRadius = 12,
  });

  final String? imageUrl;
  final String labelForInitials;
  final double size;
  final double borderRadius;

  static const _placeholderGray = Color(0xFF3A3A3C);

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final hasUrl = url != null &&
        url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'));

    if (!hasUrl) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(
          width: size,
          height: size,
          child: _GradientInitials(label: labelForInitials, size: size),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          fadeInDuration: Tokens.durationFast,
          fadeOutDuration: Tokens.durationFast,
          fadeInCurve: Tokens.springCurve,
          fadeOutCurve: Tokens.springCurve,
          placeholder: (context, progress) => Container(
            color: _placeholderGray,
          ),
          errorWidget: (context, imageUrl, error) =>
              _GradientInitials(label: labelForInitials, size: size),
        ),
      ),
    );
  }
}

class _GradientInitials extends StatelessWidget {
  const _GradientInitials({
    required this.label,
    required this.size,
  });

  final String label;
  final double size;

  static String initialsFrom(String text) {
    final parts = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final list = parts.toList();
    if (list.isEmpty) return '?';
    if (list.length == 1) {
      final w = list.first;
      if (w.isEmpty) return '?';
      return w.length >= 2
          ? w.substring(0, 2).toUpperCase()
          : w.substring(0, 1).toUpperCase();
    }
    final a = list[0].isNotEmpty ? list[0][0] : '';
    final b = list[1].isNotEmpty ? list[1][0] : '';
    if (a.isEmpty && b.isEmpty) return '?';
    return '$a$b'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initials = initialsFrom(label);
    final fontSize = size * 0.32;
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6366F1),
            Color(0xFF8B5CF6),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize.clamp(12, 22),
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          fontFamily: defaultTargetPlatform == TargetPlatform.iOS
              ? '.SF Pro Text'
              : null,
        ),
      ),
    );
  }
}
