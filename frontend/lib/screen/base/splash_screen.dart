import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _showBackground = false;
  bool _isFadingToBlack = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _fadeController.forward();

    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) setState(() => _showBackground = true);
    });

    Future.delayed(const Duration(milliseconds: 5000), () {
      if (mounted) setState(() => _isFadingToBlack = true);
    });

    Future.delayed(const Duration(milliseconds: 5800), () {
      unawaited(_finishLaunch());
    });
  }

  Future<void> _finishLaunch() async {
    if (!mounted) return;
    final store = AppStateScope.of(context);
    var authenticated = store.isAuthenticated;
    if (!authenticated) {
      authenticated = await store.tryAutoLogin();
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) =>
            authenticated ? const HomeScreen() : const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.night,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: AppPalette.appBackground)),
          AnimatedOpacity(
            opacity: _showBackground ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeInOut,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('assets/images/splash_bg.png', fit: BoxFit.cover),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppPalette.pineGreen.withValues(alpha: 0.22),
                        AppPalette.night.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(top: -80, left: -40, child: _buildGlow(const Size(240, 240), AppPalette.honeyOrange.withValues(alpha: 0.26))),
          Positioned(right: -40, bottom: 120, child: _buildGlow(const Size(220, 220), AppPalette.matchaMist.withValues(alpha: 0.18))),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              Image.asset(
                'assets/images/logo.webp',
                width: 160,
                height: 160,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: const [
                    Text(
                      '知芽',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.textPrimary,
                        letterSpacing: 8.0,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Z E R R O R',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppPalette.textSecondary,
                        letterSpacing: 6.0,
                      ),
                    ),
                    SizedBox(height: 40),
                    Text(
                      '不在错误中焦虑\n在灵感中生长',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.8,
                        color: AppPalette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _isFadingToBlack ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              child: Container(color: AppPalette.night),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlow(Size size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 120, spreadRadius: 24),
          ],
        ),
      ),
    );
  }
}
