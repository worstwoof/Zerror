import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/app_ui.dart';
import '../../core/theme.dart';

class DeviceManagementScreen extends StatelessWidget {
  const DeviceManagementScreen({super.key});

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
            _Header(
              title: '管理设备',
              subtitle: '查看当前登录中的设备状态',
              onBack: () => Navigator.pop(context),
            ),
            const SizedBox(height: 20),
            AppPanel(
              child: Row(
                children: [
                  Expanded(
                    child: _MetricChip(
                      label: '在线设备',
                      value: '${store.activeDeviceCount}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricChip(
                      label: '其他设备',
                      value: '${store.onlineOtherDeviceCount}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: store.devices.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == store.devices.length) {
                    return const AppPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '安全提醒',
                            style: TextStyle(
                              color: AppPalette.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            '如果发现异常设备，请及时退出登录并修改密码，避免学习数据在陌生环境中继续同步。',
                            style: TextStyle(
                              color: AppPalette.textSecondary,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final item = store.devices[index];
                  return _DeviceCard(
                    title: item.name,
                    subtitle: item.detail,
                    status: item.statusLabel,
                    highlight: item.isCurrent,
                    offline: !item.isOnline,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            AppPrimaryButton(
              label: store.onlineOtherDeviceCount > 0 ? '退出其他设备' : '其他设备均已退出',
              icon: Icons.logout_rounded,
              onPressed: () {
                final didChange = store.signOutOtherDevices();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(didChange ? '其他设备已安全退出' : '当前没有需要退出的其他设备'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppPalette.pastelGrey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.title,
    required this.subtitle,
    required this.status,
    this.highlight = false,
    this.offline = false,
  });

  final String title;
  final String subtitle;
  final String status;
  final bool highlight;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      color: highlight
          ? AppPalette.matchaMist.withValues(alpha: 0.12)
          : AppPalette.pastelGrey.withValues(alpha: 0.07),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppPalette.matchaMist.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              offline ? Icons.devices_fold_rounded : Icons.devices_rounded,
              color: AppPalette.textPrimary,
            ),
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
          Text(
            status,
            style: TextStyle(
              color: offline ? AppPalette.textSecondary : AppPalette.almondCream,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BackButton(onTap: onBack),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
