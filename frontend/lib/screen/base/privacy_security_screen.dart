import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/app_ui.dart';
import '../../core/theme.dart';
import 'change_password_screen.dart';
import 'device_management_screen.dart';

class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: AppPalette.night,
      body: AppSurface(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 20),
            AppPanel(
              child: Column(
                children: [
                  _SecurityItem(
                    icon: Icons.lock_rounded,
                    title: '账户密码',
                    subtitle: '上次更新于 ${store.passwordUpdatedLabel}',
                    status: store.passwordSecurityStatus,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordScreen(),
                      ),
                    ),
                  ),
                  const Divider(color: Color(0x14EDE0D0), height: 24),
                  _SecurityItem(
                    icon: Icons.devices_rounded,
                    title: '登录设备',
                    subtitle: '当前共 ${store.activeDeviceCount} 台设备在线',
                    status: store.deviceSecurityStatus,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DeviceManagementScreen(),
                      ),
                    ),
                  ),
                  const Divider(color: Color(0x14EDE0D0), height: 24),
                  _SecurityItem(
                    icon: Icons.verified_user_rounded,
                    title: '隐私权限',
                    subtitle: store.permissionSummary,
                    status: '已配置',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const AppSectionTitle(
              title: '安全建议',
              subtitle: '保持账号和学习数据更稳定、更可控',
              icon: Icons.shield_moon_rounded,
            ),
            const SizedBox(height: 12),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < store.securitySuggestions.length; index++) ...[
                    _SuggestionRow(text: store.securitySuggestions[index]),
                    if (index != store.securitySuggestions.length - 1)
                      const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppPanel(
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChangePasswordScreen(),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.matchaMist,
                        foregroundColor: AppPalette.night,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        '更改密码',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DeviceManagementScreen(),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppPalette.textPrimary,
                        side: BorderSide(
                          color: AppPalette.pastelGrey.withValues(alpha: 0.18),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('管理设备'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        _BackButton(onTap: () => Navigator.pop(context)),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '隐私与安全',
                style: TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '统一管理账号、设备与权限状态',
                style: TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SecurityItem extends StatelessWidget {
  const _SecurityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppPalette.matchaMist.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: AppPalette.textPrimary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppPalette.almondCream.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status,
                style: const TextStyle(
                  color: AppPalette.almondCream,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(height: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppPalette.textSecondary,
                size: 15,
              ),
            ],
          ],
        ),
      ],
    );

    if (onTap == null) return row;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: row,
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(
            color: AppPalette.matchaMist,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppPalette.pastelGrey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppPalette.pastelGrey.withValues(alpha: 0.08)),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppPalette.textPrimary,
          size: 18,
        ),
      ),
    );
  }
}
