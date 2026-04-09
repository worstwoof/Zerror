import 'package:flutter/material.dart';
import 'home_screen.dart';

class LoginFormScreen extends StatefulWidget {
  const LoginFormScreen({super.key});

  @override
  State<LoginFormScreen> createState() => _LoginFormScreenState();
}

// 🌟 引入 TickerProviderStateMixin 以支持多重动画
class _LoginFormScreenState extends State<LoginFormScreen> with TickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final Color primaryGreen = const Color(0xFF70A88D);

  // --- 交互动画控制器 ---
  late AnimationController _logoBreathController; // Logo 呼吸动画
  late Animation<double> _logoScaleAnimation;

  late AnimationController _buttonPressController; // 按钮物理按压动画
  late Animation<double> _buttonScaleAnimation;

  bool _isLoading = false; // 控制按钮的加载状态

  @override
  void initState() {
    super.initState();

    // 🌟 1. Logo 呼吸动画初始化 (无限循环，极其舒缓的节奏)
    _logoBreathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _logoScaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _logoBreathController, curve: Curves.easeInOutSine),
    );

    // 🌟 2. 按钮物理按压动画初始化 (极短的 Q 弹反馈)
    _buttonPressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100), // 按下瞬间变小
      reverseDuration: const Duration(milliseconds: 150), // 松开时回弹稍微慢一点
    );

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _buttonPressController, curve: Curves.easeInOut),
    );
  }

  void _handleLogin() async {
    // 如果正在加载，不响应重复点击
    if (_isLoading) return;

    String username = _usernameController.text.trim();
    String password = _passwordController.text.trim();

    if (username == 'zerror' && password == '123456') {
      // 🌟 交互优化：触发加载状态
      setState(() => _isLoading = true);

      // 模拟真实的网络请求延迟 (1.5秒)，让用户看到好看的 Loading 动画
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
              (Route<dynamic> route) => false,
        );
      }
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
          Image.asset('assets/images/auth_bg.png', fit: BoxFit.cover),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // 返回按钮
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 22),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 🌟 交互优化 1：主标题与“会呼吸”的 Logo 结合
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        '账号登录',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 7.0,
                        ),
                      ),
                      const SizedBox(width: 5),
                      // 让 Logo 跟在文字后面，并随着控制器轻微呼吸缩放
                      ScaleTransition(
                        scale: _logoScaleAnimation,
                        child: Image.asset('assets/images/logo.png', height: 80, fit: BoxFit.contain),
                      ),
                    ],
                  ),

                  const Text(
                    '欢迎回来，让错误再次发芽。',
                    style: TextStyle(fontSize: 15, height: 1.6, color: Colors.white70),
                  ),
                  const SizedBox(height: 40),

                  // 🌟 交互优化 2：带有动态悬浮占位符和图标的输入框
                  _buildInteractiveTextField(
                    controller: _usernameController,
                    label: '账号 (默认 zerror)',
                    icon: Icons.person_outline_rounded,
                    obscureText: false,
                  ),
                  const SizedBox(height: 32),

                  _buildInteractiveTextField(
                    controller: _passwordController,
                    label: '密码 (默认 123456)',
                    icon: Icons.lock_outline_rounded,
                    obscureText: true,
                  ),
                  const SizedBox(height: 100),

                  // 🌟 交互优化 3：带有真实物理反馈和 Loading 状态的按钮
                  GestureDetector(
                    onTapDown: (_) => _buttonPressController.forward(), // 按下时缩小
                    onTapUp: (_) {
                      _buttonPressController.reverse(); // 松开时回弹
                      _handleLogin(); // 触发登录
                    },
                    onTapCancel: () => _buttonPressController.reverse(), // 划走时恢复
                    child: ScaleTransition(
                      scale: _buttonScaleAnimation,
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: primaryGreen,
                          borderRadius: BorderRadius.circular(12),
                          // 给按钮加一点极其轻微的阴影，增加实体感
                          boxShadow: [
                            BoxShadow(
                              color: primaryGreen.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isLoading
                          // 如果在加载，显示优雅的白色菊花
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                          // 否则显示文字
                              : const Text(
                            '验证并登录',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
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

  // 🌟 重新设计的交互式输入框
  Widget _buildInteractiveTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscureText
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 1.2),
      decoration: InputDecoration(
        // 使用 labelText 替代 hintText，实现“点击上浮变小”的动态占位符效果
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 15),
        floatingLabelStyle: TextStyle(color: primaryGreen, fontSize: 16, fontWeight: FontWeight.w500),

        // 增加前缀图标，视觉引导更清晰
        prefixIcon: Icon(icon, color: Colors.white54, size: 22),

        // 未聚焦时的底部线条 (稍微明显一点)
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white38, width: 1.0),
        ),
        // 聚焦时底线变粗、变成品牌绿，并带有微妙的光晕感
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: primaryGreen, width: 2.0),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
      ),
    );
  }
}