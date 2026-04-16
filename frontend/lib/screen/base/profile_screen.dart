import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_state.dart';
import '../../core/media_utils.dart';
import '../../core/theme.dart';
import '../../data/file_upload_client.dart';
import 'achievements_screen.dart';
import 'edit_profile_screen.dart';
import 'favorites_screen.dart';
import 'goals_screen.dart';
import 'privacy_security_screen.dart';
import 'share_center_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.onOpenDrawer});

  static const FileUploadClient _fileUploadClient = FileUploadClient();

  final VoidCallback? onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppPalette.appBackground),
          ),
          Image.asset(
            'assets/images/auth_bg.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
            excludeFromSemantics: true,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppPalette.matchaMist.withValues(alpha: 0.05),
                  AppPalette.kombuGreen.withValues(alpha: 0.18),
                  AppPalette.night.withValues(alpha: 0.74),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 38),
              child: Column(
                children: [
                  Row(
                    children: [
                      _topButton(icon: Icons.notes_rounded, onTap: onOpenDrawer),
                      const Spacer(),
                      _topButton(
                        icon: Icons.edit_rounded,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _heroCard(context, store),
                  const SizedBox(height: 18),
                  _shareCard(context, store),
                  const SizedBox(height: 18),
                  _goalsCard(context, store),
                  const SizedBox(height: 18),
                  _menuCard(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard(BuildContext context, AppStore store) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.pastelGrey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppPalette.pastelGrey.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 144,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppPalette.artichoke.withValues(alpha: 0.96),
                  AppPalette.matchaMist.withValues(alpha: 0.92),
                  AppPalette.almondCream.withValues(alpha: 0.48),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 18,
                  top: 16,
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppPalette.honeyOrange.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                Positioned(
                  right: 18,
                  top: 18,
                  child: Icon(
                    Icons.spa_rounded,
                    size: 60,
                    color: AppPalette.kombuGreen.withValues(alpha: 0.58),
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -34),
            child: GestureDetector(
              onTap: () => _pickAvatar(context, store),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: _avatarContent(store, iconSize: 34),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppPalette.almondCream,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppPalette.night, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: AppPalette.night,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
            child: Transform.translate(
              offset: const Offset(0, -22),
              child: Column(
                children: [
                  Text(
                    store.userName,
                    style: const TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    store.userMotto,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppPalette.textSecondary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppPalette.almondCream.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium_rounded, color: AppPalette.almondCream, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Premium Study',
                          style: TextStyle(
                            color: AppPalette.almondCream,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _heroStat('\u7d2f\u8ba1\u5f55\u5165', '${store.totalErrors}', '\u9898')),
                      Expanded(child: _heroStat('\u575a\u6301\u590d\u4e60', '${store.studyStreakDays}', '\u5929')),
                      Expanded(
                        child: _heroStat('\u653b\u514b\u8003\u70b9', '${store.knowledgePointCount}', '\u4e2a'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shareCard(BuildContext context, AppStore store) {
    return _glassCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ShareCenterScreen()),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppPalette.honeyOrange.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.redeem_rounded, color: AppPalette.almondCream, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '\u5206\u4eab\u5b66\u4e60\u7a7a\u95f4',
                  style: TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\u5df2\u9080\u8bf7 ${store.invitedCount} \u4f4d\u540c\u5b66\uff0c\u7d2f\u8ba1\u89e3\u9501 ${store.unlockedMonths} \u4e2a\u6708\u9ad8\u7ea7\u6743\u76ca\u3002',
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppPalette.matchaMist.withValues(alpha: 0.18),
            ),
            child: const Icon(Icons.ios_share_rounded, color: AppPalette.textPrimary, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _goalsCard(BuildContext context, AppStore store) {
    final focusGoal = store.goalSteps.first;
    return _glassCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GoalsScreen()),
      ),
      padding: const EdgeInsets.all(20),
      borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppPalette.matchaMist.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.flag_circle_rounded, color: AppPalette.textPrimary),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u5b66\u4e60\u76ee\u6807',
                    style: TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Goals',
                    style: TextStyle(color: AppPalette.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '\u4f60\u5f53\u524d\u6b63\u5728\u63a8\u8fdb ${store.goalSteps.length} \u4e2a\u9636\u6bb5\u76ee\u6807',
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppPalette.kombuGreen.withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppPalette.matchaMist.withValues(alpha: 0.16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppPalette.matchaMist.withValues(alpha: 0.18),
                  ),
                  child: const Icon(Icons.auto_graph_rounded, color: AppPalette.textPrimary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        focusGoal.title,
                        style: const TextStyle(
                          color: AppPalette.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${focusGoal.progress} · ${focusGoal.note}',
                        style: const TextStyle(
                          color: AppPalette.textSecondary,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppPalette.matchaMist,
                  ),
                  child: const Icon(Icons.add_rounded, color: AppPalette.night, size: 30),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.pastelGrey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppPalette.pastelGrey.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Row(
              children: [
                Text(
                  '\u66f4\u591a\u8bbe\u7f6e',
                  style: TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _menuItem(
            context,
            icon: Icons.workspace_premium_rounded,
            title: '\u6211\u7684\u6210\u5c31',
            subtitle: '\u67e5\u770b\u6210\u957f\u5fbd\u7ae0\u3001\u8fde\u7eed\u6253\u5361\u548c\u91cc\u7a0b\u7891',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AchievementsScreen()),
            ),
          ),
          _divider(),
          _menuItem(
            context,
            icon: Icons.favorite_rounded,
            title: '\u6211\u7684\u6536\u85cf',
            subtitle: '\u96c6\u4e2d\u67e5\u770b\u9ad8\u4ef7\u503c\u9519\u9898\u3001\u9898\u578b\u6a21\u677f\u548c\u91cd\u70b9\u7b14\u8bb0',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            ),
          ),
          _divider(),
          _menuItem(
            context,
            icon: Icons.security_rounded,
            title: '\u9690\u79c1\u4e0e\u5b89\u5168',
            subtitle: '\u7ba1\u7406\u8d26\u53f7\u5bc6\u7801\u3001\u767b\u5f55\u8bbe\u5907\u548c\u9690\u79c1\u9009\u9879',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    required VoidCallback onTap,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
    double borderRadius = 24,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppPalette.pastelGrey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppPalette.pastelGrey.withValues(alpha: 0.08)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _heroStat(String label, String value, String unit) {
    return Column(
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppPalette.matchaMist.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppPalette.matchaMist, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppPalette.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: const TextStyle(
            color: AppPalette.textSecondary,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppPalette.textSecondary, size: 16),
      onTap: onTap,
    );
  }

  Widget _divider() {
    return Divider(
      color: AppPalette.textPrimary.withValues(alpha: 0.08),
      height: 1,
      indent: 70,
      endIndent: 18,
    );
  }

  Widget _topButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppPalette.pastelGrey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppPalette.pastelGrey.withValues(alpha: 0.08)),
          ),
          child: Icon(icon, color: AppPalette.textPrimary),
        ),
      ),
    );
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
          content: Text('\u6682\u65f6\u65e0\u6cd5\u8bfb\u53d6\u5934\u50cf\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5'),
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
      color: AppPalette.kombuGreen,
      alignment: Alignment.center,
      child: Icon(Icons.person_rounded, color: AppPalette.textPrimary, size: iconSize),
    );
  }
}
