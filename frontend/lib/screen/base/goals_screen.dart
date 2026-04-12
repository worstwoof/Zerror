import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/app_ui.dart';
import '../../core/theme.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: AppPalette.night,
      body: AppSurface(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              title: '学习目标',
              subtitle: '把长期进步拆成能完成的小节奏',
              onBack: () => Navigator.pop(context),
            ),
            const SizedBox(height: 20),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '当前主目标',
                    style: TextStyle(color: AppPalette.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '错题复盘效率提升计划',
                    style: TextStyle(color: AppPalette.textPrimary, fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '目标周期 30 天，重点提升复盘频率、归因质量和知识回收效率。目前还有 ${store.pendingReviewCount} 道错题值得继续巩固。',
                    style: const TextStyle(color: AppPalette.textSecondary, fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const AppSectionTitle(
              title: '目标拆解',
              subtitle: '本周重点推进这些事',
              icon: Icons.flag_circle_rounded,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: store.goalSteps.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = store.goalSteps[index];
                  return _GoalStep(
                    title: item.title,
                    progress: item.progress,
                    note: item.note,
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            AppPrimaryButton(label: '新建目标', icon: Icons.add_rounded, onPressed: () {}),
          ],
        ),
      ),
    );
  }
}

class _GoalStep extends StatelessWidget {
  const _GoalStep({
    required this.title,
    required this.progress,
    required this.note,
  });

  final String title;
  final String progress;
  final String note;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppPalette.matchaMist.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.checklist_rounded, color: AppPalette.textPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: AppPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(note, style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            progress,
            style: const TextStyle(color: AppPalette.almondCream, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
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
                style: const TextStyle(color: AppPalette.textPrimary, fontSize: 26, fontWeight: FontWeight.w700),
              ),
              Text(subtitle, style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13)),
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
        child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppPalette.textPrimary, size: 18),
      ),
    );
  }
}
