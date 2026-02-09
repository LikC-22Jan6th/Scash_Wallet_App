import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../src/core/theme/colors.dart';
import '../../../../../src/core/widgets/app_scaffold.dart';
import '../../../../../services/storage_service.dart';
import '../../../../../services/wallet_service.dart';
import '../../../../../src/features/wallet/domain/wallet.dart';
import '../../../../../utils/I10n.dart';
import '../../../../../utils/amount.dart';
import '../../../../../src/features/transfer/presentation/pages/scan_page.dart';
import '../../../../../src/core/config/app_config.dart';
import '../../../../../src/core/widgets/top_toast.dart';
import '../../../../core/widgets/app_radii.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../settings/presentation/pages/tx_auth_gate.dart';
import '../../../../../utils/event_bus.dart';

class SendPage extends StatefulWidget {
  final String? initialAddress;
  const SendPage({super.key, this.initialAddress});

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  final StorageService _storageService = StorageService.instance;

  final WalletService _walletService = WalletService.instance;

  bool _isSending = false;
  double _availableBalance = 0.0;
  BigInt _availableBalanceSat = BigInt.zero;
  final String _assetSymbol = 'Scash';

  BigInt get _estimatedFeeSat => BigInt.from(AppConfig.defaultFeeSat);
  Wallet? _currentWallet;

  static const String _cachePrefix = 'cache_v1_';

  String _formatBalance(double value) {
    if (value <= 0) return "0";
    return value.toStringAsFixed(6).replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
  }

  BigInt _calcPlatformFeeSat(BigInt amountSat) {
    if (!AppConfig.platformFeeEnabled) return BigInt.zero;

    final fixed = BigInt.from(AppConfig.platformFeeSat);
    if (fixed > BigInt.zero) return fixed;

    final int bpsInt = AppConfig.platformFeeBps;
    if (bpsInt <= 0) return BigInt.zero;

    final bps = BigInt.from(bpsInt);
    return (amountSat * bps + BigInt.from(9999)) ~/ BigInt.from(10000);
  }

