import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme.dart';

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.showBackgroundImage = true,
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
    final content = padding == null ? child : Padding(padding: padding!, child: child);
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(decoration: BoxDecoration(gradient: AppPalette.appBackground)),
        if (showBackgroundImage)
          Positioned.fill(
            child: Image.asset(
              backgroundAsset,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              excludeFromSemantics: true,
            ),
          ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppPalette.pineGreen.withValues(alpha: 0.14),
                  AppPalette.night.withValues(alpha: 0.76),
                ],
              ),
            ),
          ),
        ),
        Positioned(top: -90, right: -40, child: _ambientBlob(220, AppPalette.matchaMist.withValues(alpha: 0.12))),
        Positioned(bottom: 120, left: -50, child: _ambientBlob(180, AppPalette.pineGreen.withValues(alpha: 0.14))),
        SafeArea(
          top: topSafe,
          bottom: bottomSafe,
          child: content,
        ),
      ],
    );
  }

  static Widget _ambientBlob(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color, blurRadius: 120, spreadRadius: 16)],
        ),
      ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? AppPalette.pastelGrey.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppPalette.pastelGrey.withValues(alpha: 0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppPalette.almondCream.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon ?? Icons.tune_rounded, color: AppPalette.almondCream, size: 20),
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
      icon: Icon(icon ?? Icons.arrow_forward_rounded, color: AppPalette.night),
      label: Text(
        label,
        style: const TextStyle(
          color: AppPalette.night,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppPalette.almondCream,
        disabledBackgroundColor: AppPalette.laurelGreen.withValues(alpha: 0.5),
        foregroundColor: AppPalette.night,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
      ),
    );
  }
}
