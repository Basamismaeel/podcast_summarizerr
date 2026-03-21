import 'package:flutter/material.dart';

/// User-chosen light/dark behavior (persisted).
enum AppThemePreference {
  system,
  light,
  dark;

  ThemeMode get themeMode => switch (this) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      };

  String get label => switch (this) {
        AppThemePreference.system => 'System',
        AppThemePreference.light => 'Light',
        AppThemePreference.dark => 'Dark',
      };

  static AppThemePreference fromStorage(String? value) {
    switch (value) {
      case 'light':
        return AppThemePreference.light;
      case 'dark':
        return AppThemePreference.dark;
      default:
        return AppThemePreference.system;
    }
  }

  String toStorage() => name;
}
