import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 可点击小部件（无水波纹，低调高光）。
class AppPressable extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  /// 表面背景色
  final Color? color;

  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;

  /// 外边距属性
  final EdgeInsetsGeometry? margin;

  /// 按下时的遮罩颜色
  final Color? pressedOverlayColor;

  /// 是否开启触觉反馈
  final bool haptic;

  const AppPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.color,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.margin, // 初始化 margin
    this.pressedOverlayColor,
    this.haptic = false,
  });

  Color _defaultOverlayColor() {
    final c = color;
    if (c == null || c.opacity == 0) {
      return Colors.white.withOpacity(0.10);
    }
    final luminance = c.withOpacity(1).computeLuminance();
    // 浅色表面用黑色遮罩，深色表面用白色遮罩
    return luminance > 0.55 ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.10);
  }

  @override
  Widget build(BuildContext context) {
    final overlay = pressedOverlayColor ?? _defaultOverlayColor();

    // 使用 Container 来承载 margin
    return Container(
      margin: margin,
      child: Material(
        color: color ?? Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: borderRadius == null ? Clip.none : Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
            if (haptic) HapticFeedback.lightImpact();
            onTap!();
          },
          borderRadius: borderRadius,
          highlightColor: Colors.transparent, // 禁用自带的高亮
          splashFactory: NoSplash.splashFactory, // 彻底禁用波纹
          overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.pressed)) return overlay;
            return Colors.transparent;
          }),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}