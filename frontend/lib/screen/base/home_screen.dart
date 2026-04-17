import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_state.dart';
import '../../core/app_ui.dart';
import '../../core/media_utils.dart';
import '../../core/theme.dart';
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
              'assets/images/background_dark.png',
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
                    AppPalette.matchaMist.withValues(alpha: 0.05),
                    AppPalette.pineGreen.withValues(alpha: 0.10),
                    AppPalette.night.withValues(alpha: 0.52),
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
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(28, 0, 28, 22),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                color: AppPalette.kombuGreen.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppPalette.pastelGrey.withValues(alpha: 0.10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(index: 0, icon: Icons.home_rounded, label: '\u9996\u9875'),
                  GestureDetector(
                    onTap: () => _showAddActionSheet(context),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppPalette.honeyOrange, AppPalette.almondCream],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppPalette.honeyOrange.withValues(alpha: 0.28),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add_rounded, color: AppPalette.night, size: 28),
                    ),
                  ),
                  _buildNavItem(index: 1, icon: Icons.person_rounded, label: '\u6211\u7684'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context, AppStore store) {
    if (store.totalErrors == 0) {
      return _buildEmptyHomeTab(context, store);
    }

    final featuredReview = store.smartReviewQueue.isNotEmpty
        ? store.smartReviewQueue.first
        : store.errors.first;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 38, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\u6b22\u8fce\u56de\u6765\uff0c${store.userName}',
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 38,
              fontWeight: FontWeight.w700,
              height: 1.12,
            ),
          ),
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
                        MaterialPageRoute(builder: (_) => const SmartQuizScreen()),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _quickAction(
                      icon: Icons.folder_special_rounded,
                      label: '\u9519\u9898\u6863\u6848',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ErrorArchiveScreen()),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _quickAction(
                      icon: Icons.event_note_rounded,
                      label: '\u5b66\u4e60\u8ba1\u5212',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LearningPlanScreen()),
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
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 38, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '欢迎回来，${store.userName}',
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 38,
              fontWeight: FontWeight.w700,
              height: 1.12,
            ),
          ),
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
                        MaterialPageRoute(builder: (_) => const SmartQuizScreen()),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _quickAction(
                      icon: Icons.folder_special_rounded,
                      label: '错题档案',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ErrorArchiveScreen()),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _quickAction(
                      icon: Icons.event_note_rounded,
                      label: '学习计划',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LearningPlanScreen()),
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
                            border: Border.all(color: AppPalette.pastelGrey.withValues(alpha: 0.18)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      color: AppPalette.pastelGrey.withValues(alpha: 0.06),
                      child: Row(
                        children: [
                          Expanded(child: _drawerMetric('\u9519\u9898', '${store.totalErrors}')),
                          Expanded(child: _drawerMetric('\u6536\u85cf', '${store.favoriteCount}')),
                          Expanded(child: _drawerMetric('\u8fde\u7eed', '${store.studyStreakDays}\u5929')),
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
                              MaterialPageRoute(builder: (_) => const RecycleBinScreen()),
                            ),
                          ),
                          _drawerItem(
                            context,
                            icon: Icons.insert_chart_outlined_rounded,
                            title: '\u5b66\u4e60\u6570\u636e\u770b\u677f',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const DataDashboardScreen()),
                            ),
                          ),
                          _drawerItem(
                            context,
                            icon: Icons.settings_outlined,
                            title: '\u7cfb\u7edf\u8bbe\u7f6e',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
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
        Text(label, style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
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
                Icon(icon, color: isDanger ? Colors.redAccent : AppPalette.matchaMist),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isDanger ? Colors.redAccent : AppPalette.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!isDanger)
                  const Icon(Icons.chevron_right_rounded, color: AppPalette.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onNavTapped(index),
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected
                  ? AppPalette.matchaMist
                  : AppPalette.textSecondary.withValues(alpha: 0.72),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppPalette.textPrimary
                    : AppPalette.textSecondary.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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
              colors: [AppPalette.pineGreen, AppPalette.kombuGreen, AppPalette.artichoke],
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);
    if (!mounted || image == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ErrorPreviewScreen(imagePath: image.path)),
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
                  subtitle: '\u62cd\u4e00\u5f20\u9898\u76ee\u7167\u7247\uff0c\u81ea\u52a8\u8bc6\u522b\u8fdb\u5165\u9884\u89c8\u3002',
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
                  subtitle: '\u9009\u62e9\u5df2\u6709\u8bd5\u5377\u6216\u622a\u56fe\u5bfc\u5165\u9519\u9898\u6d41\u8f6c\u3002',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 12),
                _sheetAction(
                  icon: Icons.edit_note_rounded,
                  title: '\u624b\u52a8\u8bb0\u5f55',
                  subtitle: '\u9002\u5408\u5f55\u5165\u516c\u5f0f\u9898\u3001\u4e3b\u89c2\u9898\u548c\u8865\u5145\u7b14\u8bb0\u3002',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ManualEntryScreen()),
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
    final background =
        filled ? AppPalette.matchaMist : AppPalette.pastelGrey.withValues(alpha: 0.08);
    final titleColor = filled ? AppPalette.night : AppPalette.textPrimary;
    final subtitleColor =
        filled ? AppPalette.night.withValues(alpha: 0.70) : AppPalette.textSecondary;
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
      child: Icon(Icons.person_rounded, color: AppPalette.textPrimary, size: iconSize),
    );
  }

  Widget _ambientBlob(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color, blurRadius: 120, spreadRadius: 12)],
        ),
      ),
    );
  }
}
