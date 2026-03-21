import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens.dart';
import '../../providers/settings_provider.dart';
import '../../services/notification_service.dart';
import '../../services/now_playing_banner_coordinator.dart';
import 'spotify_credentials_sheet.dart';
import 'widgets/settings_section.dart';
import 'widgets/settings_tile.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.spaceMd),
        children: [
          const SettingsSection(title: 'Capture'),
          SettingsTile(
            title: 'Now Playing Banner',
            subtitle: 'Shows a quick-save button in your notifications',
            trailing: Switch.adaptive(
              value: settings.bannerEnabled,
              activeTrackColor: Tokens.accent,
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
          SettingsTile(
            title: 'Shake to save',
            subtitle: 'Shake your phone while listening',
            trailing: Switch.adaptive(
              value: settings.shakeEnabled,
              activeTrackColor: Tokens.accent,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setShakeEnabled(v),
            ),
          ),
          SettingsTile(
            title: 'Notifications',
            subtitle: 'Show persistent capture notification',
            trailing: Switch.adaptive(
              value: settings.notificationsEnabled,
              activeTrackColor: Tokens.accent,
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .setNotificationsEnabled(v),
            ),
          ),
          SettingsTile(
            title: 'Haptic feedback',
            subtitle: 'Vibrate on save',
            trailing: Switch.adaptive(
              value: settings.hapticFeedback,
              activeTrackColor: Tokens.accent,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setHapticFeedback(v),
            ),
          ),
          const SizedBox(height: Tokens.spaceLg),
          const SettingsSection(title: 'Advanced'),
          SettingsTile(
            title: 'Spotify API (developer)',
            subtitle: 'Optional testing override — ship credentials in your build for users',
            onTap: () => showSpotifyCredentialsSheet(context),
          ),
          const SizedBox(height: Tokens.spaceLg),
          const SettingsSection(title: 'Summary'),
          SettingsTile(
            title: 'Default style',
            subtitle: settings.defaultSummaryStyle.label,
            onTap: () {},
          ),
          const SizedBox(height: Tokens.spaceLg),
          const SettingsSection(title: 'Account'),
          SettingsTile(
            title: 'Sign in',
            subtitle: 'Sync sessions across devices',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
