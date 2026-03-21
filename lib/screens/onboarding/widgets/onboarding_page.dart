import 'package:flutter/material.dart';

import '../../../core/tokens.dart';

class OnboardingPageData {
  const OnboardingPageData({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  final String emoji;
  final String title;
  final String subtitle;
}

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.data});

  final OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(data.emoji, style: const TextStyle(fontSize: 64)),
          SizedBox(height: Tokens.spaceLg),
          Text(
            data.title,
            style: Tokens.headingXL,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: Tokens.spaceSm),
          Text(
            data.subtitle,
            style: Tokens.bodyL,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
