import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/app_ui.dart';
import '../../core/latex_text.dart';
import '../../core/media_utils.dart';
import '../../core/theme.dart';
import '../capture/geogebra_scene_preview_screen.dart';
import '../capture/html_artifact_preview_screen.dart';
import '../capture/manim_video_preview_screen.dart';
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
            icon:
                const Icon(Icons.share_rounded, color: AppPalette.textPrimary),
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
                            color:
                                AppPalette.matchaMist.withValues(alpha: 0.15),
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
                    if (error.imageUrl != null &&
                        error.imageUrl!.isNotEmpty) ...[
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
              if (error.richArtifacts.isNotEmpty) ...[
                const SizedBox(height: 18),
                _GeneratedArtifactsPanel(artifacts: error.richArtifacts),
              ],
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
                            color:
                                AppPalette.pastelGrey.withValues(alpha: 0.16),
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

class _GeneratedArtifactsPanel extends StatelessWidget {
  const _GeneratedArtifactsPanel({required this.artifacts});

  final List<Map<String, dynamic>> artifacts;

  @override
  Widget build(BuildContext context) {
    final visibleArtifacts = artifacts.where(_isVisibleArtifact).toList();
    if (visibleArtifacts.isEmpty) {
      return const SizedBox.shrink();
    }
    return AppPanel(
      color: AppPalette.almondCream.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionTitle(
            title: '\u751f\u6210\u5185\u5bb9',
            subtitle:
                '\u5df2\u8ddf\u968f\u8fd9\u9053\u9519\u9898\u5165\u5e93\u4fdd\u5b58',
            icon: Icons.extension_rounded,
          ),
          const SizedBox(height: 14),
          ...visibleArtifacts.map(
            (artifact) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildArtifactTile(context, artifact),
            ),
          ),
        ],
      ),
    );
  }

  static bool _isVisibleArtifact(Map<String, dynamic> artifact) {
    final type = (artifact['artifact_type'] ?? '').toString();
    return type == 'geogebra_scene' ||
        type == 'physics_scene_spec' ||
        type == 'manim_video' ||
        type == 'manim_job' ||
        type == 'interactive_html';
  }

  Widget _buildArtifactTile(
    BuildContext context,
    Map<String, dynamic> artifact,
  ) {
    final type = (artifact['artifact_type'] ?? '').toString();
    final title = _artifactTitle(type, (artifact['title'] ?? '').toString());
    final content = artifact['content'];
    final contentText = content is String ? content : jsonEncode(content);
    final parsed = _parseContent(content);
    final action = _artifactAction(context, type, title, contentText, parsed);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppPalette.pastelGrey.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          Icon(_artifactIcon(type), color: AppPalette.almondCream, size: 22),
          const SizedBox(width: 10),
          Expanded(
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
                const SizedBox(height: 4),
                Text(
                  _artifactNote(type, parsed),
                  style: const TextStyle(
                    color: AppPalette.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 10),
            IconButton(
              onPressed: action,
              icon: const Icon(
                Icons.open_in_new_rounded,
                color: AppPalette.almondCream,
              ),
              tooltip: '\u6253\u5f00',
            ),
          ],
        ],
      ),
    );
  }

  VoidCallback? _artifactAction(
    BuildContext context,
    String type,
    String title,
    String content,
    Map<String, dynamic> parsed,
  ) {
    if ((type == 'geogebra_scene' || type == 'physics_scene_spec') &&
        parsed.isNotEmpty) {
      return () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GeoGebraScenePreviewScreen(
              title: title,
              spec: parsed,
            ),
          ),
        );
      };
    }
    if (type == 'interactive_html' && content.trim().isNotEmpty) {
      return () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HtmlArtifactPreviewScreen(
              title: title,
              htmlContent: content,
            ),
          ),
        );
      };
    }
    if ((type == 'manim_video' || type == 'manim_job') && parsed.isNotEmpty) {
      final url = (parsed['url'] ?? parsed['video_url'] ?? '').toString();
      if (url.trim().isEmpty) {
        return null;
      }
      return () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ManimVideoPreviewScreen(
              title: title,
              videoUrl: url,
              absoluteVideoUrl: (parsed['absolute_video_url'] ?? '').toString(),
              jobId: (parsed['job_id'] ?? '').toString(),
              jobStatus: (parsed['status'] ?? '').toString(),
              progress: int.tryParse((parsed['progress'] ?? '').toString()),
              message: (parsed['message'] ?? '').toString(),
              error: (parsed['error'] ?? '').toString(),
              diagnostics: _asStringMap(parsed['diagnostics']),
            ),
          ),
        );
      };
    }
    return null;
  }

  static Map<String, dynamic> _parseContent(dynamic content) {
    if (content is Map<String, dynamic>) {
      return content;
    }
    if (content is Map) {
      return _asStringMap(content);
    }
    if (content is String && content.trim().isNotEmpty) {
      try {
        return _asStringMap(jsonDecode(content));
      } catch (_) {
        return const {};
      }
    }
    return const {};
  }

  static Map<String, dynamic> _asStringMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
    }
    return const <String, dynamic>{};
  }

  static IconData _artifactIcon(String type) {
    switch (type) {
      case 'geogebra_scene':
      case 'physics_scene_spec':
        return Icons.dynamic_form_rounded;
      case 'manim_video':
        return Icons.play_circle_fill_rounded;
      case 'manim_job':
        return Icons.movie_filter_rounded;
      case 'interactive_html':
        return Icons.motion_photos_auto_rounded;
      default:
        return Icons.extension_rounded;
    }
  }

  static String _artifactTitle(String type, String title) {
    final cleaned = title.trim();
    if (cleaned == 'Manim explanation video') {
      return 'Manim \u8bb2\u89e3\u89c6\u9891';
    }
    if (cleaned == 'GeoGebra interaction') {
      return 'GeoGebra \u4ea4\u4e92\u56fe';
    }
    if (cleaned.isNotEmpty) {
      return cleaned;
    }
    switch (type) {
      case 'geogebra_scene':
      case 'physics_scene_spec':
        return 'GeoGebra \u4ea4\u4e92\u56fe';
      case 'manim_video':
        return 'Manim \u8bb2\u89e3\u89c6\u9891';
      case 'manim_job':
        return 'Manim \u8bb2\u89e3\u89c6\u9891\u751f\u6210\u4e2d';
      case 'interactive_html':
        return '\u4ea4\u4e92\u6f14\u793a';
      default:
        return '\u6269\u5c55\u5185\u5bb9';
    }
  }

  static String _artifactNote(String type, Map<String, dynamic> parsed) {
    switch (type) {
      case 'geogebra_scene':
      case 'physics_scene_spec':
        return '\u53ef\u6253\u5f00\u4ea4\u4e92\u56fe\u7ee7\u7eed\u89c2\u5bdf\u53c2\u6570\u548c\u56fe\u5f62\u5173\u7cfb';
      case 'manim_video':
        return '\u89c6\u9891\u5df2\u4fdd\u5b58\uff0c\u53ef\u76f4\u63a5\u64ad\u653e';
      case 'manim_job':
        final status = (parsed['status'] ?? '').toString();
        final progress = (parsed['progress'] ?? '').toString();
        if (status == 'succeeded') {
          return '\u89c6\u9891\u5df2\u751f\u6210';
        }
        if (progress.isNotEmpty) {
          return '\u751f\u6210\u8fdb\u5ea6 $progress%';
        }
        return '\u5df2\u4fdd\u5b58\u89c6\u9891\u751f\u6210\u4efb\u52a1';
      case 'interactive_html':
        return '\u53ef\u6253\u5f00 WebView \u9884\u89c8\u4ea4\u4e92\u5185\u5bb9';
      default:
        return '\u5df2\u968f\u9519\u9898\u6863\u6848\u4fdd\u5b58';
    }
  }
}
