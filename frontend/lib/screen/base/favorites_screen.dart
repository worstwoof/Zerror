import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/app_ui.dart';
import '../../core/theme.dart';
import 'error_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final favorites = store.favorites;
    final favoriteSubjects = favorites.map((item) => item.subject).toSet().length;
    final favoriteTags = favorites.expand((item) => item.tags).toSet().length;

    return Scaffold(
      backgroundColor: AppPalette.night,
      body: AppSurface(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 20),
            AppPanel(
              child: Row(
                children: [
                  Expanded(child: _FavoriteMetric(label: '收藏题目', value: '${store.favoriteCount}')),
                  const _MetricDivider(),
                  Expanded(child: _FavoriteMetric(label: '关联学科', value: '$favoriteSubjects')),
                  const _MetricDivider(),
                  Expanded(child: _FavoriteMetric(label: '高频标签', value: '$favoriteTags')),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const AppSectionTitle(
              title: '最近收藏',
              subtitle: '优先复盘这些内容会更高效',
              icon: Icons.favorite_rounded,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: favorites.isEmpty
                  ? const Center(
                      child: Text(
                        '还没有收藏的错题',
                        style: TextStyle(color: AppPalette.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      itemCount: favorites.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _FavoriteCard(item: favorites[index]),
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
                '我的收藏',
                style: TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '重要题型、高频笔记与灵感卡片',
                style: TextStyle(
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

class _FavoriteMetric extends StatelessWidget {
  const _FavoriteMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: AppPalette.textPrimary, fontSize: 26, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 42, color: AppPalette.pastelGrey.withValues(alpha: 0.1));
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({required this.item});

  final ErrorRecord item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ErrorDetailScreen(errorId: item.id)),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppPalette.matchaMist.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.subject,
                    style: const TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.bookmark_rounded, color: AppPalette.almondCream, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.topic,
              style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.question,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.flag_rounded, color: AppPalette.honeyOrange, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '错因：${item.reason}',
                    style: TextStyle(
                      color: AppPalette.almondCream.withValues(alpha: 0.92),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
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
