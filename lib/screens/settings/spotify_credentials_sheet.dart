import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/tokens.dart';
import '../../services/spotify_episode_service.dart';

/// Lets users save Spotify Web API credentials on the device. This avoids
/// relying only on the bundled `.env` asset (which requires a full rebuild to
/// refresh on iOS).
Future<void> showSpotifyCredentialsSheet(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final idCtrl = TextEditingController(
    text: prefs.getString('spotify_client_id') ?? '',
  );
  final secCtrl = TextEditingController(
    text: prefs.getString('spotify_client_secret') ?? '',
  );

  try {
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final tt = Theme.of(ctx).textTheme;
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            left: Tokens.spaceMd,
            right: Tokens.spaceMd,
            top: Tokens.spaceMd,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + Tokens.spaceMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Spotify API (developer only)',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: Tokens.spaceSm),
              Text(
                'Normal users should not need this. For production, put Client ID '
                'and Secret in your .env and ship a release build so everyone gets them.\n\n'
                'Use this sheet only to test keys on a device without rebuilding, '
                'or for your own debugging.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: idCtrl,
                decoration: const InputDecoration(
                  labelText: 'Client ID',
                  border: OutlineInputBorder(),
                ),
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Client secret',
                  border: OutlineInputBorder(),
                ),
                autocorrect: false,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final id = idCtrl.text.trim();
                  final sec = secCtrl.text.trim();
                  if (id.isEmpty) {
                    await prefs.remove('spotify_client_id');
                  } else {
                    await prefs.setString('spotify_client_id', id);
                  }
                  if (sec.isEmpty) {
                    await prefs.remove('spotify_client_secret');
                  } else {
                    await prefs.setString('spotify_client_secret', sec);
                  }
                  SpotifyEpisodeService.hydrateFromPrefs(prefs);
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          SpotifyEpisodeService.isConfigured
                              ? 'Spotify credentials saved.'
                              : 'Enter both Client ID and Client secret.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Save'),
              ),
              TextButton(
                onPressed: () async {
                  await prefs.remove('spotify_client_id');
                  await prefs.remove('spotify_client_secret');
                  idCtrl.clear();
                  secCtrl.clear();
                  SpotifyEpisodeService.hydrateFromPrefs(prefs);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Clear saved keys'),
              ),
            ],
          ),
        );
      },
    );
  } finally {
    idCtrl.dispose();
    secCtrl.dispose();
  }
}
