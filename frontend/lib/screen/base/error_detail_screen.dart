import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/app_ui.dart';
import '../../core/latex_text.dart';
import '../../core/media_utils.dart';
import '../../core/theme.dart';
import 'home_screen.dart';

class ErrorDetailScreen extends StatelessWidget {
  const ErrorDetailScreen({super.key, required this.errorId});

  final String errorId;

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final error = store.errorById(errorId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppPalette.textPrimary),
        title: const Text(
          '错题复盘',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              error.isFavorite
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: error.isFavorite
                  ? AppPalette.almondCream
                  : AppPalette.textPrimary,
            ),
            onPressed: () {
              final wasFavorite = error.isFavorite;
              store.toggleFavorite(error.id);
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
                  content: Text('已生成错题复盘分享卡片'),
                  duration: Duration(milliseconds: 1200),
                ),
              );
            },
          ),
        ],
      ),
      body: AppSurface(
        padding: const EdgeInsets.fromLTRB(20, 72, 20, 12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppPalette.matchaMist.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            error.subject,
                            style: const TextStyle(
                              color: AppPalette.matchaMist,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          error.dateLabel,
                          style: const TextStyle(
                            color: AppPalette.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppLatexText(
                      error.topic,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    AppLatexText(
                      error.question,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 16,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (error.imageUrl != null && error.imageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: isRemoteMediaPath(error.imageUrl)
                            ? Image.network(
                                error.imageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return const SizedBox.shrink();
                                },
                              )
                            : Image.file(
                                File(error.imageUrl!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return const SizedBox.shrink();
                                },
                              ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AppPanel(
                color: const Color(0x22E17D6B),
                child: Row(
                  children: [
                    const Icon(
                      Icons.flag_rounded,
                      color: Color(0xFFE17D6B),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppLatexText(
                        '当时错因：${error.reason}',
                        style: const TextStyle(
                          color: Color(0xFFE17D6B),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AppPanel(
                color: AppPalette.honeyOrange.withValues(alpha: 0.08),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSectionTitle(
                      title: '我的回忆',
                      subtitle: '先看自己卡住的位置',
                      icon: Icons.psychology_alt_rounded,
                    ),
                    const SizedBox(height: 14),
                    AppLatexText(
                      error.myAnswer,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 15,
                        height: 1.65,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AppPanel(
                color: AppPalette.matchaMist.withValues(alpha: 0.08),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSectionTitle(
                      title: 'AI 深度解析',
                      subtitle: '这题真正应该抓住的推理核心',
                      icon: Icons.auto_awesome,
                    ),
                    const SizedBox(height: 14),
                    AppLatexText(
                      error.aiAnalysis,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 15,
                        height: 1.65,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AppPanel(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final wasFavorite = error.isFavorite;
                          store.toggleFavorite(error.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                wasFavorite ? '已取消收藏' : '已加入我的收藏',
                              ),
                              duration: const Duration(milliseconds: 1200),
                            ),
                          );
                        },
                        icon: Icon(
                          error.isFavorite
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: error.isFavorite
                              ? AppPalette.almondCream
                              : AppPalette.textSecondary,
                        ),
                        label: Text(
                          error.isFavorite ? '已加入收藏' : '加入收藏',
                          style: TextStyle(
                            color: error.isFavorite
                                ? AppPalette.almondCream
                                : AppPalette.textSecondary,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: error.isFavorite
                                ? AppPalette.almondCream.withValues(alpha: 0.4)
                                : AppPalette.pastelGrey.withValues(alpha: 0.16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('已生成错题复盘分享卡片'),
                              duration: Duration(milliseconds: 1200),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.share_rounded,
                          color: AppPalette.textPrimary,
                        ),
                        label: const Text(
                          '分享复盘',
                          style: TextStyle(color: AppPalette.textPrimary),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppPalette.pastelGrey.withValues(alpha: 0.16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => store.toggleMastered(error.id),
                  icon: Icon(
                    error.isMastered
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: error.isMastered
                        ? AppPalette.matchaMist
                        : AppPalette.textSecondary,
                  ),
                  label: Text(
                    error.isMastered ? '已掌握' : '标为掌握',
                    style: TextStyle(
                      color: error.isMastered
                          ? AppPalette.matchaMist
                          : AppPalette.textSecondary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: error.isMastered
                          ? AppPalette.matchaMist
                          : AppPalette.pastelGrey.withValues(alpha: 0.16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AppPrimaryButton(
                  label: '回到主页',
                  icon: Icons.home_rounded,
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const HomeScreen(),
                      ),
                      (route) => false,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
