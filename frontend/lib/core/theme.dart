import 'package:flutter/material.dart';

class AppPalette {
  static const Color inkBlue = Color(0xFF111A3A);
  static const Color cream = Color(0xFFF8F2E8);
  static const Color paper = Color(0xFFFFFBF3);
  static const Color mutedText = Color(0xFF8F887D);
  static const Color moodBlue = Color(0xFF405EA9);
  static const Color mint = Color(0xFFA9D9C8);
  static const Color leaf = Color(0xFFB9CC7B);
  static const Color peach = Color(0xFFFFC982);
  static const Color blush = Color(0xFFF6BCD0);
  static const Color coral = Color(0xFFE17D6B);

  static const Color honeyOrange = peach;
  static const Color almondCream = Color(0xFFFFDCA8);
  static const Color matchaMist = leaf;
  static const Color laurelGreen = Color(0xFFC8CFB4);
  static const Color artichoke = Color(0xFF91AC77);
  static const Color pineGreen = moodBlue;
  static const Color kombuGreen = inkBlue;
  static const Color jungleGreen = Color(0xFF0C1430);
  static const Color pastelGrey = Color(0xFFE9DECF);
  static const Color night = inkBlue;
  static const Color textPrimary = inkBlue;
  static const Color textSecondary = mutedText;

  static const LinearGradient appBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cream, paper, Color(0xFFF3EAD9)],
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
    final colorScheme = ColorScheme.light(
      primary: AppPalette.moodBlue,
      onPrimary: Colors.white,
      secondary: AppPalette.peach,
      onSecondary: AppPalette.inkBlue,
      surface: AppPalette.paper,
      onSurface: AppPalette.textPrimary,
      error: AppPalette.coral,
      onError: Colors.white,
    );

    final textTheme = TextTheme(
      displayLarge: _baseTextStyle(
          size: 36,
          weight: FontWeight.w700,
          color: AppPalette.textPrimary,
          height: 1.2),
      displayMedium: _baseTextStyle(
          size: 32,
          weight: FontWeight.w700,
          color: AppPalette.textPrimary,
          height: 1.22),
      headlineLarge: _baseTextStyle(
          size: 28,
          weight: FontWeight.w700,
          color: AppPalette.textPrimary,
          height: 1.25),
      headlineMedium: _baseTextStyle(
          size: 24,
          weight: FontWeight.w600,
          color: AppPalette.textPrimary,
          height: 1.3),
      titleLarge: _baseTextStyle(
          size: 20,
          weight: FontWeight.w600,
          color: AppPalette.textPrimary,
          height: 1.3),
      titleMedium: _baseTextStyle(
          size: 17,
          weight: FontWeight.w600,
          color: AppPalette.textPrimary,
          height: 1.35),
      bodyLarge: _baseTextStyle(
          size: 16,
          weight: FontWeight.w500,
          color: AppPalette.textPrimary,
          height: 1.55),
      bodyMedium: _baseTextStyle(
          size: 14,
          weight: FontWeight.w400,
          color: AppPalette.textSecondary,
          height: 1.55),
      bodySmall: _baseTextStyle(
          size: 12,
          weight: FontWeight.w400,
          color: AppPalette.textSecondary,
          height: 1.45),
      labelLarge: _baseTextStyle(
          size: 15,
          weight: FontWeight.w600,
          color: AppPalette.textPrimary,
          letterSpacing: 0.2),
      labelMedium: _baseTextStyle(
          size: 13,
          weight: FontWeight.w500,
          color: AppPalette.textSecondary,
          letterSpacing: 0.2),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      primaryColor: AppPalette.matchaMist,
      scaffoldBackgroundColor: AppPalette.cream,
      canvasColor: AppPalette.cream,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      splashColor: AppPalette.moodBlue.withOpacity(0.08),
      highlightColor: AppPalette.inkBlue.withOpacity(0.04),
      dividerColor: AppPalette.inkBlue.withOpacity(0.08),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppPalette.honeyOrange,
        selectionColor: Color(0x66FFD6A0),
        selectionHandleColor: AppPalette.honeyOrange,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppPalette.inkBlue,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      appBarTheme: const AppBarThemeData(
        backgroundColor: Colors.transparent,
        foregroundColor: AppPalette.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppPalette.pastelGrey.withOpacity(0.08),
        disabledColor: AppPalette.pastelGrey.withOpacity(0.05),
        selectedColor: AppPalette.matchaMist.withOpacity(0.18),
        secondarySelectedColor: AppPalette.matchaMist.withOpacity(0.18),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: _baseTextStyle(
            size: 13, weight: FontWeight.w500, color: AppPalette.textPrimary),
        secondaryLabelStyle: _baseTextStyle(
            size: 13, weight: FontWeight.w600, color: AppPalette.night),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.matchaMist,
          foregroundColor: AppPalette.night,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppPalette.paper.withOpacity(0.94),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: _baseTextStyle(
          size: 14,
          weight: FontWeight.w400,
          color: AppPalette.textSecondary,
        ),
        prefixIconColor: AppPalette.moodBlue,
        suffixIconColor: AppPalette.moodBlue,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppPalette.inkBlue.withOpacity(0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppPalette.inkBlue.withOpacity(0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppPalette.moodBlue, width: 1.2),
        ),
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: AppPalette.paper,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppPalette.inkBlue.withOpacity(0.08),
      ),
    );
  }
}
