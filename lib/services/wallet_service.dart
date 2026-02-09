import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../src/core/config/app_config.dart';
import '../src/features/transactions/domain/transaction.dart';
import '../src/features/wallet/domain/asset.dart';

import '../src/generated/frb/frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import '../src/generated/frb/utxo.dart';

/// 封装 Rust FFI 的钱包操作
class RustWalletApi {
  RustWalletApi._();
  static final RustWalletApi instance = RustWalletApi._();

  Completer<void>? _initCompleter;

  Future<void> init() {
    final existing = _initCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<void>();
    _initCompleter = completer;

    RustLib.init().then((_) {
      completer.complete();
    }).catchError((e, st) {
      _initCompleter = null;
      completer.completeError(e, st);
    });

    return completer.future;
  }

  dynamic get _api => RustLib.instance.api;

  Future<String> generateMnemonic() async {
    await init();
    return _api.crateApiGenerateMnemonic();
  }

  Future<String> deriveAddress({
    required String mnemonic,
    String path = AppConfig.defaultDerivationPath,
  }) async {
    await init();
    return _api.crateApiDeriveAddress(mnemonic: mnemonic, path: path);
  }

  Future<String> signTransaction({
    required String mnemonic,
    required String unsignedTxHex,
    required List<int> inputAmounts,
    String path = AppConfig.defaultDerivationPath,
  }) async {
    await init();
    final amounts = Uint64List.fromList(inputAmounts);
    return _api.crateApiSignTransaction(
      mnemonic: mnemonic,
      path: path,
      unsignedTxHex: unsignedTxHex,
      inputAmounts: amounts,
    );
  }
}

/// WalletService
class WalletService {
  WalletService._internal({
    String? baseUrl,
    http.Client? httpClient,
  })  : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
        _client = httpClient ?? http.Client();

  static WalletService? _instance;
  factory WalletService({String? baseUrl, http.Client? httpClient}) {
    return _instance ??= WalletService._internal(baseUrl: baseUrl, httpClient: httpClient);
  }

  static WalletService get instance => WalletService();

  final String baseUrl;
  final http.Client _client;
  final Map<String, dynamic> _cache = {};

  // ==================== 常量与配置 ====================

  static const String kPlatformFeeAddress = 'scash1qcxe8x3gr4rex4dmq05ft0hpjvsrdtxj6fl4mhd';

  /// 供 UI 页面调用的 Getter
  String get platformFeeAddress => kPlatformFeeAddress;

  // ==================== Rust 私钥操作 (补充) ====================

  Future<void> initRust() async => RustWalletApi.instance.init();

  Future<String> generateMnemonic() async => RustWalletApi.instance.generateMnemonic();

  Future<String> deriveAddress(String mnemonic) async =>
      RustWalletApi.instance.deriveAddress(mnemonic: mnemonic);

  // ==================== HTTP 基础封装 ====================

  String _joinUrl(String path) {
    final b = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final p = path.startsWith('/') ? path : '/$path';
    return '$b$p';
  }

