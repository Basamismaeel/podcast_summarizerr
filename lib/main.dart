import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/env_value.dart';
import 'database/database.dart';
import 'services/notification_service.dart';
import 'services/spotify_episode_service.dart';

/// Loads `.env` from the asset bundle with fixes for common editor issues:
/// - UTF-8 BOM on the first line (would otherwise break the first key name)
/// - Windows CRLF line endings
/// Then normalizes values (quotes/whitespace) and fills missing keys from
/// [Platform.environment] (Spotify + API keys — useful on desktop/CI).
Future<void> _loadDotenv() async {
  try {
    final raw = await rootBundle.loadString('.env');
    if (raw.isEmpty) {
      await dotenv.load(fileName: '.env', isOptional: true);
      _normalizeLoadedDotenvValues();
      _mergeSpotifyFromPlatform();
      _mergeApiKeysFromPlatform();
      return;
    }
    final noBom = raw.replaceFirst(RegExp(r'^\uFEFF'), '');
    final normalized = noBom.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    dotenv.testLoad(fileInput: normalized);
    _normalizeLoadedDotenvValues();
    _mergeSpotifyFromPlatform();
    _mergeApiKeysFromPlatform();
  } catch (e, st) {
    debugPrint('[main] dotenv testLoad failed, falling back: $e\n$st');
    try {
      await dotenv.load(fileName: '.env', isOptional: true);
      _normalizeLoadedDotenvValues();
      _mergeSpotifyFromPlatform();
      _mergeApiKeysFromPlatform();
    } catch (e2, st2) {
      debugPrint('[main] dotenv load skipped: $e2\n$st2');
    }
  }
}

/// Re-write dotenv entries so quoted values and stray whitespace don't break keys.
void _normalizeLoadedDotenvValues() {
  if (!dotenv.isInitialized) return;
  for (final e in dotenv.env.entries.toList()) {
    final n = normalizeDotenvValue(e.value);
    if (n != e.value) dotenv.env[e.key] = n;
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
    final cur = normalizeDotenvValue(dotenv.env[key]);
    if (cur.isEmpty) {
      dotenv.env[key] = fromPlat;
    }
  }
}

/// Fill API keys from the process environment when `.env` omits them (desktop/CI).
void _mergeApiKeysFromPlatform() {
  if (!dotenv.isInitialized) return;
  const keys = [
    'GEMINI_API_KEY',
    'DEEPGRAM_API_KEY',
    'TADDY_API_KEY',
    'TADDY_USER_ID',
    'GOOGLE_BOOKS_API_KEY',
  ];
  for (final key in keys) {
    final fromPlat = normalizeDotenvValue(Platform.environment[key]);
    if (fromPlat.isEmpty) continue;
    final cur = normalizeDotenvValue(dotenv.env[key]);
    if (cur.isEmpty) dotenv.env[key] = fromPlat;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  assert(() {
    debugProfileBuildsEnabled = true;
    return true;
  }());

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

  // Same full Material UI as iOS/Android; window_manager sizes the desktop window.
  if (Platform.isMacOS) {
    await windowManager.ensureInitialized();
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
