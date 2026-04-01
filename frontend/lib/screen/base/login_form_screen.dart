import 'package:flutter/material.dart';
import 'home_screen.dart';

class LoginFormScreen extends StatefulWidget {
  const LoginFormScreen({super.key});

  @override
  State<LoginFormScreen> createState() => _LoginFormScreenState();
}

class _LoginFormScreenState extends State<LoginFormScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final Color primaryGreen = const Color(0xFF70A88D);

  void _handleLogin() {
    String username = _usernameController.text.trim();
    String password = _passwordController.text.trim();

    if (username == 'zerror' && password == '123456') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('账号或密码不正确，请重试'),
          backgroundColor: const Color(0xFF2C362F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 保持背景图完全一致
          Image.asset('assets/images/auth_bg.png', fit: BoxFit.cover),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),

                  // 这里的 Logo 可以加上一个返回按钮
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context), // 点击返回上一页
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Image.asset('assets/images/logo.png', width: 160, fit: BoxFit.contain),
                    ],
                  ),
                  const SizedBox(height: 40),

                  const Text(
                    '账号登录',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    '欢迎回来，让错误再次发芽。',
                    style: TextStyle(fontSize: 16, height: 1.6, color: Colors.white70),
                  ),
                  const SizedBox(height: 60),

                  _buildCustomTextField(
                      controller: _usernameController,
                      hintText: '输入账号 (默认 zerror)',
                      obscureText: false
                  ),
                  const SizedBox(height: 24),

                  _buildCustomTextField(
                      controller: _passwordController,
                      hintText: '输入密码 (默认 123456)',
                      obscureText: true
                  ),
                  const SizedBox(height: 64),

                  ElevatedButton(
                    onPressed: _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('验证并登录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTextField({required TextEditingController controller, required String hintText, required bool obscureText}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 16),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24, width: 1.0)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryGreen, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
      ),
    );
  }
}