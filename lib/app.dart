import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_scroll_behavior.dart';
import 'core/app_theme.dart';
import 'core/router.dart';
import 'core/tokens.dart';
import 'providers/session_provider.dart';
import 'providers/settings_provider.dart';

class PodcastSafetyNetApp extends ConsumerStatefulWidget {
  const PodcastSafetyNetApp({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  ConsumerState<PodcastSafetyNetApp> createState() =>
      _PodcastSafetyNetAppState();
}

class _PodcastSafetyNetAppState extends ConsumerState<PodcastSafetyNetApp> {
  late final GoRouter _router = createRouter(widget.prefs);

  @override
  void initState() {
    super.initState();
    // Start the watcher that auto-retries stuck "summarizing" sessions.
    ref.read(stuckSessionWatcherProvider).start();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'Podcast Safety Net',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(seedColor: settings.accentColor),
      darkTheme: AppTheme.dark(seedColor: settings.accentColor),
      themeMode: settings.themePreference.themeMode,
      routerConfig: _router,
      scrollBehavior: const AppScrollBehavior(),
      themeAnimationDuration: Tokens.durationNormal,
      themeAnimationCurve: Tokens.springCurve,
    );
  }
}
