import 'package:flutter/material.dart';

class AppPalette {
  static const Color honeyOrange = Color(0xFFFFA06F);
  static const Color almondCream = Color(0xFFFFD6A0);
  static const Color matchaMist = Color(0xFFACBD86);
  static const Color laurelGreen = Color(0xFFB9BB9F);
  static const Color artichoke = Color(0xFF7C9570);
  static const Color pineGreen = Color(0xFF28544B);
  static const Color kombuGreen = Color(0xFF324A36);
  static const Color jungleGreen = Color(0xFF243924);
  static const Color pastelGrey = Color(0xFFEDE0D0);
  static const Color night = Color(0xFF171712);
  static const Color textPrimary = Color(0xFFF8F3EA);
  static const Color textSecondary = Color(0xFFD6D1C7);

  static const LinearGradient appBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B2119), Color(0xFF233229), Color(0xFF30463B)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [honeyOrange, almondCream, matchaMist],
  );

  static const LinearGradient softGlassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x66EDE0D0), Color(0x33ACBD86)],
  );
}

class AppTheme {
  static const List<String> _fontFallback = [
    'HarmonyOS Sans SC',
    'PingFang SC',
    'Noto Sans SC',
    'Microsoft YaHei',
    'sans-serif',
  ];

  static TextStyle _baseTextStyle({
    required double size,
    required FontWeight weight,
    required Color color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontFamilyFallback: _fontFallback,
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: AppPalette.matchaMist,
      onPrimary: AppPalette.night,
      secondary: AppPalette.honeyOrange,
      onSecondary: AppPalette.night,
      surface: const Color(0xFF233229),
      onSurface: AppPalette.textPrimary,
      error: const Color(0xFFE17D6B),
      onError: Colors.white,
    );

    final textTheme = TextTheme(
      displayLarge: _baseTextStyle(size: 36, weight: FontWeight.w700, color: AppPalette.textPrimary, height: 1.2),
      displayMedium: _baseTextStyle(size: 32, weight: FontWeight.w700, color: AppPalette.textPrimary, height: 1.22),
      headlineLarge: _baseTextStyle(size: 28, weight: FontWeight.w700, color: AppPalette.textPrimary, height: 1.25),
      headlineMedium: _baseTextStyle(size: 24, weight: FontWeight.w600, color: AppPalette.textPrimary, height: 1.3),
      titleLarge: _baseTextStyle(size: 20, weight: FontWeight.w600, color: AppPalette.textPrimary, height: 1.3),
      titleMedium: _baseTextStyle(size: 17, weight: FontWeight.w600, color: AppPalette.textPrimary, height: 1.35),
      bodyLarge: _baseTextStyle(size: 16, weight: FontWeight.w500, color: AppPalette.textPrimary, height: 1.55),
      bodyMedium: _baseTextStyle(size: 14, weight: FontWeight.w400, color: AppPalette.textSecondary, height: 1.55),
      bodySmall: _baseTextStyle(size: 12, weight: FontWeight.w400, color: AppPalette.textSecondary, height: 1.45),
      labelLarge: _baseTextStyle(size: 15, weight: FontWeight.w600, color: AppPalette.textPrimary, letterSpacing: 0.2),
      labelMedium: _baseTextStyle(size: 13, weight: FontWeight.w500, color: AppPalette.textSecondary, letterSpacing: 0.2),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      primaryColor: AppPalette.matchaMist,
      scaffoldBackgroundColor: AppPalette.night,
      canvasColor: AppPalette.night,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      splashColor: AppPalette.almondCream.withValues(alpha: 0.08),
      highlightColor: Colors.white.withValues(alpha: 0.04),
      dividerColor: Colors.white.withValues(alpha: 0.08),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppPalette.honeyOrange,
        selectionColor: Color(0x66FFD6A0),
        selectionHandleColor: AppPalette.honeyOrange,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppPalette.kombuGreen,
        contentTextStyle: const TextStyle(color: AppPalette.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppPalette.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppPalette.pastelGrey.withValues(alpha: 0.08),
        disabledColor: AppPalette.pastelGrey.withValues(alpha: 0.05),
        selectedColor: AppPalette.matchaMist.withValues(alpha: 0.18),
        secondarySelectedColor: AppPalette.matchaMist.withValues(alpha: 0.18),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: _baseTextStyle(size: 13, weight: FontWeight.w500, color: AppPalette.textPrimary),
        secondaryLabelStyle: _baseTextStyle(size: 13, weight: FontWeight.w600, color: AppPalette.night),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.matchaMist,
          foregroundColor: AppPalette.night,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}
