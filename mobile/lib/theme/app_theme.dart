import 'package:flutter/material.dart';

/// Boje i tema aplikacije. Status boje prate prijedlog iz dokumentacije:
/// Pending (zuto), Confirmed (plavo), Completed (zeleno), Cancelled (crveno).
class AppColors {
  static const primary = Color(0xFF2F6BE4);
  static const primaryDark = Color(0xFF1E4FB8);
  static const background = Color(0xFFF2F4F7);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF141B2E);
  static const textSecondary = Color(0xFF6B7280);

  // Status boje
  static const pending = Color(0xFFF5A623); // zuto
  static const confirmed = Color(0xFF3B82F6); // plavo
  static const completed = Color(0xFF22C55E); // zeleno
  static const cancelled = Color(0xFFEF4444); // crveno

  // Termini (color-coded)
  static const slotFree = Color(0xFF22C55E);
  static const slotBusy = Color(0xFFEF4444);
  static const slotSelected = Color(0xFF3B82F6);

  static Color forStatus(String status) => switch (status) {
        "Pending" => pending,
        "Confirmed" => confirmed,
        "Completed" => completed,
        "Cancelled" => cancelled,
        _ => textSecondary,
      };

  static String statusLabel(String status) => switch (status) {
        "Pending" => "Na cekanju",
        "Confirmed" => "Potvrdjeno",
        "Completed" => "Zavrseno",
        "Cancelled" => "Otkazano",
        _ => status,
      };
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: "SF Pro Text",
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
