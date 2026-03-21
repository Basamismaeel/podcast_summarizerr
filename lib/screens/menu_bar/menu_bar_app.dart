import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../database/database.dart';
import '../../models/now_playing_info.dart';
import '../../models/summary_style.dart';
import '../../providers/session_provider.dart';
import '../../services/now_playing_service.dart';

class MacMenuBarApp extends ConsumerStatefulWidget {
  const MacMenuBarApp({super.key});

  @override
  ConsumerState<MacMenuBarApp> createState() => _MacMenuBarAppState();
}

class _MacMenuBarAppState extends ConsumerState<MacMenuBarApp>
    with TrayListener, WindowListener {
  Timer? _pollTimer;
  NowPlayingInfo? _nowPlaying;
  bool _windowVisible = false;

  static final _saveHotkey = HotKey(
    key: PhysicalKeyboardKey.keyS,
    modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
  );

  @override
  void initState() {
    super.initState();
    if (!Platform.isMacOS) return;
    unawaited(_initMenuBar());
  }

  Future<void> _initMenuBar() async {
    await localNotifier.setup(
      appName: 'Podcast Safety Net',
      shortcutPolicy: ShortcutPolicy.requireCreate,
    );

    trayManager.addListener(this);
    windowManager.addListener(this);

    try {
      await trayManager.setIcon('assets/tray_icon.png');
    } catch (_) {}
    await trayManager.setToolTip('Podcast Safety Net');

    await windowManager.setTitle('Podcast Safety Net');
    await windowManager.setSize(const Size(320, 400));
    await windowManager.setMinimumSize(const Size(320, 400));
    await windowManager.setMaximumSize(const Size(320, 520));
    await windowManager.setSkipTaskbar(true);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.hide();

    await hotKeyManager.register(
      _saveHotkey,
      keyDownHandler: (_) async {
        debugPrint('[_hotkey] Command+Shift+S pressed');
        await _saveMoment();
      },
    );

    await _refreshNowPlaying();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshNowPlaying(),
    );
  }

  Future<void> _refreshNowPlaying() async {
    final info = await NowPlayingService.instance.getCurrentNowPlaying();
    if (!mounted) return;
    setState(() {
      _nowPlaying = info;
    });
  }

  Future<void> _saveMoment() async {
    debugPrint('[_saveMoment] called');
    final info = await NowPlayingService.instance.getCurrentNowPlaying();
    if (info == null) {
      debugPrint('[_saveMoment] info == null (nothing playing)');
      final notification = LocalNotification(
        title: 'Nothing playing',
        body: 'Nothing playing — open Spotify first',
        silent: false,
      );
      await notification.show();
      return;
    }

    final actions = ref.read(sessionActionsProvider);
    debugPrint(
      '[_saveMoment] saving title="${info.title}" artist="${info.artist}" sourceApp="${info.sourceApp}" pos=${info.positionSeconds ?? 0}',
    );
    final id = await actions.createAndSummarize(
      title: info.title,
      artist: info.artist.isEmpty ? 'Unknown Podcast' : info.artist,
      saveMethod: SaveMethod.manual,
      startTimeSec: info.positionSeconds ?? 0,
      sourceApp: info.sourceApp ?? 'mac_menu_bar',
    );
    debugPrint('[_saveMoment] created session id=$id');

    final ts = _formatTs(info.positionSeconds ?? 0);
    final notification = LocalNotification(
      title: 'Moment Saved ✓',
      body: '${info.title} at $ts',
      silent: false,
    );
    await notification.show();
    await _refreshNowPlaying();
  }

  String _formatTs(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleWindow() async {
    debugPrint('[_toggleWindow] windowVisible=$_windowVisible');
    if (_windowVisible) {
      await windowManager.hide();
      _windowVisible = false;
      return;
    }
    await windowManager.show();
    await windowManager.focus();
    _windowVisible = true;
  }

  @override
  void onTrayIconMouseDown() {
    debugPrint('[_tray] tray icon mouse down');
    unawaited(_toggleWindow());
  }

  @override
  void onWindowBlur() {
    debugPrint('[_window] window blur -> hiding');
    unawaited(windowManager.hide());
    _windowVisible = false;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    unawaited(hotKeyManager.unregister(_saveHotkey));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(allSessionsProvider);
    final recent = sessionsAsync.maybeWhen(
      data: (items) => items.take(3).toList(),
      orElse: () => const <ListeningSession>[],
    );

    return MacosApp(
      debugShowCheckedModeBanner: false,
      title: 'Podcast Safety Net',
      home: MacosWindow(
        child: Container(
          padding: const EdgeInsets.all(14),
          color: const Color(0xFF141414),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🎙 Podcast Safety Net',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF2D2D2D), height: 1),
              const SizedBox(height: 12),
              const Text(
                'Now Playing:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                _nowPlaying == null
                    ? 'Nothing detected'
                    : '📻 ${_nowPlaying!.title} — ${_nowPlaying!.artist}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                _nowPlaying == null
                    ? '--:--'
                    : '${_formatTs(_nowPlaying!.positionSeconds ?? 0)} ▶',
                style: const TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: PushButton(
                  controlSize: ControlSize.large,
                  onPressed: _saveMoment,
                  child: const Text('🔖 Save This Moment'),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF2D2D2D), height: 1),
              const SizedBox(height: 12),
              const Text(
                'Recent Saves:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: recent
                      .map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '• ${s.title} · ${SessionStatus.fromJson(s.status).label}',
                            style: const TextStyle(color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  PushButton(
                    controlSize: ControlSize.large,
                    child: const Text('Open Full App'),
                    onPressed: () async {
                      await windowManager.show();
                      await windowManager.focus();
                    },
                  ),
                  const SizedBox(width: 8),
                  PushButton(
                    controlSize: ControlSize.large,
                    child: const Text('Settings'),
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
