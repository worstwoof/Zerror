import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Color primaryGreen = const Color(0xFF70A88D);

  @override
  Widget build(BuildContext context) {
    // 🌟 直接写死深色模式的颜色，去除了判断逻辑
    final bgColor = const Color(0xFF1E2823);
    final textColor = Colors.white;
    final cardColor = Colors.white12;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          '系统设置',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // 🌟 整个“外观与主题”模块已被完全移除，因为现在全局唯一深色模式

          // 小标题：关于
          Text(
            '关于',
            style: TextStyle(color: primaryGreen, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  title: Text('清除缓存', style: TextStyle(color: textColor)),
                  trailing: Text('128 MB', style: TextStyle(color: textColor.withOpacity(0.5))),
                  onTap: () {
                    // TODO: 清理缓存逻辑
                  },
                ),
                Divider(color: textColor.withOpacity(0.1), height: 1),
                ListTile(
                  title: Text('当前版本', style: TextStyle(color: textColor)),
                  trailing: Text('v1.0.0 (Beta)', style: TextStyle(color: textColor.withOpacity(0.5))),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}