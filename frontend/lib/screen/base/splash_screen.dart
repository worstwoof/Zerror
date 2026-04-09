import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart'; // 用于设置状态栏
import 'login_screen.dart'; // 引入登录界面

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // 🌟 核心状态控制：像电影导演一样控制不同图层的出场顺序
  bool _showBackground = false;  // 控制森林背景是否显现
  bool _isFadingToBlack = false; // 控制最终的黑场过渡

  @override
  void initState() {
    super.initState();

    // 1. 设置沉浸式状态栏 (文字白色，背景透明)
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // 2. 文字淡入动画 (前 1.5 秒伴随 Logo 一起出现)
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _fadeController.forward();

    // 🌟 3. 时间轴节点一：第 3 秒，森林背景如朝阳般渐渐浮现
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        setState(() {
          _showBackground = true;
        });
      }
    });

    // 🌟 4. 时间轴节点二：第 5 秒，拉上“黑幕”，准备退场
    Future.delayed(const Duration(milliseconds: 5000), () {
      if (mounted) {
        setState(() {
          _isFadingToBlack = true;
        });
      }
    });

    // 🌟 5. 时间轴节点三：第 5.8 秒，黑幕完全落下，无缝切入登录页
    Future.delayed(const Duration(milliseconds: 5800), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 800),
            pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              // 登录页从纯黑中淡入
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 最底层铺设纯黑色，作为宇宙的底色
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [

          // 🌟 魔法图层 1：森林背景 (使用 AnimatedOpacity 控制它的逐渐显现)
          AnimatedOpacity(
            opacity: _showBackground ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 1200), // 背景渐出的时长为 1.2 秒，极其舒缓
            curve: Curves.easeInOut,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/splash_bg.png',
                  fit: BoxFit.cover,
                ),
                // 附带的暗色遮罩
                Container(color: Colors.black.withOpacity(0.15)),
              ],
            ),
          ),

          // 魔法图层 2：主体内容区 (一直存在于画面中央)
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

              // 你的 WebP 动图
              Image.asset(
                'assets/images/logo.webp',
                width: 160,
                height: 160,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),

              // 文字部分
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    const Text(
                      '知 芽',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 8.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Z E R R O R',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70,
                        letterSpacing: 6.0,
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      '不在错误中焦虑\n在灵感中生长',
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

          // 🌟 魔法图层 3：终极黑布 (覆盖在最顶层)
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _isFadingToBlack ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 800), // 黑幕落下的时间为 0.8 秒
              curve: Curves.easeInOut,
              child: Container(
                color: Colors.black, // 纯黑转场
              ),
            ),
          ),
        ],
      ),
    );
  }
}