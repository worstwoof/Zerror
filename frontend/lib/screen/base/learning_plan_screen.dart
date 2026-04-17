import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/app_ui.dart';
import '../../core/theme.dart';
import 'smart_quiz_screen.dart';
import 'smart_review_screen.dart';
import 'weakness_practice_screen.dart';

class LearningPlanScreen extends StatelessWidget {
  const LearningPlanScreen({super.key});

  void _handleTaskTap(BuildContext context, LearningTask task) {
    if (task.title.contains('智能复习')) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SmartReviewScreen()),
      );
      return;
    }
    if (task.title.contains('薄弱点')) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const WeaknessPracticeScreen()),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SmartQuizScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final hasLearningHistory = store.hasLearningHistory;
    final focusSubject =
        store.weakestSubject == '暂无' ? '当前重点模块' : store.weakestSubject;
    final reviewTarget = store.smartReviewQueue.isNotEmpty
        ? store.smartReviewQueue.first.topic
        : '核心错题回收';

    return Scaffold(
      backgroundColor: AppPalette.night,
      body: AppSurface(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                title: '学习计划',
                subtitle: '把复习、练习和组卷安排成清晰节奏',
                onBack: () => Navigator.pop(context),
              ),
              const SizedBox(height: 20),
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '今日重点',
                      style: TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasLearningHistory ? '完成 1 次智能复习 + 1 次薄弱点专练' : '先录入第一道错题',
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hasLearningHistory
                          ? '今天计划投入 ${store.todayPlannedMinutes} 分钟，优先回收 ${store.pendingReviewCount} 道待复习错题，再集中补强「$focusSubject」。'
                          : '新用户还没有复习历史。录入题目后，这里会根据你的错题情况自动生成今日任务、周节奏和复习建议。',
                      style: const TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const AppSectionTitle(
                title: '今日任务',
                subtitle: '把今天该做的事拆成清晰步骤',
                icon: Icons.fact_check_rounded,
              ),
              const SizedBox(height: 12),
              if (store.todayTasks.isEmpty)
                _EmptySectionPanel(
                  title: '还没有今日任务',
                  note: '先录入第一道错题，或者先去智能组卷热身，系统才会开始为你生成任务清单。',
                )
              else
                ...store.todayTasks.map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PlanTaskCard(
                      task: task,
                      onTap: () => _handleTaskTap(context, task),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              const AppSectionTitle(
                title: '本周日历',
                subtitle: '看看这一周的复习安排和节奏分布',
                icon: Icons.calendar_month_rounded,
              ),
              const SizedBox(height: 12),
              _CalendarPanel(store: store),
              const SizedBox(height: 18),
              AppSectionTitle(
                title: '艾宾浩斯遗忘曲线',
                subtitle: hasLearningHistory
                    ? '推荐先回看「$reviewTarget」，别让高价值错题滑出记忆峰值'
                    : '录入并复习错题后，这里才会生成属于你的记忆趋势',
                icon: Icons.show_chart_rounded,
              ),
              const SizedBox(height: 12),
              _ForgettingCurvePanel(pendingReviewCount: store.pendingReviewCount),
              const SizedBox(height: 18),
              const AppSectionTitle(
                title: '本周节奏',
                subtitle: '保持频率，比一次性冲刺更重要',
                icon: Icons.insights_rounded,
              ),
              const SizedBox(height: 12),
              _RhythmPanel(store: store),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanTaskCard extends StatelessWidget {
  const _PlanTaskCard({
    required this.task,
    required this.onTap,
  });

  final LearningTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AppPanel(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppPalette.matchaMist.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.checklist_rounded,
                  color: AppPalette.textPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.note,
                      style: const TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${task.durationMinutes} min',
                    style: const TextStyle(
                      color: AppPalette.almondCream,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppPalette.textSecondary,
                    size: 14,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySectionPanel extends StatelessWidget {
  const _EmptySectionPanel({
    required this.title,
    required this.note,
  });

  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.hourglass_empty_rounded,
            color: AppPalette.textSecondary,
            size: 28,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: const TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    if (!store.hasLearningHistory) {
      return const _EmptySectionPanel(
        title: '本周日历还是空的',
        note: '录入错题后，这里才会开始标记每天的复习安排和回收节奏。',
      );
    }

    return AppPanel(
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '本周复习安排',
                  style: TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${store.pendingReviewCount} 道待复习',
                style: const TextStyle(
                  color: AppPalette.almondCream,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: store.weeklyCalendar
                .map(
                  (entry) => Expanded(
                    child: Center(
                      child: Text(
                        entry.weekday,
                        style: const TextStyle(
                          color: AppPalette.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: store.weeklyCalendar
                .map(
                  (entry) => Expanded(
                    child: _CalendarDayCard(entry: entry),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _LegendDot(color: AppPalette.matchaMist, label: '已完成'),
              _LegendDot(color: AppPalette.almondCream, label: '待复习'),
              _LegendDot(color: AppPalette.artichoke, label: '计划中'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarDayCard extends StatelessWidget {
  const _CalendarDayCard({required this.entry});

  final WeeklyCalendarEntry entry;

  @override
  Widget build(BuildContext context) {
    final config = switch (entry.state) {
      CalendarState.done => (
          background: AppPalette.matchaMist.withValues(alpha: 0.18),
          foreground: AppPalette.textPrimary,
          border: AppPalette.matchaMist.withValues(alpha: 0.20),
          icon: Icons.check_rounded,
        ),
      CalendarState.review => (
          background: AppPalette.almondCream.withValues(alpha: 0.18),
          foreground: AppPalette.almondCream,
          border: AppPalette.almondCream.withValues(alpha: 0.24),
          icon: Icons.refresh_rounded,
        ),
      CalendarState.today => (
          background: AppPalette.pineGreen,
          foreground: AppPalette.textPrimary,
          border: AppPalette.matchaMist.withValues(alpha: 0.22),
          icon: Icons.flash_on_rounded,
        ),
      CalendarState.upcoming => (
          background: AppPalette.pastelGrey.withValues(alpha: 0.06),
          foreground: AppPalette.textSecondary,
          border: AppPalette.pastelGrey.withValues(alpha: 0.08),
          icon: Icons.schedule_rounded,
        ),
      CalendarState.rest => (
          background: AppPalette.jungleGreen.withValues(alpha: 0.45),
          foreground: AppPalette.textSecondary,
          border: AppPalette.pastelGrey.withValues(alpha: 0.06),
          icon: Icons.coffee_rounded,
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: config.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: config.border),
        ),
        child: Column(
          children: [
            Text(
              entry.dayLabel,
              style: TextStyle(
                color: config.foreground,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Icon(config.icon, color: config.foreground, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ForgettingCurvePanel extends StatelessWidget {
  const _ForgettingCurvePanel({required this.pendingReviewCount});

  final int pendingReviewCount;

  @override
  Widget build(BuildContext context) {
    if (pendingReviewCount == 0) {
      return const _EmptySectionPanel(
        title: '暂时还没有记忆曲线',
        note: '等你开始录入并回看错题后，系统才会生成专属的遗忘趋势和建议复习点。',
      );
    }

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  '记忆保持率走势',
                  style: TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '明天建议复习',
                style: TextStyle(
                  color: AppPalette.almondCream,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: CustomPaint(
              painter: _ForgettingCurvePainter(),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '今天回顾后，记忆保持率已经回到较高区间。如果 24 小时内不再巩固，当前这 $pendingReviewCount 道错题会进入明显回落期。',
            style: const TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _RhythmPanel extends StatelessWidget {
  const _RhythmPanel({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    if (!store.hasLearningHistory) {
      return AppPanel(
        child: Column(
          children: [
            Row(
              children: const [
                Expanded(child: _PlanMetric(label: '已完成', value: '0')),
                _MetricDivider(),
                Expanded(child: _PlanMetric(label: '待回收', value: '0')),
                _MetricDivider(),
                Expanded(child: _PlanMetric(label: '连续打卡', value: '0天')),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              '开始记录错题后，这里才会根据你的本周复习行为生成节奏柱状图。',
              style: TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    final maxMinutes = store.weeklyReviewMinutes.reduce((a, b) => a > b ? a : b);
    return AppPanel(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _PlanMetric(
                  label: '已完成',
                  value: '${store.completedReviewDaysThisWeek}',
                ),
              ),
              const _MetricDivider(),
              Expanded(
                child: _PlanMetric(
                  label: '待回收',
                  value: '${store.pendingReviewCount}',
                ),
              ),
              const _MetricDivider(),
              Expanded(
                child: _PlanMetric(
                  label: '连续打卡',
                  value: '${store.studyStreakDays}天',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(store.weeklyReviewMinutes.length, (index) {
              final ratio = maxMinutes == 0 ? 0.0 : store.weeklyReviewMinutes[index] / maxMinutes;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${store.weeklyReviewMinutes[index]}',
                        style: const TextStyle(
                          color: AppPalette.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 88 * math.max(ratio, 0.18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [AppPalette.matchaMist, AppPalette.pineGreen],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        store.weeklyCalendar[index].weekday,
                        style: const TextStyle(
                          color: AppPalette.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PlanMetric extends StatelessWidget {
  const _PlanMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppPalette.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: AppPalette.pastelGrey.withValues(alpha: 0.10),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppPalette.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BackButton(onTap: onBack),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppPalette.pastelGrey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppPalette.pastelGrey.withValues(alpha: 0.08)),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppPalette.textPrimary,
          size: 18,
        ),
      ),
    );
  }
}

class _ForgettingCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppPalette.pastelGrey.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (int i = 0; i < 4; i++) {
      final y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final axisPaint = Paint()
      ..color = AppPalette.pastelGrey.withValues(alpha: 0.14)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      axisPaint,
    );

    final forgetPath = Path();
    final reviewPath = Path();

    for (int i = 0; i <= 60; i++) {
      final x = size.width * (i / 60);
      final t = i / 60;
      final forgetY = size.height * (0.16 + 0.7 * math.pow(t, 0.55));
      final reviewY = size.height * (0.16 + 0.5 * math.pow(t, 1.45));

      if (i == 0) {
        forgetPath.moveTo(x, forgetY.toDouble());
        reviewPath.moveTo(x, reviewY.toDouble());
      } else {
        forgetPath.lineTo(x, forgetY.toDouble());
        reviewPath.lineTo(x, reviewY.toDouble());
      }
    }

    final forgetPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppPalette.honeyOrange, AppPalette.almondCream],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final reviewPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppPalette.matchaMist, AppPalette.pineGreen],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(forgetPath, forgetPaint);
    canvas.drawPath(reviewPath, reviewPaint);

    final pointPaint = Paint()..color = AppPalette.matchaMist;
    canvas.drawCircle(
      Offset(size.width * 0.58, size.height * 0.48),
      5,
      pointPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
