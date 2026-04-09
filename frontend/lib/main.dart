import 'package:flutter/material.dart';
import 'screen/base/splash_screen.dart'; // 确保路径正确

void main() {
  runApp(const ZerrorApp());
}

class ZerrorApp extends StatelessWidget {
  const ZerrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 🌟 直接返回 MaterialApp，并强制锁定为深色模式
    return MaterialApp(
      title: '知芽 Zerror',
      debugShowCheckedModeBanner: false,

      // 强制使用深色主题
      themeMode: ThemeMode.dark,

      // 只保留深色主题配置
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF70A88D),
        scaffoldBackgroundColor: const Color(0xFF1E2823),
        useMaterial3: true,
      ),

      home: const SplashScreen(),
    );
  }
}