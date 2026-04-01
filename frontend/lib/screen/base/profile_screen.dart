import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Color primaryGreen = const Color(0xFF70A88D);

  @override
  Widget build(BuildContext context) {
    // 动态获取当前主题模式
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF1E2823) : const Color(0xFFF0F4F2);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF2C362F); // 深松木灰
    final subTextColor = isDarkMode ? Colors.white70 : Colors.black54;
    final cardColor = isDarkMode ? Colors.white12 : Colors.black.withOpacity(0.05);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        automaticallyImplyLeading: false, // 🌟 新增这一行，隐藏默认的返回箭头
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        // 既然没有返回键，iconTheme 也可以根据需要删去，这里暂时保留
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          '个人中心',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_note_rounded, color: textColor),
            onPressed: () {
              // TODO: 编辑个人资料
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // 1. 顶部用户档案区域
            Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    const CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.white24,
                      backgroundImage: NetworkImage('https://picsum.photos/200'), // 你的头像占位
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primaryGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: bgColor, width: 3),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Zander', // 你的名字
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: zerror_001',
                  style: TextStyle(fontSize: 14, color: subTextColor),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '🌱 学习就像种树，让错误再次发芽',
                    style: TextStyle(color: primaryGreen, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // 2. 核心学习数据横排看板
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatCard('累计录入', '128', '题', cardColor, textColor, subTextColor),
                _buildStatCard('坚持复习', '14', '天', cardColor, textColor, subTextColor),
                _buildStatCard('攻克考点', '32', '个', cardColor, textColor, subTextColor),
              ],
            ),
            const SizedBox(height: 32),

            // 3. 功能菜单列表
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildMenuItem(Icons.workspace_premium_rounded, '我的成就', textColor, subTextColor, hasNotification: true),
                  Divider(color: textColor.withOpacity(0.1), height: 1, indent: 56),
                  _buildMenuItem(Icons.flag_circle_rounded, '学习目标设定', textColor, subTextColor),
                  Divider(color: textColor.withOpacity(0.1), height: 1, indent: 56),
                  _buildMenuItem(Icons.favorite_rounded, '我的收藏', textColor, subTextColor),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. 第二组菜单
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildMenuItem(Icons.notifications_active_rounded, '消息通知', textColor, subTextColor),
                  Divider(color: textColor.withOpacity(0.1), height: 1, indent: 56),
                  _buildMenuItem(Icons.security_rounded, '隐私与安全', textColor, subTextColor),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 提取组件：数据统计小卡片
  Widget _buildStatCard(String title, String value, String unit, Color cardColor, Color textColor, Color subTextColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: subTextColor, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(width: 2),
                Text(unit, style: TextStyle(color: subTextColor, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 提取组件：菜单列表项
  Widget _buildMenuItem(IconData icon, String title, Color textColor, Color subTextColor, {bool hasNotification = false}) {
    return ListTile(
      leading: Icon(icon, color: primaryGreen, size: 26),
      title: Text(title, style: TextStyle(color: textColor, fontSize: 16)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasNotification)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
            ),
          Icon(Icons.arrow_forward_ios_rounded, color: subTextColor, size: 16),
        ],
      ),
      onTap: () {
        // TODO: 菜单点击跳转逻辑
      },
    );
  }
}