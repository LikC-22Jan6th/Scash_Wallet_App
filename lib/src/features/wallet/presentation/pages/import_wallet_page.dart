import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_radii.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../../../services/wallet_service.dart';
import '../../../../../services/storage_service.dart';
import '../../domain/wallet.dart';
import '../../../../../utils/I10n.dart';
import '../../../../../src/features/wallet/presentation/pages/wallet_home_page.dart';
import '../../../../../src/features/profile/presentation/pages/set_app_password_page.dart';

class ImportWalletPage extends StatefulWidget {
  const ImportWalletPage({super.key});

  @override
  State<ImportWalletPage> createState() => _ImportWalletPageState();
}

class _ImportWalletPageState extends State<ImportWalletPage> {
  final TextEditingController _mnemonicController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  String? _errorKey;

  final WalletService walletService = WalletService.instance;
  final StorageService storageService = StorageService.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _kSecPwdSalt = 'security_app_lock_salt';
  static const String _kSecPwdHash = 'security_app_lock_hash';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _mnemonicController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // 一键粘贴功能
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _mnemonicController.text = data!.text!;
      setState(() => _errorKey = null);
    }
  }

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

  Future<void> _importWallet() async {
    if (_isLoading) return;

    HapticFeedback.mediumImpact();
    final mnemonic = _mnemonicController.text.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (mnemonic.isEmpty) {
      setState(() => _errorKey = 'mnemonic_empty');
      return;
    }

    final words = mnemonic.split(' ');
    if (words.length < 12) {
      setState(() => _errorKey = 'mnemonic_too_short');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorKey = null;
    });

    try {
      await walletService.initRust();
      final address = await walletService.deriveAddress(mnemonic);

      final wallet = Wallet(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: L10n.of(context).t('imported_wallet_name'),
        address: address,
        publicKey: '',
        encryptedPrivateKey: '',
        mnemonic: mnemonic,
      );

      final wallets = await storageService.getWalletList();
      final existingIndex = wallets.indexWhere((w) => w.address == address);

      if (existingIndex != -1) {
        await storageService.saveCurrentWalletIndex(existingIndex);
        await storageService.saveWalletMnemonic(wallets[existingIndex], mnemonic);
      } else {
        wallets.add(wallet);
        await storageService.saveWalletList(wallets);
        await storageService.saveCurrentWalletIndex(wallets.length - 1);
        await storageService.saveWalletMnemonic(wallet, mnemonic);
      }

      if (!mounted) return;

      final ok = await _ensureAppPassword();
      if (!ok) {
        setState(() => _isLoading = false);
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WalletHomePage()),
            (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorKey = 'mnemonic_invalid';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = L10n.of(context);
    final isFocused = _focusNode.hasFocus;

    return AppScaffold(
      backgroundColor: AppColors.background,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                loc.t('import_wallet'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                loc.t('input_mnemonic'),
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary.withOpacity(0.8),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // 输入框容器优化
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: AppRadii.r16,
                  border: Border.all(
                    color: _errorKey != null
                        ? Colors.redAccent.withOpacity(0.8)
                        : (isFocused ? AppColors.button.withOpacity(0.5) : Colors.white.withOpacity(0.05)),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _mnemonicController,
                      focusNode: _focusNode,
                      maxLines: 3, // 减小行数，防止填入后显得太空
                      cursorColor: AppColors.button,
                      onChanged: (_) {
                        if (_errorKey != null) setState(() => _errorKey = null);
                      },
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                      decoration: InputDecoration(
                        hintText: loc.t('restore_mnemonic'),
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary.withOpacity(0.3),
                          fontSize: 15,
                        ),
                        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        border: InputBorder.none,
                      ),
                    ),
                    // 输入框底部操作栏
                    Padding(
                      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (_mnemonicController.text.isNotEmpty)
                            _IconButton(
                              icon: Icons.close_rounded,
                              onTap: () {
                                _mnemonicController.clear();
                                setState(() => _errorKey = null);
                              },
                            ),
                          const SizedBox(width: 8),
                          _IconButton(
                            icon: Icons.paste_rounded,
                            label: loc.t('paste'), // 如果有多语言可以加上“粘贴”文字
                            onTap: _pasteFromClipboard,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 校验提示（外置）
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: AnimatedOpacity(
                  opacity: _errorKey != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _errorKey != null ? loc.t(_errorKey!) : '',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // 底部确认按钮
              _LoadingButton(
                isLoading: _isLoading,
                text: loc.t('import_wallet'),
                onTap: _importWallet,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// 辅助组件：输入框底部小按钮
class _IconButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;

  const _IconButton({required this.icon, required this.onTap, this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(label!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]
          ],
        ),
      ),
    );
  }
}

// 辅助组件：带 Loading 的大按钮
class _LoadingButton extends StatelessWidget {
  final bool isLoading;
  final String text;
  final VoidCallback onTap;

  const _LoadingButton({
    required this.isLoading,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: isLoading ? AppColors.button.withOpacity(0.5) : AppColors.button,
          borderRadius: AppRadii.pill,
          boxShadow: isLoading ? [] : [
            BoxShadow(
              color: AppColors.button.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
          )
              : Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }
}