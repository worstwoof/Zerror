import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'data_dashboard_screen.dart'; // 🌟 引入数据看板页
import 'recycle_bin_screen.dart'; // 🌟 引入错题回收站页
import 'settings_screen.dart'; // 🌟 引入设置页
import 'dart:io'; // 🌟 用于处理文件路径
import 'package:image_picker/image_picker.dart'; // 🌟 引入相机/相册插件
import '../capture/error_preview_screen.dart'; // 🌟 引入预览页
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Color bgDark = const Color(0xFF1E2823);
  final Color bgLight = const Color(0xFFF0F4F2);
  final Color primaryGreen = const Color(0xFF70A88D);
  final Color btnDarkGreen = const Color(0xFF465E51);

  int _currentIndex = 0; // 控制当前显示哪个 Tab

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bool isDarkMode = brightness == Brightness.dark;

    final Color currentBgColor = isDarkMode ? bgDark : bgLight;
    final Color currentTextColor = isDarkMode ? Colors.white : Colors.black87;
    final Color currentSubTextColor = isDarkMode ? Colors.white70 : Colors.black54;

    // 将页面存入列表
    final List<Widget> pages = [
      _buildHomeTab(currentTextColor, currentSubTextColor, isDarkMode), // 第 0 页：主页
      _buildAddTab(currentTextColor),                                   // 第 1 页：录入 (占位)
      const ProfileScreen(),                                            // 第 2 页：个人中心
    ];

    return Scaffold(
      backgroundColor: currentBgColor,

      // --- 侧边栏配置 ---
      drawer: Drawer(
        backgroundColor: currentBgColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: currentBgColor,
                border: Border(bottom: BorderSide(color: currentTextColor.withOpacity(0.12))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 100,
                    color: isDarkMode ? null : currentTextColor,
                  ),
                  const SizedBox(height: 5),
                  Text('让错误再次发芽', style: TextStyle(color: currentSubTextColor, fontSize: 14)),
                ],
              ),
            ),

            // 🌟 删除了“个人中心”，直接从错题回收站开始
            _buildDrawerItem(
                icon: Icons.history_rounded,
                title: '错题回收站',
                color: currentTextColor,
                onTap: () {
                  // 🌟 跳转到错题回收站页面
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const RecycleBinScreen()),
                  );
                }
            ),
            _buildDrawerItem(
                icon: Icons.insert_chart_outlined,
                title: '学习数据看板',
                color: currentTextColor,
                onTap: () {
                  // 跳转到数据看板页面
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const DataDashboardScreen()),
                  );
                }
            ),
            _buildDrawerItem(
                icon: Icons.settings_outlined,
                title: '系统设置',
                color: currentTextColor,
                onTap: () {
                  // 🌟 使用 Navigator.push 跳转到设置页
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                }
            ),

            Divider(color: currentTextColor.withOpacity(0.12), thickness: 1, height: 32),

            _buildDrawerItem(icon: Icons.help_outline_rounded, title: '帮助与反馈', color: currentTextColor, onTap: () {}),
            _buildDrawerItem(icon: Icons.logout_rounded, title: '退出登录', color: Colors.redAccent, onTap: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (Route<dynamic> route) => false,
              );
            }
            ),
          ],
        ),
      ),

      // 使用 IndexedStack 保持页面滑动状态
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),

      // 底部导航栏
      bottomNavigationBar: Theme(
        data: ThemeData(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          backgroundColor: currentBgColor,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,

          selectedItemColor: currentTextColor,
          unselectedItemColor: currentSubTextColor.withOpacity(0.38),
          showSelectedLabels: false,
          showUnselectedLabels: false,

          onTap: (index) {
            if (index == 1) {
              // 点击加号，弹出精美的底部录入菜单
              _showAddActionSheet(context, currentBgColor, currentTextColor, primaryGreen);
            } else {
              // 点击首页(0) 或 个人中心(2)，直接切换 IndexedStack 的索引
              setState(() { _currentIndex = index; });
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded, size: 28), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline_rounded, size: 28), label: 'Add'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded, size: 28), label: 'Profile'),
          ],
        ),
      ),
    );
  }
  // 🌟 新增：调用相机/相册的核心逻辑
  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      // 呼叫系统相机或相册
      final XFile? image = await picker.pickImage(source: source);

      if (image != null) {
        if (!context.mounted) return; // 确保页面还在

        // 成功获取图片后，跳转到预览页
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ErrorPreviewScreen(imagePath: image.path),
          ),
        );
      }
    } catch (e) {
      debugPrint('获取图片失败: $e');
    }
  }
