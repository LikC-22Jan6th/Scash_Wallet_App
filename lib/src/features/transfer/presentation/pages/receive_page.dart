import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../../utils/I10n.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_radii.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../../../services/storage_service.dart';
import '../../../wallet/domain/wallet.dart';

class ReceivePage extends StatefulWidget {
  const ReceivePage({super.key});

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  Wallet? _currentWallet;
  String _address = '';
  bool _isLoading = true;
  String? _errorMessageKey;

  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() {
      _isLoading = true;
      _errorMessageKey = null;
    });

    try {
      final wallet = await _storageService.getCurrentWallet();

      if (wallet == null || wallet.address.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessageKey = 'receive_no_wallet_address';
        });
        return;
      }

      setState(() {
        _currentWallet = wallet;
        _address = wallet.address;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessageKey = 'receive_init_failed';
      });
    }
  }

  void _copyToClipboard() {
    if (_address.isEmpty) return;
    HapticFeedback.heavyImpact();
    Clipboard.setData(ClipboardData(text: _address));
    TopToast.show(context, message: L10n.of(context).t('toast_address_copied'), type: TopToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final loc = L10n.of(context);

    return AppScaffold(
      statusBarIconBrightness: Brightness.light,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          loc.t('receive_scash_title'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.button))
              : _buildBody(loc),
        ),
      ),
    );
  }

  Widget _buildBody(L10n loc) {
    if (_errorMessageKey != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(loc.t(_errorMessageKey!), style: const TextStyle(color: Colors.white70)),
            TextButton(onPressed: _initData, child: Text(loc.t('retry'))),
          ],
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 20),

        // --- 警告提示文字：更精致的排版 ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: AppRadii.pill,
          ),
          child: Text(
            loc.t('receive_scash_warning'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),

        const SizedBox(height: 40),

        // --- 二维码展示区域：带发光的药丸卡片风格 ---
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: AppColors.button.withOpacity(0.05),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // 二维码白色容器
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadii.r20,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)
                    ]
                ),
                child: QrImageView(
                  data: 'scash:$_address',
                  size: 200,
                  padding: EdgeInsets.zero,
                  embeddedImage: const AssetImage('assets/images/scash-logo.png'),
                  embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(44, 44)),
                ),
              ),
              const SizedBox(height: 16),

              // 地址点击复制区域
              AppPressable(
                onTap: _copyToClipboard,
                color: Colors.transparent,
                borderRadius: AppRadii.r20,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // 地址文字显示区域
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05), // 微弱的深色块
                        borderRadius: AppRadii.r12,
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Text(
                        _address,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 复制提示
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.copy_rounded, size: 14, color: AppColors.button),
                        const SizedBox(width: 6),
                        Text(
                          loc.t('receive_copy_tip'),
                          style: const TextStyle(
                            color: AppColors.button,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),

        const Spacer(),

        // --- 底部确认提示：弱化背景 ---
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: AppRadii.r16,
          ),
          child: Row(
            children: [
              Icon(Icons.info_rounded, color: Colors.white.withOpacity(0.3), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loc.t('receive_confirm_warning'),
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}