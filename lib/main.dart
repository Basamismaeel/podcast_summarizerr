import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'database/database.dart';
import 'screens/menu_bar/menu_bar_app.dart';
import 'services/notification_service.dart';
import 'services/spotify_episode_service.dart';

/// Loads `.env` from the asset bundle with fixes for common editor issues:
/// - UTF-8 BOM on the first line (would otherwise break the first key name)
/// - Windows CRLF line endings
/// Then fills missing Spotify keys from [Platform.environment] (e.g. IDE run config).
Future<void> _loadDotenv() async {
  try {
    final raw = await rootBundle.loadString('.env');
    if (raw.isEmpty) {
      await dotenv.load(fileName: '.env', isOptional: true);
      return;
    }
    final noBom = raw.replaceFirst(RegExp(r'^\uFEFF'), '');
    final normalized = noBom.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    dotenv.testLoad(fileInput: normalized);
    _mergeSpotifyFromPlatform();
  } catch (e, st) {
    debugPrint('[main] dotenv testLoad failed, falling back: $e\n$st');
    try {
      await dotenv.load(fileName: '.env', isOptional: true);
      _mergeSpotifyFromPlatform();
    } catch (e2, st2) {
      debugPrint('[main] dotenv load skipped: $e2\n$st2');
    }
  }
}

void _mergeSpotifyFromPlatform() {
  if (!dotenv.isInitialized) return;
  const keys = [
    'SPOTIFY_CLIENT_ID',
    'SPOTIFY_CLIENT_SECRET',
    'SPOTIFY_CLIENT_SECRET_ID',
  ];
  for (final key in keys) {
    final fromPlat = Platform.environment[key]?.trim();
    if (fromPlat == null || fromPlat.isEmpty) continue;
    final cur = dotenv.env[key]?.trim();
    if (cur == null || cur.isEmpty) {
      dotenv.env[key] = fromPlat;
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _loadDotenv();

  try {
    final prefsSpotify = await SharedPreferences.getInstance();
    SpotifyEpisodeService.hydrateFromPrefs(prefsSpotify);
  } catch (e) {
    debugPrint('[main] Spotify hydrateFromPrefs: $e');
  }

  try {
    await NotificationService.instance.initialize();
  } catch (e, st) {
    debugPrint('[main] NotificationService init failed: $e\n$st');
  }

  NotificationService.instance.attachDatabase(appDatabaseSingleton);

  if (Platform.isMacOS) {
    await windowManager.ensureInitialized();
    try {
      await trayManager.setIcon('assets/tray_icon.png');
    } catch (_) {}
    runApp(
      const ProviderScope(
        child: MacMenuBarApp(),
      ),
    );
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;
  debugPrint('[main] onboarding_done at startup: $onboardingDone');

  runApp(
    const ProviderScope(
      child: _AppWithPrefs(),
    ),
  );
}

class _AppWithPrefs extends StatefulWidget {
  const _AppWithPrefs();

  @override
  State<_AppWithPrefs> createState() => _AppWithPrefsState();
}

class _AppWithPrefsState extends State<_AppWithPrefs> {
  late final Future<SharedPreferences> _prefsFuture =
      SharedPreferences.getInstance();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: _prefsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: SizedBox.shrink(),
          );
        }
        return PodcastSafetyNetApp(prefs: snapshot.data!);
      },
    );
  }
}
