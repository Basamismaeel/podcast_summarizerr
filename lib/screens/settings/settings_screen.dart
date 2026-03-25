import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/podcast_home_colors.dart';
import '../../core/tokens.dart';
import '../../providers/settings_provider.dart';
import '../../services/macos_save_hotkey_service.dart';
import '../../services/notification_service.dart';
import '../../services/now_playing_banner_coordinator.dart';
import 'spotify_credentials_sheet.dart';
import 'widgets/appearance_settings_section.dart';
import 'widgets/settings_section.dart';
import 'widgets/settings_tile.dart';

typedef _SettingsRowFactory = Widget Function();

String _clipSubtitle(int seconds) {
  if (seconds < 60) return '${seconds}s clip';
  if (seconds % 60 == 0) return '${seconds ~/ 60} min clip';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m}m ${s}s clip';
}

List<_SettingsRowFactory> _settingsRowFactories(
  BuildContext context,
  WidgetRef ref,
  AppSettings settings,
) {
  final mac = !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
  return [
    () => const AppearanceSettingsSection(),
    () => const SizedBox(height: Tokens.spaceLg),
    () => const SettingsSection(title: 'Capture'),
    if (mac)
      () => SettingsTile(
            title: 'Keyboard shortcut',
            subtitle:
                'From Spotify or any app, press ${MacosSaveHotkeyService.shortcutDescription} '
                'to save the Now Playing moment. If it does nothing, enable Accessibility '
                'for Podcast Safety Net in System Settings → Privacy & Security.',
          ),
    if (mac)
      () => SettingsTile(
            title: 'Shortcut uses a time window',
            subtitle: settings.macHotkeyUseClipWindow
                ? 'Saves from playhead for ${settings.macHotkeyClipSeconds ~/ 60}m ${settings.macHotkeyClipSeconds % 60}s (not the whole rest of the episode)'
                : 'Saves from playhead to the end of the episode',
            trailing: Switch.adaptive(
              value: settings.macHotkeyUseClipWindow,
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .setMacHotkeyUseClipWindow(v),
            ),
          ),
    if (mac)
      () => SettingsTile(
            title: 'Clip length (⌘S / menu bar)',
            subtitle: _clipSubtitle(settings.macHotkeyClipSeconds),
            onTap: () async {
              final picked = await showModalBottomSheet<int>(
                context: context,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHigh,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final sec in [60, 120, 300, 600, 1200])
                        ListTile(
                          title: Text(_clipSubtitle(sec)),
                          onTap: () => Navigator.pop(ctx, sec),
                        ),
                    ],
                  ),
                ),
              );
              if (picked != null) {
                await ref
                    .read(settingsProvider.notifier)
                    .setMacHotkeyClipSeconds(picked);
              }
            },
          ),
    () => SettingsTile(
          title: 'Now Playing Banner',
          subtitle: 'Shows a quick-save button in your notifications',
          trailing: Switch.adaptive(
            value: settings.bannerEnabled,
            onChanged: (v) async {
              if (v) {
                final granted =
                    await NotificationService.instance.requestPermission();
                if (!granted) return;
                await ref.read(settingsProvider.notifier).setBannerEnabled(v);
                await NowPlayingBannerCoordinator.instance.startIfEnabled();
              } else {
                NowPlayingBannerCoordinator.instance.stop();
                await NotificationService.instance.dismissBanner();
                await ref.read(settingsProvider.notifier).setBannerEnabled(v);
              }
            },
          ),
        ),
    () => SettingsTile(
          title: 'Shake to save',
          subtitle: 'Shake your phone while listening',
          trailing: Switch.adaptive(
            value: settings.shakeEnabled,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setShakeEnabled(v),
          ),
        ),
    () => SettingsTile(
          title: 'Notifications',
          subtitle: 'Show persistent capture notification',
          trailing: Switch.adaptive(
            value: settings.notificationsEnabled,
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .setNotificationsEnabled(v),
          ),
        ),
    () => SettingsTile(
          title: 'Haptic feedback',
          subtitle: 'Vibrate on save',
          trailing: Switch.adaptive(
            value: settings.hapticFeedback,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setHapticFeedback(v),
          ),
        ),
    () => const SizedBox(height: Tokens.spaceLg),
    () => const SettingsSection(title: 'Integrations'),
    () => SettingsTile(
          title: 'Audible',
          subtitle:
              'Paste share links from Audible to summarize by chapter. '
              'Amazon OAuth for auto position is not available — use Share → Copy link.',
          trailing: TextButton(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Audible connection'),
                  content: const Text(
                    'Connecting your Audible account for automatic playback position would use '
                    'undocumented Amazon APIs and can break without notice.\n\n'
                    'This app uses the share link you copy from Audible instead. '
                    'Optional: add GOOGLE_BOOKS_API_KEY in .env for extra book text context.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('About'),
          ),
        ),
    () => SettingsTile(
          title: 'Look up book (Open Library)',
          subtitle:
              'Search title, author, or ISBN. Then use Audible Share → Copy link '
              'from Home so chapter timestamps load (Audnexus).',
          onTap: () => context.push('/book-lookup'),
        ),
    () => const SizedBox(height: Tokens.spaceLg),
    () => const SettingsSection(title: 'Advanced'),
    () => SettingsTile(
          title: 'Spotify API (developer)',
          subtitle:
              'Optional testing override — ship credentials in your build for users',
          onTap: () => showSpotifyCredentialsSheet(context),
        ),
    () => const SizedBox(height: Tokens.spaceLg),
    () => const SettingsSection(title: 'Summary'),
    () => SettingsTile(
          title: 'Default style',
          subtitle: settings.defaultSummaryStyle.label,
          onTap: () {},
        ),
    () => const SizedBox(height: Tokens.spaceLg),
    () => const SettingsSection(title: 'Sharing'),
    () => SettingsTile(
          title: 'Tell a friend',
          subtitle: 'Share a quick pitch for Podcast Safety Net',
          onTap: () {
            Share.share(
              'I use Podcast Safety Net to save podcast moments with exact timestamps '
              'and AI summaries — clips from Spotify/Apple Podcasts to notes I can revisit.',
              subject: 'Podcast Safety Net',
            );
          },
        ),
    () => const SizedBox(height: Tokens.spaceLg),
    () => const SettingsSection(title: 'Account'),
    () => SettingsTile(
          title: 'Sign in',
          subtitle: 'Sync sessions across devices',
          onTap: () {},
        ),
  ];
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsRows = _settingsRowFactories(context, ref, settings);

    return Scaffold(
      backgroundColor: PodcastHomeColors.scaffold(context),
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
        backgroundColor: PodcastHomeColors.scaffold(context),
        foregroundColor: PodcastHomeColors.title(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          Tokens.spaceMd,
          Tokens.spaceMd,
          Tokens.spaceMd,
          Tokens.spaceXl,
        ),
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: false,
        cacheExtent: 500,
        itemCount: settingsRows.length,
        itemBuilder: (context, index) => settingsRows[index](),
      ),
    );
  }
}
