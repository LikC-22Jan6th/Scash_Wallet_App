import 'package:flutter/material.dart';

class AppColors {
  /// 背景色
  static const Color background = Color(0xFF000000);

  /// 渐变起始色
  static const Color bgGradientStart = Color(0xFF0D0D0D);

  /// 渐变结束色
  static const Color bgGradientEnd = Color(0xFF1A0B2E);

  /// 按钮
  static const Color button = Color(0xFF9754C7);

  /// 卡片
  static const Color card = Color(0xFF17171A);

  /// 文字主色
  static const Color textPrimary = Color(0xFFE0E0E0);

  /// 次要文字
  static const Color textSecondary = Color(0xFFB0B0C0);

  /// 错误色
  static const Color error = Color(0xFFE53935);


  /// 标准黑紫背景渐变
  static const LinearGradient mainGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      bgGradientStart,
      bgGradientEnd,
    ],
  );

  /// 按下状态的高亮覆盖色
  static Color get highlight => Colors.white.withOpacity(0.1);

  static const Color disabled = Color(0xFF333333);

  static const Color divider = Color(0xFF1A1A1A);
}