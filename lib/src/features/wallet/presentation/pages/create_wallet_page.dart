import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../../utils/I10n.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_radii.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/top_toast.dart';

import '../../../../../services/wallet_service.dart';
import '../../../../../services/storage_service.dart';
import '../../domain/wallet.dart';
import '../../../../../src/features/wallet/presentation/pages/wallet_home_page.dart';
import '../../../../../src/features/profile/presentation/pages/set_app_password_page.dart';

class CreateWalletPage extends StatefulWidget {
  const CreateWalletPage({super.key});

  @override
  State<CreateWalletPage> createState() => _CreateWalletPageState();
}

class _CreateWalletPageState extends State<CreateWalletPage> {
  bool _isLoading = false;
  String _mnemonic = '';
  Wallet? _wallet;

  final WalletService _walletService = WalletService();
  final StorageService _storageService = StorageService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _kSecPwdSalt = 'security_app_lock_salt';
  static const String _kSecPwdHash = 'security_app_lock_hash';

  @override
  void initState() {
    super.initState();
    // 延迟一小会儿执行，确保 context 准备好处理 L10n
    Future.microtask(() => _createWallet());
  }

  // ... (逻辑部分保持一致: _hasAppPassword, _ensureAppPassword, _createWallet, _goHomeAfterBackup)
  // 仅在 _goHomeAfterBackup 中加入了触感反馈

  Future<bool> _hasAppPassword() async {
    final salt = await _secureStorage.read(key: _kSecPwdSalt);
    final hash = await _secureStorage.read(key: _kSecPwdHash);
    return salt != null && salt.isNotEmpty && hash != null && hash.isNotEmpty;
  }

  Future<bool> _ensureAppPassword() async {
    if (await _hasAppPassword()) return true;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SetAppPasswordPage(requiredSetup: true)),
    );
    final has = await _hasAppPassword();
    if ((ok != true || !has) && mounted) {
      TopToast.infoKey(context, 'pwd_required_before_wallet');
    }
    return has;
  }

  Future<void> _createWallet() async {
    setState(() => _isLoading = true);
    try {
      await _walletService.initRust();
      final mnemonic = await _walletService.generateMnemonic();
      final address = await _walletService.deriveAddress(mnemonic);
      final wallet = Wallet(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: L10n.of(context).t('default_wallet_name'),
        address: address,
        publicKey: '',
        encryptedPrivateKey: '',
        mnemonic: mnemonic,
      );
      final wallets = await _storageService.getWalletList();
      wallets.add(wallet);
      await _storageService.saveWalletList(wallets);
      await _storageService.saveCurrentWalletIndex(wallets.length - 1);
      await _storageService.saveWalletMnemonic(wallet, mnemonic);
      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _mnemonic = mnemonic;
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('CreateWalletPage._createWallet error: $e\n$st');
      if (!mounted) return;
      setState(() => _isLoading = false);
      TopToast.errorKey(context, 'create_wallet_failed');
    }
  }

  Future<void> _goHomeAfterBackup() async {
    HapticFeedback.mediumImpact();
    if (_wallet == null || _mnemonic.isEmpty) {
      TopToast.infoKey(context, 'wallet_creating_wait');
      return;
    }
    final ok = await _ensureAppPassword();
    if (!ok) return;
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WalletHomePage()),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = L10n.of(context);

    return AppScaffold(
      backgroundColor: AppColors.background,
      statusBarIconBrightness: Brightness.light,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _isLoading
              ? const Center(child: CupertinoActivityIndicator(radius: 12, color: AppColors.button))
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                loc.t('create_wallet_title'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                loc.t('create_wallet_mnemonic_tip'),
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              if (_mnemonic.isNotEmpty)
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Clipboard.setData(ClipboardData(text: _mnemonic));
                      TopToast.successKey(context, 'toast_mnemonic_copied');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.button),
                    label: Text(
                      loc.t('copy_mnemonic'),
                      style: const TextStyle(color: AppColors.button, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              if (_mnemonic.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: AppRadii.r16,
                  ),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _mnemonic.split(' ').asMap().entries.map((entry) {
                      final index = entry.key;
                      final word = entry.value;

                      final itemWidth = (MediaQuery.of(context).size.width - 24 * 2 - 10 * 2 - 8) / 3;

                      return Container(
                        width: itemWidth,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: AppRadii.r12,
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.button.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              word,
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Monospace',
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const Spacer(),

              GestureDetector(
                onTap: _goHomeAfterBackup,
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.button,
                    borderRadius: AppRadii.pill,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.button.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Center(
                    child: Text(
                      loc.t('i_backed_up'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}