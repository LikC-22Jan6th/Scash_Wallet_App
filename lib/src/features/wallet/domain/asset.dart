import 'package:flutter/foundation.dart';

@immutable
class Asset {
  final String symbol;
  final double balance;
  final double price;
  final String? logo;

  // 使用 getter 替代成员变量，确保计算永远是最新的
  double get usdValue => balance * price;

  const Asset({
    required this.symbol,
    double? balance,
    double? price,
    this.logo,
  })  : balance = balance ?? 0.0,
        price = price ?? 0.0;

  // copyWith 同步更新
  Asset copyWith({
    String? symbol,
    double? balance,
    double? price,
    String? logo,
  }) {
    return Asset(
      symbol: symbol ?? this.symbol,
      balance: balance ?? this.balance,
      price: price ?? this.price,
      logo: logo ?? this.logo,
    );
  }
}