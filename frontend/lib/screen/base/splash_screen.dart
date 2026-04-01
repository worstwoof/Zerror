import 'package:flutter/material.dart';
import 'dart:async';
import 'home_screen.dart'; // 引入我们之前写好的首页

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

    // 1. 设置一个呼吸感的渐显动画 (持续 1.5 秒)
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();

    // 2. 设置定时器，2.5 秒后自动跳转到 HomeScreen，并销毁当前启动页
    Timer(const Duration(milliseconds: 2500), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
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
          // 底层图层：全屏背景图
          Image.asset(
            'assets/images/splash_bg.png',
            fit: BoxFit.cover, // 保持比例缩放并裁剪以铺满屏幕
          ),

          // 顶层图层：Logo 与文字 (使用渐显动画)
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 占位 Logo：用 Flutter 自带的生态/植物图标代替你设计图里的莲花
                // 以后你有透明背景的 Logo 切图了，这里可以换成 Image.asset
                const Icon(
                  Icons.spa_rounded,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),

                // 主标题：知芽
                const Text(
                  '知 芽',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 8.0, // 加大字间距，提升高级感
                  ),
                ),
                const SizedBox(height: 8),

                // 英文副标题
                Text(
                  'Z E R R O R',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.8), // 微微透明，增加层次
                    letterSpacing: 6.0,
                  ),
                ),
                const SizedBox(height: 40),

                // 底部 Slogan
                Text(
                  '做冥想，保持专注\n过健康的生活',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.8,
                    color: Colors.white.withValues(alpha: 0.9),
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