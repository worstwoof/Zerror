import 'package:flutter/material.dart';

class LevelOneScreen extends StatefulWidget {
  const LevelOneScreen({super.key});

  @override
  State<LevelOneScreen> createState() => _LevelOneScreenState();
}

class _LevelOneScreenState extends State<LevelOneScreen> {
  final Color bgDark = const Color(0xFF1E2823);
  final Color primaryGreen = const Color(0xFF70A88D);
  final Color cardBg = const Color(0xFF2A352F);
  final Color currentTextColor = Colors.white;

  bool _isVideoPlaying = false;
  bool _isSubmitted = false;

  // 模拟 2 道基础判断题
  final List<Map<String, dynamic>> _questions = [
    {
      'question': '矩阵的特征值一定是实数。',
      'isTrue': false,
      'analysis': '错误。实对称矩阵的特征值一定是实数，但一般的实数矩阵也可能含有复数特征值（共轭复根）。',
      'userAnswer': null, // 用户的选择：true 或 false
    },
    {
      'question': '如果 λ 是矩阵 A 的特征值，那么必定存在一个非零向量 x，使得 Ax = λx。',
      'isTrue': true,
      'analysis': '正确。这是特征值与特征向量的核心定义。注意，特征向量 x 必须是“非零”的！',
      'userAnswer': null,
    }
  ];

  // 检查是否所有题目都已作答
  bool get _allAnswered => _questions.every((q) => q['userAnswer'] != null);

  void _submitAnswers() {
    setState(() {
      _isSubmitted = true;
    });
  }

  void _finishLevel() {
    // 弹出成功动画，然后携带 true 返回，告诉路线图页面已通关！
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: primaryGreen.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: Icon(Icons.check_circle_rounded, color: primaryGreen, size: 48),
            ),
            const SizedBox(height: 24),
            const Text('概念扫盲完成！', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('你已经掌握了特征值的核心定义，底子打得很牢靠，准备迎接实战吧！',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // 关弹窗
                  Navigator.pop(context, true); // 🌟 携带 true 返回，触发路线图打勾！
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('返回路线图', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
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
        title: const Text('第 01 关：概念扫盲', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 背景层
          Positioned.fill(child: Image.asset('assets/images/auth_bg.png', fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.4))),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🌟 1. AI 动画播放器 (模拟)
                        _buildVideoPlayer(),
                        const SizedBox(height: 32),

                        // 🌟 2. 随堂测试标题
                        Row(
                          children: [
                            Icon(Icons.edit_note_rounded, color: primaryGreen),
                            const SizedBox(width: 8),
                            const Text('随堂测验 (2题)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 🌟 3. 判断题列表
                        ...List.generate(_questions.length, (index) => _buildTrueFalseQuestion(index)),
                      ],
                    ),
                  ),
                ),

                // 🌟 4. 底部提交按钮
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  decoration: BoxDecoration(
                    color: bgDark,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, -5))],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: !_allAnswered ? null : (_isSubmitted ? _finishLevel : _submitAnswers),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                            _isSubmitted ? '完成本关' : '提交答案',
                            style: TextStyle(color: !_allAnswered ? Colors.white54 : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                        ),
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

  // 构建模拟视频播放器
  Widget _buildVideoPlayer() {
    return GestureDetector(
      onTap: () => setState(() => _isVideoPlaying = !_isVideoPlaying),
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          // 模拟黑板或视频封面
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [const Color(0xFF1A2621), const Color(0xFF0F1713)],
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 封面水印字
            if (!_isVideoPlaying)
              Text('什么是特征值？\n(Ax = λx 的几何意义)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 18, fontWeight: FontWeight.bold)),

            // 播放状态动画
            if (_isVideoPlaying) ...[
              Positioned.fill(child: Center(child: Text('正在播放 AI 动画...', style: TextStyle(color: primaryGreen.withValues(alpha: 0.6))))),
            ],

            // 播放/暂停按钮
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
              child: Icon(_isVideoPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 40),
            ),

            // 底部进度条
            Positioned(
              bottom: 12, left: 16, right: 16,
              child: Row(
                children: [
                  Text(_isVideoPlaying ? '01:12' : '00:00', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _isVideoPlaying ? 0.4 : 0.0,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('03:00', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // 构建单道判断题
  Widget _buildTrueFalseQuestion(int index) {
    final q = _questions[index];
    final bool? userAnswer = q['userAnswer'];
    final bool isCorrectAnswer = q['isTrue'];

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('题 ${index + 1}', style: TextStyle(color: primaryGreen, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(q['question'], style: TextStyle(color: currentTextColor, fontSize: 16, height: 1.5)),
          const SizedBox(height: 20),

          // 判断题按钮组
          Row(
            children: [
              Expanded(child: _buildChoiceButton(index, true, '正确', Icons.check_rounded)),
              const SizedBox(width: 16),
              Expanded(child: _buildChoiceButton(index, false, '错误', Icons.close_rounded)),
            ],
          ),

          // 提交后显示解析
          if (_isSubmitted) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (userAnswer == isCorrectAnswer ? primaryGreen : Colors.redAccent).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (userAnswer == isCorrectAnswer ? primaryGreen : Colors.redAccent).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(userAnswer == isCorrectAnswer ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: userAnswer == isCorrectAnswer ? primaryGreen : Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Text(userAnswer == isCorrectAnswer ? '回答正确' : '回答错误',
                          style: TextStyle(color: userAnswer == isCorrectAnswer ? primaryGreen : Colors.redAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(q['analysis'], style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, height: 1.5)),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  // 选项按钮
  Widget _buildChoiceButton(int qIndex, bool choiceValue, String label, IconData icon) {
    final q = _questions[qIndex];
    final bool isSelected = q['userAnswer'] == choiceValue;

    // 提交后的颜色反馈逻辑
    Color borderColor = Colors.white.withValues(alpha: 0.1);
    Color bgColor = Colors.transparent;
    Color textColor = Colors.white70;

    if (_isSubmitted) {
      if (q['isTrue'] == choiceValue) {
        borderColor = primaryGreen; bgColor = primaryGreen.withValues(alpha: 0.15); textColor = primaryGreen;
      } else if (isSelected) {
        borderColor = Colors.redAccent; bgColor = Colors.redAccent.withValues(alpha: 0.15); textColor = Colors.redAccent;
      }
    } else if (isSelected) {
      borderColor = primaryGreen; bgColor = primaryGreen.withValues(alpha: 0.1); textColor = primaryGreen;
    }

    return GestureDetector(
      onTap: _isSubmitted ? null : () {
        setState(() => _questions[qIndex]['userAnswer'] = choiceValue);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 18),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}