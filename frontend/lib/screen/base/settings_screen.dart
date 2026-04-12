import 'package:flutter/material.dart';

import '../../core/app_ui.dart';
import '../../core/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppPalette.textPrimary),
        title: const Text('系统设置', style: TextStyle(color: AppPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: AppSurface(
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
        child: ListView(
          children: [
            const AppSectionTitle(
              title: '存储与版本',
              subtitle: '清理空间，查看当前版本信息',
              icon: Icons.settings_suggest_rounded,
            ),
            const SizedBox(height: 16),
            AppPanel(
              child: Column(
                children: [
                  _settingTile('清理缓存', '128 MB', onTap: () {}),
                  Divider(color: AppPalette.pastelGrey.withValues(alpha: 0.08), height: 1),
                  _settingTile('当前版本', 'v1.0.0 (Beta)'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingTile(String title, String trailing, {VoidCallback? onTap}) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: AppPalette.textPrimary)),
      trailing: Text(trailing, style: const TextStyle(color: AppPalette.textSecondary)),
      onTap: onTap,
    );
  }
}
