import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/app_ui.dart';
import '../../core/theme.dart';

class ShareCenterScreen extends StatelessWidget {
  const ShareCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: AppPalette.night,
      body: AppSurface(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                title: '分享中心',
                subtitle: '邀请同学加入，一起把复习节奏坚持下去',
                onBack: () => Navigator.pop(context),
              ),
              const SizedBox(height: 20),
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '你的专属邀请码',
                      style: TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      store.inviteCode,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '每邀请 1 位同学开始使用，你都能解锁 1 个月高级复习权益。当前已邀请 ${store.invitedCount} 人，累计解锁 ${store.unlockedMonths} 个月。',
                      style: const TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    AppPrimaryButton(
                      label: '复制邀请码',
                      icon: Icons.copy_rounded,
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: store.inviteCode));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('邀请码已复制到剪贴板')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const AppSectionTitle(
                title: '分享方式',
                subtitle: '把你的学习空间发给更多同学',
                icon: Icons.ios_share_rounded,
              ),
              const SizedBox(height: 12),
              _ShareOption(
                title: '复制邀请链接',
                subtitle: '直接复制链接发给同学，最快完成邀请。',
                icon: Icons.link_rounded,
                onTap: () async {
                  final link = 'https://zerror.app/invite/${store.inviteCode}';
                  await Clipboard.setData(ClipboardData(text: link));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('邀请链接已复制')),
                  );
                },
              ),
              const SizedBox(height: 12),
              _ShareOption(
                title: '生成分享海报',
                subtitle: '快速生成一张带邀请码的学习邀请海报。',
                icon: Icons.image_rounded,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('海报生成功能已准备好交互入口')),
                  );
                },
              ),
              const SizedBox(height: 12),
              _ShareOption(
                title: '发送邀请码',
                subtitle: '适合直接把邀请码发给正在和你一起学习的同学。',
                icon: Icons.send_rounded,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: store.inviteCode));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('邀请码已复制，可以直接粘贴发送')),
                  );
                },
              ),
              const SizedBox(height: 18),
              AppPanel(
                child: Row(
                  children: [
                    Expanded(
                      child: _InviteStat(
                        label: '已邀请',
                        value: '${store.invitedCount}',
                      ),
                    ),
                    const _StatDivider(),
                    Expanded(
                      child: _InviteStat(
                        label: '待加入',
                        value: '${store.pendingInviteCount}',
                      ),
                    ),
                    const _StatDivider(),
                    Expanded(
                      child: _InviteStat(
                        label: '已解锁',
                        value: '${store.unlockedMonths}个月',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AppPanel(
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
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
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppPalette.textSecondary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteStat extends StatelessWidget {
  const _InviteStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 24,
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
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: AppPalette.pastelGrey.withValues(alpha: 0.10),
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
