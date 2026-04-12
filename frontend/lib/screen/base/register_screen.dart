import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late AnimationController _logoBreathController;
  late Animation<double> _logoScaleAnimation;
  late AnimationController _buttonPressController;
  late Animation<double> _buttonScaleAnimation;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _logoBreathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _logoScaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(
        parent: _logoBreathController,
        curve: Curves.easeInOutSine,
      ),
    );

    _buttonPressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _buttonPressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _logoBreathController.dispose();
    _buttonPressController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goBackToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> _handleRegister() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBackToLogin();
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(gradient: AppPalette.appBackground),
            ),
            Image.asset('assets/images/auth_bg.png', fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppPalette.pineGreen.withValues(alpha: 0.18),
                    AppPalette.night.withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _goBackToLogin,
                      child: const Padding(
                        padding: EdgeInsets.only(right: 16, top: 8, bottom: 8),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppPalette.textSecondary,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          '立即注册',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.textPrimary,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ScaleTransition(
                          scale: _logoScaleAnimation,
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 80,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      '欢迎加入，让每一道错题都变成新的理解。',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: AppPalette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildInteractiveTextField(
                      controller: _usernameController,
                      label: '用户名',
                      icon: Icons.person_outline_rounded,
                      obscureText: false,
                    ),
                    const SizedBox(height: 32),
                    _buildInteractiveTextField(
                      controller: _emailController,
                      label: '邮箱',
                      icon: Icons.alternate_email_rounded,
                      obscureText: false,
                    ),
                    const SizedBox(height: 32),
                    _buildInteractiveTextField(
                      controller: _passwordController,
                      label: '密码',
                      icon: Icons.lock_outline_rounded,
                      obscureText: true,
                    ),
                    const SizedBox(height: 100),
                    GestureDetector(
                      onTapDown: (_) => _buttonPressController.forward(),
                      onTapUp: (_) {
                        _buttonPressController.reverse();
                        _handleRegister();
                      },
                      onTapCancel: () => _buttonPressController.reverse(),
                      child: ScaleTransition(
                        scale: _buttonScaleAnimation,
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppPalette.almondCream,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppPalette.almondCream.withValues(
                                  alpha: 0.18,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: AppPalette.night,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    '立即注册',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppPalette.night,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '已经有账号？',
                          style: TextStyle(color: AppPalette.textSecondary),
                        ),
                        TextButton(
                          onPressed: _goBackToLogin,
                          child: const Text(
                            '去登录',
                            style: TextStyle(
                              color: AppPalette.almondCream,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscureText,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(
        color: AppPalette.textPrimary,
        fontSize: 16,
        letterSpacing: 1.2,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: AppPalette.textSecondary,
          fontSize: 15,
        ),
        floatingLabelStyle: const TextStyle(
          color: AppPalette.almondCream,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: AppPalette.textSecondary, size: 22),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0x66F8F3EA), width: 1),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppPalette.honeyOrange, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}
