import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/app_ui.dart';
import '../../core/theme.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final current = _currentController.text.trim();
    final next = _newController.text.trim();
    final confirm = _confirmController.text.trim();

    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先完整填写密码信息')),
      );
      return;
    }
    if (next.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('新密码至少需要 8 位')),
      );
      return;
    }
    if (next != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('两次输入的新密码不一致')),
      );
      return;
    }

    AppStateScope.of(context).markPasswordUpdated();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('密码已更新')),
    );
    Navigator.pop(context);
  }

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
              title: '更改密码',
              subtitle: '上次更新于 ${store.passwordUpdatedLabel}',
              onBack: () => Navigator.pop(context),
            ),
            const SizedBox(height: 20),
            _InputCard(
              label: '当前密码',
              controller: _currentController,
              hintText: '请输入当前密码',
              icon: Icons.lock_outline_rounded,
              obscureText: _hideCurrent,
              onToggleObscure: () {
                setState(() => _hideCurrent = !_hideCurrent);
              },
            ),
            const SizedBox(height: 12),
            _InputCard(
              label: '新密码',
              controller: _newController,
              hintText: '请设置新的登录密码',
              icon: Icons.password_rounded,
              obscureText: _hideNew,
              helperText: '建议使用 8 位以上密码，并组合大小写字母和数字。',
              onToggleObscure: () {
                setState(() => _hideNew = !_hideNew);
              },
            ),
            const SizedBox(height: 12),
            _InputCard(
              label: '确认新密码',
              controller: _confirmController,
              hintText: '请再次输入新密码',
              icon: Icons.verified_user_outlined,
              obscureText: _hideConfirm,
              onToggleObscure: () {
                setState(() => _hideConfirm = !_hideConfirm);
              },
            ),
            const SizedBox(height: 18),
            const AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '密码建议',
                    style: TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '为了更稳妥地保护学习数据，建议定期更新密码，并避免在多个平台重复使用同一组口令。',
                    style: TextStyle(
                      color: AppPalette.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            AppPrimaryButton(
              label: '保存新密码',
              icon: Icons.check_rounded,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.obscureText,
    required this.onToggleObscure,
    this.helperText,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final VoidCallback onToggleObscure;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            obscureText: obscureText,
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: Icon(icon, color: AppPalette.matchaMist),
              suffixIcon: IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppPalette.textSecondary,
                ),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppPalette.pastelGrey.withValues(alpha: 0.06),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppPalette.pastelGrey.withValues(alpha: 0.06),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppPalette.matchaMist,
                  width: 1.2,
                ),
              ),
            ),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 8),
            Text(
              helperText!,
              style: const TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
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
