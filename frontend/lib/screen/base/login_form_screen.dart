import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../data/auth_api_client.dart';
import 'home_screen.dart';

class LoginFormScreen extends StatefulWidget {
  const LoginFormScreen({super.key});

  @override
  State<LoginFormScreen> createState() => _LoginFormScreenState();
}

class _LoginFormScreenState extends State<LoginFormScreen>
    with TickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
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

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    final identifier = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (identifier.isEmpty || password.isEmpty) {
      _showSnackBar('请输入账号和密码');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AppStateScope.of(context).loginUser(
        identifier: identifier,
        password: password,
      );

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (Route<dynamic> route) => false,
      );
    } on AuthApiException catch (error) {
      _showSnackBar(error.message);
    } catch (_) {
      _showSnackBar('登录失败，请稍后再试');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppPalette.kombuGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _logoBreathController.dispose();
    _buttonPressController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
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
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
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
                        '账号登录',
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
                    '欢迎回来，让错题继续变成真正的理解。',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: AppPalette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildInteractiveTextField(
                    controller: _usernameController,
                    label: '用户名或邮箱',
                    icon: Icons.person_outline_rounded,
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
                      _handleLogin();
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
                              color: AppPalette.almondCream.withValues(alpha: 0.18),
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
                                  '验证并登录',
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
                ],
              ),
            ),
          ),
        ],
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
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
      ),
    );
  }
}