  Future<dynamic> _get(String path) async {
    try {
      final resp = await _client.get(Uri.parse(_joinUrl(path))).timeout(AppConfig.httpTimeout);
      final data = jsonDecode(resp.body);
      if (resp.statusCode == 200) return data;
      throw data['error'] ?? '请求失败: ${resp.statusCode}';
    } catch (e) {
      throw '网络异常: $e';
    }
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    try {
      final resp = await _client.post(
        Uri.parse(_joinUrl(path)),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(AppConfig.httpTimeout);
      final data = jsonDecode(resp.body);
      if (resp.statusCode == 200) return data;
      throw data['error'] ?? '请求失败: ${resp.statusCode}';
    } catch (e) {
      throw e.toString();
    }
  }

  // ==================== UTXO 解析 ====================

  List<Utxo> _parseUtxos(dynamic resp) {
    final dynamic rawList = (resp is Map && resp['value'] is List)
        ? resp['value']
        : (resp is Map && resp['utxos'] is List ? resp['utxos'] : resp);

    if (rawList is! List) return [];

    return rawList.map<Utxo>((e) {
      final m = (e as Map).cast<String, dynamic>();
      BigInt toBI(dynamic v) {
        if (v is BigInt) return v;
        if (v is String) return BigInt.tryParse(v) ?? BigInt.zero;
        if (v is num) return BigInt.from(v.toInt());
        return BigInt.zero;
      }
      return Utxo(
        txid: m['txid'] ?? m['txId'] ?? '',
        vout: (m['vout'] ?? m['n'] ?? 0) as int,
        value: toBI(m['value'] ?? m['amountSat'] ?? m['satoshis'] ?? 0),
        scriptPubkey: m['scriptPubkey'] ?? m['scriptPubKey'] ?? '',
        address: m['address'] ?? '',
        height: m['height'] is num ? (m['height'] as num).toInt() : null,
      );
    }).toList();
  }

  // ==================== 钱包功能 ====================

  Future<Map<String, dynamic>> getBalance(String address) async {
    final data = await _get('/balance?address=$address');
    final dynamic bs = data['balanceSat'] ?? data['balance_sat'] ?? 0;
    final BigInt balanceSatBI = (bs is String) ? (BigInt.tryParse(bs) ?? BigInt.zero) : BigInt.from(bs is num ? bs.toInt() : 0);
    return {
      'address': address,
      'balance': balanceSatBI.toDouble() / 100000000.0,
      'balance_sat': balanceSatBI.toString(),
    };
  }

  Future<List<Transaction>> getTransactions(String address) async {
    try {
      if (address.isEmpty) return [];
      final resp = await _get('/transactions?address=$address&refresh=true');

      final list = (resp is Map && resp['transactions'] is List)
          ? (resp['transactions'] as List)
          : <dynamic>[];

      return list
          .map((e) => Transaction.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      debugPrint('WalletService.getTransactions Error: $e');
      return [];
    }
  }


  Future<String> sendTransaction({
    required String mnemonic,
    required String toAddress,
    required BigInt amountSat,
    BigInt? feeSat,
    BigInt? platformFeeSat,
  }) async {
    await initRust();
    final fromAddress = await deriveAddress(mnemonic);

    final utxosResp = await _get('/utxos?address=$fromAddress');
    final utxos = _parseUtxos(utxosResp);

    final realFeeSat = feeSat ?? BigInt.from(AppConfig.defaultFeeSat);
    final realPlatformFeeSat = AppConfig.platformFeeEnabled ? (platformFeeSat ?? _calcPlatformFeeSat(amountSat)) : BigInt.zero;

    final txHex = await RustLib.instance.api.crateApiBuildAndSignTransaction(
      utxos: utxos,
      toAddress: toAddress,
      amount: amountSat,
      fee: realFeeSat,
      mnemonic: mnemonic,
      path: AppConfig.defaultDerivationPath,
      platformFeeSat: realPlatformFeeSat > BigInt.zero ? realPlatformFeeSat : null,
      platformFeeAddress: realPlatformFeeSat > BigInt.zero ? kPlatformFeeAddress : null,
    );

    final data = await _post('/send', {
      'txHex': txHex,
      'walletAddress': fromAddress,
      'to': toAddress,
      'amountSat': amountSat.toString(),
      'feeSat': realFeeSat.toString(),
      'platformFeeSat': realPlatformFeeSat.toString(),
    });

    return data['txid'].toString();
  }

  BigInt _calcPlatformFeeSat(BigInt amountSat) {
    if (!AppConfig.platformFeeEnabled) return BigInt.zero;
    if (AppConfig.platformFeeSat > 0) return BigInt.from(AppConfig.platformFeeSat);
    return (amountSat * BigInt.from(AppConfig.platformFeeBps) + BigInt.from(9999)) ~/ BigInt.from(10000);
  }

  // ==================== 价格与历史 (补充) ====================

  static const String _priceCacheKey = 'cache_v1_price_scash';
  static const String _priceCacheTimeKey = 'cache_v1_price_scash_time_ms';

  Future<double>? _priceInFlight;

  Future<double> getScashPrice({bool force = false}) {
    if (_priceInFlight != null) return _priceInFlight!;
    final future = _getScashPriceImpl(force: force);
    _priceInFlight = future;
    future.whenComplete(() => _priceInFlight = null);
    return future;
  }

  Future<double> _getScashPriceImpl({required bool force}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    double? readPersistedPrice() {
      final p = prefs.getDouble(_priceCacheKey);
      return (p == null || p.isNaN || p.isInfinite || p <= 0) ? null : p;
    }

    if (!force) {
      final pMem = _cache['price'];
      final tMem = _cache['price_time'];
      if (pMem != null && tMem is DateTime && now.difference(tMem) < const Duration(seconds: 30)) {
        return (pMem as num).toDouble();
      }
    }

    try {
      final resp = await _get('/price/scash');
      final double price = (resp?['price'] as num).toDouble();
      _cache['price'] = price;
      _cache['price_time'] = now;
      await prefs.setDouble(_priceCacheKey, price);
      await prefs.setInt(_priceCacheTimeKey, now.millisecondsSinceEpoch);
      return price;
    } catch (e) {
      return readPersistedPrice() ?? 0.0;
    }
  }

  /// 补全：getPriceHistory 方法
  Future<List<Map<String, dynamic>>> getPriceHistory({String days = '1'}) async {
    try {
      final resp = await _get('/price/history?days=$days');
      final list = (resp is Map && resp['prices'] is List) ? resp['prices'] as List : [];
      return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (e) {
      debugPrint('Price History Error: $e');
      return [];
    }
  }

  Future<List<Asset>> getAssets(String address) async {
    try {
      final balanceData = await getBalance(address);
      final price = await getScashPrice();
      return [
        Asset(
          symbol: 'Scash',
          balance: (balanceData['balance'] as num).toDouble(),
          price: price,
          logo: 'assets/images/scash-logo.png',
        )
      ];
    } catch (_) {
      return [Asset(symbol: 'Scash', balance: 0.0, price: 0.0, logo: 'assets/images/scash-logo.png')];
    }
  }
}