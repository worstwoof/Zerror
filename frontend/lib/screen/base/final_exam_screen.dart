import 'dart:async';
import 'package:flutter/material.dart';

class FinalExamScreen extends StatefulWidget {
  const FinalExamScreen({super.key});

  @override
  State<FinalExamScreen> createState() => _FinalExamScreenState();
}

class _FinalExamScreenState extends State<FinalExamScreen> {
  final Color bgDark = const Color(0xFF1E2823);
  final Color primaryGreen = const Color(0xFF70A88D);
  final Color cardBg = const Color(0xFF2A352F);

  late Timer _timer;
  int _secondsRemaining = 45 * 60; // 模拟考试 45 分钟

  // 用户的答题卡记录 (题目index : 选中的选项index)
  final Map<int, int> _answers = {};

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer.cancel();
        _submitExam(); // 时间到自动交卷
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _formattedTime {
    int minutes = _secondsRemaining ~/ 60;
    int seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _submitExam() {
    // 实际项目中这里需要核对 _answers 和标准答案计算分数
    _timer.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💯 测评报告', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text('综合得分：92 / 100', style: TextStyle(color: primaryGreen, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('薄弱点已被彻底攻克！特征多项式计算准确率达到 100%。知芽已将相关错题移出“每日高频复习”列表。', style: TextStyle(color: Colors.white70, height: 1.5)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // 关弹窗
                Navigator.pop(context, true); // 🌟 告诉路线图：我闯关成功啦！
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text('完成特训', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: _secondsRemaining < 300 ? Colors.redAccent.withValues(alpha: 0.2) : primaryGreen.withValues(alpha: 0.2), // 最后5分钟变红
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_outlined, size: 16, color: _secondsRemaining < 300 ? Colors.redAccent : primaryGreen),
              const SizedBox(width: 8),
              Text(_formattedTime, style: TextStyle(color: _secondsRemaining < 300 ? Colors.redAccent : primaryGreen, fontWeight: FontWeight.bold, fontSize: 16, fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: _submitExam, child: const Text('交卷', style: TextStyle(color: Colors.white70, fontSize: 16))),
        ],
      ),
      body: PageView.builder(
        itemCount: 10, // 模拟 10 道题
        itemBuilder: (context, index) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('单选题 ${index + 1}/10', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 16),
                const Text('设方阵 A 的特征值为 λ，则矩阵 A² - 2A + E 的特征值为？', style: TextStyle(color: Colors.white, fontSize: 18, height: 1.5)),
                const SizedBox(height: 32),

                ...List.generate(4, (optIdx) {
                  final isSelected = _answers[index] == optIdx;
                  final options = ['λ² - 2λ + 1', '(λ - 1)²', 'λ² + 2λ + 1', '以上都不对'];

                  return GestureDetector(
                    onTap: () => setState(() => _answers[index] = optIdx),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryGreen.withValues(alpha: 0.1) : cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isSelected ? primaryGreen : Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: isSelected ? primaryGreen : Colors.white54),
                          const SizedBox(width: 16),
                          Text(options[optIdx], style: const TextStyle(color: Colors.white, fontSize: 16)),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
      // 底部答题卡进度条
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16, top: 16, left: 24, right: 24),
        decoration: BoxDecoration(color: cardBg, border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05)))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('已作答: ${_answers.length} / 10', style: const TextStyle(color: Colors.white70)),
            LinearProgressIndicator(
              value: _answers.length / 10,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
            ).paddingBox(), // 伪代码，实际可以用 Container 包裹限制宽度
          ],
        ),
      ),
    );
  }
}

extension on Widget {
  Widget paddingBox() => SizedBox(width: 150, child: ClipRRect(borderRadius: BorderRadius.circular(4), child: this));
}