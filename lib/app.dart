import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_theme.dart';
import 'core/router.dart';
import 'providers/session_provider.dart';

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
    return MaterialApp.router(
      title: 'Podcast Safety Net',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
    );
  }
}