  BigInt _calcMaxSendableAmountSat() {
    final fee = _estimatedFeeSat;
    if (_availableBalanceSat <= fee) return BigInt.zero;

    if (!AppConfig.platformFeeEnabled) {
      return _availableBalanceSat - fee;
    }

    final fixed = BigInt.from(AppConfig.platformFeeSat);
    final int bpsInt = AppConfig.platformFeeBps;

    if (fixed > BigInt.zero) {
      final needed = fee + fixed;
      if (_availableBalanceSat <= needed) return BigInt.zero;
      return _availableBalanceSat - needed;
    }

    if (bpsInt > 0) {
      final bps = BigInt.from(bpsInt);
      final avail = _availableBalanceSat - fee;
      final denom = BigInt.from(10000) + bps;

      BigInt amt = (avail * BigInt.from(10000)) ~/ denom;

      for (int i = 0; i < 3; i++) {
        final pf = _calcPlatformFeeSat(amt);
        if (amt + fee + pf <= _availableBalanceSat) break;
        if (amt > BigInt.zero) {
          amt -= BigInt.one;
        } else {
          break;
        }
      }

      return amt;
    }

    return _availableBalanceSat - fee;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) {
      _addressController.text = widget.initialAddress!;
    }
    _initFlow();
  }

  Future<void> _initFlow() async {
    final wallet = await _storageService.getCurrentWallet();
    if (wallet == null) return;

    if (mounted) {
      setState(() => _currentWallet = wallet);
    }

    await _loadBalanceFromCache(wallet.address);
    _refreshBalanceFromServer(wallet.address);
  }

  Future<void> _loadBalanceFromCache(String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedBal = prefs.getDouble('${_cachePrefix}bal_$address') ?? 0.0;

      if (cachedBal > 0 && mounted) {
        setState(() {
          _availableBalance = cachedBal;
          _availableBalanceSat = AmountUtils.coinTextToSat(
            _availableBalance.toStringAsFixed(AppConfig.coinDecimals),
          );
        });
      }
    } catch (e) {
      debugPrint('读取发送页缓存失败: $e');
    }
  }

  Future<void> _refreshBalanceFromServer(String address) async {
    try {
      final balanceData = await _walletService.getBalance(address);
      final double bal =
          double.tryParse(balanceData['balance'].toString()) ?? 0.0;
      final BigInt balSat = BigInt.from(balanceData['balance_sat'] ?? 0);

      if (!mounted) return;

      setState(() {
        _availableBalance = bal;
        _availableBalanceSat = balSat;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('${_cachePrefix}bal_$address', bal);
    } catch (e) {
      debugPrint('发送页静默刷新失败: $e');
    }
  }

  Future<void> _scanAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (result != null && result is String) {
      setState(() => _addressController.text = result);
    }
  }

  Future<void> _send() async {
    final loc = L10n.of(context);
    final address = _addressController.text.trim();
    final amountText = _amountController.text.trim();

    if (address.isEmpty || amountText.isEmpty) {
      TopToast.show(
        context,
        message: loc.t('toast_invalid_address_amount'),
        type: TopToastType.error,
      );
      return;
    }

    final amountSat = AmountUtils.coinTextToSat(amountText);
    if (amountSat <= BigInt.zero) {
      TopToast.show(
        context,
        message: loc.t('toast_invalid_address_amount'),
        type: TopToastType.error,
      );
      return;
    }

    final platformFeeSat =
    AppConfig.platformFeeEnabled ? _calcPlatformFeeSat(amountSat) : BigInt.zero;

    // 防止误把平台手续费地址当作收款地址
    final String platformFeeAddress = _walletService.platformFeeAddress;
    if (address.toLowerCase() == platformFeeAddress.toLowerCase()) {
      TopToast.show(
        context,
        message: '收款地址不能是平台手续费地址',
        type: TopToastType.error,
      );
      return;
    }

    final totalDebitSat = amountSat + _estimatedFeeSat + platformFeeSat;

    if (totalDebitSat > _availableBalanceSat) {
      TopToast.show(
        context,
        message: loc.t('toast_insufficient_balance_fee'),
        type: TopToastType.error,
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final authGate = TxAuthGate();
      final authed = await authGate.requireAuth(
        context,
        reason: loc.t('tx_auth_reason'),
      );

      if (!authed) {
        setState(() => _isSending = false);
        return;
      }

      final wallet = _currentWallet;
      if (wallet == null) throw Exception('no_wallet');

      final mnemonic = await _storageService.getWalletMnemonic(wallet);

      final txid = await _walletService.sendTransaction(
        mnemonic: mnemonic!,
        toAddress: address,
        amountSat: amountSat,
        feeSat: null,
        platformFeeSat: (AppConfig.platformFeeEnabled && platformFeeSat > BigInt.zero)
            ? platformFeeSat
            : null,
      );

      // 只发事件，让交易列表去刷新/轮询
      EventBus().fire(RefreshWalletEvent(txHash: txid));

      if (mounted) {
        _showSuccessDialog(txid);
      }
    } catch (e) {
      debugPrint('发送过程发生错误: $e');
      TopToast.show(
        context,
        message: loc.t('toast_transfer_failed'),
        type: TopToastType.error,
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSuccessDialog(String txid) {
    final loc = L10n.of(context);
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.green,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              loc.t('broadcast'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'TXID: ${txid.substring(0, 8)}...${txid.substring(txid.length - 8)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white38,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 32),
            AppPressable(
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(true);
              },
              color: AppColors.button,
              borderRadius: AppRadii.pill,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 40),
              child: Text(
                loc.t('finish'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final loc = L10n.of(context);

    return AppScaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.t('send'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildAddressField(loc),
                    const SizedBox(height: 16),
                    _buildAmountField(loc),
                    const SizedBox(height: 12),
                    _buildBalanceInfo(loc),
                  ],
                ),
              ),
            ),
            _buildBottomAction(loc),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressField(L10n loc) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadii.pill,
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: _addressController,
        maxLines: 1,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: loc.t('enterTheAddress'),
          hintStyle: const TextStyle(color: Colors.white12, fontSize: 14),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: const Icon(
              Icons.qr_code_scanner_rounded,
              color: AppColors.button,
              size: 20,
            ),
            onPressed: _scanAddress,
          ),
        ),
      ),
    );
  }

  Widget _buildAmountField(L10n loc) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadii.pill,
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: _amountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          hintText: loc.t('0.00'),
          hintStyle: const TextStyle(
            color: Colors.white12,
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: InputBorder.none,
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _assetSymbol,
                  style: const TextStyle(
                    color: AppColors.button,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceInfo(L10n loc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "${loc.t('availableBalance')}: ${_formatBalance(_availableBalance)} $_assetSymbol",
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          AppPressable(
            onTap: () {
              final maxSat = _calcMaxSendableAmountSat();
              if (maxSat > BigInt.zero) {
                final double coinValue =
                double.parse(AmountUtils.satToCoinFixed(maxSat));
                _amountController.text = _formatBalance(coinValue);
              }
            },
            color: AppColors.button.withOpacity(0.1),
            borderRadius: AppRadii.r12,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: const Text(
              "MAX",
              style: TextStyle(
                color: AppColors.button,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(L10n loc) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: AppPressable(
        onTap: _isSending ? null : _send,
        color: AppColors.button,
        borderRadius: AppRadii.pill,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: _isSending
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : Text(
            loc.t('confirmAndSend'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
