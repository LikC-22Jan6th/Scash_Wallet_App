import '../src/core/config/app_config.dart';

/// 金额工具
class AmountUtils {
  AmountUtils._();

  static int get decimals => AppConfig.coinDecimals;
  static BigInt get unit => BigInt.from(10).pow(decimals);

  /// coin 十进制字符串 -> sat(BigInt)
  ///
  /// 允许输入：
  /// - "1"
  /// - "1."
  /// - "0.1"
  /// - "0.00001"
  /// - "+1.23" / "-0.5"
  ///
  /// 超过 decimals 位的小数会被【截断】（如需四舍五入，可扩展 round 版）。
  static BigInt coinTextToSat(String input) {
    var s = input.trim();
    if (s.isEmpty) return BigInt.zero;

    var sign = BigInt.one;
    if (s.startsWith('-')) {
      sign = BigInt.from(-1);
      s = s.substring(1);
    } else if (s.startsWith('+')) {
      s = s.substring(1);
    }

    if (s.isEmpty) return BigInt.zero;

    final parts = s.split('.');
    final wholeStr = parts[0].isEmpty ? '0' : parts[0];
    final whole = BigInt.tryParse(wholeStr) ?? BigInt.zero;

    var frac = parts.length > 1 ? parts[1] : '';
    if (frac.length > decimals) {
      frac = frac.substring(0, decimals); // 截断
    }
    frac = frac.padRight(decimals, '0');
    final fracInt = BigInt.tryParse(frac.isEmpty ? '0' : frac) ?? BigInt.zero;

    return sign * (whole * unit + fracInt);
    // 注意：如果输入包含非数字字符，tryParse 会返回 null -> 当作 0
  }

  /// sat(BigInt) -> coin 固定小数位字符串（适合回填输入框）
  /// 例：1000 sat -> "0.00001000"
  static String satToCoinFixed(BigInt sat) {
    final isNeg = sat.isNegative;
    final x = sat.abs();

    final whole = x ~/ unit;
    final frac = (x % unit).toString().padLeft(decimals, '0');

    return '${isNeg ? '-' : ''}${whole.toString()}.$frac';
  }

  /// sat(BigInt) -> coin 去掉尾随 0 的字符串（适合展示）
  /// 例：1000 sat -> "0.00001"
  static String satToCoinTrimmed(BigInt sat) {
    final isNeg = sat.isNegative;
    final x = sat.abs();

    final whole = x ~/ unit;
    var frac = (x % unit).toString().padLeft(decimals, '0');
    frac = frac.replaceFirst(RegExp(r'0+$'), '');

    final body = frac.isEmpty ? whole.toString() : '${whole.toString()}.$frac';
    return isNeg ? '-$body' : body;
  }

  /// 用于 UI 校验：输入是否是一个合法的 coin 数字格式
  /// （允许空字符串由调用方决定是否视为合法）
  static bool isValidCoinText(String input, {bool allowEmpty = false}) {
    final s = input.trim();
    if (s.isEmpty) return allowEmpty;

    // 允许 "+", "-" 前缀；小数点最多 1 个；小数位不超过 decimals
    final reg = RegExp(r'^[+-]?\d+(\.\d*)?$');
    if (!reg.hasMatch(s)) return false;

    final parts = s.replaceFirst(RegExp(r'^[+-]'), '').split('.');
    if (parts.length == 2 && parts[1].length > decimals) return false;

    return true;
  }
}
