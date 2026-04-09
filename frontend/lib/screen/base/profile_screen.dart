import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onOpenDrawer});

  final VoidCallback? onOpenDrawer;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Color primaryGreen = AppPalette.matchaMist;

  @override
  Widget build(BuildContext context) {
    const textColor = AppPalette.textPrimary;
    const subTextColor = AppPalette.textSecondary;
    final cardColor = AppPalette.pastelGrey.withValues(alpha: 0.08);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textColor),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.notes_rounded, color: textColor),
            onPressed: widget.onOpenDrawer,
          ),
        ),
        title: const Text('个人中心', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: textColor),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen()));
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: AppPalette.appBackground)),
          Image.asset('assets/images/auth_bg.png', fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppPalette.kombuGreen.withValues(alpha: 0.14),
                  AppPalette.night.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppPalette.almondCream.withValues(alpha: 0.35), width: 2),
                          boxShadow: [
                            BoxShadow(color: AppPalette.honeyOrange.withValues(alpha: 0.14), blurRadius: 14, spreadRadius: 2),
                          ],
                        ),
                        child: const CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.black26,
                          backgroundImage: NetworkImage('https://picsum.photos/200'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Zander', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 4),
                      const Text('ID: zerror_001', style: TextStyle(fontSize: 14, color: subTextColor)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppPalette.almondCream.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '学习就像种树，让错误重新长出理解',
                          style: TextStyle(color: primaryGreen, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatCard('累计录入', '128', '题', cardColor, textColor, subTextColor),
                      _buildStatCard('坚持复习', '14', '天', cardColor, textColor, subTextColor),
                      _buildStatCard('攻克考点', '32', '个', cardColor, textColor, subTextColor),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildMenuGroup(cardColor, [
                    _buildMenuItem(Icons.workspace_premium_rounded, '我的成就', textColor, subTextColor, hasNotification: true),
                    Divider(color: textColor.withValues(alpha: 0.1), height: 1, indent: 56),
                    _buildMenuItem(Icons.flag_circle_rounded, '学习目标设定', textColor, subTextColor),
                    Divider(color: textColor.withValues(alpha: 0.1), height: 1, indent: 56),
                    _buildMenuItem(Icons.favorite_rounded, '我的收藏', textColor, subTextColor),
                  ]),
                  const SizedBox(height: 24),
                  _buildMenuGroup(cardColor, [
                    _buildMenuItem(Icons.notifications_active_rounded, '消息通知', textColor, subTextColor),
                    Divider(color: textColor.withValues(alpha: 0.1), height: 1, indent: 56),
                    _buildMenuItem(Icons.security_rounded, '隐私与安全', textColor, subTextColor),
                  ]),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGroup(Color cardColor, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.laurelGreen.withValues(alpha: 0.12)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildStatCard(String title, String value, String unit, Color cardColor, Color textColor, Color subTextColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppPalette.laurelGreen.withValues(alpha: 0.12)),
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
      onTap: () {},
    );
  }
}
