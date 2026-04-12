import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/app_ui.dart';
import '../../core/theme.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final highlights = [
      (
        icon: Icons.local_fire_department_rounded,
        title: '复习火力全开',
        subtitle: '你已经连续 ${store.studyStreakDays} 天保持学习节奏',
        accent: AppPalette.honeyOrange,
      ),
      (
        icon: Icons.psychology_rounded,
        title: '攻克薄弱点',
        subtitle: '${store.weakestSubject} 已经进入你的重点改善名单',
        accent: AppPalette.matchaMist,
      ),
    ];

    final badges = [
      (title: '首个错题', icon: Icons.lightbulb_rounded),
      (title: '坚持一周', icon: Icons.calendar_month_rounded),
      (title: '收藏达人', icon: Icons.bookmark_rounded),
      (title: '复盘高手', icon: Icons.menu_book_rounded),
    ];

    return Scaffold(
      backgroundColor: AppPalette.night,
      body: AppSurface(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  AppPanel(
                    child: Row(
                      children: [
                        _AchievementOverviewItem(
                          label: '连续复习',
                          value: '${store.studyStreakDays}',
                          unit: '天',
                        ),
                        const _VerticalDivider(),
                        _AchievementOverviewItem(
                          label: '已点亮徽章',
                          value: '${store.unlockedBadgeCount}',
                          unit: '枚',
                        ),
                        const _VerticalDivider(),
                        _AchievementOverviewItem(
                          label: '攻克考点',
                          value: '${store.knowledgePointCount}',
                          unit: '个',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const AppSectionTitle(
                    title: '本周高光',
                    subtitle: '最近解锁的关键成就',
                    icon: Icons.auto_awesome_rounded,
                  ),
                  const SizedBox(height: 12),
                  for (final item in highlights) ...[
                    _buildBadgeCard(
                      icon: item.icon,
                      title: item.title,
                      subtitle: item.subtitle,
                      accent: item.accent,
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 6),
                  const AppSectionTitle(
                    title: '成长徽章',
                    subtitle: '你已经积累下来的学习印记',
                    icon: Icons.workspace_premium_rounded,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final badge in badges)
                        _MiniBadge(title: badge.title, icon: badge.icon),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        _BackButton(onTap: () => Navigator.pop(context)),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '我的成就',
                style: TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '成长轨迹与复习里程碑',
                style: TextStyle(color: AppPalette.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
  }) {
    return AppPanel(
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: accent, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppPalette.textSecondary,
                    fontSize: 13,
                    height: 1.45,
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

class _AchievementOverviewItem extends StatelessWidget {
  const _AchievementOverviewItem({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(color: AppPalette.textPrimary, fontSize: 26, fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: unit,
                  style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 46, color: AppPalette.pastelGrey.withValues(alpha: 0.1));
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: AppPanel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppPalette.matchaMist.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppPalette.textPrimary),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
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
        child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppPalette.textPrimary, size: 18),
      ),
    );
  }
}
