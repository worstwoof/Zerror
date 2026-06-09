import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_state.dart';
import '../../core/media_utils.dart';
import '../../core/theme.dart';
import '../../data/file_upload_client.dart';
import 'data_dashboard_screen.dart';
import 'edit_profile_screen.dart';
import 'goals_screen.dart';
import 'learning_plan_screen.dart';
import 'smart_review_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.onOpenDrawer});

  static const FileUploadClient _fileUploadClient = FileUploadClient();
  static const Color _blueTop = AppPalette.moodBlue;
  static const Color _blueDeep = AppPalette.inkBlue;
  static const Color _sheet = AppPalette.paper;

  final VoidCallback? onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          const minSheetSize = 0.36;
          const maxSheetSize = 0.84;
          final topInset = MediaQuery.of(context).padding.top;
          final preferredSheetTop = topInset + 320;
          final initialSheetSize =
              ((constraints.maxHeight - preferredSheetTop) /
                      constraints.maxHeight)
                  .clamp(minSheetSize + 0.06, maxSheetSize - 0.04)
                  .toDouble();

          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(color: _blueTop),
              ),
              _topStage(context, store),
              DraggableScrollableSheet(
                minChildSize: minSheetSize,
                initialChildSize: initialSheetSize,
                maxChildSize: maxSheetSize,
                snap: true,
                snapSizes: [
                  minSheetSize,
                  initialSheetSize,
                  maxSheetSize,
                ],
                builder: (context, scrollController) {
                  return _contentSheet(context, store, scrollController);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _topStage(BuildContext context, AppStore store) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: _blueTop),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: topInset + 38,
            right: -48,
            child: _headerBlob(
              size: 154,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Positioned(
            top: topInset + 154,
            left: -42,
            child: _headerBlob(
              size: 116,
              color: AppPalette.mint.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            top: topInset + 136,
            right: 34,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white.withValues(alpha: 0.08),
              size: 86,
            ),
          ),
          Positioned(
            top: topInset + 356,
            left: 24,
            right: 24,
            child: _blueStageNote(store),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Column(
                children: [
                  _topToolbar(context),
                  const SizedBox(height: 18),
                  _heroAvatar(context, store),
                  const SizedBox(height: 8),
                  Text(
                    store.userName,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _greetingMark(),
                  const SizedBox(height: 10),
                  Text(
                    _greetingText(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'How was your review today?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xBFFFFBF3),
                      fontSize: 14,
                      height: 1.4,
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

  Widget _topToolbar(BuildContext context) {
    return Row(
      children: [
        _headerButton(icon: Icons.notes_rounded, onTap: onOpenDrawer),
        const Spacer(),
        _headerButton(
          icon: Icons.edit_calendar_rounded,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EditProfileScreen()),
          ),
        ),
      ],
    );
  }

  Widget _heroAvatar(BuildContext context, AppStore store) {
    return GestureDetector(
      onTap: () => _pickAvatar(context, store),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 96,
            height: 96,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _blueDeep.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: _avatarContent(store, iconSize: 34),
            ),
          ),
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppPalette.almondCream,
                shape: BoxShape.circle,
                border: Border.all(color: _blueTop, width: 3),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: _blueDeep,
                size: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contentSheet(
    BuildContext context,
    AppStore store,
    ScrollController scrollController,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: _blueDeep.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ListView(
        controller: scrollController,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 116),
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: _blueDeep.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _sectionHeader(
            title: '\u63a8\u8350\u590d\u76d8',
            actionLabel: 'See All',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LearningPlanScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _recommendationList(context, store),
          const SizedBox(height: 18),
          _drawerNote(store),
        ],
      ),
    );
  }

  Widget _recommendationList(BuildContext context, AppStore store) {
    return Column(
      children: [
        _recommendationCard(
          title: '\u4eca\u65e5\u590d\u76d8',
          subtitle: store.hasLearningHistory
              ? '\u4f18\u5148\u56de\u6536 ${store.pendingReviewCount} \u9053\u9519\u9898'
              : '\u5148\u5f55\u5165\u7b2c\u4e00\u9053\u9519\u9898',
          metric: '${store.smartReviewQueue.length}',
          metricLabel: '\u9898',
          icon: Icons.playlist_add_check_rounded,
          accent: AppPalette.mint,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SmartReviewScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _recommendationCard(
          title: '\u9636\u6bb5\u76ee\u6807',
          subtitle: store.goalSteps.isNotEmpty
              ? '\u6b63\u5728\u63a8\u8fdb ${store.goalSteps.length} \u4e2a\u9636\u6bb5'
              : '\u5efa\u7acb\u672c\u5468\u5b66\u4e60\u8282\u594f',
          metric: '${store.goalSteps.length}',
          metricLabel: '\u4e2a',
          icon: Icons.flag_circle_rounded,
          accent: AppPalette.peach,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GoalsScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _recommendationCard(
          title: '\u6570\u636e\u770b\u677f',
          subtitle: '\u67e5\u770b\u8584\u5f31\u5b66\u79d1\u548c\u8d8b\u52bf',
          metric: '${store.knowledgePointCount}',
          metricLabel: '\u70b9',
          icon: Icons.stacked_line_chart_rounded,
          accent: AppPalette.blush,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DataDashboardScreen()),
          ),
        ),
      ],
    );
  }

  Widget _blueStageNote(AppStore store) {
    final message = store.hasLearningHistory
        ? '\u5148\u6311\u4e00\u4ef6\u6700\u987a\u624b\u7684\u5c0f\u4efb\u52a1\uff0c\u8ba9\u4eca\u5929\u7684\u8282\u594f\u8f7b\u4e00\u70b9\u3002'
        : '\u4eca\u5929\u53ea\u8981\u6709\u4e00\u4e2a\u5c0f\u5f00\u59cb\uff0c\u5c31\u5df2\u7ecf\u5728\u5f80\u524d\u8d70\u4e86\u3002';

    return Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xDFFFFBF3),
        fontSize: 14,
        height: 1.55,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _drawerNote(AppStore store) {
    final message = store.hasLearningHistory
        ? '\u628a\u6700\u5bb9\u6613\u5fd8\u7684\u90a3\u4e00\u6b65\u5199\u6e05\u695a\uff0c\u660e\u5929\u590d\u76d8\u4f1a\u8f7b\u5f88\u591a\u3002'
        : '\u4e0d\u7528\u4e00\u6b21\u5b8c\u6210\u5f88\u591a\uff0c\u53ea\u8981\u7559\u4e0b\u7b2c\u4e00\u6761\u53ef\u56de\u6536\u7684\u7ebf\u7d22\u3002';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppPalette.cream,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _blueDeep.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppPalette.almondCream,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: _blueDeep,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '\u590d\u76d8\u5c0f\u8bb0',
                  style: TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
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

  Widget _sectionHeader({
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }

  Widget _recommendationCard({
    required String title,
    required String subtitle,
    required String metric,
    required String metricLabel,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          height: 136,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppPalette.cream,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _blueDeep.withValues(alpha: 0.06)),
          ),
          child: Stack(
            clipBehavior: Clip.antiAlias,
            children: [
              Positioned(
                right: -24,
                bottom: -36,
                child: Icon(
                  icon,
                  color: accent.withValues(alpha: 0.42),
                  size: 122,
                ),
              ),
              Positioned(
                right: 18,
                top: 18,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: _blueDeep, size: 22),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 92, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          metric,
                          style: const TextStyle(
                            color: AppPalette.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            metricLabel,
                            style: const TextStyle(
                              color: AppPalette.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _greetingMark() {
    return SizedBox(
      width: 58,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 4,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            child: Container(
              width: 54,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            child: Icon(
              Icons.air_rounded,
              color: Colors.white.withValues(alpha: 0.92),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerBlob({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning!';
    if (hour < 18) return 'Good Afternoon!';
    return 'Good Evening!';
  }

  Future<void> _pickAvatar(BuildContext context, AppStore store) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (!context.mounted || pickedFile == null) return;
      final uploaded = await _fileUploadClient.uploadFile(
        filePath: pickedFile.path,
        category: 'avatar',
        syncUserId: store.syncUserId,
        authToken: store.authToken,
      );
      if (!context.mounted) return;
      store.setAvatarPath(uploaded.fileUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('\u5934\u50cf\u5df2\u66f4\u65b0')),
      );
    } on FileUploadException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '\u6682\u65f6\u65e0\u6cd5\u8bfb\u53d6\u5934\u50cf\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5'),
        ),
      );
    }
  }

  Widget _avatarContent(AppStore store, {double iconSize = 28}) {
    final avatarPath = store.avatarPath;
    if (avatarPath != null) {
      if (isRemoteMediaPath(avatarPath)) {
        return Image.network(
          avatarPath,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) {
            return _avatarFallback(iconSize: iconSize);
          },
        );
      }
      return Image.file(
        File(avatarPath),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) {
          return _avatarFallback(iconSize: iconSize);
        },
      );
    }
    return _avatarFallback(iconSize: iconSize);
  }

  Widget _avatarFallback({double iconSize = 28}) {
    return Container(
      color: AppPalette.almondCream,
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        color: AppPalette.textPrimary,
        size: iconSize,
      ),
    );
  }
}
