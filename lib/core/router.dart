import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/book_lookup/book_lookup_screen.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/library/library_screen.dart';
import '../screens/manual_entry/manual_entry_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/search/search_placeholder_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/shell/main_shell_scaffold.dart';
import '../screens/summary/summary_screen.dart';
import 'router_transitions.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter createRouter(SharedPreferences prefs) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final onboarded = prefs.getBool('onboarding_done') ?? false;
      final path = state.fullPath ?? '';

      debugPrint('[router] onboarding_done=$onboarded path=$path');

      if (!onboarded && path != '/onboarding') return '/onboarding';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/summary/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return psnTransitionPage<void>(
            key: state.pageKey,
            child: SummaryScreen(sessionId: id),
          );
        },
      ),
      GoRoute(
        path: '/manual-entry',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => psnTransitionPage<void>(
          key: state.pageKey,
          child: const ManualEntryScreen(),
        ),
      ),
      GoRoute(
        path: '/book-lookup',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => psnTransitionPage<void>(
          key: state.pageKey,
          child: const BookLookupScreen(),
        ),
      ),
      GoRoute(
        path: '/auth',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => psnTransitionPage<void>(
          key: state.pageKey,
          child: const AuthScreen(),
        ),
      ),
      GoRoute(
        path: '/search',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => psnTransitionPage<void>(
          key: state.pageKey,
          child: const SearchPlaceholderScreen(),
        ),
      ),
    ],
  );
}
