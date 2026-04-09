import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'weakness_practice_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'data_dashboard_screen.dart';
import 'recycle_bin_screen.dart';
import 'settings_screen.dart';
import '../capture/error_preview_screen.dart';
import 'error_archive_screen.dart';
import 'smart_quiz_screen.dart';
import 'manual_entry_screen.dart';
import 'smart_review_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final Color bgDark = const Color(0xFF1E2823);
  final Color primaryGreen = const Color(0xFF70A88D);
  final Color btnDarkGreen = const Color(0xFF465E51);
  final Color currentTextColor = Colors.white;
  final Color currentSubTextColor = Colors.white70;

  int _currentIndex = 0;
  late PageController _pageController;

  late AnimationController _homeBtnController;
  late Animation<double> _homeBtnScale;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);

    _homeBtnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _homeBtnScale = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _homeBtnController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _homeBtnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      extendBody: true,

      // 🌟 全新升级的沉浸式侧边栏
      drawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.75, // 占屏幕 3/4 宽度
        backgroundColor: Colors.transparent, // 设为透明，让内部的 Stack 接管背景
        elevation: 20,
        child: ClipRRect(
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(32)), // 右侧大圆角
          child: Stack(
            children: [
              // 1. 全局暗调植物背景
              Positioned.fill(child: Image.asset('assets/images/auth_bg.png', fit: BoxFit.cover)),
              // 2. 深色遮罩层，保证文字清晰度
              Positioned.fill(child: Container(color: const Color(0xFF161E1A).withValues(alpha: 0.85))),

              // 3. 侧边栏实际内容区
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 头部：个人名片区 ---
                    Padding(
                      padding: const EdgeInsets.only(left: 24, top: 40, right: 24, bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: primaryGreen.withValues(alpha: 0.3), width: 2),
                            ),
                            child: const CircleAvatar(
                              radius: 36,
                              backgroundColor: Colors.black26,
                              backgroundImage: NetworkImage('https://picsum.photos/200'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('Zander', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('ID: zerror_001', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
                          const SizedBox(height: 16),
                          // Slogan 徽章
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('🌱 让错误再次发芽', style: TextStyle(color: primaryGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                    Divider(color: Colors.white.withValues(alpha: 0.05), thickness: 1, height: 1),
                    const SizedBox(height: 16),

                    // --- 中间：菜单列表区 ---
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildModernDrawerItem(icon: Icons.history_rounded, title: '错题回收站', onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const RecycleBinScreen()));
                          }),
                          _buildModernDrawerItem(icon: Icons.insert_chart_outlined, title: '学习数据看板', onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const DataDashboardScreen()));
                          }),
                          _buildModernDrawerItem(icon: Icons.settings_outlined, title: '系统设置', onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SettingsScreen()));
                          }),
                          _buildModernDrawerItem(icon: Icons.help_outline_rounded, title: '帮助与反馈', onTap: () {}),
                        ],
                      ),
                    ),

                    // --- 底部：退出登录区 ---
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildModernDrawerItem(
                          icon: Icons.logout_rounded,
                          title: '退出登录',
                          isDestructive: true, // 开启警示色
                          onTap: () {
                            Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false);
                          }
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/images/background_dark.png', fit: BoxFit.cover)),
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildHomeTab(),
              const ProfileScreen(),
            ],
          ),
        ],
      ),

      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 32, right: 32, bottom: 24),
        child: SafeArea(
          child: _buildGlassmorphism(
            height: 64,
            borderRadius: BorderRadius.circular(32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAnimatedNavIcon(index: 0, icon: Icons.home_rounded, controller: _homeBtnController, scaleAnimation: _homeBtnScale),
                GestureDetector(
                  onTap: () => _showAddActionSheet(context, bgDark, currentTextColor, primaryGreen),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: primaryGreen, shape: BoxShape.circle, boxShadow: [BoxShadow(color: primaryGreen.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))]),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                  ),
                ),
                _buildSimpleNavIcon(1, Icons.person_outline_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🌟 新增：现代化侧边栏气泡菜单项
  Widget _buildModernDrawerItem({required IconData icon, required String title, required VoidCallback onTap, bool isDestructive = false}) {
    final Color textColor = isDestructive ? Colors.redAccent : Colors.white;
    final Color iconColor = isDestructive ? Colors.redAccent : primaryGreen;
    final Color bgColor = isDestructive ? Colors.redAccent.withValues(alpha: 0.1) : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.pop(context); // 点击后自动收起侧边栏
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          splashColor: Colors.white.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(title, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500)),
                ),
                if (!isDestructive)
                  Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.2), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 导航栏及辅助 UI 构建代码保持不变 ---
  Widget _buildAnimatedNavIcon({required int index, required IconData icon, required AnimationController controller, required Animation<double> scaleAnimation}) {
    final bool isSelected = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => controller.forward(),
      onTapCancel: () => controller.reverse(),
      onTapUp: (_) { controller.reverse(); _onNavTapped(index); },
      child: Container(
        width: 60, alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(scale: scaleAnimation, child: Icon(icon, size: 28, color: isSelected ? primaryGreen : currentSubTextColor.withValues(alpha: 0.5))),
            const SizedBox(height: 4),
            AnimatedOpacity(duration: const Duration(milliseconds: 200), opacity: isSelected ? 1.0 : 0.0, child: Container(width: 4, height: 4, decoration: BoxDecoration(color: primaryGreen, shape: BoxShape.circle, boxShadow: [BoxShadow(color: primaryGreen, blurRadius: 4)]))),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleNavIcon(int index, IconData icon) {
    final bool isSelected = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onNavTapped(index),
      child: Container(
        width: 60, alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: isSelected ? primaryGreen : currentSubTextColor.withValues(alpha: 0.5)),
            const SizedBox(height: 4),
            AnimatedOpacity(duration: const Duration(milliseconds: 200), opacity: isSelected ? 1.0 : 0.0, child: Container(width: 4, height: 4, decoration: BoxDecoration(color: primaryGreen, shape: BoxShape.circle, boxShadow: [BoxShadow(color: primaryGreen, blurRadius: 4)]))),
          ],
        ),
      ),
    );
  }

  void _onNavTapped(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(index, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
  }

  Widget _buildGlassmorphism({required Widget child, double? width, double? height, BorderRadiusGeometry? borderRadius}) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: width, height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF121A16).withValues(alpha: 0.6),
            borderRadius: borderRadius ?? BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
          ),
          child: child,
        ),
      ),
    );
  }

  // ==================== 主页 UI 构建 ====================
  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
          left: 24.0,
          right: 24.0,
          top: MediaQuery.of(context).padding.top + 40.0,
          bottom: 120.0
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('欢迎回来，Zerror', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: currentTextColor, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text('今天准备攻克哪些知识盲区？', style: TextStyle(fontSize: 18, color: currentSubTextColor)),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQuickActionItem(Icons.camera_alt_rounded, '拍照录入', currentTextColor, onTap: () { _showAddActionSheet(context, bgDark, currentTextColor, primaryGreen); }),
              _buildQuickActionItem(Icons.bolt_rounded, '智能组卷', currentTextColor, onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const SmartQuizScreen())); }),
              _buildQuickActionItem(Icons.folder_special_rounded, '错题档案', currentTextColor, onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const ErrorArchiveScreen())); }),
              _buildQuickActionItem(Icons.account_tree_rounded, '知识图谱', currentTextColor, onTap: () {}),
            ],
          ),
          const SizedBox(height: 40),
          _buildTaskCard(
              title: '今日智能复习', subtitle: '根据艾宾浩斯记忆曲线，\n今天有 15 道错题需要巩固。', illustrationIcon: Icons.menu_book_rounded, btnText: '开始复习',
              onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const SmartReviewScreen())); }
          ),
          const SizedBox(height: 24),
          _buildTaskCard(
              title: '攻克薄弱点', subtitle: 'AI 分析发现「线性代数」\n是你近期的主要丢分项。', illustrationIcon: Icons.psychology_rounded, btnText: '去练练',
              onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const WeaknessPracticeScreen())); }
          ),
        ],
      ),
    );
  }

  // --- 卡片与底部弹窗代码保持不变 ---
  Widget _buildQuickActionItem(IconData iconData, String label, Color textColor, {VoidCallback? onTap}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap, borderRadius: BorderRadius.circular(22), highlightColor: Colors.white.withValues(alpha: 0.2), splashColor: Colors.white.withValues(alpha: 0.1),
            child: Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [primaryGreen.withValues(alpha: 0.95), primaryGreen]),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                  BoxShadow(color: Colors.white.withValues(alpha: 0.15), blurRadius: 0, spreadRadius: 1, offset: const Offset(0, 1)),
                ],
              ),
              child: Center(child: Icon(iconData, color: Colors.white, size: 32)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildTaskCard({required String title, required String subtitle, required IconData illustrationIcon, required String btnText, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(24), highlightColor: Colors.white.withValues(alpha: 0.1), splashColor: Colors.white.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [primaryGreen.withValues(alpha: 0.9), primaryGreen]),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 6)),
              BoxShadow(color: Colors.white.withValues(alpha: 0.15), blurRadius: 0, spreadRadius: 1, offset: const Offset(0, 1)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 12),
                    Text(subtitle, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.white70)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: onTap, icon: Text(btnText, style: const TextStyle(fontSize: 14)), label: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      style: ElevatedButton.styleFrom(backgroundColor: btnDarkGreen, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.24)), child: Icon(illustrationIcon, size: 60, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: source);
      if (image != null && context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (context) => ErrorPreviewScreen(imagePath: image.path)));
    } catch (e) { debugPrint('获取图片失败: $e'); }
  }

  void _showAddActionSheet(BuildContext context, Color bgColor, Color textColor, Color primaryColor) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.only(top: 24, bottom: 40, left: 24, right: 24),
        decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: textColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2))),
            Text('收录新错题', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildBottomSheetButton(icon: Icons.camera_alt_rounded, title: '拍照录入', subtitle: '智能 OCR 提取题目与解答', bgColor: primaryColor, textColor: Colors.white, iconColor: Colors.white, onTap: () { Navigator.pop(sheetContext); _pickImage(context, ImageSource.camera); }),
            const SizedBox(height: 16),
            _buildBottomSheetButton(icon: Icons.photo_library_rounded, title: '从相册导入', subtitle: '选择已有的试卷或截图', bgColor: textColor.withValues(alpha: 0.05), textColor: textColor, iconColor: primaryColor, onTap: () { Navigator.pop(sheetContext); _pickImage(context, ImageSource.gallery); }),
            const SizedBox(height: 16),
            _buildBottomSheetButton(
              icon: Icons.edit_note_rounded,
              title: '手动记录',
              subtitle: '支持 LaTeX 数学公式输入',
              bgColor: textColor.withValues(alpha: 0.05),
              textColor: textColor,
              iconColor: primaryColor,
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManualEntryScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheetButton({required IconData icon, required String title, required String subtitle, required Color bgColor, required Color textColor, required Color iconColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 24)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 12))])),
            Icon(Icons.chevron_right_rounded, color: textColor.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}