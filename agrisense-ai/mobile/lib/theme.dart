// AgriSense AI - Design system
// A deliberate palette grounded in the subject: soil, crop, and sensor data —
// not the default Material green.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary: deep moss — the crop canopy
  static const moss = Color(0xFF1B4332);
  static const mossLight = Color(0xFF2D6A4F);
  // Accent: turmeric ochre — soil and spice, ties to MP agriculture
  static const ochre = Color(0xFFC98A2B);
  // Background: sage mist, not generic cream
  static const background = Color(0xFFEEF2EA);
  static const surface = Color(0xFFFFFFFF);
  // Severity language
  static const healthy = Color(0xFF2D6A4F);
  static const watch = Color(0xFFD68C2A);
  static const alert = Color(0xFFB3401F);
  // Text
  static const ink = Color(0xFF1E2A22);
  static const inkMuted = Color(0xFF5B6B5F);
}

class AppTheme {
  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.moss,
        primary: AppColors.moss,
        secondary: AppColors.ochre,
        surface: AppColors.surface,
        error: AppColors.alert,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    final displayFont = GoogleFonts.fraunces;
    final bodyFont = GoogleFonts.inter;

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineSmall: displayFont(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        titleLarge: displayFont(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        titleMedium: bodyFont(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        bodyMedium: bodyFont(fontSize: 14, color: AppColors.ink),
        bodySmall: bodyFont(fontSize: 12, color: AppColors.inkMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        elevation: 0,
        titleTextStyle: displayFont(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.moss.withValues(alpha: 0.08)),
        ),
      ),
    );
  }

  static TextStyle mono({double size = 15, FontWeight weight = FontWeight.w600, Color? color}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.ink,
    );
  }

  static Color severityColor(String severity) {
    switch (severity) {
      case 'red':
        return AppColors.alert;
      case 'amber':
        return AppColors.watch;
      default:
        return AppColors.healthy;
    }
  }
}