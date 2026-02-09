import 'package:flutter/foundation.dart';

@immutable
class Transaction {
  final String txHash;

  /// sent / received（权威字段）
  final String direction;

  /// 对方地址（可能为 Unknown）
  final String counterparty;

  /// 始终为正数（sat），符号由 direction 决定
  final BigInt amountSat;

  /// 仅 sent 时可能存在（sat）
  final BigInt? feeSat;

  /// 链上时间（可能为 null → pending）
  final DateTime? timestamp;

  final String status;
  final int confirmations;
  final int blockHeight;

  static const int _decimals = 8;
  static final BigInt _unit = BigInt.from(10).pow(_decimals);

  const Transaction({
    required this.txHash,
    required this.direction,
    required this.counterparty,
    required this.amountSat,
    this.feeSat,
    this.timestamp,
    required this.status,
    required this.confirmations,
    required this.blockHeight,
  });

  // ==================== 转为 JSON 格式 ====================
  Map<String, dynamic> toJson() {
    return {
      'txHash': txHash,
      'direction': direction,
      'counterparty': counterparty,
      // BigInt 转为 String 存储是最安全的，能彻底避免 Web/原生平台的精度差异
      'amountSat': amountSat.toString(),
      'feeSat': feeSat?.toString(),
      // DateTime 转为 ISO8601 字符串
      'timestamp': timestamp?.toIso8601String(),
      'status': status,
      'confirmations': confirmations,
      'blockHeight': blockHeight,
    };
  }

  // ==================== fromJson (处理 toJson 存入的格式) ====================
  factory Transaction.fromJson(Map<String, dynamic> json) {
    final rawTime = json['timestamp'];

    return Transaction(
      txHash: json['txHash']?.toString() ?? json['txid']?.toString() ?? '',
      direction: json['direction']?.toString() ?? 'received',
      counterparty: json['counterparty']?.toString() ?? json['from']?.toString() ?? 'Unknown',
      amountSat: _readAmountSat(json),
      feeSat: _readFeeSat(json),
      // 修改这里：兼容 ISO8601 字符串和时间戳
      timestamp: _parseTimestampEnhanced(rawTime),
      status: json['status']?.toString() ?? 'pending',
      confirmations: (json['confirmations'] as num?)?.toInt() ?? 0,
      blockHeight: (json['blockHeight'] as num?)?.toInt() ?? 0,
    );
  }

  // 增强版时间解析，兼容缓存中的 ISO 字符串
  static DateTime? _parseTimestampEnhanced(dynamic time) {
    if (time == null) return null;
    if (time is String && time.contains('T')) {
      return DateTime.tryParse(time); // 解析 ISO 8601
    }
    return _parseTimestampNullable(time); // 解析旧的时间戳逻辑
  }

  // ==================== UI 友好属性 ====================

  bool get isSent => direction == 'sent';
  bool get isReceived => direction == 'received';

  bool get isConfirmed => confirmations > 0;

  bool get isValid => txHash.isNotEmpty && txHash != 'null';

  /// UI 显示用（带符号）sat
  BigInt get displayAmountSat => isSent ? -amountSat : amountSat;

  /// UI 显示用（字符串，最安全）
  String get amountText => _formatSat(amountSat);

  String? get feeText => feeSat == null ? null : _formatSat(feeSat!);

  /// double（仅展示/排序，不要参与签名/找零/计算）
  double get amountDouble => amountSat.toDouble() / _unit.toDouble();

  double? get feeDouble =>
      feeSat == null ? null : feeSat!.toDouble() / _unit.toDouble();

  /// UI 显示用（带符号 double）
  double get displayAmountDouble => isSent ? -amountDouble : amountDouble;

  int getRealtimeConfirmations(int currentChainHeight) {
    if (status != 'confirmed' || blockHeight <= 0) return 0;
    return currentChainHeight - blockHeight + 1;
  }

  // ==================== JSON 解析辅助 ====================

  static BigInt _readAmountSat(Map<String, dynamic> json) {

    final v = json['amountSat'] ?? json['amount_sat'] ?? json['amount_sats'];
    if (v != null) return _toBigInt(v);

    // 兼容旧字段：amount 可能是 coin(小数) 或 string
    final amount = json['amount'];
    if (amount == null) return BigInt.zero;
    return _coinToSat(amount);
  }

  static BigInt? _readFeeSat(Map<String, dynamic> json) {

    final v = json['feeSat'] ?? json['fee_sat'] ?? json['fee_sats'];
    if (v != null) return _toBigInt(v);

    // 兼容旧字段：fee 可能是 coin(小数) 或 string
    final fee = json['fee'];
    if (fee == null) return null;
    return _coinToSat(fee);
  }

  static BigInt _toBigInt(dynamic value) {
    if (value is BigInt) return value;
    if (value is int) return BigInt.from(value);
    if (value is num) return BigInt.from(value.toInt());
    return BigInt.parse(value.toString());
  }

  /// 把 coin（"1.2345" / 1.2345）转 sat（BigInt）
  static BigInt _coinToSat(dynamic coin) {
    final s = coin is String ? coin : coin.toString();
    return _parseCoinStringToSat(s);
  }

  static BigInt _parseCoinStringToSat(String input) {
    var s = input.trim();
    if (s.isEmpty) return BigInt.zero;

    var sign = BigInt.one;
    if (s.startsWith('-')) {
      sign = BigInt.from(-1);
      s = s.substring(1);
    } else if (s.startsWith('+')) {
      s = s.substring(1);
    }

    final parts = s.split('.');
    final whole = BigInt.parse(parts[0].isEmpty ? '0' : parts[0]);

    var frac = parts.length > 1 ? parts[1] : '';
    if (frac.length > _decimals) {
      frac = frac.substring(0, _decimals);
    }
    frac = frac.padRight(_decimals, '0');
    final fracInt = BigInt.parse(frac.isEmpty ? '0' : frac);

    return sign * (whole * _unit + fracInt);
  }

  static String _formatSat(BigInt sat) {
    final isNeg = sat.isNegative;
    final x = sat.abs();

    final whole = x ~/ _unit;
    var frac = (x % _unit).toString().padLeft(_decimals, '0');

    frac = frac.replaceFirst(RegExp(r'0+$'), '');
    final body = frac.isEmpty ? whole.toString() : '${whole.toString()}.$frac';
    return isNeg ? '-$body' : body;
  }

  static DateTime? _parseTimestampNullable(dynamic time) {
    if (time == null) return null;

    final intTime = (time is num)
        ? time.toInt()
        : (int.tryParse(time.toString()) ?? 0);

    if (intTime <= 0) return null;

    if (intTime < 10000000000) {
      return DateTime.fromMillisecondsSinceEpoch(intTime * 1000);
    }
    return DateTime.fromMillisecondsSinceEpoch(intTime);
  }

  // ==================== 相等性 ====================

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Transaction &&
              txHash == other.txHash &&
              confirmations == other.confirmations &&
              blockHeight == other.blockHeight &&
              status == other.status;

  @override
  int get hashCode =>
      txHash.hashCode ^
      confirmations.hashCode ^
      blockHeight.hashCode ^
      status.hashCode;
}
