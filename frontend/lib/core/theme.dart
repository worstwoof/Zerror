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

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      primaryColor: AppPalette.matchaMist,
      scaffoldBackgroundColor: AppPalette.night,
      canvasColor: AppPalette.night,
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
