import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../src/features/wallet/domain/wallet.dart';

class StorageService {
  StorageService._internal();
  static final StorageService instance = StorageService._internal();
  factory StorageService() => instance;

  static const _mnemonicKeyPrefix = 'mnemonic_';
  static const _walletsKey = 'wallets';
  static const _currentWalletIndexKey = 'current_wallet_index';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// 保存钱包助记词到安全存储
  Future<void> saveWalletMnemonic(Wallet wallet, String mnemonic) async {
    await _secureStorage.write(
      key: '$_mnemonicKeyPrefix${wallet.id}',
      value: mnemonic,
      aOptions: const AndroidOptions(
        keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
        storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
      ),
      iOptions: const IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
    );
  }

  /// 获取钱包助记词
  Future<String?> getWalletMnemonic(Wallet wallet) async {
    return _secureStorage.read(key: '$_mnemonicKeyPrefix${wallet.id}');
  }

  /// 删除钱包助记词
  Future<void> deleteWalletMnemonic(Wallet wallet) async {
    await _secureStorage.delete(key: '$_mnemonicKeyPrefix${wallet.id}');
  }

  /// 保存钱包列表（不包含敏感信息）
  Future<void> saveWalletList(List<Wallet> wallets) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = wallets
        .map((w) => jsonEncode({
      'id': w.id,
      'name': w.name,
      'address': w.address,
      'publicKey': w.publicKey,
    }))
        .toList();
    await prefs.setStringList(_walletsKey, jsonList);
  }

  /// 获取钱包列表
  Future<List<Wallet>> getWalletList() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_walletsKey) ?? [];
    return jsonList.map((e) {
      final data = jsonDecode(e);
      return Wallet(
        id: data['id'],
        name: data['name'],
        address: data['address'],
        publicKey: data['publicKey'] ?? '',
        encryptedPrivateKey: '',
      );
    }).toList();
  }

  /// 保存当前选中钱包索引
  Future<void> saveCurrentWalletIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentWalletIndexKey, index);
  }

  /// 获取当前选中钱包索引（永远返回 int，不会是 null）
  Future<int> getCurrentWalletIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currentWalletIndexKey) ?? 0;
  }

  /// WalletListPage 用到的：保存“当前钱包”
  /// 逻辑：优先按 id 找，其次按 address 找，找不到就不动（避免无意新增重复钱包）
  Future<void> saveCurrentWallet(Wallet wallet) async {
    final wallets = await getWalletList();
    if (wallets.isEmpty) {
      await saveCurrentWalletIndex(0);
      return;
    }

    int idx = wallets.indexWhere((w) => w.id == wallet.id);
    if (idx == -1) {
      idx = wallets.indexWhere(
            (w) => w.address.toLowerCase() == wallet.address.toLowerCase(),
      );
    }

    if (idx >= 0) {
      await saveCurrentWalletIndex(idx);
    }
  }

  /// 获取当前选中钱包
  Future<Wallet?> getCurrentWallet() async {
    final wallets = await getWalletList();
    if (wallets.isEmpty) return null;

    final index = await getCurrentWalletIndex();
    if (index < 0 || index >= wallets.length) return wallets.first;

    return wallets[index];
  }

  /// 删除钱包（同时删助记词 & 修正 current index）
  Future<void> deleteWallet(Wallet wallet) async {
    final wallets = await getWalletList();
    if (wallets.isEmpty) return;

    int idx = wallets.indexWhere((w) => w.id == wallet.id);
    if (idx == -1) {
      idx = wallets.indexWhere(
            (w) => w.address.toLowerCase() == wallet.address.toLowerCase(),
      );
    }
    if (idx == -1) return;

    // 删助记词
    await deleteWalletMnemonic(wallet);

    // 删列表并保存
    final newList = List<Wallet>.from(wallets)..removeAt(idx);
    await saveWalletList(newList);

    // 修正 current index
    if (newList.isEmpty) {
      await saveCurrentWalletIndex(0);
    } else {
      final oldCurrent = await getCurrentWalletIndex();
      final adjusted = oldCurrent >= newList.length ? newList.length - 1 : oldCurrent;
      await saveCurrentWalletIndex(adjusted.clamp(0, newList.length - 1));
    }
  }
}
