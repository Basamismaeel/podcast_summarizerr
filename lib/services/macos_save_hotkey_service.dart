import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'now_playing_service.dart';

/// System-wide save shortcuts when another app (e.g. Spotify) is focused.
///
/// Registers **⌘S** and **⌘⇧S** (⌘⇧S matches the legacy menu-bar build; some apps
/// consume ⌘S before a global hotkey sees it).
class MacosSaveHotkeyService {
  MacosSaveHotkeyService._();

  static bool _installed = false;
  static HotKey? _cmdS;
  static HotKey? _cmdShiftS;

  /// [onSave] receives now-playing info and should create the session (Riverpod).
  static Future<void> installIfMacos({
    required Future<void> Function({
      required String title,
      required String artist,
      required int startTimeSec,
      int? endTimeSec,
      String? sourceApp,
    }) onSave,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;
    if (_installed) return;
    _installed = true;

    try {
      await localNotifier.setup(
        appName: 'Podcast Safety Net',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
    } catch (e, st) {
      debugPrint('[MacosSaveHotkey] localNotifier.setup failed: $e\n$st');
    }

    Future<void> handle(HotKey _) async {
      try {
        final info = await NowPlayingService.instance.getCurrentNowPlaying();
        if (info == null) {
          await _notify(
            title: 'Nothing playing',
            body: 'Start playback in Spotify (or another app), then try again.',
          );
          return;
        }
        if (info.title.trim().isEmpty) {
          await _notify(
            title: 'Could not read Now Playing',
            body: 'Allow media access / try again while audio is playing.',
          );
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        final useClip = prefs.getBool('mac_hotkey_use_clip_window') ?? true;
        final clipSec = prefs.getInt('mac_hotkey_clip_seconds') ?? 120;
        final start = info.positionSeconds ?? 0;
        int? endTimeSec;
        if (useClip && clipSec > 0) {
          endTimeSec = start + clipSec;
        }

        await onSave(
          title: info.title,
          artist: info.artist.isEmpty ? 'Unknown Podcast' : info.artist,
          startTimeSec: start,
          endTimeSec: endTimeSec,
          sourceApp: info.sourceApp ?? 'mac_hotkey',
        );

        final pos = info.positionSeconds ?? 0;
        final m = pos ~/ 60;
        final s = pos % 60;
        final ts = '$m:${s.toString().padLeft(2, '0')}';
        await _notify(
          title: 'Moment saved',
          body: '${info.title} · $ts — summarizing in the app',
        );
      } catch (e, st) {
        debugPrint('[MacosSaveHotkey] save failed: $e\n$st');
        await _notify(
          title: 'Save failed',
          body: e.toString(),
        );
      }
    }

    _cmdS = HotKey(
      identifier: 'com.podcasts.safetynet.save.cmd_s',
      key: PhysicalKeyboardKey.keyS,
      modifiers: [HotKeyModifier.meta],
      scope: HotKeyScope.system,
    );
    _cmdShiftS = HotKey(
      identifier: 'com.podcasts.safetynet.save.cmd_shift_s',
      key: PhysicalKeyboardKey.keyS,
      modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
      scope: HotKeyScope.system,
    );

    try {
      await hotKeyManager.register(_cmdS!, keyDownHandler: handle);
      await hotKeyManager.register(_cmdShiftS!, keyDownHandler: handle);
      debugPrint(
        '[MacosSaveHotkey] Registered ⌘S and ⌘⇧S (system-wide save moment)',
      );
    } catch (e, st) {
      debugPrint('[MacosSaveHotkey] register failed: $e\n$st');
      _installed = false;
      _cmdS = null;
      _cmdShiftS = null;
    }
  }

  static Future<void> disposeIfMacos() async {
    if (!_installed) return;
    try {
      if (_cmdS != null) await hotKeyManager.unregister(_cmdS!);
      if (_cmdShiftS != null) await hotKeyManager.unregister(_cmdShiftS!);
    } catch (e, st) {
      debugPrint('[MacosSaveHotkey] unregister: $e\n$st');
    }
    _cmdS = null;
    _cmdShiftS = null;
    _installed = false;
  }

  static Future<void> _notify({
    required String title,
    required String body,
  }) async {
    try {
      final n = LocalNotification(title: title, body: body, silent: false);
      await n.show();
    } catch (e, st) {
      debugPrint('[MacosSaveHotkey] notification: $e\n$st');
    }
  }

  /// Label for settings / docs.
  static String get shortcutDescription => '⌘S or ⌘⇧S';
}
