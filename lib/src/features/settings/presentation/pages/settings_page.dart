import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 核心组件与主题
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_radii.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_bottom_drawer.dart';
import '../../../../core/widgets/top_toast.dart';

// 业务页面与服务
import '../../../settings/presentation/pages/security_page.dart';
import '../../../settings/presentation/pages/tx_auth_gate.dart';
import '../../../../../utils/I10n.dart';

import '../../../../../services/storage_service.dart';
import '../../../wallet/domain/wallet.dart';
import '../../../onboarding/presentation/pages/onboarding_page.dart';

class SettingsPage extends StatelessWidget {
  SettingsPage({super.key});

  final StorageService _storageService = StorageService();

  // --- 语言选择弹窗 ---
  Future<void> _showLanguageSheet(BuildContext context) async {
    final controller = LocaleController.instance;
    final loc = L10n.of(context);

    await AppBottomDrawer.show(
      context,
      maxHeightFactor: 0.50,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              loc.t('language'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _LanguageOption(
                  title: loc.t('lang_zh'),
                  selected: controller.currentLocale.languageCode == 'zh',
                  onTap: () async {
                    await controller.setLocale(const Locale('zh'));
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 12),
                _LanguageOption(
                  title: loc.t('lang_en'),
                  selected: controller.currentLocale.languageCode == 'en',
                  onTap: () async {
                    await controller.setLocale(const Locale('en'));
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 删除钱包：先确认，再做安全验证，再删除（避免用户取消也弹验证）
  Future<void> _deleteCurrentWallet(BuildContext context) async {
    final loc = L10n.of(context);

    final wallets = await _storageService.getWalletList();
    if (wallets.isEmpty) return;
    final idx = await _storageService.getCurrentWalletIndex();
    final Wallet current = wallets[idx.clamp(0, wallets.length - 1)];

    HapticFeedback.heavyImpact();
    final bool? confirmed = await AppBottomDrawer.show<bool>(
      context,
      maxHeightFactor: 0.60,
      child: _DeleteWalletConfirmSheet(wallet: current),
    );

    if (confirmed != true) return;

    // 安全验证（密码/生物识别）
    final authed = await TxAuthGate().requireAuth(
      context,
      reason: loc.t('tx_auth_reason'),
    );
    if (authed != true) return;

    try {
      await _storageService.deleteWallet(current);
      final after = await _storageService.getWalletList();
      if (!context.mounted) return;

      TopToast.successKey(context, 'wallet_deleted');
      if (after.isEmpty) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingPage()),
              (_) => false,
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final loc = L10n.of(context);

    return AppScaffold(
      statusBarIconBrightness: Brightness.light,
      useSafeArea: false,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.t('settings'),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 16),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.language_rounded,
                title: loc.t('language'),
                onTap: () => _showLanguageSheet(context),
              ),
              _SettingsTile(
                icon: Icons.security_rounded,
                title: loc.t('security'),
                isLast: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SecurityPage()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.shield_moon_rounded,
                title: loc.t('backup_mnemonic'),
                subtitle: loc.t('backup_mnemonic_desc'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BackupMnemonicPage()),
                ),
              ),
              _SettingsTile(
                icon: Icons.delete_forever_rounded,
                iconColor: AppColors.error,
                title: loc.t('delete_wallet'),
                subtitle: loc.t('delete_wallet_desc'),
                onTap: () => _deleteCurrentWallet(context),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 60),
          const Center(
            child: Text(
              "SCASH Wallet v1.0.0",
              style: TextStyle(color: Colors.white12, fontSize: 11),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// -------------------- 备份助记词页（新增：显示/复制前做安全验证） --------------------
class BackupMnemonicPage extends StatefulWidget {
  const BackupMnemonicPage({super.key});

  @override
  State<BackupMnemonicPage> createState() => _BackupMnemonicPageState();
}

class _BackupMnemonicPageState extends State<BackupMnemonicPage> {
  final StorageService _storageService = StorageService();

  bool _loading = true;
  bool _revealed = false;

  Wallet? _wallet;
  String? _mnemonic;
  bool _authed = false;

  @override
  void initState() {
    super.initState();
    _loadWalletOnly();
  }

  Future<void> _loadWalletOnly() async {
    try {
      final wallet = await _storageService.getCurrentWallet();
      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<bool> _ensureAuthed() async {
    if (_authed) return true;

    final loc = L10n.of(context);
    final ok = await TxAuthGate().requireAuth(
      context,
      reason: loc.t('tx_auth_reason'),
    );

    if (!mounted) return false;
    if (ok == true) {
      setState(() => _authed = true);
      return true;
    }
    return false;
  }

  Future<void> _ensureMnemonicLoaded() async {
    if (_mnemonic != null) return;

    final wallet = _wallet;
    if (wallet == null) return;

    final mnemonic = await _storageService.getWalletMnemonic(wallet);
    if (!mounted) return;
    setState(() => _mnemonic = mnemonic?.trim());
  }

  Future<void> _toggleReveal() async {
    // 只有从“隐藏 -> 显示”才做验证
    if (!_revealed) {
      HapticFeedback.mediumImpact();

      final ok = await _ensureAuthed();
      if (!ok) return;

      await _ensureMnemonicLoaded();
      if (!mounted) return;

      if ((_mnemonic ?? '').isEmpty) {
        TopToast.errorKey(context, 'mnemonic_empty');
        return;
      }
    }

    setState(() => _revealed = !_revealed);
  }

  Future<void> _copyMnemonic() async {
    HapticFeedback.lightImpact();

    final ok = await _ensureAuthed();
    if (!ok) return;

    await _ensureMnemonicLoaded();
    if (!mounted) return;

    if ((_mnemonic ?? '').isEmpty) {
      TopToast.errorKey(context, 'mnemonic_empty');
      return;
    }

    await Clipboard.setData(ClipboardData(text: _mnemonic!));
    if (mounted) TopToast.successKey(context, 'backup_mnemonic_copied');
  }

  @override
  Widget build(BuildContext context) {
    final loc = L10n.of(context);

    return AppScaffold(
      statusBarIconBrightness: Brightness.light,
      useSafeArea: false,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.t('backup_mnemonic_title'),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(color: AppColors.button),
      )
          : ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _buildWarningCard(loc.t('backup_mnemonic_warning')),
          const SizedBox(height: 24),
          _buildMnemonicBox(loc),
          const SizedBox(height: 40),
          _buildCopyButton(loc),
        ],
      ),
    );
  }

  Widget _buildWarningCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.05),
        borderRadius: AppRadii.r16,
        border: Border.all(color: AppColors.error.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMnemonicBox(L10n loc) {
    return GestureDetector(
      onTap: _toggleReveal,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: AppRadii.r20,
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  loc.t('backup_mnemonic'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  _revealed
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _revealed
                  ? Text(
                _mnemonic ?? "",
                key: const ValueKey('shown'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  height: 1.8,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.bold,
                ),
              )
                  : Container(
                key: const ValueKey('hidden'),
                height: 60,
                alignment: Alignment.center,
                child: Text(
                  "•••• •••• •••• ••••",
                  style: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.3),
                    fontSize: 24,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopyButton(L10n loc) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: (_wallet == null) ? null : _copyMnemonic,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.button,
          disabledBackgroundColor: AppColors.button.withOpacity(0.15),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.pill),
          elevation: 0,
        ),
        child: Text(
          loc.t('backup_mnemonic_copy'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

// -------------------- UI 辅助组件 --------------------

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadii.r20,
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ClipRRect(
        borderRadius: AppRadii.r20,
        child: Column(children: children),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isLast;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.iconColor,
    this.subtitle,
    this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: AppColors.highlight,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (iconColor ?? AppColors.button).withOpacity(0.10),
                      borderRadius: AppRadii.r12,
                    ),
                    child: Icon(icon,
                        color: iconColor ?? AppColors.button, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withOpacity(0.15),
                    size: 12,
                  ),
                ],
              ),
            ),
            if (!isLast)
              Divider(
                height: 1,
                indent: 56,
                endIndent: 16,
                color: Colors.white.withOpacity(0.03),
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.r16,
        splashFactory: NoSplash.splashFactory,
        highlightColor: AppColors.highlight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: selected ? AppColors.button.withOpacity(0.05) : AppColors.card,
            borderRadius: AppRadii.r16,
            border: Border.all(
              color: selected ? AppColors.button : Colors.white.withOpacity(0.05),
              width: selected ? 1 : 0.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: selected ? AppColors.button : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.button, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteWalletConfirmSheet extends StatelessWidget {
  final Wallet wallet;
  const _DeleteWalletConfirmSheet({required this.wallet});

  @override
  Widget build(BuildContext context) {
    final loc = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            loc.t('delete_wallet_confirm_title'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            loc.t('delete_wallet_confirm_body'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    loc.t('cancel'),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: AppRadii.r12),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    loc.t('delete'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
