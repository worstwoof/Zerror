import 'package:flutter/material.dart';
import 'home_screen.dart'; // 引入首页以便跳转
import 'login_screen.dart'; // 🌟 确保引入了登录页
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // 从设计稿提取的薄荷绿/治愈绿主色调
  final Color primaryGreen = const Color(0xFF70A88D);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 解决键盘弹出时背景被压缩变形的问题
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 底层：带有植物线稿的背景图
          Image.asset(
            'assets/images/auth_bg.png',
            fit: BoxFit.cover,
          ),

          // 2. 顶层内容：使用 SafeArea 避开刘海屏
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0), // 左右留白
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // 🌟 核心：全部靠左对齐
                children: [
                  const SizedBox(height: 60), // 距离顶部的留白

                  // 🌟 Logo
                  Image.asset(
                    'assets/images/logo.png', // 指向你放进去的莲花+文字的 Logo
                    width: 120, // 设定一个合理的宽度
                    fit: BoxFit.contain, // 确保 Logo 在不拉伸的情况下完整显示
                  ),
                  const SizedBox(height: 15),

                  // 🌟 主标题
                  const Text(
                    '立即注册',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 🌟 副标题
                  const Text(
                    '现在免费注册，开始冥想，快来探索\n我们的美好。',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 50), // 标题和表单之间的留白

                  // 🌟 输入框：用户名
                  _buildCustomTextField(hintText: '输入用户名', obscureText: false),
                  const SizedBox(height: 24),

                  // 🌟 输入框：Email
                  _buildCustomTextField(hintText: '输入Email', obscureText: false),
                  const SizedBox(height: 24),

                  // 🌟 输入框：密码
                  _buildCustomTextField(hintText: '输入密码', obscureText: true),
                  const SizedBox(height: 48),

                  // 🌟 注册按钮
                  ElevatedButton(
                    onPressed: () {
                      // TODO: 注册逻辑，暂时跳转首页
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const HomeScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 56), // 更高一些，显得大气
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), // 稍微圆角，不那么圆滑，更契合原图
                      ),
                    ),
                    child: const Text(
                        '立即注册',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)
                    ),
                  ),

                  const Spacer(), // 占据剩余空白，把底部文字推到底下

                  // 🌟 底部去登录链接
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center, // 底部文字居中
                      children: [
                        const Text(
                            '已经有账号？ ',
                            style: TextStyle(color: Colors.white54, fontSize: 14)
                        ),
                    GestureDetector(
                      onTap: () {
                        // 🌟 修复：点击去登录，跳转到登录界面 (LoginScreen)
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                          child: const Text(
                            '去登录',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 提取出来的极简输入框组件 (只留底部边框)
  Widget _buildCustomTextField({required String hintText, required bool obscureText}) {
    return TextField(
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white, fontSize: 16), // 用户输入的字体颜色
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 16), // 占位符颜色
        // 未选中时的底部线条（微透明的白/灰色）
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24, width: 1.0),
        ),
        // 选中/输入时的底部线条（变为治愈绿）
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: primaryGreen, width: 1.5),
        ),
        // 移除内部默认的 padding，使文字和底边框贴合度更好
        contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
      ),
    );
  }
}