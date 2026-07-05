import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_state.dart';
import '../../core/app_ui.dart';
import '../../core/latex_text.dart';
import '../../core/media_utils.dart';
import '../../core/rose_three_loader.dart';
import '../../core/theme.dart';
import '../capture/error_edit_screen.dart';
import '../capture/error_preview_screen.dart';
import '../capture/html_artifact_preview_screen.dart';
import '../capture/manim_video_preview_screen.dart';
import 'achievements_screen.dart';
import 'ai_chat_screen.dart';
import 'error_archive_screen.dart';
import 'favorites_screen.dart';
import 'manual_entry_screen.dart';
import 'privacy_security_screen.dart';
import 'profile_screen.dart';
import 'practice_paper_entry_screen.dart';
import 'recycle_bin_screen.dart';
import 'settings_screen.dart';
import 'smart_quiz_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _flatInk = AppPalette.inkBlue;
  static const Color _flatCream = AppPalette.cream;
  static const Color _flatMuted = AppPalette.textSecondary;
  static const Color _flatBlue = AppPalette.moodBlue;
  static const Color _flatGreen = AppPalette.leaf;
  static const Color _flatMint = AppPalette.mint;
  static const Color _flatPeach = AppPalette.peach;
  static const Color _flatPink = AppPalette.blush;
  static const Color _queueSheetSurface = Color(0xFFFFFCF6);
  static const Color _queueTaskSurface = Color(0xFFFFFEFB);
  static const Color _queueSuccess = Color(0xFF53784F);
  static const Color _queueWarning = Color(0xFF9A681F);
  static const Color _queueDanger = Color(0xFFB9574F);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppPalette.cream,
      extendBody: true,
      drawer: _buildDrawer(context, store),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(color: _flatCream),
            ),
          ),
          _flatBlob(
            top: 94,
            right: -28,
            width: 150,
            height: 106,
            color: _flatMint.withOpacity(0.55),
            radius: const BorderRadius.only(
              topLeft: Radius.circular(42),
              topRight: Radius.circular(30),
              bottomLeft: Radius.circular(64),
              bottomRight: Radius.circular(34),
            ),
          ),
          _flatBlob(
            top: 226,
            left: -28,
            width: 132,
            height: 96,
            color: _flatGreen.withOpacity(0.54),
            radius: const BorderRadius.only(
              topLeft: Radius.circular(34),
              topRight: Radius.circular(56),
              bottomLeft: Radius.circular(42),
              bottomRight: Radius.circular(28),
            ),
          ),
          _flatBlob(
            bottom: 142,
            right: 26,
            width: 94,
            height: 94,
            color: _flatPink.withOpacity(0.52),
            radius: BorderRadius.circular(36),
          ),
          PageView(
            controller: _pageController,
            physics: const ClampingScrollPhysics(),
            onPageChanged: (index) {
              if (_currentIndex != index) {
                setState(() => _currentIndex = index);
              }
            },
            children: [
              RepaintBoundary(child: _buildHomeTab(context, store)),
              RepaintBoundary(
                child: ProfileScreen(
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _buildCenterAddButton(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomAppBar(),
    );
  }

  Widget _buildHomeTab(BuildContext context, AppStore store) {
    final topPadding = MediaQuery.of(context).padding.top + 38;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, topPadding, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHomeHeader(context, store),
          const SizedBox(height: 14),
          _buildHomeBrief(store),
          const SizedBox(height: 26),
          _buildPrimaryCaptureCard(context, store),
          const SizedBox(height: 16),
          _buildSecondaryActions(context, store),
          const SizedBox(height: 16),
          _buildAiAssistantCard(context),
        ],
      ),
    );
  }

  Widget _buildHomeBrief(AppStore store) {
    final description = store.totalErrors == 0
        ? '先拍下第一道错题，后面只围绕录入、档案和组卷继续展开。'
        : '已收录 ${store.totalErrors} 道错题，今天可以继续补充档案，或直接用档案生成一套练习。';

    return Text(
      description,
      style: const TextStyle(
        color: _flatMuted,
        fontSize: 16,
        height: 1.55,
      ),
    );
  }

  Widget _flatBlob({
    double? top,
    double? right,
    double? bottom,
    double? left,
    required double width,
    required double height,
    required Color color,
    required BorderRadiusGeometry radius,
  }) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: IgnorePointer(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: radius,
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryCaptureCard(BuildContext context, AppStore store) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showAddActionSheet(context),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 24, 22, 24),
          decoration: BoxDecoration(
            color: _flatBlue,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: _flatInk.withOpacity(0.14),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xF2FFFFFF),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0x22000000),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        store.totalErrors == 0
                            ? '从第一题开始'
                            : '档案中已有 ${store.totalErrors} 题',
                        style: const TextStyle(
                          color: _flatInk,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '拍照录入',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '拍下题目后进入预览，确认识别结果，再保存到错题档案。',
                      style: TextStyle(
                        color: Color(0xDDEFF2FF),
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _flatCream,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.camera_alt_rounded,
                            color: _flatInk,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '开始录入',
                            style: TextStyle(
                              color: _flatInk,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Container(
                width: 94,
                height: 94,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _flatCream,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.42),
                  ),
                ),
                child: const Center(
                  child: _FlatHomeIcon(
                    kind: _FlatHomeIconKind.capture,
                    size: 78,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryActions(BuildContext context, AppStore store) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = constraints.maxWidth < 360 ? 10.0 : 14.0;
        return Row(
          children: [
            Expanded(
              child: _homeActionTile(
                icon: _FlatHomeIconKind.archive,
                color: _flatGreen,
                title: '错题档案',
                subtitle: '${store.totalErrors} 道已收录',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ErrorArchiveScreen()),
                ),
              ),
            ),
            SizedBox(width: spacing),
            Expanded(
              child: _homeActionTile(
                icon: _FlatHomeIconKind.quiz,
                color: _flatPeach,
                title: '智能组卷',
                subtitle: store.totalErrors == 0 ? '先录入错题' : '从档案出题',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SmartQuizScreen()),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAiAssistantCard(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AiChatScreen()),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
          decoration: BoxDecoration(
            color: AppPalette.paper.withOpacity(0.94),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppPalette.inkBlue.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: AppPalette.inkBlue.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            children: [
              _FlatHomeIcon(
                kind: _FlatHomeIconKind.assistant,
                size: 58,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 助教',
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '用对话拆题、复盘错因、安排下一次练习',
                      style: TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Icon(
                Icons.chevron_right_rounded,
                color: AppPalette.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _homeActionTile({
    required _FlatHomeIconKind icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _flatInk.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _FlatHomeIcon(kind: icon, size: 54),
              const SizedBox(height: 22),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _flatInk,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xB3111A3A),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeHeader(BuildContext context, AppStore store) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            store.userName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _flatInk,
              fontSize: 46,
              fontWeight: FontWeight.w800,
              height: 1.04,
            ),
          ),
        ),
        if (store.hasBackgroundTasks) ...[
          const SizedBox(width: 14),
          _buildAnalysisQueueLauncher(context, store),
        ],
      ],
    );
  }

  Widget _buildDrawer(BuildContext context, AppStore store) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.76,
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(30)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(color: AppPalette.inkBlue),
            ),
            Positioned(
              top: 70,
              right: -34,
              child: FlatShape(
                width: 118,
                height: 90,
                color: AppPalette.mint.withOpacity(0.22),
              ),
            ),
            Positioned(
              bottom: 124,
              left: -28,
              child: FlatShape(
                width: 96,
                height: 86,
                color: AppPalette.peach.withOpacity(0.22),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                                color: AppPalette.pastelGrey.withOpacity(0.18)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: _avatarContent(store, iconSize: 28),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                store.userName,
                                style: const TextStyle(
                                  color: AppPalette.almondCream,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${store.userId}',
                                style: const TextStyle(
                                  color: Color(0xB3FFF7EA),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppPalette.almondCream.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        store.userMotto,
                        style: const TextStyle(
                          color: AppPalette.almondCream,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    AppPanel(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 16),
                      color: AppPalette.pastelGrey.withOpacity(0.06),
                      child: Row(
                        children: [
                          Expanded(
                              child: _drawerMetric(
                                  '\u9519\u9898', '${store.totalErrors}')),
                          Expanded(
                              child: _drawerMetric(
                                  '\u6536\u85cf', '${store.favoriteCount}')),
                          Expanded(
                              child: _drawerMetric('\u8fde\u7eed',
                                  '${store.studyStreakDays}\u5929')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _drawerItem(
                            context,
                            icon: Icons.workspace_premium_rounded,
                            title: '我的成就',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const AchievementsScreen()),
                            ),
                          ),
                          _drawerItem(
                            context,
                            icon: Icons.favorite_rounded,
                            title: '我的收藏',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const FavoritesScreen()),
                            ),
                          ),
                          _drawerItem(
                            context,
                            icon: Icons.security_rounded,
                            title: '隐私与安全',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const PrivacySecurityScreen()),
                            ),
                          ),
                          _drawerItem(
                            context,
                            icon: Icons.auto_awesome_rounded,
                            title: 'AI 助教',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const AiChatScreen()),
                            ),
                          ),
                          _drawerItem(
                            context,
                            icon: Icons.restore_from_trash_rounded,
                            title: '\u9519\u9898\u56de\u6536\u7ad9',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const RecycleBinScreen()),
                            ),
                          ),
                          _drawerItem(
                            context,
                            icon: Icons.settings_outlined,
                            title: '\u7cfb\u7edf\u8bbe\u7f6e',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const SettingsScreen()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppPalette.almondCream,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Color(0xB3FFF7EA), fontSize: 12)),
      ],
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDanger
            ? Colors.redAccent.withOpacity(0.10)
            : AppPalette.pastelGrey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.pop(context);
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Icon(icon,
                    color: isDanger ? AppPalette.blush : AppPalette.matchaMist),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color:
                          isDanger ? AppPalette.blush : AppPalette.almondCream,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!isDanger)
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0x99FFF7EA)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAppBar() {
    return BottomAppBar(
      height: 48,
      color: AppPalette.paper,
      elevation: 0,
      shadowColor: AppPalette.inkBlue.withOpacity(0.08),
      shape: const CircularNotchedRectangle(),
      notchMargin: 6,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          const SizedBox(width: 18),
          Expanded(
            child: _buildBottomTab(
              index: 0,
              icon: Icons.home_outlined,
              label: '主页',
            ),
          ),
          const SizedBox(width: 66),
          Expanded(
            child: _buildBottomTab(
              index: 1,
              icon: Icons.person_outline_rounded,
              label: '个人中心',
            ),
          ),
          const SizedBox(width: 18),
        ],
      ),
    );
  }

  Widget _buildBottomTab({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    const selectedColor = AppPalette.moodBlue;
    const unselectedColor = AppPalette.textSecondary;
    final contentColor = isSelected ? selectedColor : unselectedColor;

    return Material(
      color: Colors.transparent,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: InkWell(
          onTap: () => _onNavTapped(index),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const SizedBox(height: 1),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: Icon(
                  icon,
                  key: ValueKey<bool>(isSelected),
                  color: contentColor,
                  size: 30,
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                opacity: isSelected ? 1 : 0,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: selectedColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(height: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterAddButton(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showAddActionSheet(context),
      elevation: 4,
      highlightElevation: 6,
      backgroundColor: AppPalette.inkBlue,
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
      child: const Icon(Icons.add_rounded, size: 32),
    );
  }

  void _onNavTapped(int index) {
    if (_currentIndex == index) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    setState(() => _currentIndex = index);
  }

  Widget _buildAnalysisQueueLauncher(BuildContext context, AppStore store) {
    final completedCount = store.completedBackgroundTaskCount;
    final failedCount = store.failedBackgroundTaskCount;
    final activeCount = store.activeBackgroundTaskCount;
    final totalCount = store.totalBackgroundTaskCount;
    final hasFailure = failedCount > 0;
    final hasCompleted = completedCount > 0;
    final hasActive = activeCount > 0;
    final tint = hasFailure
        ? _queueDanger
        : hasActive
            ? AppPalette.moodBlue
            : hasCompleted
                ? _queueSuccess
                : AppPalette.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showAnalysisQueueSheet(context),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppPalette.paper.withOpacity(0.96),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: tint.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                color: AppPalette.inkBlue.withOpacity(0.10),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              hasActive && !hasFailure
                  ? const _ActiveDownloadIndicator()
                  : Icon(
                      hasFailure
                          ? Icons.error_outline_rounded
                          : Icons.pending_actions_rounded,
                      color: tint,
                      size: 21,
                    ),
              const SizedBox(width: 8),
              Text(
                '$totalCount',
                style: TextStyle(
                  color: tint,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAnalysisQueueSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _buildAnalysisQueueSheet(sheetContext),
    );
  }

  Widget _buildAnalysisQueueSheet(BuildContext sheetContext) {
    return Builder(
      builder: (context) {
        final store = AppStateScope.of(context);
        final tasks = store.analysisTasks;
        final paperTasks = store.practicePaperTasks;
        final handoutTasks = store.lectureHandoutTasks;
        final videoTasks = store.lectureVideoTasks;
        final taskCards = <Widget>[
          ...tasks.map(
            (task) => _buildAnalysisTaskTile(sheetContext, store, task),
          ),
          ...paperTasks.map(
            (task) => _buildPracticePaperTaskTile(sheetContext, store, task),
          ),
          ...handoutTasks.map(
            (task) => _buildLectureHandoutTaskTile(sheetContext, store, task),
          ),
          ...videoTasks.map(
            (task) => _buildLectureVideoTaskTile(sheetContext, store, task),
          ),
        ];
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.76,
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: const BoxDecoration(
            color: _queueSheetSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Color(0x24111A3A),
                blurRadius: 28,
                offset: Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppPalette.inkBlue.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppPalette.moodBlue.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.pending_actions_rounded,
                        color: AppPalette.moodBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '后台学习任务',
                            style: TextStyle(
                              color: AppPalette.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _queueSummary(store),
                            style: const TextStyle(
                              color: AppPalette.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: taskCards.isEmpty
                      ? const Center(
                          child: Text(
                            '暂无后台学习任务',
                            style: TextStyle(color: AppPalette.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: taskCards.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) => taskCards[index],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _queueSummary(AppStore store) {
    final active = store.activeBackgroundTaskCount;
    final completed = store.completedBackgroundTaskCount;
    final failed = store.failedBackgroundTaskCount;
    if (active > 0) {
      return '正在后台处理 $active 个任务，$completed 个已完成';
    }
    if (failed > 0) {
      return '$failed 个任务需要重试，$completed 个已完成';
    }
    if (completed > 0) {
      return '$completed 个任务已完成，等你打开确认';
    }
    return '拍题解析、智能组卷、讲义和视频讲解都会在这里排队';
  }

  Widget _buildQueueTaskHeader({
    required ({IconData icon, Color color, String label, String note}) status,
    required DateTime createdAt,
    required bool showQueuePosition,
    required int queuePosition,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(status.icon, color: status.color, size: 17),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: status.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (showQueuePosition) ...[
                const SizedBox(height: 2),
                Text(
                  queuePosition == 1 ? '当前执行' : '队列第 $queuePosition',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(
            _formatTaskTime(createdAt),
            style: const TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisTaskTile(
    BuildContext sheetContext,
    AppStore store,
    BackgroundAnalysisTask task,
  ) {
    final status = _analysisTaskStatus(task);
    final queuePosition = store.analysisTaskQueuePosition(task.id);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _analysisTaskTap(sheetContext, task),
        borderRadius: BorderRadius.circular(24),
        child: AppPanel(
          padding: const EdgeInsets.all(12),
          color: _queueTaskSurface,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 62,
                  height: 62,
                  child: Image.file(
                    File(task.imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppPalette.pastelGrey.withOpacity(0.45),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_rounded,
                          color: AppPalette.textSecondary,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQueueTaskHeader(
                      status: status,
                      createdAt: task.createdAt,
                      showQueuePosition: task.isActive && queuePosition > 0,
                      queuePosition: queuePosition,
                    ),
                    const SizedBox(height: 8),
                    _buildTaskPreviewText(task, status.note),
                    const SizedBox(height: 10),
                    _buildAnalysisTaskActions(sheetContext, store, task),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPracticePaperTaskTile(
    BuildContext sheetContext,
    AppStore store,
    BackgroundPracticePaperTask task,
  ) {
    final status = _practicePaperTaskStatus(task);
    final queuePosition = store.practicePaperTaskQueuePosition(task.id);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _practicePaperTaskTap(sheetContext, task),
        borderRadius: BorderRadius.circular(24),
        child: AppPanel(
          padding: const EdgeInsets.all(12),
          color: _queueTaskSurface,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppPalette.moodBlue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppPalette.moodBlue.withOpacity(0.14),
                  ),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: AppPalette.moodBlue,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQueueTaskHeader(
                      status: status,
                      createdAt: task.createdAt,
                      showQueuePosition: task.isActive && queuePosition > 0,
                      queuePosition: queuePosition,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _practicePaperTaskPreviewText(task, status.note),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildPracticePaperTaskActions(sheetContext, store, task),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLectureHandoutTaskTile(
    BuildContext sheetContext,
    AppStore store,
    BackgroundLectureHandoutTask task,
  ) {
    final status = _lectureHandoutTaskStatus(task);
    final queuePosition = store.lectureHandoutTaskQueuePosition(task.id);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _lectureHandoutTaskTap(sheetContext, task),
        borderRadius: BorderRadius.circular(24),
        child: AppPanel(
          padding: const EdgeInsets.all(12),
          color: _queueTaskSurface,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppPalette.leaf.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppPalette.leaf.withOpacity(0.16),
                  ),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppPalette.leaf,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQueueTaskHeader(
                      status: status,
                      createdAt: task.createdAt,
                      showQueuePosition: task.isActive && queuePosition > 0,
                      queuePosition: queuePosition,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _lectureHandoutTaskPreviewText(task, status.note),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildLectureHandoutTaskActions(sheetContext, store, task),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLectureVideoTaskTile(
    BuildContext sheetContext,
    AppStore store,
    BackgroundLectureVideoTask task,
  ) {
    final status = _lectureVideoTaskStatus(task);
    final queuePosition = store.lectureVideoTaskQueuePosition(task.id);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _lectureVideoTaskTap(sheetContext, task),
        borderRadius: BorderRadius.circular(24),
        child: AppPanel(
          padding: const EdgeInsets.all(12),
          color: _queueTaskSurface,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppPalette.moodBlue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppPalette.moodBlue.withOpacity(0.16),
                  ),
                ),
                child: const Icon(
                  Icons.movie_creation_outlined,
                  color: AppPalette.moodBlue,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQueueTaskHeader(
                      status: status,
                      createdAt: task.createdAt,
                      showQueuePosition: task.isActive && queuePosition > 0,
                      queuePosition: queuePosition,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _lectureVideoTaskPreviewText(task, status.note),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildLectureVideoTaskActions(sheetContext, store, task),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  VoidCallback? _analysisTaskTap(
    BuildContext sheetContext,
    BackgroundAnalysisTask task,
  ) {
    if (task.status == AnalysisTaskStatus.completed && task.analysis != null) {
      return () {
        Navigator.pop(sheetContext);
        _openCompletedAnalysisTask(task);
      };
    }
    if (task.status == AnalysisTaskStatus.failed) {
      return () {
        Navigator.pop(sheetContext);
        _openFailedAnalysisTask(task);
      };
    }
    if (task.isActive) {
      return () {
        Navigator.pop(sheetContext);
        _openWaitingAnalysisTask(task);
      };
    }
    return null;
  }

  VoidCallback? _practicePaperTaskTap(
    BuildContext sheetContext,
    BackgroundPracticePaperTask task,
  ) {
    if (task.status == AnalysisTaskStatus.completed && task.paper != null) {
      return () {
        Navigator.pop(sheetContext);
        _openCompletedPracticePaperTask(task);
      };
    }
    return null;
  }

  VoidCallback? _lectureHandoutTaskTap(
    BuildContext sheetContext,
    BackgroundLectureHandoutTask task,
  ) {
    if (task.status == AnalysisTaskStatus.completed && task.handout != null) {
      return () {
        Navigator.pop(sheetContext);
        _openCompletedLectureHandoutTask(task);
      };
    }
    return null;
  }

  VoidCallback? _lectureVideoTaskTap(
    BuildContext sheetContext,
    BackgroundLectureVideoTask task,
  ) {
    if (task.status == AnalysisTaskStatus.completed && task.video != null) {
      return () {
        Navigator.pop(sheetContext);
        _openCompletedLectureVideoTask(task);
      };
    }
    return null;
  }

  Widget _buildTaskPreviewText(BackgroundAnalysisTask task, String fallback) {
    final content = task.isCompleted && task.extractedText.trim().isNotEmpty
        ? task.extractedText.trim()
        : task.errorMessage ?? task.statusMessage ?? fallback;

    if (!task.isCompleted) {
      return Text(
        content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppPalette.textPrimary,
          fontSize: 13,
          height: 1.45,
        ),
      );
    }

    return SizedBox(
      height: 42,
      child: ClipRect(
        child: Align(
          alignment: Alignment.topLeft,
          child: AppLatexText(
            content,
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }

  String _practicePaperTaskPreviewText(
    BackgroundPracticePaperTask task,
    String fallback,
  ) {
    final paper = task.paper;
    if (task.isCompleted && paper != null) {
      final title = paper.title.trim().isEmpty ? '专题针对性练习' : paper.title;
      return '$title · ${paper.questions.length} 题';
    }
    return task.errorMessage ?? task.statusMessage ?? fallback;
  }

  String _lectureHandoutTaskPreviewText(
    BackgroundLectureHandoutTask task,
    String fallback,
  ) {
    final handout = task.handout;
    if (task.isCompleted && handout != null) {
      final title = handout.title.trim().isEmpty ? '知识讲义' : handout.title;
      final topic = handout.topic.trim().isEmpty ? task.topic : handout.topic;
      return topic.trim().isEmpty ? title : '$title · $topic';
    }
    return task.errorMessage ?? task.statusMessage ?? fallback;
  }

  String _lectureVideoTaskPreviewText(
    BackgroundLectureVideoTask task,
    String fallback,
  ) {
    final video = task.video;
    if (task.isCompleted && video != null) {
      final title = video.title.trim().isEmpty ? '知识点视频讲解' : video.title;
      final topic = video.topic.trim().isEmpty ? task.topic : video.topic;
      return topic.trim().isEmpty ? title : '$title · $topic';
    }
    return task.errorMessage ?? task.statusMessage ?? fallback;
  }

  Widget _buildAnalysisTaskActions(
    BuildContext sheetContext,
    AppStore store,
    BackgroundAnalysisTask task,
  ) {
    if (task.status == AnalysisTaskStatus.completed && task.analysis != null) {
      final hasPartialWarning = (task.errorMessage ?? '').trim().isNotEmpty;
      return Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(sheetContext);
              _openCompletedAnalysisTask(task);
            },
            icon: const Icon(Icons.fact_check_rounded, size: 17),
            label: const Text('\u786e\u8ba4\u5165\u6863'),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.moodBlue,
              padding: EdgeInsets.zero,
            ),
          ),
          if (hasPartialWarning)
            TextButton.icon(
              onPressed: () => store.retryAnalysisTask(task.id),
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('重试详解'),
              style: TextButton.styleFrom(
                foregroundColor: AppPalette.textPrimary,
                padding: EdgeInsets.zero,
              ),
            ),
          TextButton(
            onPressed: () => store.dismissAnalysisTask(task.id),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.textSecondary,
              padding: EdgeInsets.zero,
            ),
            child: const Text('\u79fb\u9664'),
          ),
        ],
      );
    }

    if (task.status == AnalysisTaskStatus.failed) {
      return Row(
        children: [
          TextButton.icon(
            onPressed: () => store.retryAnalysisTask(task.id),
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('\u91cd\u8bd5'),
            style: TextButton.styleFrom(
              foregroundColor: _queueDanger,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () {
              Navigator.pop(sheetContext);
              _openFailedAnalysisTask(task);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.textPrimary,
              padding: EdgeInsets.zero,
            ),
            child: const Text('\u624b\u52a8\u6574\u7406'),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => store.dismissAnalysisTask(task.id),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.textSecondary,
              padding: EdgeInsets.zero,
            ),
            child: const Text('\u79fb\u9664'),
          ),
        ],
      );
    }

    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: AppPalette.moodBlue.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.file_download_rounded,
            color: AppPalette.moodBlue,
            size: 13,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          '\u4f60\u53ef\u4ee5\u7ee7\u7eed\u62cd\u4e0b\u4e00\u9898',
          style: TextStyle(color: AppPalette.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPracticePaperTaskActions(
    BuildContext sheetContext,
    AppStore store,
    BackgroundPracticePaperTask task,
  ) {
    if (task.status == AnalysisTaskStatus.completed && task.paper != null) {
      return Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(sheetContext);
              _openCompletedPracticePaperTask(task);
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 17),
            label: const Text('打开试卷'),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.moodBlue,
              padding: EdgeInsets.zero,
            ),
          ),
          TextButton(
            onPressed: () => store.dismissPracticePaperTask(task.id),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.textSecondary,
              padding: EdgeInsets.zero,
            ),
            child: const Text('移除'),
          ),
        ],
      );
    }

    if (task.status == AnalysisTaskStatus.failed) {
      return Row(
        children: [
          TextButton.icon(
            onPressed: () => store.retryPracticePaperTask(task.id),
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('重试'),
            style: TextButton.styleFrom(
              foregroundColor: _queueDanger,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => store.dismissPracticePaperTask(task.id),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.textSecondary,
              padding: EdgeInsets.zero,
            ),
            child: const Text('移除'),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            value: task.progress > 0 ? task.progress / 100 : null,
            strokeWidth: 2,
            color: AppPalette.moodBlue,
            backgroundColor: AppPalette.moodBlue.withOpacity(0.12),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          '可以先回主页继续学习',
          style: TextStyle(color: AppPalette.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildLectureHandoutTaskActions(
    BuildContext sheetContext,
    AppStore store,
    BackgroundLectureHandoutTask task,
  ) {
    if (task.status == AnalysisTaskStatus.completed && task.handout != null) {
      return Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(sheetContext);
              _openCompletedLectureHandoutTask(task);
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 17),
            label: const Text('打开讲义'),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.leaf,
              padding: EdgeInsets.zero,
            ),
          ),
          TextButton(
            onPressed: () => store.dismissLectureHandoutTask(task.id),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.textSecondary,
              padding: EdgeInsets.zero,
            ),
            child: const Text('移除'),
          ),
        ],
      );
    }

    if (task.status == AnalysisTaskStatus.failed) {
      return Row(
        children: [
          TextButton.icon(
            onPressed: () => store.retryLectureHandoutTask(task.id),
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('重试'),
            style: TextButton.styleFrom(
              foregroundColor: _queueDanger,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => store.dismissLectureHandoutTask(task.id),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.textSecondary,
              padding: EdgeInsets.zero,
            ),
            child: const Text('移除'),
          ),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            value: task.progress > 0 ? task.progress / 100 : null,
            strokeWidth: 2,
            color: AppPalette.leaf,
            backgroundColor: AppPalette.leaf.withOpacity(0.12),
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            '可以继续提问或学习其他内容',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppPalette.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildLectureVideoTaskActions(
    BuildContext sheetContext,
    AppStore store,
    BackgroundLectureVideoTask task,
  ) {
    if (task.status == AnalysisTaskStatus.completed && task.video != null) {
      return Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(sheetContext);
              _openCompletedLectureVideoTask(task);
            },
            icon: const Icon(Icons.play_circle_outline_rounded, size: 17),
            label: const Text('打开视频'),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.moodBlue,
              padding: EdgeInsets.zero,
            ),
          ),
          TextButton(
            onPressed: () => store.dismissLectureVideoTask(task.id),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.textSecondary,
              padding: EdgeInsets.zero,
            ),
            child: const Text('移除'),
          ),
        ],
      );
    }

    if (task.status == AnalysisTaskStatus.failed) {
      return Row(
        children: [
          TextButton.icon(
            onPressed: () => store.retryLectureVideoTask(task.id),
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('重试'),
            style: TextButton.styleFrom(
              foregroundColor: _queueDanger,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => store.dismissLectureVideoTask(task.id),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.textSecondary,
              padding: EdgeInsets.zero,
            ),
            child: const Text('移除'),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            value: task.progress > 0 ? task.progress / 100 : null,
            strokeWidth: 2,
            color: AppPalette.moodBlue,
            backgroundColor: AppPalette.moodBlue.withOpacity(0.12),
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            '可以继续提问，视频生成好会留在这里',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppPalette.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }

  ({IconData icon, Color color, String label, String note}) _analysisTaskStatus(
    BackgroundAnalysisTask task,
  ) {
    switch (task.status) {
      case AnalysisTaskStatus.queued:
        return (
          icon: Icons.schedule_rounded,
          color: AppPalette.textSecondary,
          label: '\u7b49\u5f85\u6574\u7406',
          note: '\u5df2\u6536\u5230\u540e\u53f0\u961f\u5217',
        );
      case AnalysisTaskStatus.analyzing:
        return (
          icon: Icons.file_download_rounded,
          color: AppPalette.moodBlue,
          label: '\u6b63\u5728\u6574\u7406',
          note:
              '\u6b63\u5728\u8bc6\u522b\u9898\u5e72\u5e76\u751f\u6210\u9519\u9898\u5206\u6790',
        );
      case AnalysisTaskStatus.completed:
        if ((task.errorMessage ?? '').trim().isNotEmpty) {
          return (
            icon: Icons.fact_check_rounded,
            color: _queueWarning,
            label: '基础结果',
            note: '已保留识别结果，可先入档或重试详解',
          );
        }
        return (
          icon: Icons.check_circle_rounded,
          color: _queueSuccess,
          label: '\u5df2\u5b8c\u6210',
          note: '\u70b9\u51fb\u786e\u8ba4\u540e\u5c31\u80fd\u5165\u6863',
        );
      case AnalysisTaskStatus.failed:
        return (
          icon: Icons.error_outline_rounded,
          color: _queueDanger,
          label: '\u9700\u8981\u91cd\u8bd5',
          note:
              '\u8fd9\u9053\u9898\u6ca1\u6709\u4e22\uff0c\u53ef\u4ee5\u91cd\u8bd5\u6216\u624b\u52a8\u6574\u7406',
        );
    }
  }

  ({IconData icon, Color color, String label, String note})
      _practicePaperTaskStatus(
    BackgroundPracticePaperTask task,
  ) {
    switch (task.status) {
      case AnalysisTaskStatus.queued:
        return (
          icon: Icons.schedule_rounded,
          color: AppPalette.textSecondary,
          label: '等待组卷',
          note: '已收到智能组卷任务',
        );
      case AnalysisTaskStatus.analyzing:
        return (
          icon: Icons.auto_awesome_rounded,
          color: AppPalette.moodBlue,
          label: '正在组卷',
          note: 'AI 正在编排练习题、答案和打印讲义',
        );
      case AnalysisTaskStatus.completed:
        return (
          icon: Icons.check_circle_rounded,
          color: _queueSuccess,
          label: '试卷已生成',
          note: '点击打开试卷即可开始练习',
        );
      case AnalysisTaskStatus.failed:
        return (
          icon: Icons.error_outline_rounded,
          color: _queueDanger,
          label: '组卷失败',
          note: '可以重试生成智能试卷',
        );
    }
  }

  ({IconData icon, Color color, String label, String note})
      _lectureHandoutTaskStatus(
    BackgroundLectureHandoutTask task,
  ) {
    switch (task.status) {
      case AnalysisTaskStatus.queued:
        return (
          icon: Icons.schedule_rounded,
          color: AppPalette.textSecondary,
          label: '等待生成',
          note: '已收到讲义生成任务',
        );
      case AnalysisTaskStatus.analyzing:
        return (
          icon: Icons.auto_awesome_rounded,
          color: AppPalette.leaf,
          label: '正在生成',
          note: 'AI 正在整理知识讲义和打印版式',
        );
      case AnalysisTaskStatus.completed:
        return (
          icon: Icons.check_circle_rounded,
          color: _queueSuccess,
          label: '讲义已生成',
          note: '点击打开后可导出 PDF',
        );
      case AnalysisTaskStatus.failed:
        return (
          icon: Icons.error_outline_rounded,
          color: _queueDanger,
          label: '生成失败',
          note: '可以重试生成知识讲义',
        );
    }
  }

  ({IconData icon, Color color, String label, String note})
      _lectureVideoTaskStatus(
    BackgroundLectureVideoTask task,
  ) {
    switch (task.status) {
      case AnalysisTaskStatus.queued:
        return (
          icon: Icons.schedule_rounded,
          color: AppPalette.textSecondary,
          label: '等待生成',
          note: '已收到视频讲解任务',
        );
      case AnalysisTaskStatus.analyzing:
        return (
          icon: Icons.movie_creation_outlined,
          color: AppPalette.moodBlue,
          label: '正在生成',
          note: 'AI 正在生成知识点视频讲解',
        );
      case AnalysisTaskStatus.completed:
        return (
          icon: Icons.check_circle_rounded,
          color: _queueSuccess,
          label: '视频已生成',
          note: '点击打开视频讲解',
        );
      case AnalysisTaskStatus.failed:
        return (
          icon: Icons.error_outline_rounded,
          color: _queueDanger,
          label: '生成失败',
          note: '可以重试生成视频讲解',
        );
    }
  }

  String _formatTaskTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _openCompletedAnalysisTask(BackgroundAnalysisTask task) {
    final analysis = task.analysis;
    if (analysis == null) return;
    final store = AppStateScope.of(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ErrorEditScreen(
          imagePath: task.imagePath,
          initialText: task.extractedText,
          initialAnalysis: analysis,
          onArchived: () => store.dismissAnalysisTask(
            task.id,
            cleanupGeneratedContent: false,
          ),
          onAnalysisUpdated: (analysis) =>
              store.updateAnalysisTaskAnalysis(task.id, analysis),
        ),
      ),
    );
  }

  void _openCompletedPracticePaperTask(BackgroundPracticePaperTask task) {
    final paper = task.paper;
    if (paper == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PracticePaperEntryScreen(
          paper: paper,
          selectedSubjects: task.selectedSubjects,
          strategyLabel: paper.strategyLabel.isEmpty
              ? task.strategyLabel
              : paper.strategyLabel,
        ),
      ),
    );
  }

  void _openCompletedLectureHandoutTask(BackgroundLectureHandoutTask task) {
    final handout = task.handout;
    if (handout == null) return;
    final html = handout.printableHtml.trim();
    if (html.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前讲义没有可预览的打印内容')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HtmlArtifactPreviewScreen(
          title: handout.title.isEmpty ? '知识讲义' : handout.title,
          htmlContent: html,
          infoTitle: 'A4 知识讲义预览',
          infoNote: '这份讲义由 AI 助教后台生成，可用右上角 PDF 按钮导出。',
          scrollable: true,
          exportable: true,
        ),
      ),
    );
  }

  void _openCompletedLectureVideoTask(BackgroundLectureVideoTask task) {
    final video = task.video;
    if (video == null) return;
    final artifact = video.artifact;
    final content = _artifactContentMap(artifact['content']);
    final videoUrl = (content['video_url'] ??
            content['url'] ??
            artifact['video_url'] ??
            artifact['url'] ??
            '')
        .toString()
        .trim();
    final absoluteVideoUrl =
        (content['absolute_video_url'] ?? artifact['absolute_video_url'] ?? '')
            .toString()
            .trim();
    if (videoUrl.isEmpty && absoluteVideoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前视频还没有可播放地址')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManimVideoPreviewScreen(
          title: video.title.isEmpty ? '知识点视频讲解' : video.title,
          videoUrl: videoUrl,
          absoluteVideoUrl: absoluteVideoUrl,
          jobId: (content['job_id'] ?? '').toString(),
          jobStatus: (content['status'] ?? '').toString(),
          progress: int.tryParse((content['progress'] ?? '').toString()),
          message: (content['message'] ?? '').toString(),
          error: (content['error'] ?? '').toString(),
          diagnostics: _artifactContentMap(content['diagnostics']),
        ),
      ),
    );
  }

  Map<String, dynamic> _artifactContentMap(dynamic content) {
    if (content is Map<String, dynamic>) {
      return content;
    }
    if (content is Map) {
      return content.map((key, value) => MapEntry(key.toString(), value));
    }
    if (content is String) {
      try {
        final decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {
        return const {};
      }
    }
    return const {};
  }

  void _openFailedAnalysisTask(BackgroundAnalysisTask task) {
    final store = AppStateScope.of(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ErrorEditScreen(
          imagePath: task.imagePath,
          initialText: task.extractedText,
          onArchived: () => store.dismissAnalysisTask(
            task.id,
            cleanupGeneratedContent: false,
          ),
          onAnalysisUpdated: (analysis) =>
              store.updateAnalysisTaskAnalysis(task.id, analysis),
        ),
      ),
    );
  }

  void _openWaitingAnalysisTask(BackgroundAnalysisTask task) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalysisTaskWaitingScreen(taskId: task.id),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        requestFullMetadata: false,
      );
      if (!mounted || image == null) return;
      Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => ErrorPreviewScreen(imagePath: image.path)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('图片选择失败：$error')),
      );
    }
  }

  void _showAddActionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 34),
          decoration: const BoxDecoration(
            color: AppPalette.paper,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppPalette.textSecondary.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                _sheetAction(
                  icon: Icons.camera_alt_rounded,
                  title: '拍照录入',
                  subtitle: '拍一张题目照片，自动识别进入预览。',
                  filled: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 12),
                _sheetAction(
                  icon: Icons.photo_library_rounded,
                  title: '从相册导入',
                  subtitle: '选择已有试卷或截图导入错题流转。',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 12),
                _sheetAction(
                  icon: Icons.edit_note_rounded,
                  title: '手动记录',
                  subtitle: '适合录入公式题、主观题和补充笔记。',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ManualEntryScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    final background = filled ? AppPalette.mint : AppPalette.cream;
    const titleColor = AppPalette.textPrimary;
    final subtitleColor = filled
        ? AppPalette.textPrimary.withOpacity(0.72)
        : AppPalette.textSecondary;
    const iconColor = AppPalette.textPrimary;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: filled
                      ? AppPalette.paper.withOpacity(0.68)
                      : AppPalette.peach.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: subtitleColor),
            ],
          ),
        ),
      ),
    );
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
      child: Icon(Icons.person_rounded,
          color: AppPalette.textPrimary, size: iconSize),
    );
  }
}

enum _FlatHomeIconKind { archive, quiz, capture, assistant }

class _FlatHomeIcon extends StatelessWidget {
  const _FlatHomeIcon({required this.kind, this.size = 54});

  final _FlatHomeIconKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _FlatHomeIconPainter(kind),
    );
  }
}

class _FlatHomeIconPainter extends CustomPainter {
  const _FlatHomeIconPainter(this.kind);

  final _FlatHomeIconKind kind;

  static const _ink = AppPalette.inkBlue;
  static const _paper = AppPalette.paper;
  static const _mint = AppPalette.mint;
  static const _peach = AppPalette.peach;
  static const _blue = AppPalette.moodBlue;
  static const _coral = AppPalette.coral;
  static const _captureAccent = Color(0xFFFFC25F);
  static const _captureLens = Color(0xFFFF9F8A);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);

    final fill = Paint()..style = PaintingStyle.fill;

    fill.color = _baseFor(kind);
    canvas.drawRRect(_rr(s, 0.08, 0.08, 0.84, 0.84, 0.24), fill);

    fill.color = _accentFor(kind);
    canvas.drawCircle(Offset(s * 0.76, s * 0.24), s * 0.105, fill);

    switch (kind) {
      case _FlatHomeIconKind.archive:
        _paintArchive(canvas, s, fill);
      case _FlatHomeIconKind.quiz:
        _paintQuiz(canvas, s, fill);
      case _FlatHomeIconKind.capture:
        _paintCapture(canvas, s, fill);
      case _FlatHomeIconKind.assistant:
        _paintAssistant(canvas, s, fill);
    }

    canvas.restore();
  }

  Color _baseFor(_FlatHomeIconKind kind) {
    return switch (kind) {
      _FlatHomeIconKind.archive => const Color(0xFFFFFBF3),
      _FlatHomeIconKind.quiz => const Color(0xFFFFF0D7),
      _FlatHomeIconKind.capture => const Color(0xFFEAF0FF),
      _FlatHomeIconKind.assistant => const Color(0xFFFFF3DF),
    };
  }

  Color _accentFor(_FlatHomeIconKind kind) {
    return switch (kind) {
      _FlatHomeIconKind.archive => _peach,
      _FlatHomeIconKind.quiz => _coral.withAlpha(92),
      _FlatHomeIconKind.capture => _captureAccent,
      _FlatHomeIconKind.assistant => _peach,
    };
  }

  RRect _rr(
    double s,
    double x,
    double y,
    double width,
    double height,
    double radius,
  ) {
    return RRect.fromRectAndRadius(
      Rect.fromLTWH(s * x, s * y, s * width, s * height),
      Radius.circular(s * radius),
    );
  }

  void _paintArchive(Canvas canvas, double s, Paint fill) {
    fill.color = _ink;
    canvas.drawRRect(
      _rr(s, 0.22, 0.36, 0.56, 0.34, 0.09),
      fill,
    );
    fill.color = _mint;
    canvas.drawRRect(
      _rr(s, 0.25, 0.29, 0.29, 0.15, 0.06),
      fill,
    );

    fill.color = _paper;
    canvas.drawRRect(
      _rr(s, 0.30, 0.48, 0.40, 0.06, 0.03),
      fill,
    );
    canvas.drawRRect(
      _rr(s, 0.30, 0.58, 0.27, 0.06, 0.03),
      fill,
    );
  }

  void _paintQuiz(Canvas canvas, double s, Paint fill) {
    fill.color = _paper;
    canvas.drawRRect(
      _rr(s, 0.30, 0.23, 0.40, 0.56, 0.08),
      fill,
    );

    fill.color = _coral;
    canvas.drawRRect(
      _rr(s, 0.39, 0.18, 0.22, 0.12, 0.045),
      fill,
    );

    fill.color = _ink;
    _drawCheck(canvas, s, 0.39, 0.40, fill);
    canvas.drawRRect(_rr(s, 0.50, 0.41, 0.15, 0.045, 0.022), fill);
    _drawCheck(canvas, s, 0.39, 0.56, fill);
    canvas.drawRRect(_rr(s, 0.50, 0.57, 0.13, 0.045, 0.022), fill);
  }

  void _paintCapture(Canvas canvas, double s, Paint fill) {
    fill.color = _blue;
    canvas.drawRRect(
      _rr(s, 0.22, 0.34, 0.56, 0.36, 0.10),
      fill,
    );
    fill.color = _blue;
    canvas.drawRRect(
      _rr(s, 0.33, 0.26, 0.22, 0.12, 0.045),
      fill,
    );
    fill.color = _paper;
    canvas.drawCircle(Offset(s * 0.50, s * 0.52), s * 0.13, fill);
    fill.color = _captureLens;
    canvas.drawCircle(Offset(s * 0.50, s * 0.52), s * 0.075, fill);
    fill.color = _paper;
    canvas.drawCircle(Offset(s * 0.67, s * 0.43), s * 0.032, fill);
  }

  void _paintAssistant(Canvas canvas, double s, Paint fill) {
    fill.color = _ink;
    canvas.drawRRect(
      _rr(s, 0.22, 0.30, 0.58, 0.38, 0.12),
      fill,
    );
    final tail = Path()
      ..moveTo(s * 0.36, s * 0.66)
      ..lineTo(s * 0.28, s * 0.78)
      ..lineTo(s * 0.52, s * 0.66)
      ..close();
    canvas.drawPath(tail, fill);

    fill.color = _paper;
    canvas.drawRRect(_rr(s, 0.34, 0.43, 0.34, 0.055, 0.026), fill);
    canvas.drawRRect(_rr(s, 0.34, 0.54, 0.24, 0.055, 0.026), fill);
  }

  void _drawCheck(
    Canvas canvas,
    double s,
    double x,
    double y,
    Paint fill,
  ) {
    final path = Path()
      ..moveTo(s * x, s * y)
      ..lineTo(s * (x + 0.035), s * (y + 0.035))
      ..lineTo(s * (x + 0.11), s * (y - 0.055))
      ..lineTo(s * (x + 0.14), s * (y - 0.025))
      ..lineTo(s * (x + 0.04), s * (y + 0.085))
      ..lineTo(s * (x - 0.03), s * (y + 0.015))
      ..close();
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant _FlatHomeIconPainter oldDelegate) {
    return oldDelegate.kind != kind;
  }
}

class _ActiveDownloadIndicator extends StatefulWidget {
  const _ActiveDownloadIndicator();

  @override
  State<_ActiveDownloadIndicator> createState() =>
      _ActiveDownloadIndicatorState();
}

class _ActiveDownloadIndicatorState extends State<_ActiveDownloadIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _dropAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _dropAnimation = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: -2, end: 3), weight: 50),
        TweenSequenceItem(tween: Tween(begin: 3, end: -2), weight: 50),
      ],
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 27,
      height: 27,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _controller,
            child: const CustomPaint(
              size: Size.square(27),
              painter: _DownloadRingPainter(color: AppPalette.moodBlue),
            ),
          ),
          AnimatedBuilder(
            animation: _dropAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _dropAnimation.value),
                child: child,
              );
            },
            child: const Icon(
              Icons.file_download_rounded,
              color: AppPalette.moodBlue,
              size: 17,
            ),
          ),
        ],
      ),
    );
  }
}

