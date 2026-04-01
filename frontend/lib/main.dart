import 'package:flutter/material.dart';
import 'screen/base/splash_screen.dart';

void main() {
  runApp(const DouDuiApp());
}

class DouDuiApp extends StatelessWidget {
  const DouDuiApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. 定义核心颜色
    const Color primaryColor = Color(0xFF6A8A71); // 鼠尾草绿
    const Color secondaryColor = Color(0xFF8A9A85); // 薄荷灰绿
    const Color backgroundColor = Color(0xFFF8F9F6); // 燕麦白
    const Color textColorPrimary = Color(0xFF2C362F); // 深松木灰
    const Color textColorSecondary = Color(0xFF8A928C); // 晨雾灰

    return MaterialApp(
      title: '知芽 Zerror',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          secondary: secondaryColor,
          surface: backgroundColor,
        ),
        // 2. 全局卡片样式重写 (极轻微阴影，纯白底色)
        cardTheme: CardThemeData( // 🌟 修复：改为 CardThemeData
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            // 🌟 修复：改为 withValues(alpha: 0.1)
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        // 3. 全局文本样式规范
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: textColorPrimary, height: 1.4), // H1
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textColorPrimary, height: 1.4), // H2
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColorPrimary, height: 1.5), // H3
          bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: textColorPrimary, height: 1.6), // Body
          bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: textColorSecondary), // Caption
        ),
      ),
      home: const SplashScreen(), // 指向真正的首页
    );
  }
}