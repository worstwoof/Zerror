import 'dart:io';

import 'package:flutter/material.dart';
import '../../data/ai_api_client.dart';
import '../../core/theme.dart';
import 'error_edit_screen.dart'; // 🌟 引入刚写的编辑页

class ErrorPreviewScreen extends StatefulWidget {
  const ErrorPreviewScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<ErrorPreviewScreen> createState() => _ErrorPreviewScreenState();
}

class _ErrorPreviewScreenState extends State<ErrorPreviewScreen> {
  final AiApiClient _apiClient = const AiApiClient();
  bool _isRecognizing = false; // 控制加载动画的状态

  // 直接调用图片解析接口，减少 OCR 误差在前端二次放大的问题。
  Future<void> _startOCR() async {
    setState(() { _isRecognizing = true; });

    try {
      final payload = await _apiClient.analyzeImage(
        imagePath: widget.imagePath,
      );
      if (!mounted) return;
      setState(() { _isRecognizing = false; });

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ErrorEditScreen(
            imagePath: widget.imagePath,
            initialText: payload.extractedText,
            initialAnalysis: payload.analysis,
          ),
        ),
      );
    } on AiApiException catch (error) {
      if (!mounted) return;
      setState(() { _isRecognizing = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('图片解析失败：${error.message}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() { _isRecognizing = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('图片解析失败，请检查本地后端是否已启动。'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.night,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppPalette.textPrimary),
        title: const Text('图片预览', style: TextStyle(color: AppPalette.textPrimary, fontSize: 18)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppPalette.kombuGreen,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppPalette.pastelGrey.withValues(alpha: 0.08)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.contain,
                  width: double.infinity,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
            decoration: BoxDecoration(
              color: AppPalette.night.withValues(alpha: 0.94),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: AppPalette.pastelGrey.withValues(alpha: 0.08))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isRecognizing ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPalette.textPrimary,
                      side: BorderSide(color: AppPalette.pastelGrey.withValues(alpha: 0.18)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('重新选择', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRecognizing ? null : _startOCR,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.almondCream,
                      foregroundColor: AppPalette.night,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isRecognizing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: AppPalette.night, strokeWidth: 2),
                          )
                        : const Text('分析题目', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
