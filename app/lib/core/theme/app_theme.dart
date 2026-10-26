import 'package:flutter/material.dart';

class AppColors {
  // Brand & Harmoni Islami (Emerald, Cypress, Gold, Sand)
  static const Color primary = Color(0xFF0F6E56);
  static const Color primaryDark = Color(0xFF085041);
  static const Color primaryContainer = Color(0xFFE1F5EE);
  static const Color onPrimaryContainer = Color(0xFF04342C);

  static const Color secondary = Color(0xFFC68B2C);
  static const Color secondaryContainer = Color(0xFFFDF3DC);
  static const Color onSecondaryContainer = Color(0xFF4A3208);

  // Neutral & Surfaces (Flat Modern)
  static const Color background = Color(0xFFF6F8F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEDF2EF);
  static const Color outline = Color(0xFFD5E0DA);

  // Typography
  static const Color textPrimary = Color(0xFF16241E);
  static const Color textSecondary = Color(0xFF52665E);
  static const Color textHint = Color(0xFF889992);

  // Semantik (KKM, Absensi, Sinkronisasi)
  static const Color success = Color(0xFF15803D);
  static const Color successSoft = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF0284C7);
  static const Color infoSoft = Color(0xFFE0F2FE);
}

class AppTheme {
  // Aliases for color tokens
  static const Color emeraldPrimary = AppColors.primary;
  static const Color mintSurface = AppColors.primaryContainer;
  static const Color warmGold = AppColors.secondary;
  static const Color sandGrey = AppColors.background;
  static const Color borderSubtle = AppColors.outline;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color textHint = AppColors.textHint;

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceVariant,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.outline,
      error: AppColors.danger,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'PlusJakartaSans',

      // AppBar Flat & Bersih (Anti-elevation tint di Material 3)
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(
          bottom: BorderSide(color: AppColors.outline, width: 1),
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),

      // Card Flat Modern (Zero Shadow + 1px Subtle Border)
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.outline, width: 1),
        ),
      ),

      // Input Field Bersih & Kontras
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),

      // Tombol Primer Taktil
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(88, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Chip Filter & Jenis Nilai
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primaryContainer,
        side: const BorderSide(color: AppColors.outline, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),

      // Divider Tipis
      dividerTheme: const DividerThemeData(
        color: AppColors.outline,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Helper style untuk angka tabel (Nilai, NIS, NISN, KKM) agar sejajar lurus
  static const TextStyle tabularNumberStyle = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
}
