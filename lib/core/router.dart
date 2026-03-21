import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/tokens.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/design_preview/design_preview_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/manual_entry/manual_entry_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/summary/summary_screen.dart';

class LibraryPlaceholderScreen extends StatelessWidget {
  const LibraryPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: Center(
        child: Text(
          'Library coming soon',
          style: Tokens.headingM,
        ),
      ),
    );
  }
}

GoRouter createRouter(SharedPreferences prefs) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final onboarded = prefs.getBool('onboarding_done') ?? false;
      final path = state.fullPath ?? '';

      // Debug visibility for onboarding flag on app start.
      // Helpful especially on web where persistence can be flaky in debug.
      debugPrint('[router] onboarding_done=$onboarded path=$path');

      if (!onboarded && path != '/onboarding') return '/onboarding';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/summary/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return SummaryScreen(sessionId: id);
        },
      ),
      GoRoute(
        path: '/manual-entry',
        builder: (context, state) => const ManualEntryScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/library',
        builder: (context, state) => const LibraryPlaceholderScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      if (kDebugMode)
        GoRoute(
          path: '/design-preview',
          builder: (context, state) => const DesignPreviewScreen(),
        ),
    ],
  );
}
