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
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.spaceXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            data.emoji,
            style: tt.displayMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: Tokens.spaceLg),
          Text(
            data.title,
            style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: Tokens.spaceSm),
          Text(
            data.subtitle,
            style: tt.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
