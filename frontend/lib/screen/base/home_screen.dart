import 'dart:io';
import 'dart:ui';

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
import 'data_dashboard_screen.dart';
import 'error_archive_screen.dart';
import 'learning_plan_screen.dart';
import 'login_screen.dart';
import 'manual_entry_screen.dart';
import 'profile_screen.dart';
import 'recycle_bin_screen.dart';
import 'settings_screen.dart';
import 'smart_quiz_screen.dart';
import 'smart_review_screen.dart';
import 'weakness_practice_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
      backgroundColor: AppPalette.night,
      extendBody: true,
      drawer: _buildDrawer(context, store),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppPalette.appBackground),
            ),
          ),
          Positioned.fill(
            child: Image.asset(
              'assets/images/splash_bg.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              excludeFromSemantics: true,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppPalette.night.withValues(alpha: 0.42),
                    AppPalette.pineGreen.withValues(alpha: 0.36),
                    AppPalette.night.withValues(alpha: 0.76),
                  ],
                ),
              ),
            ),
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
    if (store.totalErrors == 0) {
      return _buildEmptyHomeTab(context, store);
    }

    final featuredReview = store.smartReviewQueue.isNotEmpty
        ? store.smartReviewQueue.first
        : store.errors.first;
    final topPadding = MediaQuery.of(context).padding.top + 38;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, topPadding, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHomeHeader(context, store),
          const SizedBox(height: 10),
          Text(
            '\u4eca\u5929\u8fd8\u6709 ${store.pendingReviewCount} \u9053\u9519\u9898\u5f85\u590d\u4e60\uff0c\u4f18\u5148\u8865\u5f3a\u300c${store.weakestSubject}\u300d\u3002',
            style: const TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 36) / 4;
              return Wrap(
                spacing: 12,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _quickAction(
                      icon: Icons.camera_alt_rounded,
                      label: '\u62cd\u7167\u5f55\u5165',
                      onTap: () => _showAddActionSheet(context),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _quickAction(
                      icon: Icons.bolt_rounded,
                      label: '\u667a\u80fd\u7ec4\u5377',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SmartQuizScreen()),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _quickAction(
                      icon: Icons.folder_special_rounded,
                      label: '\u9519\u9898\u6863\u6848',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ErrorArchiveScreen()),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _quickAction(
                      icon: Icons.event_note_rounded,
                      label: '\u5b66\u4e60\u8ba1\u5212',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const LearningPlanScreen()),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          _featureCard(
            title: '\u4eca\u65e5\u667a\u80fd\u590d\u4e60',
            subtitle:
                '\u7cfb\u7edf\u5df2\u7ecf\u4e3a\u4f60\u6311\u51fa ${store.smartReviewQueue.length} \u9053\u4f18\u5148\u9519\u9898\uff0c\u5148\u56de\u6536\u300c${featuredReview.topic}\u300d\u3002',
            tag: '${store.pendingReviewCount} \u9053\u5f85\u590d\u4e60',
            icon: Icons.menu_book_rounded,
            actionLabel: '\u5f00\u59cb\u590d\u4e60',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SmartReviewScreen()),
            ),
          ),
          const SizedBox(height: 18),
          _featureCard(
            title: '\u653b\u514b\u8584\u5f31\u70b9',
            subtitle:
                '\u5f53\u524d\u6700\u9700\u8981\u8865\u5f3a\u7684\u662f\u300c${store.weakestSubject}\u300d\uff0c\u5df2\u8986\u76d6 ${store.knowledgePointCount} \u4e2a\u8003\u70b9\u3002',
            tag: '\u8fde\u7eed\u5b66\u4e60 ${store.studyStreakDays} \u5929',
            icon: Icons.psychology_rounded,
            actionLabel: '\u53bb\u8bad\u7ec3',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WeaknessPracticeScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHomeTab(BuildContext context, AppStore store) {
    final topPadding = MediaQuery.of(context).padding.top + 38;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, topPadding, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHomeHeader(context, store),
          const SizedBox(height: 10),
          const Text(
            '你的错题档案还是空的。先录入第一道题，后面的复习、学科拓展和数据统计才会慢慢长出来。',
            style: TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 36) / 4;
              return Wrap(
                spacing: 12,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _quickAction(
                      icon: Icons.camera_alt_rounded,
                      label: '拍照录入',
                      onTap: () => _showAddActionSheet(context),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _quickAction(
                      icon: Icons.bolt_rounded,
                      label: '智能组卷',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SmartQuizScreen()),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _quickAction(
                      icon: Icons.folder_special_rounded,
                      label: '错题档案',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ErrorArchiveScreen()),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _quickAction(
                      icon: Icons.event_note_rounded,
                      label: '学习计划',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const LearningPlanScreen()),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          _featureCard(
            title: '开始建立第一份错题档案',
            subtitle: '拍题或手动录入都可以。只要有了第一道题，首页就会自动长出复习队列、收藏和学科扩展。',
            tag: '当前 0 道错题',
            icon: Icons.auto_stories_rounded,
            actionLabel: '去录入',
            onTap: () => _showAddActionSheet(context),
          ),
          const SizedBox(height: 18),
          _featureCard(
            title: '先搭好学习节奏',
            subtitle: '现在可以先看计划页，但真正的复习推荐会在你录入错题之后按数据生成。',
            tag: '空白起点',
            icon: Icons.insights_rounded,
            actionLabel: '查看计划',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LearningPlanScreen()),
            ),
          ),
        ],
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
              color: AppPalette.textPrimary,
              fontSize: 46,
              fontWeight: FontWeight.w800,
              height: 1.04,
            ),
          ),
        ),
        if (store.hasAnalysisTasks) ...[
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
            Image.asset(
              'assets/images/auth_bg.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              excludeFromSemantics: true,
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppPalette.kombuGreen.withValues(alpha: 0.90),
                      AppPalette.pineGreen.withValues(alpha: 0.86),
                    ],
                  ),
                ),
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
                                color: AppPalette.pastelGrey
                                    .withValues(alpha: 0.18)),
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
                                  color: AppPalette.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${store.userId}',
                                style: const TextStyle(
                                  color: AppPalette.textSecondary,
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
                        color: AppPalette.almondCream.withValues(alpha: 0.12),
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
                      color: AppPalette.pastelGrey.withValues(alpha: 0.06),
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
                            icon: Icons.restore_from_trash_rounded,
                            title: '\u9519\u9898\u56de\u6536\u7ad9',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const RecycleBinScreen()),
                            ),
                          ),
                          _drawerItem(
                            context,
                            icon: Icons.insert_chart_outlined_rounded,
                            title: '\u5b66\u4e60\u6570\u636e\u770b\u677f',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const DataDashboardScreen()),
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
                    _drawerItem(
                      context,
                      icon: Icons.logout_rounded,
                      title: '\u9000\u51fa\u767b\u5f55',
                      isDanger: true,
                      onTap: () async {
                        await store.signOutUser();
                        if (!context.mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      },
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
            color: AppPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style:
                const TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
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
            ? Colors.redAccent.withValues(alpha: 0.10)
            : AppPalette.pastelGrey.withValues(alpha: 0.08),
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
                    color: isDanger ? Colors.redAccent : AppPalette.matchaMist),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color:
                          isDanger ? Colors.redAccent : AppPalette.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!isDanger)
                  const Icon(Icons.chevron_right_rounded,
                      color: AppPalette.textSecondary),
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
      color: const Color(0xFF1E211F),
      elevation: 18,
      shadowColor: Colors.black.withValues(alpha: 0.36),
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
    const selectedColor = Colors.white;
    const unselectedColor = Color(0xFF757575);
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
      elevation: 10,
      highlightElevation: 12,
      backgroundColor: const Color(0xFFFCD9A8),
      foregroundColor: const Color(0xFF121212),
      shape: const CircleBorder(),
      child: const Icon(Icons.add_rounded, size: 32),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppPalette.kombuGreen, AppPalette.pineGreen],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureCard({
    required String title,
    required String subtitle,
    required String tag,
    required IconData icon,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppPalette.pineGreen,
                AppPalette.kombuGreen,
                AppPalette.artichoke
              ],
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: AppPalette.almondCream,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppPalette.almondCream,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        actionLabel,
                        style: const TextStyle(
                          color: AppPalette.night,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppPalette.textPrimary, size: 44),
              ),
            ],
          ),
        ),
      ),
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
    final completedCount = store.completedAnalysisTaskCount;
    final failedCount = store.failedAnalysisTaskCount;
    final activeCount = store.activeAnalysisTaskCount;
    final totalCount = store.analysisTasks.length;
    final hasFailure = failedCount > 0;
    final hasCompleted = completedCount > 0;
    final hasActive = activeCount > 0;
    final tint = hasFailure
        ? Colors.redAccent
        : hasActive
            ? AppPalette.almondCream
            : hasCompleted
                ? AppPalette.matchaMist
                : AppPalette.almondCream;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showAnalysisQueueSheet(context),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppPalette.night.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: tint.withValues(alpha: 0.32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
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
                          : Icons.file_download_rounded,
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
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.76,
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: const BoxDecoration(
            color: AppPalette.night,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                      color: AppPalette.textSecondary.withValues(alpha: 0.22),
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
                        color: AppPalette.almondCream.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.file_download_rounded,
                        color: AppPalette.almondCream,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '\u540e\u53f0\u9519\u9898\u6574\u7406',
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
                  child: tasks.isEmpty
                      ? const Center(
                          child: Text(
                            '\u6682\u65e0\u540e\u53f0\u6574\u7406\u4efb\u52a1',
                            style: TextStyle(color: AppPalette.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: tasks.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildAnalysisTaskTile(
                              sheetContext,
                              store,
                              tasks[index],
                            );
                          },
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
    final active = store.activeAnalysisTaskCount;
    final completed = store.completedAnalysisTaskCount;
    final failed = store.failedAnalysisTaskCount;
    if (active > 0) {
      return '\u6b63\u5728\u6574\u7406 $active \u9053\uff0c$completed \u9053\u5f85\u786e\u8ba4';
    }
    if (failed > 0) {
      return '$failed \u9053\u9700\u8981\u91cd\u8bd5\uff0c$completed \u9053\u5f85\u786e\u8ba4';
    }
    if (completed > 0) {
      return '$completed \u9053\u5df2\u6574\u7406\u597d\uff0c\u7b49\u4f60\u786e\u8ba4\u5165\u6863';
    }
    return '\u62cd\u5b8c\u9898\u540e\u4f1a\u81ea\u52a8\u5728\u8fd9\u91cc\u6392\u961f';
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
          color: AppPalette.pastelGrey.withValues(alpha: 0.06),
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
                        color: AppPalette.pineGreen,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_rounded,
                          color: AppPalette.textPrimary,
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
                    Row(
                      children: [
                        Icon(status.icon, color: status.color, size: 17),
                        const SizedBox(width: 6),
                        Text(
                          status.label,
                          style: TextStyle(
                            color: status.color,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (task.isActive && queuePosition > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            queuePosition == 1 ? '当前执行' : '队列第 $queuePosition',
                            style: const TextStyle(
                              color: AppPalette.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          _formatTaskTime(task.createdAt),
                          style: const TextStyle(
                            color: AppPalette.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
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

  Widget _buildAnalysisTaskActions(
    BuildContext sheetContext,
    AppStore store,
    BackgroundAnalysisTask task,
  ) {
    if (task.status == AnalysisTaskStatus.completed && task.analysis != null) {
      return Row(
        children: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(sheetContext);
              _openCompletedAnalysisTask(task);
            },
            icon: const Icon(Icons.fact_check_rounded, size: 17),
            label: const Text('\u786e\u8ba4\u5165\u6863'),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.almondCream,
              padding: EdgeInsets.zero,
            ),
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

    if (task.status == AnalysisTaskStatus.failed) {
      return Row(
        children: [
          TextButton.icon(
            onPressed: () => store.retryAnalysisTask(task.id),
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('\u91cd\u8bd5'),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.almondCream,
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
            color: AppPalette.almondCream.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.file_download_rounded,
            color: AppPalette.almondCream,
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
          color: AppPalette.almondCream,
          label: '\u6b63\u5728\u6574\u7406',
          note:
              '\u6b63\u5728\u8bc6\u522b\u9898\u5e72\u5e76\u751f\u6210\u9519\u9898\u5206\u6790',
        );
      case AnalysisTaskStatus.completed:
        return (
          icon: Icons.check_circle_rounded,
          color: AppPalette.matchaMist,
          label: '\u5df2\u5b8c\u6210',
          note: '\u70b9\u51fb\u786e\u8ba4\u540e\u5c31\u80fd\u5165\u6863',
        );
      case AnalysisTaskStatus.failed:
        return (
          icon: Icons.error_outline_rounded,
          color: Colors.redAccent,
          label: '\u9700\u8981\u91cd\u8bd5',
          note:
              '\u8fd9\u9053\u9898\u6ca1\u6709\u4e22\uff0c\u53ef\u4ee5\u91cd\u8bd5\u6216\u624b\u52a8\u6574\u7406',
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
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);
    if (!mounted || image == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => ErrorPreviewScreen(imagePath: image.path)),
    );
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
            color: AppPalette.night,
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
                    color: AppPalette.textSecondary.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                _sheetAction(
                  icon: Icons.camera_alt_rounded,
                  title: '\u62cd\u7167\u5f55\u5165',
                  subtitle:
                      '\u62cd\u4e00\u5f20\u9898\u76ee\u7167\u7247\uff0c\u81ea\u52a8\u8bc6\u522b\u8fdb\u5165\u9884\u89c8\u3002',
                  filled: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 12),
                _sheetAction(
                  icon: Icons.photo_library_rounded,
                  title: '\u4ece\u76f8\u518c\u5bfc\u5165',
                  subtitle:
                      '\u9009\u62e9\u5df2\u6709\u8bd5\u5377\u6216\u622a\u56fe\u5bfc\u5165\u9519\u9898\u6d41\u8f6c\u3002',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 12),
                _sheetAction(
                  icon: Icons.edit_note_rounded,
                  title: '\u624b\u52a8\u8bb0\u5f55',
                  subtitle:
                      '\u9002\u5408\u5f55\u5165\u516c\u5f0f\u9898\u3001\u4e3b\u89c2\u9898\u548c\u8865\u5145\u7b14\u8bb0\u3002',
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
    final background = filled
        ? AppPalette.matchaMist
        : AppPalette.pastelGrey.withValues(alpha: 0.08);
    final titleColor = filled ? AppPalette.night : AppPalette.textPrimary;
    final subtitleColor = filled
        ? AppPalette.night.withValues(alpha: 0.70)
        : AppPalette.textSecondary;
    final iconColor = filled ? AppPalette.night : AppPalette.matchaMist;

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
                  color: iconColor.withValues(alpha: filled ? 0.14 : 0.12),
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
                      style: TextStyle(
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
              painter: _DownloadRingPainter(color: AppPalette.almondCream),
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
              color: AppPalette.almondCream,
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
      backgroundColor: AppPalette.night,
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
                        color: AppPalette.pastelGrey.withValues(alpha: 0.08),
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
                    color: AppPalette.almondCream.withValues(alpha: 0.10),
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
