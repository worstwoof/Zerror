import 'package:flutter/material.dart';

import 'theme.dart';

class FlatShape extends StatelessWidget {
  const FlatShape({
    super.key,
    required this.width,
    required this.height,
    required this.color,
    this.borderRadius,
    this.child,
  });

  final double width;
  final double height;
  final Color color;
  final BorderRadiusGeometry? borderRadius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius ??
            const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(46),
              bottomLeft: Radius.circular(42),
              bottomRight: Radius.circular(30),
            ),
      ),
      child: child,
    );
  }
}

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.showBackgroundImage = false,
    this.backgroundAsset = 'assets/images/auth_bg.png',
    this.padding,
    this.bottomSafe = true,
    this.topSafe = true,
  });

  final Widget child;
  final bool showBackgroundImage;
  final String backgroundAsset;
  final EdgeInsetsGeometry? padding;
  final bool bottomSafe;
  final bool topSafe;

  @override
  Widget build(BuildContext context) {
    final content =
        padding == null ? child : Padding(padding: padding!, child: child);
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppPalette.appBackground),
        ),
        if (showBackgroundImage)
          Positioned.fill(
            child: Image.asset(
              backgroundAsset,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              excludeFromSemantics: true,
            ),
          ),
        Positioned(
          top: -54,
          right: -36,
          child: FlatShape(
            width: 154,
            height: 116,
            color: AppPalette.mint.withOpacity(0.52),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(48),
              topRight: Radius.circular(32),
              bottomLeft: Radius.circular(72),
              bottomRight: Radius.circular(34),
            ),
          ),
        ),
        Positioned(
          top: 146,
          left: -42,
          child: FlatShape(
            width: 130,
            height: 96,
            color: AppPalette.leaf.withOpacity(0.46),
          ),
        ),
        Positioned(
          bottom: 96,
          right: 28,
          child: FlatShape(
            width: 88,
            height: 88,
            color: AppPalette.blush.withOpacity(0.42),
            borderRadius: BorderRadius.circular(32),
          ),
        ),
        SafeArea(
          top: topSafe,
          bottom: bottomSafe,
          child: content,
        ),
      ],
    );
  }
}

class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppPalette.paper.withOpacity(0.92),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppPalette.inkBlue.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: AppPalette.inkBlue.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconBackgroundColor = AppPalette.peach,
    this.iconColor = AppPalette.inkBlue,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color iconBackgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconBackgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon ?? Icons.tune_rounded,
            color: iconColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: AppPalette.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.arrow_forward_rounded, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppPalette.inkBlue,
        disabledBackgroundColor: AppPalette.laurelGreen.withOpacity(0.5),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
      ),
    );
  }
}

class AppFlatIconButton extends StatelessWidget {
  const AppFlatIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = AppPalette.paper,
    this.iconColor = AppPalette.inkBlue,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: iconColor, size: size * 0.48),
        ),
      ),
    );
  }
}

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: AppPalette.textSecondary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.color = AppPalette.mint,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.paper.withOpacity(0.94),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppPalette.inkBlue, size: 21),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppPalette.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ??
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppPalette.textSecondary,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.asset = 'assets/images/empty_study_illustration.png',
    this.action,
  });

  final String title;
  final String message;
  final String asset;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            asset,
            height: 148,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 18),
            action!,
          ],
        ],
      ),
    );
  }
}

class AppChatBubble extends StatelessWidget {
  const AppChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.label,
  });

  final String text;
  final bool isUser;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isUser ? AppPalette.moodBlue : AppPalette.paper;
    final textColor = isUser ? Colors.white : AppPalette.textPrimary;
    final alignment =
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 6),
            child: Text(
              label!,
              style: const TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 292),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(22),
                topRight: const Radius.circular(22),
                bottomLeft: Radius.circular(isUser ? 22 : 8),
                bottomRight: Radius.circular(isUser ? 8 : 22),
              ),
              border: isUser
                  ? null
                  : Border.all(
                      color: AppPalette.inkBlue.withOpacity(0.06),
                    ),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AppChatInputBar extends StatelessWidget {
  const AppChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.hintText = '问问 AI 助教',
  });

  final TextEditingController controller;
  final VoidCallback? onSend;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        color: AppPalette.paper,
        border: Border(
          top: BorderSide(color: AppPalette.inkBlue.withOpacity(0.06)),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 286),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 1,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: hintText,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    prefixIcon:
                        const Icon(Icons.auto_awesome_rounded, size: 20),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 42,
                      minHeight: 38,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AppFlatIconButton(
                icon: Icons.arrow_upward_rounded,
                onTap: onSend,
                color: AppPalette.inkBlue,
                iconColor: Colors.white,
                size: 42,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
