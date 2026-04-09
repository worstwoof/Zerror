import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screen/base/splash_screen.dart';

void main() {
  runApp(const ZerrorApp());
}

class ZerrorApp extends StatelessWidget {
  const ZerrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zerror',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
