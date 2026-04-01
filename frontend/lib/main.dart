import 'package:flutter/material.dart';
import 'screen/base/splash_screen.dart'; // 确保路径正确

// 🌟 1. 定义一个全局的主题通知器，默认跟随系统
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() {
  runApp(const ZerrorApp());
}

class ZerrorApp extends StatelessWidget {
  const ZerrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 🌟 2. 使用 ValueListenableBuilder 监听主题变化
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: '知芽 Zerror',
          debugShowCheckedModeBanner: false,

          // 🌟 3. 将模式绑定到通知器
          themeMode: currentMode,

          // 浅色主题配置
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: const Color(0xFF70A88D),
            scaffoldBackgroundColor: const Color(0xFFF0F4F2),
            useMaterial3: true,
          ),

          // 深色主题配置
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF70A88D),
            scaffoldBackgroundColor: const Color(0xFF1E2823),
            useMaterial3: true,
          ),

          home: const SplashScreen(),
        );
      },
    );
  }
}