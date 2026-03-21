import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Tokens.bgPrimary,
      primaryColor: Tokens.accent,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      fontFamily: GoogleFonts.dmSans().fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: Tokens.accent,
        surface: Tokens.bgSurface,
        error: Tokens.error,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Tokens.bgPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: Tokens.headingM,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Tokens.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: Tokens.bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          side: const BorderSide(color: Tokens.borderLight, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Tokens.bgElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          borderSide: const BorderSide(color: Tokens.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          borderSide: const BorderSide(color: Tokens.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          borderSide: const BorderSide(color: Tokens.accent, width: 1.5),
        ),
        hintStyle: const TextStyle(color: Tokens.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Tokens.bgSurface,
        selectedItemColor: Tokens.accent,
        unselectedItemColor: Tokens.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: Tokens.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Tokens.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusLg),
        ),
      ),
    );
  }
}
