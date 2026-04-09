import 'package:flutter/material.dart';

class QuizResultScreen extends StatelessWidget {
  final int totalQuestions;
  final int answeredCount;
  final String timeSpent;

  const QuizResultScreen({
    super.key,
    required this.totalQuestions,
    required this.answeredCount,
    required this.timeSpent,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF1E2823) : const Color(0xFFF0F4F2);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF2C362F);
    final cardColor = isDarkMode ? Colors.white12 : Colors.white;
    final primaryGreen = const Color(0xFF70A88D);

    // 模拟的结算数据
    const int score = 85;
    const int correctCount = 12;
    const int wrongCount = 3;
    // 模拟刚才做错的题目集合
    final List<Map<String, dynamic>> wrongQuestions = [
      {
        'subject': '线性代数',
        'type': '单选题',
        'content': '设矩阵 A 的特征值为 λ1, λ2, λ3，且 A 可逆。A 的伴随矩阵 A* 的特征值是？',
        'userAnswer': '1/λ1, 1/λ2, 1/λ3',
        'correctAnswer': '|A|/λ1, |A|/λ2, |A|/λ3',
      },
      {
        'subject': '数据结构',
        'type': '简答题',
        'content': '在 C++ 中编写 KMP 模式匹配算法时，发生失配时的回溯逻辑是什么？',
        'userAnswer': 'j = next[j]',
        'correctAnswer': 'j = next[j - 1] (取决于 next 数组的具体实现和整体偏移)',
      }
    ];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // 隐藏默认返回键，强制走底部按钮
        title: Text('测验报告', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. 顶部得分看板
            _buildScoreBoard(score, timeSpent, correctCount, wrongCount, textColor, cardColor, primaryGreen),
            const SizedBox(height: 24),

            // 2. AI 诊断建议
            _buildAiDiagnosis(textColor, primaryGreen),
            const SizedBox(height: 24),

            // 3. 错题萃取列表
            Align(
              alignment: Alignment.centerLeft,
              child: Text('本次错题萃取 (${wrongQuestions.length}题)', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            ...wrongQuestions.map((q) => _buildWrongQuestionCard(q, textColor, cardColor, primaryGreen)),

            const SizedBox(height: 40),
          ],
        ),
      ),

      // 底部操作区
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bgColor,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: () {
                  // 返回主页，清除路由栈
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: textColor.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('返回主页', style: TextStyle(color: textColor, fontSize: 16)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('🎉 已成功将 ${wrongQuestions.length} 道错题存入档案！'), backgroundColor: primaryGreen),
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.archive_rounded, color: Colors.white, size: 20),
                label: const Text('一键收入错题档案', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= 组件：得分环形看板 =================
  Widget _buildScoreBoard(int score, String timeSpent, int correct, int wrong, Color textColor, Color cardColor, Color primaryGreen) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120, height: 120,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 10,
                  backgroundColor: textColor.withValues(alpha: 0.05),
                  color: primaryGreen,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                children: [
                  Text('$score', style: TextStyle(color: primaryGreen, fontSize: 40, fontWeight: FontWeight.w900, height: 1.0)),
                  Text('综合得分', style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12)),
                ],
              )
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('答对', '$correct 题', primaryGreen, textColor),
              Container(width: 1, height: 30, color: textColor.withValues(alpha: 0.1)),
              _buildStatItem('答错', '$wrong 题', Colors.redAccent, textColor),
              Container(width: 1, height: 30, color: textColor.withValues(alpha: 0.1)),
              _buildStatItem('用时', timeSpent, Colors.orange, textColor),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor, Color textColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: valueColor, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12)),
      ],
    );
  }

  // ================= 组件：AI 诊断 =================
  Widget _buildAiDiagnosis(Color textColor, Color primaryGreen) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.psychology_rounded, color: primaryGreen, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI 学情诊断', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text('你的基础概念掌握得很扎实，但在处理【线性代数-特征值综合题】时容易忽略逆矩阵的性质，建议针对该考点进行一次专项突破。',
                    style: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 13, height: 1.5)),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ================= 组件：错题萃取卡片 =================
  Widget _buildWrongQuestionCard(Map<String, dynamic> q, Color textColor, Color cardColor, Color primaryGreen) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('答错', style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Text('${q['subject']} · ${q['type']}', style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(q['content'], style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: textColor.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('你的答案: ', style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 13)),
                    Expanded(child: Text(q['userAnswer'], style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('正确答案: ', style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 13)),
                    Expanded(child: Text(q['correctAnswer'], style: TextStyle(color: primaryGreen, fontSize: 13, fontWeight: FontWeight.w500))),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}