import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import 'advanced_challenge_screen.dart';
import 'final_exam_screen.dart';
import 'level_one_screen.dart';
import 'level_practice_screen.dart';

class WeaknessPracticeScreen extends StatefulWidget {
  const WeaknessPracticeScreen({super.key});

  @override
  State<WeaknessPracticeScreen> createState() => _WeaknessPracticeScreenState();
}

class _WeaknessPracticeScreenState extends State<WeaknessPracticeScreen> {
  final Color bgDark = AppPalette.night;
  final Color primaryGreen = AppPalette.matchaMist;
  final Color cardBg = AppPalette.kombuGreen;
  final Color currentSubTextColor = AppPalette.textSecondary;

  int _currentActiveLevel = 1;

  Future<void> _startCurrentLevel() async {
    if (_currentActiveLevel > 4) return;

    Widget nextScreen;
    switch (_currentActiveLevel) {
      case 1:
        nextScreen = const LevelOneScreen();
        break;
      case 2:
        nextScreen = const LevelPracticeScreen();
        break;
      case 3:
        nextScreen = const AdvancedChallengeScreen();
        break;
      case 4:
        nextScreen = const FinalExamScreen();
        break;
      default:
        return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    );

    if (result == true) {
      setState(() {
        _currentActiveLevel++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final focusSubject =
        store.weakestSubject == '暂无' ? '综合复盘' : store.weakestSubject;
    final focusTopic = store.weakestTopic;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '攻克薄弱点',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppPalette.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppPalette.appBackground),
          ),
          Image.asset('assets/images/auth_bg.png', fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppPalette.pineGreen.withValues(alpha: 0.16),
                  AppPalette.night.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -40,
            child: _buildAmbientBlob(
              220,
              AppPalette.matchaMist.withValues(alpha: 0.14),
            ),
          ),
          Positioned(
            bottom: 140,
            left: -40,
            child: _buildAmbientBlob(
              180,
              AppPalette.pineGreen.withValues(alpha: 0.16),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                top: 12,
                bottom: 116,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroSummary(store, focusSubject, focusTopic),
                  const SizedBox(height: 28),
                  _buildAiDiagnosisCard(store, focusSubject, focusTopic),
                  const SizedBox(height: 36),
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppPalette.almondCream.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.route_rounded,
                          color: AppPalette.almondCream,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '专属突破计划',
                            style: TextStyle(
                              color: AppPalette.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '按阶段推进，逐步从回忆到综合应用',
                            style: TextStyle(
                              color: AppPalette.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _buildPracticeNode(
                    level: 1,
                    title: '概念回温：重新讲透「$focusTopic」',
                    subtitle: '先用短讲解和判断题，把最容易混淆的定义重新压实。',
                    icon: Icons.play_circle_fill_rounded,
                  ),
                  _buildPracticeNode(
                    level: 2,
                    title: '基础演练：围绕 $focusSubject 补 5 题',
                    subtitle: '把失分最高的计算或推理步骤单独拆开，先把手感找回来。',
                    icon: Icons.edit_document,
                  ),
                  _buildPracticeNode(
                    level: 3,
                    title: '变式挑战：跨题型迁移到综合题',
                    subtitle: '让你把同一考点从熟悉题迁移到新题里，避免只会做原题。',
                    icon: Icons.workspace_premium_rounded,
                  ),
                  _buildPracticeNode(
                    level: 4,
                    title: '收尾检测：用一组小卷确认掌握度',
                    subtitle: '最后用限时检测验证这轮训练是否真正把错误回收掉。',
                    icon: Icons.flag_rounded,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: BoxDecoration(
          color: bgDark.withValues(alpha: 0.92),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: AppPalette.pastelGrey.withValues(alpha: 0.08),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _currentActiveLevel > 4 ? null : _startCurrentLevel,
          icon: Icon(
            _currentActiveLevel > 4
                ? Icons.verified_rounded
                : Icons.bolt_rounded,
            color: AppPalette.night,
          ),
          label: Text(
            _currentActiveLevel > 4
                ? '本轮特训已完成'
                : '开始第 0$_currentActiveLevel 关',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppPalette.night,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.almondCream,
            disabledBackgroundColor: AppPalette.laurelGreen.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSummary(
    AppStore store,
    String focusSubject,
    String focusTopic,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppPalette.pineGreen.withValues(alpha: 0.92),
                AppPalette.kombuGreen.withValues(alpha: 0.90),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppPalette.laurelGreen.withValues(alpha: 0.14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.almondCream.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'AI 定制路径',
                      style: TextStyle(
                        color: AppPalette.almondCream,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '当前进度 $_currentActiveLevel / 4',
                    style: const TextStyle(
                      color: AppPalette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '这次先攻克「$focusSubject」里的关键断点。',
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '当前有 ${store.weakestSubjectPendingCount} 道待复习错题集中在这个模块，其中「$focusTopic」占了 ${store.weakestTopicPendingCount} 道。我们先把最影响正确率的环节拆开处理。',
                style: const TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiDiagnosisCard(
    AppStore store,
    String focusSubject,
    String focusTopic,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppPalette.pastelGrey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppPalette.pastelGrey.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppPalette.honeyOrange, AppPalette.almondCream],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: AppPalette.night,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '知芽 AI 诊断',
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '目标指向：$focusSubject · $focusTopic',
                      style: const TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '过去一轮错题里，你在「$focusTopic」上的丢分最集中。我们把训练压缩成 4 段短流程，先清概念，再补计算和迁移应用，让错因从“会看不会做”变成“看见就能拆”。',
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 14,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InsightChip(label: '薄弱模块：$focusSubject'),
              _InsightChip(label: '核心考点：$focusTopic'),
              _InsightChip(label: '待回收：${store.weakestSubjectPendingCount} 道'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeNode({
    required int level,
    required String title,
    required String subtitle,
    required IconData icon,
    bool isLast = false,
  }) {
    final isCompleted = level < _currentActiveLevel;
    final isActive = level == _currentActiveLevel;
    final isLocked = level > _currentActiveLevel;

    final nodeColor = isCompleted
        ? AppPalette.almondCream
        : (isActive ? primaryGreen : Colors.white.withValues(alpha: 0.18));
    final cardColor = isActive
        ? primaryGreen.withValues(alpha: 0.12)
        : AppPalette.pastelGrey.withValues(alpha: 0.05);
    final textColor = isLocked
        ? AppPalette.textSecondary.withValues(alpha: 0.5)
        : AppPalette.textPrimary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppPalette.almondCream
                      : isActive
                          ? primaryGreen.withValues(alpha: 0.18)
                          : cardBg.withValues(alpha: 0.90),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: nodeColor,
                    width: isActive ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppPalette.night,
                          size: 18,
                        )
                      : Text(
                          '0$level',
                          style: TextStyle(
                            color: nodeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          isCompleted
                              ? AppPalette.almondCream
                              : Colors.white.withValues(alpha: 0.14),
                          Colors.white.withValues(alpha: 0.06),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 22),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isActive
                      ? primaryGreen.withValues(alpha: 0.35)
                      : AppPalette.pastelGrey.withValues(alpha: 0.08),
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: primaryGreen.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildStatusTag(
                              isCompleted: isCompleted,
                              isActive: isActive,
                              isLocked: isLocked,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '第 0$level 关',
                              style: TextStyle(
                                color: currentSubTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          title,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.72),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppPalette.almondCream.withValues(alpha: 0.16)
                          : isActive
                              ? primaryGreen.withValues(alpha: 0.14)
                              : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isCompleted
                          ? Icons.check_circle_rounded
                          : (isLocked ? Icons.lock_outline_rounded : icon),
                      color: isCompleted
                          ? AppPalette.almondCream
                          : (isActive ? primaryGreen : currentSubTextColor),
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTag({
    required bool isCompleted,
    required bool isActive,
    required bool isLocked,
  }) {
    final label = isCompleted
        ? '已完成'
        : isActive
            ? '进行中'
            : '未解锁';
    final bgColor = isCompleted
        ? AppPalette.almondCream.withValues(alpha: 0.18)
        : isActive
            ? primaryGreen.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.06);
    final textColor = isCompleted
        ? AppPalette.almondCream
        : isActive
            ? primaryGreen
            : currentSubTextColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
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

class _InsightChip extends StatelessWidget {
  const _InsightChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppPalette.pastelGrey.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppPalette.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
