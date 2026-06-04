import 'package:flutter/material.dart';

import '../../core/theme.dart';

class LevelPracticeScreen extends StatefulWidget {
  const LevelPracticeScreen({super.key});

  @override
  State<LevelPracticeScreen> createState() => _LevelPracticeScreenState();
}

class _LevelPracticeScreenState extends State<LevelPracticeScreen> {
  final Color bgDark = AppPalette.cream;
  final Color primaryGreen = AppPalette.moodBlue;
  final Color cardBg = AppPalette.paper;
  final Color currentTextColor = AppPalette.textPrimary;

  int _currentIndex = 0;
  int? _selectedOptionIndex;
  bool _isAnswerSubmitted = false;

  // 模拟关卡数据：5道特征多项式计算题
  final List<Map<String, dynamic>> _questions = [
    {
      'type': '单选题',
      'title': '求以下二阶矩阵 A 的特征多项式 |λE - A|：',
      'content': 'A = [ 1   2 ]\n    [ 3   2 ]',
      'options': [
        'f(λ) = λ² - 3λ - 4',
        'f(λ) = λ² - 3λ + 4',
        'f(λ) = λ² + 3λ - 4',
        'f(λ) = λ² + 3λ + 4'
      ],
      'correctIndex': 0,
      'analysis': '特征多项式 f(λ) = |λE - A| = (λ-1)(λ-2) - (2×3) = λ² - 3λ + 2 - 6 = λ² - 3λ - 4。注意符号不要算错哦！',
    },
    {
      'type': '单选题',
      'title': '已知矩阵 A 的特征多项式为 f(λ) = λ³ - 5λ² + 6λ，求 A 的特征值。',
      'content': '',
      'options': [
        'λ = 1, 2, 3',
        'λ = 0, 2, 3',
        'λ = -1, -2, -3',
        'λ = 0, -2, -3'
      ],
      'correctIndex': 1,
      'analysis': '提取公因式 λ，得到 λ(λ² - 5λ + 6) = λ(λ-2)(λ-3) = 0，解得 λ = 0, 2, 3。',
    },
    // 实际项目中可以继续添加满 5 题...
  ];

  void _submitAnswer() {
    if (_selectedOptionIndex == null) return;

    setState(() {
      _isAnswerSubmitted = true;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionIndex = null;
        _isAnswerSubmitted = false;
      });
    } else {
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: primaryGreen.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(Icons.workspace_premium_rounded, color: primaryGreen, size: 48),
            ),
            const SizedBox(height: 24),
            const Text('闯关成功！', style: TextStyle(color: AppPalette.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('太棒了！你已顺利完成「特征多项式计算」的针对性训练，粗心率显著下降。',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppPalette.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // 关弹窗
                  Navigator.pop(context, true); // 🌟 告诉路线图：我闯关成功啦！
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('返回计划', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQ = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppPalette.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text('第 02 关：基础演练', style: TextStyle(color: AppPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${_currentIndex + 1} / ${_questions.length}', style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.lightbulb_outline_rounded, color: primaryGreen),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('知芽提示：记得公式 f(λ) = |λE - A| 哦！'), backgroundColor: bgDark),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/images/auth_bg.png', fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: AppPalette.cream.withOpacity(0.78))),

          SafeArea(
            child: Column(
              children: [
                // 顶部进度条
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppPalette.inkBlue.withOpacity(0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                      minHeight: 6,
                    ),
                  ),
                ),

                // 题目与选项区域
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 题目卡片
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cardBg.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppPalette.inkBlue.withOpacity(0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: primaryGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                child: Text(currentQ['type'], style: TextStyle(color: primaryGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 16),
                              Text(currentQ['title'], style: TextStyle(color: currentTextColor, fontSize: 16, height: 1.5)),
                              if ((currentQ['content'] as String).isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(color: AppPalette.inkBlue.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
                                  child: Text(currentQ['content'], style: const TextStyle(color: AppPalette.textPrimary, fontSize: 16, fontFamily: 'monospace')),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // 选项列表
                        ...(currentQ['options'] as List<String>).asMap().entries.map((entry) {
                          final int idx = entry.key;
                          final String text = entry.value;
                          final bool isSelected = _selectedOptionIndex == idx;
                          final bool isCorrect = idx == currentQ['correctIndex'];

                          // 提交后的颜色逻辑
                          Color borderColor = AppPalette.inkBlue.withOpacity(0.08);
                          Color bgColor = cardBg.withOpacity(0.6);
                          Widget? trailingIcon;

                          if (_isAnswerSubmitted) {
                            if (isCorrect) {
                              borderColor = primaryGreen;
                              bgColor = primaryGreen.withOpacity(0.1);
                              trailingIcon = Icon(Icons.check_circle_rounded, color: primaryGreen);
                            } else if (isSelected && !isCorrect) {
                              borderColor = Colors.redAccent;
                              bgColor = Colors.redAccent.withOpacity(0.1);
                              trailingIcon = const Icon(Icons.cancel_rounded, color: Colors.redAccent);
                            }
                          } else if (isSelected) {
                            borderColor = primaryGreen.withOpacity(0.8);
                            bgColor = primaryGreen.withOpacity(0.05);
                          }

                          return GestureDetector(
                            onTap: _isAnswerSubmitted ? null : () => setState(() => _selectedOptionIndex = idx),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor, width: isSelected || (_isAnswerSubmitted && isCorrect) ? 2 : 1),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28, height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: isSelected || (_isAnswerSubmitted && isCorrect) ? Colors.transparent : AppPalette.inkBlue.withOpacity(0.18)),
                                      color: isSelected && !_isAnswerSubmitted ? primaryGreen : Colors.transparent,
                                    ),
                                    child: Center(
                                      child: Text(String.fromCharCode(65 + idx), // A, B, C, D
                                          style: TextStyle(color: isSelected && !_isAnswerSubmitted ? Colors.white : AppPalette.textSecondary, fontWeight: FontWeight.bold)
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(child: Text(text, style: TextStyle(color: currentTextColor, fontSize: 15))),
                                  if (trailingIcon != null) trailingIcon,
                                ],
                              ),
                            ),
                          );
                        }),

                        // 提交后显示的解析
                        if (_isAnswerSubmitted) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(color: primaryGreen.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: primaryGreen.withOpacity(0.3))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.auto_awesome, color: primaryGreen, size: 18),
                                    const SizedBox(width: 8),
                                    Text('知芽解析', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(currentQ['analysis'], style: const TextStyle(color: AppPalette.textPrimary, height: 1.5, fontSize: 14)),
                              ],
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),

                // 底部按钮
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  decoration: BoxDecoration(
                    color: bgDark,
                    boxShadow: [BoxShadow(color: AppPalette.inkBlue.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -5))],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedOptionIndex == null ? null : (_isAnswerSubmitted ? _nextQuestion : _submitAnswer),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          disabledBackgroundColor: AppPalette.inkBlue.withOpacity(0.08),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(_isAnswerSubmitted ? '下一题' : '确认答案', style: TextStyle(color: _selectedOptionIndex == null ? Colors.white.withOpacity(0.72) : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
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
