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
    final isLast = _currentPage == 3;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Tokens.spaceMd,
                vertical: Tokens.spaceSm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.podcasts, size: 18, color: cs.primary),
                  ),
                  const SizedBox(width: Tokens.spaceSm + 2),
                  Text(
                    'Podcast Safety Net',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                ],
              ),
            ),
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
                  _HowToSavePage(),
                ],
              ),
            ),
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
                      4,
                      (i) => AnimatedContainer(
                        duration: Tokens.durationFast,
                        curve: Tokens.springCurve,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? cs.primary
                              : cs.outlineVariant.withValues(alpha: 0.5),
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
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool('onboarding_done', true);

                              if (!context.mounted) return;
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
      curve: Tokens.springCurve,
    );
  }

  Future<void> _onGetStarted() async {
    final router = GoRouter.of(context);
    await _showPermissionSheet();
    if (!mounted) return;
    ref.read(settingsProvider.notifier).completeOnboarding();
    router.go('/');
  }

  Future<void> _showPermissionSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final sheetText = Theme.of(ctx).textTheme;
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
                style: sheetText.bodyLarge,
              ),
              const SizedBox(height: Tokens.spaceLg),
              PSNButton(
                label: 'Allow Notifications',
                fullWidth: true,
                onTap: () async {
                  try {
                    await NotificationService.instance.requestPermission();
                  } catch (e, st) {
                    debugPrint('[onboarding] requestPermission: $e\n$st');
                  } finally {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('onboarding_done', true);
                    if (ctx.mounted && Navigator.of(ctx).canPop()) {
                      Navigator.of(ctx).pop();
                    }
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
                  if (!ctx.mounted) return;
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

class _ProblemPage extends StatelessWidget {
  const _ProblemPage();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.spaceXl,
        vertical: Tokens.spaceLg,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _HeroCircle(
            child: Icon(
              Icons.hourglass_empty_rounded,
              size: 56,
              color: cs.primary,
            ),
          )
              .animate()
              .fade(duration: 300.ms)
              .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
          const SizedBox(height: Tokens.spaceXl),
          Text(
            'Insights disappear.',
            style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          )
              .animate()
              .fade(duration: 300.ms, delay: 150.ms)
              .slideY(begin: 0.2, end: 0),
          const SizedBox(height: Tokens.spaceSm),
          Text(
            'You hear something brilliant at minute 34.\n'
            'You think you\'ll remember it. You never do.',
            style: tt.bodyLarge,
            textAlign: TextAlign.center,
          )
              .animate()
              .fade(duration: 300.ms, delay: 250.ms)
              .slideY(begin: 0.2, end: 0),
          const SizedBox(height: Tokens.spaceXl),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                ),
                child: Icon(Icons.mic_rounded, color: cs.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The Joe Rogan Experience',
                      style: tt.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Now at 34:12 — something important was just said',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.spaceSm + 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(Tokens.radiusFull),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  Container(color: cs.surfaceContainerHighest),
                  FractionallySizedBox(
                    widthFactor: 0.5,
                    child: Container(color: cs.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SolutionPage extends StatelessWidget {
  const _SolutionPage();

  static const _methods = <(IconData, String, String)>[
    (Icons.notifications_active_outlined, 'Notification Banner', '100% reliable'),
    (Icons.graphic_eq_rounded, 'Voice Command', 'Hands-free'),
    (Icons.vibration_rounded, 'Shake to Save', 'Always on'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.spaceXl,
        vertical: Tokens.spaceLg,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _HeroCircle(
            useTertiary: true,
            child: Icon(
              Icons.bookmark_added_rounded,
              size: 56,
              color: cs.tertiary,
            ),
          )
              .animate()
              .fade(duration: 300.ms)
              .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
          const SizedBox(height: Tokens.spaceXl),
          Text(
            'One tap. Saved.',
            style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          )
              .animate()
              .fade(duration: 300.ms, delay: 150.ms)
              .slideY(begin: 0.2, end: 0),
          const SizedBox(height: Tokens.spaceSm),
          Text(
            'Keep using Spotify. When you hear something good, tap once.\n'
            'The AI summary waits for you.',
            style: tt.bodyLarge,
            textAlign: TextAlign.center,
          )
              .animate()
              .fade(duration: 300.ms, delay: 250.ms)
              .slideY(begin: 0.2, end: 0),
          const SizedBox(height: Tokens.spaceXl),
          for (var i = 0; i < _methods.length; i++)
            _MethodCard(
              icon: _methods[i].$1,
              title: _methods[i].$2,
              badge: _methods[i].$3,
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
    required this.icon,
    required this.title,
    required this.badge,
  });

  final IconData icon;
  final String title;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.spaceSm),
      child: PSNCard(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.spaceMd,
          vertical: Tokens.spaceSm + 4,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: tt.bodyLarge?.copyWith(color: cs.onSurface),
              ),
            ),
            const SizedBox(width: Tokens.spaceSm),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: Tokens.spaceXs),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer,
                borderRadius:
                    BorderRadius.circular(Tokens.radiusFull),
                border: Border.all(
                  color: cs.tertiary.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                badge,
                style: tt.bodySmall?.copyWith(
                  color: cs.onTertiaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPage extends StatelessWidget {
  const _SummaryPage();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
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
          _HeroCircle(
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 56,
              color: cs.primary,
            ),
          )
              .animate()
              .fade(duration: 300.ms)
              .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
          const SizedBox(height: Tokens.spaceXl),
          Text(
            'AI reads it for you.',
            style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          )
              .animate()
              .fade(duration: 300.ms, delay: 150.ms)
              .slideY(begin: 0.2, end: 0),
          const SizedBox(height: Tokens.spaceSm),
          Text(
            'Come back anytime. A 3‑point summary of exactly what you heard '
            'is already waiting.',
            style: tt.bodyLarge,
            textAlign: TextAlign.center,
          )
              .animate()
              .fade(duration: 300.ms, delay: 250.ms)
              .slideY(begin: 0.2, end: 0),
          const SizedBox(height: Tokens.spaceXl),
          PSNCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JRE #2100 · 34:12 – 44:12',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
          const SizedBox(height: Tokens.spaceMd),
          Text(
            'No microphone used. Only reads system Now Playing metadata.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _HowToSavePage extends StatelessWidget {
  const _HowToSavePage();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget step(String n, String title, String body) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Tokens.spaceMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Text(
                n,
                style: tt.labelLarge?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: Tokens.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(body, style: tt.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.spaceXl,
        vertical: Tokens.spaceLg,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to save a moment',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Tokens.spaceMd),
          step(
            '1',
            'Copy a podcast link',
            'In Spotify or Apple Podcasts: Share → Copy link.',
          ),
          step(
            '2',
            'Paste in the app',
            'Open Podcast Safety Net → paste the link → choose the exact start and end time.',
          ),
          step(
            '3',
            'Or add manually',
            'Use Manual Entry for title & show, pick an approximate segment.',
          ),
          const SizedBox(height: Tokens.spaceSm),
          Text(
            'On Mac you can also press ⌘S (or use the menu bar) while audio is playing.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final number = (index + 1).toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(Tokens.radiusFull),
            ),
            child: Center(
              child: Text(
                number,
                style: tt.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
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

class _HeroCircle extends StatelessWidget {
  const _HeroCircle({
    required this.child,
    this.useTertiary = false,
  });

  final Widget child;
  final bool useTertiary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fill = useTertiary ? cs.tertiaryContainer : cs.primaryContainer;
    final border = useTertiary ? cs.tertiary : cs.primary;

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: border.withValues(alpha: 0.25)),
      ),
      child: Center(child: child),
    );
  }
}
