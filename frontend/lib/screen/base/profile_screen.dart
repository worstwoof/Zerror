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
    // 🌟 既然全局锁定了深色模式，直接写死深色色值，去掉冗余判断
    final Color textColor = Colors.white;
    final Color subTextColor = Colors.white70;
    final Color cardColor = Colors.white12;

    return Scaffold(
      // 🌟 1. Scaffold 背景设为透明，让底下的 Stack 显露出来
      backgroundColor: Colors.transparent,

      // 🌟 2. 关键属性：让 body 的内容延伸穿透到 AppBar 的背后
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent, // AppBar 完全透明
        elevation: 0,
        centerTitle: true,
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

      // 🌟 3. 使用 Stack 来铺设背景和内容
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 第一层：全屏背景图 (复用你在首页用的 background_dark.png)
          Image.asset(
            'assets/images/auth_bg.png',
            fit: BoxFit.cover,
          ),

          // 第二层：微微的暗色遮罩 (可选)。为了保证前景白色文字的清晰度，加一层极淡的黑膜
          Container(color: Colors.black.withOpacity(0.15)),

          // 第三层：滑动内容区。🌟 必须套上 SafeArea，防止头像顶进刘海屏里
          SafeArea(
            child: SingleChildScrollView(
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
                              // 边框颜色改用纯透明或半透明黑，因为背景不再是纯色了
                              border: Border.all(color: Colors.black26, width: 3),
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Zander',
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
          ),
        ],
      ),
    );
  }

  // 数据统计小卡片保持不变
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

  // 菜单列表项保持不变
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