import 'package:flutter/material.dart';

import '../../core/app_ui.dart';
import '../../core/theme.dart';
import '../capture/error_edit_screen.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final TextEditingController _textController = TextEditingController();

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
          imagePath: '',
          initialText: _textController.text,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
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
        title: const Text('手动录入题目', style: TextStyle(color: AppPalette.textPrimary, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppPalette.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AppSurface(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 72),
            const AppSectionTitle(
              title: '输入题目内容',
              subtitle: '支持粘贴题目、手动录入，公式也可以一起写',
              icon: Icons.edit_note_rounded,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AppPanel(
                borderRadius: 28,
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  autofocus: true,
                  style: const TextStyle(color: AppPalette.textPrimary, fontSize: 16, height: 1.7),
                  decoration: const InputDecoration(
                    hintText: '在这里输入或粘贴题目内容...\n\n支持 LaTeX 公式、条件、图形描述等完整信息。',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: AppPrimaryButton(
                label: '下一步：完善档案',
                icon: Icons.arrow_forward_rounded,
                onPressed: _proceedToEdit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
