import 'package:flutter/material.dart';

class SmartReviewScreen extends StatefulWidget {
  const SmartReviewScreen({super.key});

  @override
  State<SmartReviewScreen> createState() => _SmartReviewScreenState();
}

class _SmartReviewScreenState extends State<SmartReviewScreen> with SingleTickerProviderStateMixin {
  final Color primaryGreen = const Color(0xFF70A88D);
  final Color cardBg = const Color(0xFF2A352F);

  int _currentIndex = 0;
  bool _isAnswerRevealed = false; // 控制是否展开了答案

  // 模拟基于艾宾浩斯曲线今天需要复习的错题数据
  final List<Map<String, dynamic>> _reviewList = [
    {
      'tags': ['线性代数', '矩阵特征值', '一阶复习'],
      'question': '设矩阵 A 的特征值为 λ1, λ2, λ3，且 A 可逆。\n求证：A 的伴随矩阵 A* 的特征值为 |A|/λi。',
      'myAnswer': 'A* = A^(-1) * |A|，然后我就不会推了...',
      'aiAnalysis': '核心考点在于理解伴随矩阵与逆矩阵的关系。遇到此类问题，优先联想定义式 A*A = |A|E。因为 A 可逆，所以 A* = |A|A⁻¹。A 的特征值为 λ，则 A⁻¹ 的特征值为 1/λ，因此 A* 的特征值为 |A|/λ。',
    },
    {
      'tags': ['离散数学', '图论', '二阶复习'],
      'question': '什么是欧拉回路？一个无向连通图具有欧拉回路的充要条件是什么？',
      'myAnswer': '经过所有边一次且仅一次的回路。条件是所有顶点的度数都是偶数。',
      'aiAnalysis': '回答基本正确！补充细节：无向连通图 G 有欧拉回路 <=> G 是连通的且没有奇度顶点。注意区分欧拉路径（可以有2个奇度顶点）和欧拉回路。',
    }
  ];

  void _nextQuestion() {
    if (_currentIndex < _reviewList.length - 1) {
      setState(() {
        _currentIndex++;
        _isAnswerRevealed = false; // 切换到下一题时，重置为未展开状态
      });
    } else {
      // 复习完成
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Icon(Icons.verified_rounded, color: Color(0xFF70A88D), size: 48),
        content: const Text('太棒了！\n今日的 15 道错题已全部巩固完毕，知识的小树苗又长大了一点。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5)
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16)
              ),
              onPressed: () {
                Navigator.pop(context); // 关弹窗
                Navigator.pop(context); // 回主页
              },
              child: const Text('返回首页', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentData = _reviewList[_currentIndex];
    final progress = (_currentIndex + 1) / _reviewList.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text('智能复习', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${_currentIndex + 1} / ${_reviewList.length}', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
          ],
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 背景
          Positioned.fill(child: Image.asset('assets/images/auth_bg.png', fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.4))),

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
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                      minHeight: 6,
                    ),
                  ),
                ),

                // 核心卡片区域
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cardBg.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 标签
                          Wrap(
                            spacing: 8,
                            children: (currentData['tags'] as List<String>).map((tag) => Chip(
                              label: Text(tag, style: TextStyle(color: primaryGreen, fontSize: 12)),
                              backgroundColor: primaryGreen.withValues(alpha: 0.15),
                              side: BorderSide.none,
                              padding: EdgeInsets.zero,
                            )).toList(),
                          ),
                          const SizedBox(height: 20),

                          // 原题展示
                          const Text('❓ 题目', style: TextStyle(color: Colors.white54, fontSize: 14)),
                          const SizedBox(height: 8),
                          Text(currentData['question'], style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.6)),

                          const SizedBox(height: 32),

                          // 答案与解析区域 (根据状态切换)
                          AnimatedCrossFade(
                            firstChild: _buildRevealButton(), // 未展开时的遮罩按钮
                            secondChild: _buildAnswerSection(currentData), // 展开后的答案解析
                            crossFadeState: _isAnswerRevealed ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 300),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 底部操作区 (仅在展开答案后显示)
                AnimatedOpacity(
                  opacity: _isAnswerRevealed ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: !_isAnswerRevealed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: Column(
                        children: [
                          const Text('根据记忆情况给这题打个分吧', style: TextStyle(color: Colors.white54, fontSize: 13)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildFeedbackButton('忘记了', Colors.redAccent, () => _nextQuestion()),
                              _buildFeedbackButton('有点模糊', Colors.orangeAccent, () => _nextQuestion()),
                              _buildFeedbackButton('完全掌握', primaryGreen, () => _nextQuestion()),
                            ],
                          ),
                        ],
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

  // 遮罩按钮：点击查看解析
  Widget _buildRevealButton() {
    return GestureDetector(
      onTap: () => setState(() => _isAnswerRevealed = true),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Icon(Icons.visibility_rounded, color: primaryGreen, size: 32),
            const SizedBox(height: 12),
            const Text('点击查看回忆结果与 AI 解析', style: TextStyle(color: Colors.white70, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  // 答案与解析内容区
  Widget _buildAnswerSection(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white12),
        const SizedBox(height: 16),
        const Text('📝 当时错解', style: TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 8),
        Text(data['myAnswer'], style: const TextStyle(color: Colors.white70, fontSize: 15, decoration: TextDecoration.lineThrough)),

        const SizedBox(height: 24),
        Row(
          children: [
            Icon(Icons.auto_awesome, color: primaryGreen, size: 18),
            const SizedBox(width: 6),
            const Text('知芽 AI 解析', style: TextStyle(color: Color(0xFF70A88D), fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(data['aiAnalysis'], style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.6)),
        ),
      ],
    );
  }

  // 底部反馈按钮构建器
  Widget _buildFeedbackButton(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ),
    );
  }
}