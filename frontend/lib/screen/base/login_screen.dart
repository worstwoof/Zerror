import 'package:flutter/material.dart';
import 'home_screen.dart'; // 引入首页以便未来跳转
import 'register_screen.dart'; // 🌟 确保引入了注册页
import 'login_form_screen.dart'; // 🌟 引入刚写好的表单页

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 定义主色调 (与设计稿一致的治愈绿)
  final Color primaryColor = const Color(0xFF6A8A71);
  final Color textColorPrimary = const Color(0xFF2C362F); // 深松木灰

  // 控制开场黑幕的状态变量
  bool _isBlackScreen = true;

  @override
  void initState() {
    super.initState();
    // 页面渲染出第一帧后，立刻触发“揭开黑幕”的动画
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _isBlackScreen = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 使用 Stack 组件来实现背景图铺满，文字 Logo 悬浮在其上
      body: Stack(
        fit: StackFit.expand, // 让子组件填满整个屏幕
        children: [
          // 1. 底层图层：全屏背景图 (复用之前的森林背景)
          Image.asset(
            'assets/images/splash_bg.png',
            fit: BoxFit.cover, // 保持比例缩放并裁剪以铺满屏幕
          ),

          // 2. 顶层图层：Logo 与表单区域
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // 居中显示
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 占位 Spacer，将主要内容垂直居中偏下一些
                const SizedBox(height: 80),

                // Logo 区域
                Image.asset(
                  'assets/images/logo.png', // 指向你放进去的莲花+文字的 Logo
                  width: 300, // 设定一个合理的宽度
                  fit: BoxFit.contain, // 确保 Logo 在不拉伸的情况下完整显示
                ),

                // 🌟 主标题：与 Splash 完美对齐的排版
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
                const SizedBox(height: 24), // 增加一点与副标题的间距，让层次更分明

                // 副标题：修改为错题复盘相关主题
                const Text(
                  '智能挖掘错题价值\n让每一次错误都成为生长的养分',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.8,
                    color: Colors.white70, // 微微透明，增加层次
                  ),
                ),
                const SizedBox(height: 60), // spacer

                // 登录按钮 (全圆角主按钮)
                ElevatedButton(
                  onPressed: () {
                    // 核心魔法：使用 FadeTransition 实现无缝交叉淡入淡出
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        // 设定动画时长为 400 毫秒
                        transitionDuration: const Duration(milliseconds: 400),
                        // 目标页面
                        pageBuilder: (context, animation, secondaryAnimation) => const LoginFormScreen(),
                        // 动画构建器：让新页面渐渐浮现
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 50), // 按钮填满宽度
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: const Text('立即登录', style: TextStyle(fontWeight: FontWeight.bold)),
                ),

                const SizedBox(height: 24),

                // 注册入口
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('还没有账号？', style: TextStyle(color: Colors.white70)),
                    TextButton(
                      onPressed: () {
                        // 跳转到注册界面 (RegisterScreen)
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const RegisterScreen()),
                        );
                      },
                      child: Text(
                        '去注册',
                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                // 底部 Spacer
                const SizedBox(height: 40),
              ],
            ),
          ),

          // 3. 最顶层图层：逐渐消散的黑幕
          // IgnorePointer 确保这层黑布不会阻挡用户的点击事件
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _isBlackScreen ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 1200), // 黑幕消散的时长，1.2秒极具呼吸感
              curve: Curves.easeInOut,
              child: Container(
                color: Colors.black, // 纯黑布
              ),
            ),
          ),
        ],
      ),
    );
  }
}