import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import 'login_screen.dart';
import 'profile_screen.dart';
import 'data_dashboard_screen.dart';
import 'recycle_bin_screen.dart';
import 'settings_screen.dart';
import '../capture/error_preview_screen.dart';
import 'error_archive_screen.dart';
import 'smart_quiz_screen.dart';

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

  // 🌟 核心升级：为主页按钮单独配置的物理按压动画控制器
  late AnimationController _homeBtnController;
  late Animation<double> _homeBtnScale;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);

    // 弹簧物理按压动画
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

      // --- 侧边栏配置 (保持不变) ---
      drawer: Drawer(
        backgroundColor: bgDark,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: currentTextColor.withOpacity(0.12)))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Image.asset('assets/images/logo.png', width: 100),
                  const SizedBox(height: 5),
                  Text('让错误再次发芽', style: TextStyle(color: currentSubTextColor, fontSize: 14)),
                ],
              ),
            ),
            _buildDrawerItem(icon: Icons.history_rounded, title: '错题回收站', color: currentTextColor, onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const RecycleBinScreen()));
            }),
            _buildDrawerItem(icon: Icons.insert_chart_outlined, title: '学习数据看板', color: currentTextColor, onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const DataDashboardScreen()));
            }),
            _buildDrawerItem(icon: Icons.settings_outlined, title: '系统设置', color: currentTextColor, onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SettingsScreen()));
            }),
            Divider(color: currentTextColor.withOpacity(0.12), thickness: 1, height: 32),
            _buildDrawerItem(icon: Icons.help_outline_rounded, title: '帮助与反馈', color: currentTextColor, onTap: () {}),
            _buildDrawerItem(icon: Icons.logout_rounded, title: '退出登录', color: Colors.redAccent, onTap: () {
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false);
            }),
          ],
        ),
      ),

      // 🌟 全局唯一背景底图，保证翻页时背景不动，只有内容在滑动
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

      // 🌟 核心升级：更纤薄、具有高级交互的自定义底部导航栏
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 32, right: 32, bottom: 24),
        child: SafeArea(
          child: _buildGlassmorphism(
            height: 64, // 🌟 强制压低高度，变得修长纤薄
            borderRadius: BorderRadius.circular(32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 🌟 主页按钮：带物理缩放与呼吸点
                _buildAnimatedNavIcon(
                  index: 0,
                  icon: Icons.home_rounded,
                  controller: _homeBtnController,
                  scaleAnimation: _homeBtnScale,
                ),

                // 中间加号按钮
                GestureDetector(
                  onTap: () => _showAddActionSheet(context, bgDark, currentTextColor, primaryGreen),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: primaryGreen.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                  ),
                ),

                // 个人中心按钮
                _buildSimpleNavIcon(1, Icons.person_outline_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🌟 高级定制：带物理反馈的主页按钮
  Widget _buildAnimatedNavIcon({required int index, required IconData icon, required AnimationController controller, required Animation<double> scaleAnimation}) {
    final bool isSelected = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => controller.forward(),
      onTapCancel: () => controller.reverse(),
      onTapUp: (_) {
        controller.reverse();
        _onNavTapped(index);
      },
      child: Container(
        width: 60, // 扩大响应热区
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: scaleAnimation,
              child: Icon(icon, size: 28, color: isSelected ? primaryGreen : currentSubTextColor.withOpacity(0.5)),
            ),
            const SizedBox(height: 4),
            // 🌟 悬浮呼吸点：选中时在图标下方亮起一个精致的绿点
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isSelected ? 1.0 : 0.0,
              child: Container(
                width: 4, height: 4,
                decoration: BoxDecoration(
                  color: primaryGreen,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: primaryGreen, blurRadius: 4)],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // 普通导航按钮
  Widget _buildSimpleNavIcon(int index, IconData icon) {
    final bool isSelected = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onNavTapped(index),
      child: Container(
        width: 60,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: isSelected ? primaryGreen : currentSubTextColor.withOpacity(0.5)),
            const SizedBox(height: 4),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isSelected ? 1.0 : 0.0,
              child: Container(
                width: 4, height: 4,
                decoration: BoxDecoration(color: primaryGreen, shape: BoxShape.circle, boxShadow: [BoxShadow(color: primaryGreen, blurRadius: 4)]),
              ),
            )
          ],
        ),
      ),
    );
  }

  // 处理翻页逻辑
  void _onNavTapped(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  // 底部导航栏专属的玻璃拟态生成器
  Widget _buildGlassmorphism({required Widget child, double? width, double? height, BorderRadiusGeometry? borderRadius}) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: borderRadius ?? BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.5),
          ),
          child: child,
        ),
      ),
    );
  }

  // ==================== 主页 UI 构建 ====================

  Widget _buildHomeTab() {
    return Stack(
      children: [
        // 内容滑动区
        SingleChildScrollView(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 130.0, bottom: 120.0), // 顶部留出 130 空间给实心导航栏
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
              _buildTaskCard(title: '今日智能复习', subtitle: '根据艾宾浩斯记忆曲线，\n今天有 15 道错题需要巩固。', illustrationIcon: Icons.menu_book_rounded, btnText: '开始复习'),
              const SizedBox(height: 24),
              _buildTaskCard(title: '攻克薄弱点', subtitle: 'AI 分析发现「线性代数」\n是你近期的主要丢分项。', illustrationIcon: Icons.psychology_rounded, btnText: '去练练'),
            ],
          ),
        ),

        // 🌟 全新设计：全宽沉浸式顶栏 (Full-width Solid Header)
        // 完全贴合顶部，去除了左右边距和圆角
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            // 自动适配刘海屏/状态栏高度，并增加下间距
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 12,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              // 比底层 bgDark (0xFF1E2823) 稍微亮一阶的颜色，显得有层次
              color: const Color(0xFF243029),
              boxShadow: [
                // 底部微阴影，当内容在下方滑动时产生空间感
                BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4)
                ),
              ],
              border: Border(
                // 底部增加一条极细的高光分割线，提升 UI 精致度
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.05),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 左侧菜单按钮
                Builder(
                  builder: (context) => IconButton(
                      icon: Icon(Icons.notes_rounded, color: currentTextColor, size: 28),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Scaffold.of(context).openDrawer()
                  ),
                ),

                // 中间 Logo
                Image.asset('assets/images/logo.png', height: 26, fit: BoxFit.contain),

                // 右侧头像
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryGreen.withOpacity(0.5), width: 1.5), // 头像外圈增加主题色微光描边
                  ),
                  child: const CircleAvatar(
                      radius: 15,
                      backgroundColor: Colors.white24,
                      backgroundImage: NetworkImage('https://picsum.photos/100')
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }


  // 快捷按钮 (保持你的实心质感设计)
  Widget _buildQuickActionItem(IconData iconData, String label, Color textColor, {VoidCallback? onTap}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            highlightColor: Colors.white.withOpacity(0.2),
            splashColor: Colors.white.withOpacity(0.1),
            child: Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [primaryGreen.withOpacity(0.95), primaryGreen]),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                  BoxShadow(color: Colors.white.withOpacity(0.15), blurRadius: 0, spreadRadius: 1, offset: const Offset(0, 1)),
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

  // 任务卡片 (保持你的实心质感设计)
  Widget _buildTaskCard({required String title, required String subtitle, required IconData illustrationIcon, required String btnText}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(24),
        highlightColor: Colors.white.withOpacity(0.1),
        splashColor: Colors.white.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [primaryGreen.withOpacity(0.9), primaryGreen]),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 6)),
              BoxShadow(color: Colors.white.withOpacity(0.15), blurRadius: 0, spreadRadius: 1, offset: const Offset(0, 1)),
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
                      onPressed: () {},
                      icon: Text(btnText, style: const TextStyle(fontSize: 14)),
                      label: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btnDarkGreen, foregroundColor: Colors.white, elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(height: 120, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24), child: Icon(illustrationIcon, size: 60, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 杂项方法 ---
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
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: textColor.withOpacity(0.1), borderRadius: BorderRadius.circular(2))),
            Text('收录新错题', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildBottomSheetButton(icon: Icons.camera_alt_rounded, title: '拍照录入', subtitle: '智能 OCR 提取题目与解答', bgColor: primaryColor, textColor: Colors.white, iconColor: Colors.white, onTap: () { Navigator.pop(sheetContext); _pickImage(context, ImageSource.camera); }),
            const SizedBox(height: 16),
            _buildBottomSheetButton(icon: Icons.photo_library_rounded, title: '从相册导入', subtitle: '选择已有的试卷或截图', bgColor: textColor.withOpacity(0.05), textColor: textColor, iconColor: primaryColor, onTap: () { Navigator.pop(sheetContext); _pickImage(context, ImageSource.gallery); }),
            const SizedBox(height: 16),
            _buildBottomSheetButton(icon: Icons.edit_note_rounded, title: '手动记录', subtitle: '支持 LaTeX 数学公式输入', bgColor: textColor.withOpacity(0.05), textColor: textColor, iconColor: primaryColor, onTap: () { Navigator.pop(sheetContext); }),
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
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 24)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12))])),
            Icon(Icons.chevron_right_rounded, color: textColor.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: color.withOpacity(0.8), size: 24),
      title: Text(title, style: TextStyle(color: color, fontSize: 16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
      onTap: () { Navigator.pop(context); onTap(); },
    );
  }
}