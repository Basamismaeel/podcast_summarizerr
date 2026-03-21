import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class Tokens {
  // ── Backgrounds ──────────────────────────────────────────────────────
  static const bgPrimary = Color(0xFF0A0A14);
  static const bgSurface = Color(0xFF12121E);
  static const bgElevated = Color(0xFF1A1A2E);
  static const bgOverlay = Color(0xFF22223A);

  // ── Brand ────────────────────────────────────────────────────────────
  static const accent = Color(0xFF6366F1);
  static const accentDim = Color(0x336366F1);
  static const accentBorder = Color(0x666366F1);

  // ── Semantic ─────────────────────────────────────────────────────────
  static const success = Color(0xFF10B981);
  static const successDim = Color(0x1A10B981);
  static const warning = Color(0xFFF59E0B);
  static const warningDim = Color(0x1AF59E0B);
  static const error = Color(0xFFEF4444);
  static const errorDim = Color(0x1AEF4444);

  // ── Text ─────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecond = Color(0x99FFFFFF);
  static const textMuted = Color(0x4DFFFFFF);
  static const textDisabled = Color(0x26FFFFFF);

  // ── Borders ──────────────────────────────────────────────────────────
  static const borderSubtle = Color(0x0FFFFFFF);
  static const borderLight = Color(0x1AFFFFFF);
  static const borderMedium = Color(0x33FFFFFF);

  // ── Typography ───────────────────────────────────────────────────────
  static TextStyle get headingXL => GoogleFonts.syne(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: textPrimary,
      );

  static TextStyle get headingL => GoogleFonts.syne(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: textPrimary,
      );

  static TextStyle get headingM => GoogleFonts.syne(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: textPrimary,
      );

  static TextStyle get headingS => GoogleFonts.syne(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: textPrimary,
      );

  static TextStyle get bodyL => GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: textSecond,
      );

  static TextStyle get bodyM => GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: textSecond,
      );

  static TextStyle get bodyS => GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: textSecond,
      );

  static TextStyle get label => GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: textMuted,
      );

  static TextStyle get mono => GoogleFonts.dmMono(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: textSecond,
      );

  // ── Spacing (8pt grid) ──────────────────────────────────────────────
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;
  static const double spaceXxl = 48.0;

  // ── Radius ───────────────────────────────────────────────────────────
  static const double radiusSm = 8.0;
  static const double radiusMd = 14.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 28.0;
  static const double radiusFull = 999.0;

  // ── Shadows ──────────────────────────────────────────────────────────
  static const cardShadow = BoxShadow(
    color: Color(0x40000000),
    blurRadius: 24,
    offset: Offset(0, 8),
  );

  static const glowAccent = BoxShadow(
    color: Color(0x406366F1),
    blurRadius: 20,
    spreadRadius: -4,
  );

  static const glowSuccess = BoxShadow(
    color: Color(0x4010B981),
    blurRadius: 20,
    spreadRadius: -4,
  );

  // ── Durations ────────────────────────────────────────────────────────
  static const durationFast = Duration(milliseconds: 150);
  static const durationNormal = Duration(milliseconds: 250);
  static const durationSlow = Duration(milliseconds: 400);
  static const durationXslow = Duration(milliseconds: 600);
}
