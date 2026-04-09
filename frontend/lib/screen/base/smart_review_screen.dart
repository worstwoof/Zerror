import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme.dart';

class SmartReviewScreen extends StatefulWidget {
  const SmartReviewScreen({super.key});

  @override
  State<SmartReviewScreen> createState() => _SmartReviewScreenState();
}

class _SmartReviewScreenState extends State<SmartReviewScreen> {
  final Color primaryGreen = AppPalette.matchaMist;
  final Color cardBg = AppPalette.kombuGreen;

  int _currentIndex = 0;
  bool _isAnswerRevealed = false;

  final List<Map<String, dynamic>> _reviewList = [
    {
      'tags': ['线性代数', '矩阵特征值', '一轮复习'],
      'question':
          '设矩阵 A 的特征值为 λ1, λ2, λ3，且 A 可逆。求证：A 的伴随矩阵 A* 的特征值为 |A|/λi。',
      'myAnswer': 'A* = A^(-1) * |A|，然后我就不会往下推了。',
      'aiAnalysis':
          '关键是把伴随矩阵和逆矩阵联系起来。因为 A 可逆，所以 A* = |A|A^-1。若 A 的特征值为 λ，则 A^-1 的特征值为 1/λ，因此 A* 的特征值就是 |A|/λ。',
    },
    {
      'tags': ['离散数学', '图论', '二轮复习'],
      'question': '什么是欧拉回路？一个无向连通图具有欧拉回路的充要条件是什么？',
      'myAnswer': '经过所有边一次且仅一次的回路。条件是所有顶点的度数都是偶数。',
      'aiAnalysis':
          '你的结论基本正确。更完整地说：无向连通图存在欧拉回路，当且仅当图连通且所有顶点度数都为偶数。要注意区分欧拉路径与欧拉回路。',
    },
  ];

  void _nextQuestion() {
    if (_currentIndex < _reviewList.length - 1) {
      setState(() {
        _currentIndex++;
        _isAnswerRevealed = false;
      });
    } else {
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
        title: const Icon(
          Icons.verified_rounded,
          color: AppPalette.almondCream,
          size: 48,
        ),
        content: const Text(
          '今天的重点复习已经完成。\n这轮错题已经重新巩固过一遍了。',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.almondCream,
                foregroundColor: AppPalette.night,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text(
                '返回首页',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
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
          icon: const Icon(Icons.close_rounded, color: AppPalette.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              '今日智能复习',
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_currentIndex + 1} / ${_reviewList.length}',
              style: TextStyle(
                color: AppPalette.textSecondary.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppPalette.appBackground),
            ),
          ),
          Positioned.fill(
            child: Image.asset('assets/images/auth_bg.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0x28324A36),
                    Color(0xCC171712),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -70,
            right: -30,
            child: _buildAmbientBlob(
              220,
              AppPalette.matchaMist.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            bottom: 160,
            left: -60,
            child: _buildAmbientBlob(
              200,
              AppPalette.pineGreen.withValues(alpha: 0.14),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: _buildTopSummary(progress),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cardBg.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: AppPalette.pastelGrey.withValues(alpha: 0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: (currentData['tags'] as List<String>)
                                .map(
                                  (tag) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryGreen.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      tag,
                                      style: TextStyle(
                                        color: primaryGreen,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            '本题回忆目标',
                            style: TextStyle(
                              color: AppPalette.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currentData['question'],
                            style: const TextStyle(
                              color: AppPalette.textPrimary,
                              fontSize: 17,
                              height: 1.7,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 28),
                          AnimatedCrossFade(
                            firstChild: _buildRevealButton(),
                            secondChild: _buildAnswerSection(currentData),
                            crossFadeState: _isAnswerRevealed
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 280),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: _isAnswerRevealed
                      ? Container(
                          key: const ValueKey('feedback'),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
                          child: Column(
                            children: [
                              const Text(
                                '这题现在的记忆状态怎么样？',
                                style: TextStyle(
                                  color: AppPalette.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildFeedbackButton(
                                    '忘记了',
                                    const Color(0xFFE17D6B),
                                    () => _nextQuestion(),
                                  ),
                                  _buildFeedbackButton(
                                    '有点模糊',
                                    AppPalette.honeyOrange,
                                    () => _nextQuestion(),
                                  ),
                                  _buildFeedbackButton(
                                    '完全掌握',
                                    primaryGreen,
                                    () => _nextQuestion(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(height: 26, key: ValueKey('empty')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSummary(double progress) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppPalette.pastelGrey.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppPalette.pastelGrey.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '今日计划',
                    style: TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      color: AppPalette.almondCream,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '先回忆，再看解析，让复习更像一次主动提取。',
                style: TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppPalette.almondCream,
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevealButton() {
    return GestureDetector(
      onTap: () => setState(() => _isAnswerRevealed = true),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppPalette.pastelGrey.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: primaryGreen.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.visibility_rounded,
                color: primaryGreen,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '点击查看回忆结果与 AI 解析',
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '先想一遍，再对照答案，会记得更牢。',
              style: TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerSection(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: Colors.white.withValues(alpha: 0.08)),
        const SizedBox(height: 18),
        const Text(
          '你的原始回忆',
          style: TextStyle(
            color: AppPalette.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            data['myAnswer'],
            style: const TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 15,
              height: 1.6,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppPalette.honeyOrange, AppPalette.almondCream],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppPalette.night,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              '知芽 AI 解析',
              style: TextStyle(
                color: AppPalette.almondCream,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primaryGreen.withValues(alpha: 0.14),
            ),
          ),
          child: Text(
            data['aiAnalysis'],
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 15,
              height: 1.7,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackButton(
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          border: Border.all(color: color.withValues(alpha: 0.36)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAmbientBlob(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 120, spreadRadius: 16),
          ],
        ),
      ),
    );
  }
}
