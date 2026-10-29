import "package:flutter/material.dart";

/// Boje aplikacije. Status boje prate dokumentaciju:
/// Pending (zuto), Confirmed (plavo), Completed (zeleno), Cancelled (crveno).
class AppColors {
  static const primary = Color(0xFF2F6BE4);
  static const primaryDark = Color(0xFF1E4FB8);
  static const sidebar = Color(0xFF141B2E);
  static const sidebarHover = Color(0xFF243049);
  static const background = Color(0xFFF2F4F7);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF141B2E);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);

  static const pending = Color(0xFFF5A623);
  static const confirmed = Color(0xFF3B82F6);
  static const completed = Color(0xFF22C55E);
  static const cancelled = Color(0xFFEF4444);

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
    );
    return base.copyWith(
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
