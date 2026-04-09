import 'package:flutter/material.dart';
import '../capture/error_edit_screen.dart'; // 🌟 修复 1：修改了相对引入路径

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  // 保持与主页、预览页一致的色值
  final Color bgDark = const Color(0xFF1E2823);
  final Color primaryGreen = const Color(0xFF70A88D);
  final Color inputBgColor = const Color(0xFF2A352F);
  final Color currentTextColor = Colors.white;

  final TextEditingController _textController = TextEditingController();

  // 🌟 核心逻辑：点击“确定”后，跳转到统一的 ErrorEditScreen
  void _proceedToEdit() {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入题目内容后再继续')),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ErrorEditScreen(
          imagePath: '', // 手动录入没有图片，传入空字符串或占位符
          initialText: _textController.text, // 传入手动输入的文字
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('手动录入题目', style: TextStyle(color: Colors.white, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 背景图层：复用项目的暗色底图
          Positioned.fill(
            child: Image.asset('assets/images/auth_bg.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            // 🌟 修复 2：使用最新的 .withValues(alpha: x) 语法
            child: Container(color: Colors.black.withValues(alpha: 0.3)),
          ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: inputBgColor.withValues(alpha: 0.8), // 🌟 修复 2
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)), // 🌟 修复 2
                      ),
                      child: TextField(
                        controller: _textController,
                        maxLines: null, // 自动换行
                        autofocus: true, // 进页面自动弹出键盘
                        style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6),
                        decoration: const InputDecoration(
                          hintText: '在这里输入或粘贴题目内容...\n\n支持 LaTeX 公式录入',
                          hintStyle: TextStyle(color: Colors.white30),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),

                // 底部操作按钮区
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  decoration: BoxDecoration(
                    color: bgDark,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _proceedToEdit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('下一步：完善档案',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}