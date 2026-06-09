import 'package:flutter/material.dart';

import '../../core/app_ui.dart';
import '../../core/theme.dart';
import 'login_form_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isBlackScreen = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _isBlackScreen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppPalette.appBackground),
          ),
          Positioned(
            top: 96,
            left: -34,
            child: FlatShape(
              width: 126,
              height: 98,
              color: AppPalette.leaf.withOpacity(0.50),
            ),
          ),
          Positioned(
            top: 156,
            right: -28,
            child: FlatShape(
              width: 142,
              height: 110,
              color: AppPalette.mint.withOpacity(0.58),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(52),
                topRight: Radius.circular(34),
                bottomLeft: Radius.circular(38),
                bottomRight: Radius.circular(64),
              ),
            ),
          ),
          Positioned(
            right: 46,
            bottom: 124,
            child: FlatShape(
              width: 86,
              height: 86,
              color: AppPalette.blush.withOpacity(0.46),
              borderRadius: BorderRadius.circular(34),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 80),
                Image.asset(
                  'assets/images/logo.png',
                  width: 300,
                  fit: BoxFit.contain,
                ),
                const Text(
                  '知芽',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.textPrimary,
                    letterSpacing: 8.0,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Z E R R O R',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppPalette.textSecondary,
                    letterSpacing: 6.0,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '智能挖掘错题价值\n让每一次错误都成为生长的养分',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.8,
                    color: AppPalette.textSecondary,
                  ),
                ),
                const SizedBox(height: 60),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 400),
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const LoginFormScreen(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                              opacity: animation, child: child);
                        },
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.inkBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25)),
                  ),
                  child: const Text('立即登录',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('还没有账号？',
                        style: TextStyle(color: AppPalette.textSecondary)),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                              builder: (context) => const RegisterScreen()),
                        );
                      },
                      child: const Text(
                        '去注册',
                        style: TextStyle(
                            color: AppPalette.moodBlue,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _isBlackScreen ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              child: Container(color: AppPalette.inkBlue),
            ),
          ),
        ],
      ),
    );
  }
}
