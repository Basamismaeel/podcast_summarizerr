import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'core/app_scroll_behavior.dart';
import 'core/app_theme.dart';
import 'core/haptics.dart';
import 'core/router.dart';
import 'core/tokens.dart';
import 'models/summary_style.dart';
import 'providers/session_provider.dart';
import 'providers/settings_provider.dart';
import 'services/macos_save_hotkey_service.dart';

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
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_configureMacDesktopWindow());
        unawaited(_installMacSaveHotkeys());
      });
    }
  }

  /// Global shortcuts while Spotify (or any app) is focused — ⌘S and ⌘⇧S.
  Future<void> _installMacSaveHotkeys() async {
    await MacosSaveHotkeyService.installIfMacos(
      onSave: ({
        required String title,
        required String artist,
        required int startTimeSec,
        int? endTimeSec,
        String? sourceApp,
      }) async {
        if (!mounted) return;
        final actions = ref.read(sessionActionsProvider);
        await actions.createAndSummarize(
          title: title,
          artist: artist,
          saveMethod: SaveMethod.manual,
          startTimeSec: startTimeSec,
          endTimeSec: endTimeSec,
          rangeLabel: endTimeSec != null
              ? 'Keyboard shortcut clip'
              : null,
          sourceApp: sourceApp ?? 'mac_hotkey',
        );
        if (mounted) await PSNHaptics.momentSaved();
      },
    );
  }

  Future<void> _configureMacDesktopWindow() async {
    try {
      await windowManager.waitUntilReadyToShow();
      await windowManager.setTitle('Podcast Safety Net');
      await windowManager.setResizable(true);
      // Small minimum, very large maximum so you can resize freely and use native fullscreen.
      await windowManager.setMinimumSize(const Size(320, 360));
      await windowManager.setMaximumSize(const Size(16000, 16000));
      await windowManager.setSize(const Size(1100, 820));
      await windowManager.center();
      await windowManager.show();
    } catch (e, st) {
      debugPrint('[PodcastSafetyNetApp] macOS window: $e\n$st');
    }
  }

  @override
  void dispose() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      unawaited(MacosSaveHotkeyService.disposeIfMacos());
    }
    super.dispose();
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
      builder: (context, child) {
        final mode = Theme.of(context).brightness;
        SystemChrome.setSystemUIOverlayStyle(
          mode == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
        );
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
