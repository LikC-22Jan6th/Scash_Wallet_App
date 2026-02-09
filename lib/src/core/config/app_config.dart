class AppConfig {
  static const String apiBaseUrl = 'https://scash.world/api';
  static const Duration httpTimeout = Duration(seconds: 60);

  static const String defaultDerivationPath = "m/84'/0'/0'/0/0";

  /// 小数位（1 coin = 10^8 sat）
  static const int coinDecimals = 8;

  /// 链上权威：默认矿工费（sat），0.00001 * 1e8 = 1000 sat
  static const int defaultFeeSat = 500;

  /// 平台手续费收款地址（平台自己的地址）
  /// 必须是 Scash 支持的地址格式
  static const String platformFeeAddress = 'scash1qcxe8x3gr4rex4dmq05ft0hpjvsrdtxj6fl4mhd';

  /// 平台手续费：固定模式（sat）
  /// 例如：500000 sat = 0.005 coin
  static const int platformFeeSat = 500000;

  /// 平台手续费：比例模式（bps，万分比）
  /// 例如：50 bps = 0.5%
  /// 如果启用比例模式，就把 platformFeeSat 设为 0，并用这个值计算
  static const int platformFeeBps = 0;

  /// 是否启用平台手续费（有任一模式 > 0 即启用）
  static bool get platformFeeEnabled => platformFeeSat > 0 || platformFeeBps > 0;
}
