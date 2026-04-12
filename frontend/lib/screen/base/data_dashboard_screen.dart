import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/app_ui.dart';
import '../../core/theme.dart';

class DataDashboardScreen extends StatelessWidget {
  const DataDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final distribution = store.subjectDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = distribution.isEmpty ? 1 : distribution.first.value;
    final maxMinutes = store.weeklyReviewMinutes.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppPalette.textPrimary),
        title: const Text(
          '学习数据看板',
          style: TextStyle(color: AppPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: AppSurface(
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppPanel(
                color: AppPalette.matchaMist.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: AppPalette.almondCream),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AI 洞察：当前最值得优先补强的是「${store.weakestSubject}」，现在还有 ${store.pendingReviewCount} 道错题等待回收。',
                        style: const TextStyle(color: AppPalette.textPrimary, fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const AppSectionTitle(
                title: '学习概况',
                subtitle: '总量与攻克进度一眼看见',
                icon: Icons.dashboard_rounded,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _overviewCard('收录错题', '${store.totalErrors}', AppPalette.textPrimary),
                  const SizedBox(width: 16),
                  _overviewCard('成功消灭', '${store.masteredCount}', AppPalette.matchaMist),
                ],
              ),
              const SizedBox(height: 28),
              const AppSectionTitle(
                title: '本周复习活跃度',
                subtitle: '最近 7 天的复习强度变化',
                icon: Icons.bar_chart_rounded,
              ),
              const SizedBox(height: 16),
              AppPanel(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(store.weeklyReviewMinutes.length, (index) {
                    final labels = ['一', '二', '三', '四', '五', '六', '日'];
                    return _BarItem(
                      label: labels[index],
                      ratio: store.weeklyReviewMinutes[index] / maxMinutes,
                    );
                  }),
                ),
              ),
              const SizedBox(height: 28),
              const AppSectionTitle(
                title: '错题考点分布',
                subtitle: '先攻占高频薄弱点',
                icon: Icons.linear_scale_rounded,
              ),
              const SizedBox(height: 16),
              AppPanel(
                child: Column(
                  children: [
                    for (int i = 0; i < distribution.length; i++) ...[
                      _ProgressItem(
                        subject: distribution[i].key,
                        ratio: distribution[i].value / maxCount,
                        count: '${distribution[i].value} 题',
                      ),
                      if (i != distribution.length - 1) const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overviewCard(String title, String value, Color valueColor) {
    return Expanded(
      child: AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(color: valueColor, fontSize: 32, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({required this.label, required this.ratio});

  final String label;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 14,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: ratio.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppPalette.matchaMist,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _ProgressItem extends StatelessWidget {
  const _ProgressItem({required this.subject, required this.ratio, required this.count});

  final String subject;
  final double ratio;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              subject,
              style: const TextStyle(color: AppPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Text(count, style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            color: AppPalette.matchaMist,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
