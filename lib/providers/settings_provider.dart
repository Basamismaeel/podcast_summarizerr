import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_theme_preference.dart';
import '../models/summary_style.dart';

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

class AppSettings {
  const AppSettings({
    this.defaultSummaryStyle = SummaryStyle.insights,
    this.shakeEnabled = true,
    this.bannerEnabled = true,
    this.notificationsEnabled = true,
    this.hapticFeedback = true,
    this.onboardingComplete = false,
    this.themePreference = AppThemePreference.system,
    this.accentColorArgb = 0xFF007AFF,
  });

  final SummaryStyle defaultSummaryStyle;
  final bool shakeEnabled;
  final bool bannerEnabled;
  final bool notificationsEnabled;
  final bool hapticFeedback;
  final bool onboardingComplete;
  final AppThemePreference themePreference;
  /// Stored as 32-bit ARGB (e.g. 0xFF007AFF).
  final int accentColorArgb;

  Color get accentColor => Color(accentColorArgb);

  AppSettings copyWith({
    SummaryStyle? defaultSummaryStyle,
    bool? shakeEnabled,
    bool? bannerEnabled,
    bool? notificationsEnabled,
    bool? hapticFeedback,
    bool? onboardingComplete,
    AppThemePreference? themePreference,
    int? accentColorArgb,
  }) {
    return AppSettings(
      defaultSummaryStyle: defaultSummaryStyle ?? this.defaultSummaryStyle,
      shakeEnabled: shakeEnabled ?? this.shakeEnabled,
      bannerEnabled: bannerEnabled ?? this.bannerEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      themePreference: themePreference ?? this.themePreference,
      accentColorArgb: accentColorArgb ?? this.accentColorArgb,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  static const _defaultAccent = 0xFF007AFF;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      defaultSummaryStyle: SummaryStyle.fromJson(
              prefs.getString('default_summary_style')) ??
          SummaryStyle.insights,
      shakeEnabled: prefs.getBool('shake_enabled') ?? true,
      bannerEnabled: prefs.getBool('banner_enabled') ?? true,
      notificationsEnabled: prefs.getBool('notifications_enabled') ?? true,
      hapticFeedback: prefs.getBool('haptic_feedback') ?? true,
      onboardingComplete: prefs.getBool('onboarding_done') ?? false,
      themePreference:
          AppThemePreference.fromStorage(prefs.getString('theme_preference')),
      accentColorArgb: prefs.getInt('accent_color') ?? _defaultAccent,
    );
  }

  Future<void> setDefaultStyle(SummaryStyle style) async {
    state = state.copyWith(defaultSummaryStyle: style);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_summary_style', style.toJson());
  }

  Future<void> setShakeEnabled(bool value) async {
    state = state.copyWith(shakeEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shake_enabled', value);
  }

  Future<void> setBannerEnabled(bool value) async {
    state = state.copyWith(bannerEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('banner_enabled', value);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    state = state.copyWith(notificationsEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
  }

  Future<void> setHapticFeedback(bool value) async {
    state = state.copyWith(hapticFeedback: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('haptic_feedback', value);
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(onboardingComplete: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
  }

  Future<void> setThemePreference(AppThemePreference value) async {
    state = state.copyWith(themePreference: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_preference', value.toStorage());
  }

  Future<void> setAccentColor(Color color) async {
    final argb = color.toARGB32();
    state = state.copyWith(accentColorArgb: argb);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accent_color', argb);
  }
}
