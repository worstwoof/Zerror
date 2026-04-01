import 'dart:io';
import 'package:flutter/material.dart';

class ErrorPreviewScreen extends StatelessWidget {
  final String imagePath; // 接收拍下来或选中的图片路径

  const ErrorPreviewScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF1E2823) : const Color(0xFFF0F4F2);
    final primaryGreen = const Color(0xFF70A88D);

    return Scaffold(
      backgroundColor: Colors.black, // 预览页背景通常用纯黑，更沉浸
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('图片预览', style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
      body: Column(
        children: [
          // 1. 图片展示区
          Expanded(
            child: InteractiveViewer( // 允许用户双指放大缩小图片
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                width: double.infinity,
              ),
            ),
          ),

          // 2. 底部操作区
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                // 重拍/重选 按钮
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
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
                // 确认识别 按钮
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: 接入 AI OCR 识别逻辑
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('正在呼叫 AI 提取题目... (功能开发中)'),
                          backgroundColor: primaryGreen,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('提取文字', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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