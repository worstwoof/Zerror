import 'package:flutter/material.dart';
import 'dart:async';
import 'login_screen.dart'; // 🌟 1. 引入剛搓好的登录界面

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // 初始化呼吸动画
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();

    // 🌟 2. 重新开启 Timer，设置 2.5 秒后自动跳转到 LoginScreen
    Timer(const Duration(milliseconds: 2500), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand, // 让子组件填满整个屏幕
        children: [
          // 3. 全屏森林背景图 (assets/images/splash_bg.png)
          Image.asset(
            'assets/images/splash_bg.png',
            fit: BoxFit.cover, // 保持比例缩放并裁剪以铺满屏幕
          ),

          // 4. 文字 (使用渐显动画)
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 占位 Logo
                Image.asset(
                  'assets/images/logo.png', // 指向你放进去的莲花+文字的 Logo
                  width: 250, // 设定一个合理的宽度
                  fit: BoxFit.contain, // 确保 Logo 在不拉伸的情况下完整显示
                ),
                const SizedBox(height: 24),

                // 知芽
                const Text(
                  '知 芽',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 8.0, // 加大字间距
                  ),
                ),
                const SizedBox(height: 8),

                // Z E R R O R
                Text(
                  'Z E R R O R',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.white70,
                    letterSpacing: 6.0,
                  ),
                ),
                const SizedBox(height: 40),

                // Slogan
                const Text(
                  '做冥想，保持专注\n过健康的生活',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.8,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
