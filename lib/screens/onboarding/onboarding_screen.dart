import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/tokens.dart';
import '../../providers/settings_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/psn_bottom_sheet.dart';
import '../../widgets/psn_button.dart';
import '../../widgets/psn_card.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == 2;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Tokens.spaceMd,
                vertical: Tokens.spaceSm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Tokens.accentDim,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.podcasts, size: 16, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('Podcast Safety Net', style: Tokens.headingS),
                  const Spacer(),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) {
                  setState(() => _currentPage = i);
                },
                children: const [
                  _ProblemPage(),
                  _SolutionPage(),
                  _SummaryPage(),
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.spaceMd,
                0,
                Tokens.spaceMd,
                Tokens.spaceMd,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (i) => AnimatedContainer(
                        duration: Tokens.durationFast,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? Tokens.accent
                              : Tokens.borderLight,
                          borderRadius:
                              BorderRadius.circular(Tokens.radiusFull),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Tokens.spaceMd),
                  Row(
                    children: [
                      if (!isLast)
                        Expanded(
                          child: PSNButton(
                            label: 'Skip',
                            variant: ButtonVariant.ghost,
                            fullWidth: true,
                            onTap: () async {
                              // Completing onboarding without asking
                              // for notifications.
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool('onboarding_done', true);

                              if (!mounted) return;
                              ref
                                  .read(settingsProvider.notifier)
                                  .completeOnboarding();
                              context.go('/');
                            },
                          ),
                        ),
                      if (!isLast) const SizedBox(width: Tokens.spaceSm),
                      Expanded(
                        child: PSNButton(
                          label: isLast ? 'Get Started' : 'Continue',
                          fullWidth: true,
                          onTap: () => isLast ? _onGetStarted() : _nextPage(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nextPage() {
    _controller.nextPage(
      duration: Tokens.durationNormal,
      curve: Curves.easeInOut,
    );
  }

  Future<void> _onGetStarted() async {
    await _showPermissionSheet();
    if (!mounted) return;
    ref.read(settingsProvider.notifier).completeOnboarding();
    context.go('/');
  }

  Future<void> _showPermissionSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return PSNBottomSheet(
          title: 'One permission needed',
          showHandle: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To show the quick-save button, we need notification permission. '
                'We will never send spam.',
                style: Tokens.bodyL,
              ),
              const SizedBox(height: Tokens.spaceLg),
              PSNButton(
                label: 'Allow Notifications',
                fullWidth: true,
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('onboarding_done', true);
                  await NotificationService.instance.requestPermission();
                  if (Navigator.of(ctx).canPop()) {
                    Navigator.of(ctx).pop();
                  }
                },
              ),
              const SizedBox(height: Tokens.spaceSm),
              PSNButton(
                label: 'Skip for now',
                variant: ButtonVariant.ghost,
                fullWidth: true,
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('onboarding_done', true);
                  if (Navigator.of(ctx).canPop()) {
                    Navigator.of(ctx).pop();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Page 1: The Problem ─────────────────────────────────────────────────

class _ProblemPage extends StatelessWidget {
  const _ProblemPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.spaceXl,
        vertical: Tokens.spaceLg,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _GlowingEmojiCircle(
            emoji: '💨',
            glowColor: Tokens.accent,
          )
              .animate()
              .fade(duration: 300.ms)
              .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
          SizedBox(height: Tokens.spaceXl),
          Text('Insights disappear.', style: Tokens.headingXL)
              .animate()
              .fade(duration: 300.ms, delay: 150.ms)
              .slideY(begin: 0.2, end: 0),
          SizedBox(height: Tokens.spaceSm),
          Text(
            'You hear something brilliant at minute 34.\n'
            'You think you\'ll remember it. You never do.',
            style: Tokens.bodyL,
            textAlign: TextAlign.center,
          )
              .animate()
              .fade(duration: 300.ms, delay: 250.ms)
              .slideY(begin: 0.2, end: 0),
          SizedBox(height: Tokens.spaceXl),
          const _ProblemPodcastCard()
              .animate()
              .fade(duration: 300.ms, delay: 350.ms)
              .slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }
}

class _ProblemPodcastCard extends StatelessWidget {
  const _ProblemPodcastCard();

  @override
  Widget build(BuildContext context) {
    return PSNCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Tokens.bgElevated,
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                ),
                child: const Center(
                  child: Text('🎙️', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The Joe Rogan Experience',
                      style: Tokens.bodyM
                          .copyWith(color: Tokens.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Now at 34:12 — something important was just said',
                      style: Tokens.bodyS,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(Tokens.radiusFull),
            child: Container(
              height: 4,
              color: Tokens.bgElevated,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.5,
                child: Container(
                  color: Tokens.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page 2: The Solution ────────────────────────────────────────────────

class _SolutionPage extends StatelessWidget {
  const _SolutionPage();

  @override
  Widget build(BuildContext context) {
    const methods = [
      ('🔔', 'Notification Banner', '100% reliable'),
      ('🎤', 'Voice Command', 'Hands-free'),
      ('📳', 'Shake to Save', 'Always on'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.spaceXl,
        vertical: Tokens.spaceLg,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _GlowingEmojiCircle(
            emoji: '🔖',
            glowColor: Tokens.success,
          )
              .animate()
              .fade(duration: 300.ms)
              .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
          SizedBox(height: Tokens.spaceXl),
          Text('One tap. Saved.', style: Tokens.headingXL)
              .animate()
              .fade(duration: 300.ms, delay: 150.ms)
              .slideY(begin: 0.2, end: 0),
          SizedBox(height: Tokens.spaceSm),
          Text(
            'Keep using Spotify. When you hear something good, tap once.\n'
            'The AI summary waits for you.',
            style: Tokens.bodyL,
            textAlign: TextAlign.center,
          )
              .animate()
              .fade(duration: 300.ms, delay: 250.ms)
              .slideY(begin: 0.2, end: 0),
          SizedBox(height: Tokens.spaceXl),
          for (var i = 0; i < methods.length; i++)
            _MethodCard(
              emoji: methods[i].$1,
              title: methods[i].$2,
              badge: methods[i].$3,
            )
                .animate()
                .fade(duration: 250.ms, delay: (100 * (i + 1)).ms)
                .slideY(begin: 0.2, end: 0)
                .then(delay: 0.ms),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.emoji,
    required this.title,
    required this.badge,
  });

  final String emoji;
  final String title;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.spaceSm),
      child: PSNCard(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.spaceMd,
          vertical: 12,
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Tokens.bodyM.copyWith(color: Tokens.textPrimary),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Tokens.successDim,
                borderRadius:
                    BorderRadius.circular(Tokens.radiusFull),
                border: Border.all(
                  color: Tokens.success.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: Text(
                badge,
                style: Tokens.bodyS.copyWith(color: Tokens.success),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page 3: The Summary ─────────────────────────────────────────────────

class _SummaryPage extends StatelessWidget {
  const _SummaryPage();

  @override
  Widget build(BuildContext context) {
    final bullets = [
      '3 key ideas from this 10‑minute stretch, written in plain language.',
      'Actionable takeaways you can revisit in seconds, not minutes.',
      'Context that ties this clip back to the rest of the conversation.',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.spaceXl,
        vertical: Tokens.spaceLg,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _GlowingEmojiCircle(
            emoji: '✨',
            glowColor: Tokens.accent,
          )
              .animate()
              .fade(duration: 300.ms)
              .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
          SizedBox(height: Tokens.spaceXl),
          Text('AI reads it for you.', style: Tokens.headingXL)
              .animate()
              .fade(duration: 300.ms, delay: 150.ms)
              .slideY(begin: 0.2, end: 0),
          SizedBox(height: Tokens.spaceSm),
          Text(
            'Come back anytime. A 3‑point summary of exactly what you heard '
            'is already waiting.',
            style: Tokens.bodyL,
            textAlign: TextAlign.center,
          )
              .animate()
              .fade(duration: 300.ms, delay: 250.ms)
              .slideY(begin: 0.2, end: 0),
          SizedBox(height: Tokens.spaceXl),
          PSNCard(
            glowColor: Tokens.accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JRE #2100 · 34:12 – 44:12',
                  style: Tokens.bodyS.copyWith(color: Tokens.textMuted),
                ),
                const SizedBox(height: Tokens.spaceSm),
                for (var i = 0; i < bullets.length; i++)
                  _SummaryBullet(
                    index: i,
                    text: bullets[i],
                    delay: (400 * i).ms,
                  ),
              ],
            ),
          ),
          SizedBox(height: Tokens.spaceMd),
          Text(
            '🔒 No microphone used. Only reads system Now Playing metadata.',
            style: Tokens.bodyS.copyWith(color: Tokens.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SummaryBullet extends StatelessWidget {
  const _SummaryBullet({
    required this.index,
    required this.text,
    required this.delay,
  });

  final int index;
  final String text;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final number = (index + 1).toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: Tokens.accentDim,
              borderRadius: BorderRadius.circular(Tokens.radiusFull),
            ),
            child: Center(
              child: Text(
                number,
                style: Tokens.bodyS.copyWith(color: Tokens.accent),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Tokens.bodyM.copyWith(color: Tokens.textSecond),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fade(duration: 300.ms, delay: delay)
        .slideY(begin: 0.2, end: 0);
  }
}

// ── Shared helpers ──────────────────────────────────────────────────────

class _GlowingEmojiCircle extends StatelessWidget {
  const _GlowingEmojiCircle({
    required this.emoji,
    required this.glowColor,
  });

  final String emoji;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Tokens.accentDim,
        borderRadius: BorderRadius.circular(Tokens.radiusFull),
        border: Border.all(color: Tokens.accentBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.6),
            blurRadius: 40,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 48),
        ),
      ),
    );
  }
}
