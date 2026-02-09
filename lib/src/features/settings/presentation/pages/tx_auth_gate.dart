import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../services/app_password_service.dart';
import '../../../../../utils/I10n.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_bottom_drawer.dart';
import '../../../../core/widgets/app_radii.dart';
import '../../../../core/widgets/top_toast.dart';

class TxAuthGate {
  static const String kPrefFingerprint = 'security_fingerprint_enabled';
  static const String kPrefFaceId = 'security_faceid_enabled';

  final LocalAuthentication _localAuth;
  final AppPasswordService _pwd;

  TxAuthGate({
    LocalAuthentication? localAuth,
    AppPasswordService? passwordService,
  })  : _localAuth = localAuth ?? LocalAuthentication(),
        _pwd = passwordService ?? AppPasswordService();

  /// 返回 true 才允许继续发币
  Future<bool> requireAuth(
      BuildContext context, {
        required String reason,
      }) async {
    final sp = await SharedPreferences.getInstance();

    final bool bioEnabled = Platform.isIOS
        ? (sp.getBool(kPrefFaceId) ?? false)
        : (sp.getBool(kPrefFingerprint) ?? false);

    final bool hasAppPwd = await _pwd.hasPassword();

    // 两者都没配置：默认不拦（你也可以改成强制 return false 并提示去设置）
    if (!bioEnabled && !hasAppPwd) return true;

    // 生物识别优先
    if (bioEnabled) {
      final ok = await _tryBiometric(reason: reason);
      if (ok) return true;

      // 生物识别失败/取消：有密码就回退密码；没密码就拒绝
      if (!hasAppPwd) return false;
    }

    // 回退 App 密码
    if (hasAppPwd) {
      return await _promptPasswordAndVerify(context);
    }

    return false;
  }

  Future<bool> _tryBiometric({required String reason}) async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      if (!canCheck || !supported) return false;

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> _promptPasswordAndVerify(BuildContext context) async {
    final bool? ok = await AppBottomDrawer.show<bool>(
      context,
      maxHeightFactor: 0.55,
      child: _TxPasswordSheet(passwordService: _pwd),
    );
    return ok == true;
  }
}

class _TxPasswordSheet extends StatefulWidget {
  final AppPasswordService passwordService;
  const _TxPasswordSheet({required this.passwordService});

  @override
  State<_TxPasswordSheet> createState() => _TxPasswordSheetState();
}

class _TxPasswordSheetState extends State<_TxPasswordSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toastTop(String msg, {TopToastType type = TopToastType.error}) {
    TopToast.show(context, message: msg, type: type);
  }

  Future<void> _confirm() async {
    if (_submitting) return;
    final loc = L10n.of(context);

    final pass = _controller.text.trim();
    if (pass.isEmpty) {
      _toastTop(loc.t('tx_auth_pwd_hint'), type: TopToastType.info);
      return;
    }

    setState(() => _submitting = true);
    try {
      final verified = await widget.passwordService.verify(pass);
      if (!mounted) return;

      if (!verified) {
        HapticFeedback.lightImpact();
        _toastTop(loc.t('tx_auth_pwd_wrong'), type: TopToastType.error);
        return; // 不关闭，允许继续输入
      }

      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      _toastTop(loc.t('toast_operation_failed'), type: TopToastType.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = L10n.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.button.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded, color: AppColors.button, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                loc.t('tx_auth_pwd_title'),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context, false),
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: AppRadii.r16,
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 2),
            cursorColor: AppColors.button,
            decoration: InputDecoration(
              hintText: loc.t('tx_auth_pwd_hint'),
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 14, letterSpacing: 0),
              border: InputBorder.none,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
              ),
            ),
            onSubmitted: (_) => _confirm(),
          ),
        ),

        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting ? null : () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.16)),
                  shape: RoundedRectangleBorder(borderRadius: AppRadii.r16),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(loc.t('cancel')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _submitting ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.button,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.button.withOpacity(0.35),
                  shape: RoundedRectangleBorder(borderRadius: AppRadii.r16),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : Text(loc.t('tx_auth_confirm')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