// 🌟 新增：底部弹出的录入动作菜单
  void _showAddActionSheet(BuildContext context, Color bgColor, Color textColor, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // 透明背景以显示圆角
      isScrollControlled: true, // 允许自适应高度
      builder: (context) {
        return Container(
          padding: const EdgeInsets.only(top: 24, bottom: 40, left: 24, right: 24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // 高度包裹内容
            children: [
              // 顶部小滑块指示器
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                '收录新错题',
                style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // 选项 1：拍照录入
              _buildBottomSheetButton(
                icon: Icons.camera_alt_rounded,
                title: '拍照录入',
                subtitle: '智能 OCR 提取题目与解答',
                bgColor: primaryColor,
                textColor: Colors.white,
                iconColor: Colors.white,
                onTap: () {
                  Navigator.pop(context); // 先关闭底部弹窗
                  _pickImage(context, ImageSource.camera); // 🌟 呼叫相机
                },
              ),
              const SizedBox(height: 16),

              // 选项 2：相册导入
              _buildBottomSheetButton(
                icon: Icons.photo_library_rounded,
                title: '从相册导入',
                subtitle: '选择已有的试卷或截图',
                bgColor: textColor.withOpacity(0.05),
                textColor: textColor,
                iconColor: primaryColor,
                onTap: () {
                  Navigator.pop(context); // 先关闭底部弹窗
                  _pickImage(context, ImageSource.gallery); // 🌟 呼叫相册
                },
              ),
              const SizedBox(height: 16),

              // 选项 3：手动输入
              _buildBottomSheetButton(
                icon: Icons.edit_note_rounded,
                title: '手动记录',
                subtitle: '支持 LaTeX 数学公式输入',
                bgColor: textColor.withOpacity(0.05),
                textColor: textColor,
                iconColor: primaryColor,
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 跳转手动输入页
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 提取弹窗里的按钮组件
  Widget _buildBottomSheetButton({
    required IconData icon, required String title, required String subtitle,
    required Color bgColor, required Color textColor, required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textColor.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
  // ==================== 提取的页面组件 ====================

  Widget _buildHomeTab(Color currentTextColor, Color currentSubTextColor, bool isDarkMode) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            isDarkMode ? 'assets/images/background_dark.png' : 'assets/images/background_light.png',
            fit: BoxFit.cover,
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Builder(
                        builder: (context) {
                          return IconButton(
                            icon: Icon(Icons.notes_rounded, color: currentTextColor, size: 32),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () { Scaffold.of(context).openDrawer(); },
                          );
                        }
                    ),
                    Image.asset('assets/images/logo.png', height: 40, fit: BoxFit.contain, color: isDarkMode ? null : currentTextColor),
                    const CircleAvatar(radius: 20, backgroundColor: Colors.white24, backgroundImage: NetworkImage('https://picsum.photos/100')),
                  ],
                ),
                const SizedBox(height: 40),
                Text('欢迎回来，Zerror', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: currentTextColor, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Text('今天准备攻克哪些知识盲区？', style: TextStyle(fontSize: 18, color: currentSubTextColor)),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildQuickActionItem(Icons.camera_alt_rounded, '拍照录入', currentTextColor),
                    _buildQuickActionItem(Icons.bolt_rounded, '智能组卷', currentTextColor),
                    _buildQuickActionItem(Icons.pie_chart_rounded, '错因分析', currentTextColor),
                    _buildQuickActionItem(Icons.account_tree_rounded, '知识图谱', currentTextColor),
                  ],
                ),
                const SizedBox(height: 40),
                _buildTaskCard(title: '今日智能复习', subtitle: '根据艾宾浩斯记忆曲线，\n今天有 15 道错题需要巩固。', illustrationIcon: Icons.menu_book_rounded, btnText: '开始复习'),
                const SizedBox(height: 24),
                _buildTaskCard(title: '攻克薄弱点', subtitle: 'AI 分析发现「线性代数」\n是你近期的主要丢分项。', illustrationIcon: Icons.psychology_rounded, btnText: '去练练'),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddTab(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_rounded, size: 80, color: primaryGreen.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('错题录入功能开发中...', style: TextStyle(color: textColor, fontSize: 18)),
        ],
      ),
    );
  }

  // ==================== 提取的小组件 ====================

  Widget _buildDrawerItem({required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: color.withOpacity(0.8), size: 24),
      title: Text(title, style: TextStyle(color: color, fontSize: 16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget _buildQuickActionItem(IconData iconData, String label, Color textColor) {
    return Column(
      children: [
        Container(
          width: 70, height: 70,
          decoration: BoxDecoration(color: primaryGreen, borderRadius: BorderRadius.circular(20)),
          child: Icon(iconData, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 12),
        Text(label, style: TextStyle(color: textColor, fontSize: 14)),
      ],
    );
  }

  Widget _buildTaskCard({required String title, required String subtitle, required IconData illustrationIcon, required String btnText}) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(color: primaryGreen, borderRadius: BorderRadius.circular(24)),
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
            child: Container(
              height: 120, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
              child: Icon(illustrationIcon, size: 60, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}