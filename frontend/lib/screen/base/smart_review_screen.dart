import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import 'learning_plan_screen.dart';
import 'weakness_practice_screen.dart';

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

  void _handleFeedback(
    AppStore store,
    ErrorRecord item,
    ReviewFeedback feedback,
  ) {
    store.applyReviewFeedback(item.id, feedback);

    if (_currentIndex < store.smartReviewQueue.length - 1) {
      setState(() {
        _currentIndex++;
        _isAnswerRevealed = false;
      });
      return;
    }

    _showCompletionDialog();
  }

  void _showCompletionDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Icon(
          Icons.verified_rounded,
          color: AppPalette.almondCream,
          size: 48,
        ),
        content: const Text(
          '今天的重点复习已经完成。这轮错题已经重新巩固过一遍了。',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    Navigator.pop(dialogContext);
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const WeaknessPracticeScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    '继续攻克薄弱点',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.textPrimary,
                    side: BorderSide(
                      color: AppPalette.pastelGrey.withValues(alpha: 0.18),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const LearningPlanScreen(),
                      ),
                    );
                  },
                  child: const Text('回到学习计划'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final reviewList = store.smartReviewQueue;

    if (reviewList.isEmpty) {
      return Scaffold(
        backgroundColor: AppPalette.night,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppPalette.textPrimary),
          title: const Text('今日智能复习'),
        ),
        body: const Center(
          child: Text(
            '当前没有待复习错题',
            style: TextStyle(color: AppPalette.textSecondary),
          ),
        ),
      );
    }

    final current = reviewList[_currentIndex.clamp(0, reviewList.length - 1)];
    final progress = (_currentIndex + 1) / reviewList.length;

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
              '${_currentIndex + 1} / ${reviewList.length}',
              style: TextStyle(
                color: AppPalette.textSecondary.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              current.isFavorite
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: current.isFavorite
                  ? AppPalette.almondCream
                  : AppPalette.textPrimary,
            ),
            onPressed: () {
              final wasFavorite = current.isFavorite;
              store.toggleFavorite(current.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(wasFavorite ? '已取消收藏' : '已加入我的收藏'),
                  duration: const Duration(milliseconds: 1200),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppPalette.textPrimary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已生成这道错题的复盘分享卡片'),
                  duration: Duration(milliseconds: 1200),
                ),
              );
            },
          ),
        ],
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x28324A36), Color(0xCC171712)],
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
                  child: _buildTopSummary(progress, reviewList.length),
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
                            children: current.tags.map((tag) {
                              return Container(
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
                              );
                            }).toList(),
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
                            current.question,
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
                            secondChild: _buildAnswerSection(current),
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
                                children: [
                                  _buildFeedbackButton(
                                    '忘记了',
                                    const Color(0xFFE17D6B),
                                    () => _handleFeedback(
                                      store,
                                      current,
                                      ReviewFeedback.forgot,
                                    ),
                                  ),
                                  _buildFeedbackButton(
                                    '有点模糊',
                                    AppPalette.honeyOrange,
                                    () => _handleFeedback(
                                      store,
                                      current,
                                      ReviewFeedback.fuzzy,
                                    ),
                                  ),
                                  _buildFeedbackButton(
                                    '完全掌握',
                                    primaryGreen,
                                    () => _handleFeedback(
                                      store,
                                      current,
                                      ReviewFeedback.mastered,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(
                          height: 26,
                          key: ValueKey('empty'),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSummary(double progress, int totalCount) {
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
              Text(
                '当前还有 $totalCount 道重点错题等待巩固，先回忆，再看解析。',
                style: const TextStyle(
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
              '点击查看回忆结果和 AI 解析',
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '先想一遍，再对照答案，记忆会更牢。',
              style: TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerSection(ErrorRecord current) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBlock(
          title: '我的回忆',
          content: current.myAnswer,
          tint: AppPalette.honeyOrange.withValues(alpha: 0.12),
        ),
        const SizedBox(height: 14),
        _infoBlock(
          title: 'AI 解析',
          content: current.aiAnalysis,
          tint: primaryGreen.withValues(alpha: 0.12),
        ),
      ],
    );
  }

  Widget _infoBlock({
    required String title,
    required String content,
    required Color tint,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackButton(
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.16),
            foregroundColor: color,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
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
            BoxShadow(color: color, blurRadius: 120, spreadRadius: 12),
          ],
        ),
      ),
    );
  }
}
