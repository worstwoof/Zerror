import 'package:flutter/material.dart';
import '../../main.dart'; // 🌟 引入 main.dart 里的 themeNotifier

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 核心颜色
  final Color primaryGreen = const Color(0xFF70A88D);

  @override
  Widget build(BuildContext context) {
    // 获取当前模式，以便调整 UI 颜色
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF1E2823) : const Color(0xFFF0F4F2);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final cardColor = isDarkMode ? Colors.white12 : Colors.black.withOpacity(0.05);

    return Scaffold(
      backgroundColor: bgColor,
      // 🌟 标准的原生顶部导航栏
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor), // 返回按钮颜色跟随主题
        title: Text(
          '系统设置',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // 小标题：外观
          Text(
            '外观与主题',
            style: TextStyle(color: primaryGreen, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // 🌟 设置卡片容器
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // 1. 跟随系统开关
                SwitchListTile(
                  activeColor: primaryGreen,
                  title: Text('跟随系统', style: TextStyle(color: textColor)),
                  subtitle: Text('开启后，App 将跟随手机系统的深浅色模式', style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12)),
                  value: themeNotifier.value == ThemeMode.system,
                  onChanged: (bool value) {
                    if (value) {
                      themeNotifier.value = ThemeMode.system;
                    } else {
                      // 如果关闭跟随系统，则固定为当前模式
                      themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
                    }
                  },
                ),

                Divider(color: textColor.withOpacity(0.1), height: 1),

                // 2. 深色模式手动开关 (仅在不跟随系统时可用)
                ListTile(
                  title: Text('深色模式', style: TextStyle(color: textColor)),
                  trailing: Switch(
                    activeColor: primaryGreen,
                    value: isDarkMode,
                    // 如果正在跟随系统，禁用这个手动开关
                    onChanged: themeNotifier.value == ThemeMode.system
                        ? null
                        : (bool value) {
                      themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // 小标题：其他
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