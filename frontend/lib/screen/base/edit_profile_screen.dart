import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // 保持与主色调一致的颜色配置
  final Color bgDark = const Color(0xFF1E2823);
  final Color primaryGreen = const Color(0xFF70A88D);
  final Color inputBgColor = const Color(0xFF2A352F); // 输入框底色，比背景稍亮
  final Color currentTextColor = Colors.white;
  final Color currentSubTextColor = Colors.white70;

  File? _avatarImage;
  final picker = ImagePicker();

  // 基础资料 Controller
  late TextEditingController _nameController;
  late TextEditingController _idController;
  late TextEditingController _bioController;

  // 账号安全 Controller
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _isPasswordObscured = true; // 控制密码是否隐藏

  @override
  void initState() {
    super.initState();
    // 模拟初始数据
    _nameController = TextEditingController(text: 'Zander');
    _idController = TextEditingController(text: 'zerror_001');
    _bioController = TextEditingController(text: '学习就像种树，让错误再次发芽');

    _emailController = TextEditingController(text: 'zander@example.com');
    _passwordController = TextEditingController(text: '12345678');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 调起相册选择头像
  Future<void> _pickAvatar() async {
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _avatarImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('选择头像失败: $e');
    }
  }

  // 保存操作
  void _saveProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('资料保存成功'),
        backgroundColor: primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.pop(context); // 保存后返回上一页
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // 允许底层背景透出
      extendBodyBehindAppBar: true, // 延伸到 AppBar 背后

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('编辑资料', style: TextStyle(color: currentTextColor, fontSize: 18, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: currentTextColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: Text('保存', style: TextStyle(color: primaryGreen, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: Stack(
        fit: StackFit.expand,
        children: [
          // 第一层：背景图
          Image.asset(
            'assets/images/auth_bg.png', // 确保路径正确
            fit: BoxFit.cover,
          ),

          // 第二层：暗色遮罩
          Container(color: Colors.black.withOpacity(0.25)),

          // 第三层：交互内容区
          SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(), // 点击空白处收起键盘
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // 改为左对齐，方便排版标题
                  children: [
                    // 🌟 头像编辑区域 (居中)
                    Center(
                      child: GestureDetector(
                        onTap: _pickAvatar,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.15), width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.black26,
                                backgroundImage: _avatarImage != null
                                    ? FileImage(_avatarImage!) as ImageProvider
                                    : const NetworkImage('https://picsum.photos/200'),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryGreen,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black45, width: 2.5),
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // 🌟 分组 1：基础资料
                    _buildSectionTitle('基础资料'),
                    const SizedBox(height: 16),
                    _buildInputField(label: '昵称', controller: _nameController, hintText: '请输入昵称'),
                    const SizedBox(height: 20),
                    _buildInputField(label: '账号 ID', controller: _idController, hintText: '设置专属 ID', helperText: 'ID 是你在应用中的唯一标识。'),
                    const SizedBox(height: 20),
                    _buildInputField(label: '个性签名', controller: _bioController, hintText: '一句话介绍自己', maxLines: 3),

                    const SizedBox(height: 40),

                    // 🌟 分组 2：账号安全
                    _buildSectionTitle('账号安全'),
                    const SizedBox(height: 16),
                    _buildInputField(
                      label: '绑定邮箱',
                      controller: _emailController,
                      hintText: '请输入邮箱地址',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      label: '登录密码',
                      controller: _passwordController,
                      hintText: '设置新密码',
                      obscureText: _isPasswordObscured, // 密码隐藏属性
                      suffixIcon: IconButton( // 右侧小眼睛图标
                        icon: Icon(
                          _isPasswordObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: currentSubTextColor,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordObscured = !_isPasswordObscured;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 60), // 底部留白
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 辅助方法：构建分组小标题
  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: primaryGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(color: currentTextColor, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // 统一的输入框构建方法 (增强版)
  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    String? helperText,
    int maxLines = 1,
    bool obscureText = false, // 是否隐藏文本 (密码)
    Widget? suffixIcon,       // 右侧图标 (小眼睛等)
    TextInputType? keyboardType, // 键盘类型 (邮箱等)
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: currentSubTextColor, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: TextStyle(color: currentTextColor, fontSize: 16),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: currentTextColor.withOpacity(0.3)),
            filled: true,
            fillColor: inputBgColor,
            suffixIcon: suffixIcon, // 接入右侧图标
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            // 无焦点时的边框
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.transparent),
            ),
            // 获取焦点时的边框（主题色高亮）
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: primaryGreen.withOpacity(0.8), width: 1.5),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Text(helperText, style: TextStyle(color: currentTextColor.withOpacity(0.4), fontSize: 12)),
          ),
        ],
      ],
    );
  }
}