class AnalysisTaskWaitingScreen extends StatefulWidget {
  const AnalysisTaskWaitingScreen({
    super.key,
    required this.taskId,
  });

  final String taskId;

  @override
  State<AnalysisTaskWaitingScreen> createState() =>
      _AnalysisTaskWaitingScreenState();
}

class _AnalysisTaskWaitingScreenState extends State<AnalysisTaskWaitingScreen> {
  AppStore? _store;
  bool _isNavigating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextStore = AppStateScope.of(context);
    if (_store == nextStore) {
      return;
    }
    _store?.removeListener(_handleStoreChanged);
    _store = nextStore;
    _store?.addListener(_handleStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleStoreChanged());
  }

  @override
  void dispose() {
    _store?.removeListener(_handleStoreChanged);
    super.dispose();
  }

  void _handleStoreChanged() {
    if (!mounted || _isNavigating) {
      return;
    }
    final task = _taskForCurrentStore();
    if (task == null) {
      Navigator.of(context).maybePop();
      return;
    }
    if (task.status == AnalysisTaskStatus.completed && task.analysis != null) {
      _replaceWithEditScreen(task);
    } else if (task.status == AnalysisTaskStatus.failed) {
      _replaceWithEditScreen(task);
    }
  }

  void _replaceWithEditScreen(BackgroundAnalysisTask task) {
    final store = _store;
    if (store == null) return;
    final initialAnalysis =
        task.status == AnalysisTaskStatus.completed ? task.analysis : null;
    _isNavigating = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ErrorEditScreen(
          imagePath: task.imagePath,
          initialText: task.extractedText,
          initialAnalysis: initialAnalysis,
          onArchived: () => store.dismissAnalysisTask(
            task.id,
            cleanupGeneratedContent: false,
          ),
          onAnalysisUpdated: (analysis) =>
              store.updateAnalysisTaskAnalysis(task.id, analysis),
        ),
      ),
    );
  }

  BackgroundAnalysisTask? _taskForCurrentStore() {
    final store = _store;
    if (store == null) {
      return null;
    }
    for (final task in store.analysisTasks) {
      if (task.id == widget.taskId) {
        return task;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final task = _taskForCurrentStore();
    final isQueued = task?.status == AnalysisTaskStatus.queued;

    return Scaffold(
      backgroundColor: AppPalette.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppPalette.textPrimary),
        title: const Text(
          'AI 正在整理',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: AppSurface(
        topSafe: false,
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        child: Center(
          child: AppPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (task != null) ...[
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.34,
                    ),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppPalette.kombuGreen,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppPalette.pastelGrey.withOpacity(0.08),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(task.imagePath),
                        width: double.infinity,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox(
                            height: 160,
                            child: Icon(
                              Icons.image_rounded,
                              color: AppPalette.textPrimary,
                              size: 42,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                const RoseThreeLoader(size: 142),
                const SizedBox(height: 24),
                Text(
                  isQueued ? '正在排队等待整理...' : '知芽 AI 正在深度分析题目...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  '识别题干、定位知识点、生成错因诊断和复习建议。完成后会自动进入确认入档页面。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppPalette.textSecondary,
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppPalette.almondCream.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isQueued ? '已加入后台队列' : '正在生成错题分析',
                    style: const TextStyle(
                      color: AppPalette.almondCream,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadRingPainter extends CustomPainter {
  const _DownloadRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.1;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      arcRect,
      -1.35,
      4.75,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DownloadRingPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
