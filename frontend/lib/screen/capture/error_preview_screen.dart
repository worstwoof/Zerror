import 'dart:io';
import 'package:flutter/material.dart';
import 'error_edit_screen.dart'; // 🌟 引入刚写的编辑页

class ErrorPreviewScreen extends StatefulWidget {
  final String imagePath;

  const ErrorPreviewScreen({super.key, required this.imagePath});

  @override
  State<ErrorPreviewScreen> createState() => _ErrorPreviewScreenState();
}

class _ErrorPreviewScreenState extends State<ErrorPreviewScreen> {
  bool _isRecognizing = false; // 控制加载动画的状态

  // 模拟调用 AI 大模型 OCR 的过程
  Future<void> _startOCR() async {
    setState(() { _isRecognizing = true; });

    // 假装后端 AI 在努力识别，转圈等 2 秒
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() { _isRecognizing = false; });

    // 🌟 识别完成，带上识别出的文字，跳入编辑页！
    // 这里我们先写死一段文本作为占位符，以后替换成真实 API 返回的数据
    String mockExtractedText = "设矩阵 A 的特征值为 λ1, λ2, λ3，且 A 可逆。\n求证：A 的伴随矩阵 A* 的特征值。";

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ErrorEditScreen(
          imagePath: widget.imagePath,
          initialText: mockExtractedText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF1E2823) : const Color(0xFFF0F4F2);
    final primaryGreen = const Color(0xFF70A88D);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('图片预览', style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(
                File(widget.imagePath),
                fit: BoxFit.contain,
                width: double.infinity,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isRecognizing ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                      side: BorderSide(color: isDarkMode ? Colors.white24 : Colors.black12),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('重新选择', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRecognizing ? null : _startOCR, // 🌟 点击调用识别函数
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isRecognizing
                        ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    )
                        : const Text('提取文字', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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