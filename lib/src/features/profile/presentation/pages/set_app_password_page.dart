import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_radii.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../../../utils/I10n.dart';
import '../../../../core/widgets/app_scaffold.dart';

class SetAppPasswordPage extends StatefulWidget {
  final bool requiredSetup;
  final bool changeMode;

  const SetAppPasswordPage({
    super.key,
    this.requiredSetup = false,
    this.changeMode = false,
  });

  @override
  State<SetAppPasswordPage> createState() => _SetAppPasswordPageState();
}

class _SetAppPasswordPageState extends State<SetAppPasswordPage> {
  static const String _kSecPwdSalt = 'security_app_lock_salt';
  static const String _kSecPwdHash = 'security_app_lock_hash';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  // 记录字段错误信息，用于外置提示
  final Map<String, String?> _fieldErrors = {};

  bool _submitting = false;
  bool _hasExistingPassword = false;
  bool _resetMode = false;

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _loadExistingState();
  }

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ------ 加载现有状态 ------
  Future<void> _loadExistingState() async {
    final salt = await _secureStorage.read(key: _kSecPwdSalt);
    final hash = await _secureStorage.read(key: _kSecPwdHash);
    final has = salt != null && salt.isNotEmpty && hash != null && hash.isNotEmpty;
    if (!mounted) return;
    setState(() => _hasExistingPassword = has);
  }

  // ------ 加密逻辑 ------
  List<int> _randomBytes(int len) {
    final r = Random.secure();
    return List<int>.generate(len, (_) => r.nextInt(256));
  }

  String _hashPassword(String password, List<int> salt) {
    final bytes = <int>[...salt, ...utf8.encode(password)];
    return sha256.convert(bytes).toString();
  }

  Future<bool> _verifyOldPassword(String oldPwd) async {
    final saltB64 = await _secureStorage.read(key: _kSecPwdSalt);
    final storedHash = await _secureStorage.read(key: _kSecPwdHash);
    if (saltB64 == null || storedHash == null) return false;
    final salt = base64Decode(saltB64);
    final hash = _hashPassword(oldPwd, salt);
    return hash == storedHash;
  }

  // ------ 核心操作 ------
  bool _validate() {
    final loc = L10n.of(context);
    final errors = <String, String?>{};
    final bool needOld = (widget.changeMode || _hasExistingPassword) && !_resetMode;

    if (needOld && _oldController.text.isEmpty) {
      errors['old'] = loc.t('pwd_old_hint');
    }
    if (_newController.text.trim().length < 6) {
      errors['new'] = loc.t('pwd_min_len');
    }
    if (_confirmController.text != _newController.text) {
      errors['confirm'] = loc.t('pwd_mismatch');
    }

    setState(() {
      _fieldErrors.clear();
      _fieldErrors.addAll(errors);
    });
    return errors.isEmpty;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_validate()) return;

    setState(() => _submitting = true);
    try {
      final bool needOld = (widget.changeMode || _hasExistingPassword) && !_resetMode;
      if (needOld) {
        final ok = await _verifyOldPassword(_oldController.text);
        if (!ok) {
          setState(() => _fieldErrors['old'] = L10n.of(context).t('pwd_old_wrong'));
          return;
        }
      }

      final salt = _randomBytes(16);
      final hash = _hashPassword(_newController.text, salt);
      await _secureStorage.write(key: _kSecPwdSalt, value: base64Encode(salt));
      await _secureStorage.write(key: _kSecPwdHash, value: hash);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      TopToast.show(context, message: L10n.of(context).t('pwd_save_failed'), type: TopToastType.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _forgotPasswordReset() async {
    final loc = L10n.of(context);
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!supported || !canCheck) {
        TopToast.show(context, message: loc.t('security_bio_unavailable'), type: TopToastType.error);
        return;
      }
      final ok = await _localAuth.authenticate(
        localizedReason: loc.t('pwd_bio_reason_reset'),
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (!ok) return;

      await _secureStorage.delete(key: _kSecPwdSalt);
      await _secureStorage.delete(key: _kSecPwdHash);

      setState(() {
        _hasExistingPassword = false;
        _resetMode = true;
        _oldController.clear();
        _fieldErrors.clear();
      });
      TopToast.show(context, message: loc.t('pwd_reset_ready'), type: TopToastType.success);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final loc = L10n.of(context);
    final bool needOld = (widget.changeMode || _hasExistingPassword) && !_resetMode;

    return AppScaffold(
      statusBarIconBrightness: Brightness.light,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.requiredSetup
            ? null
            : IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          _resetMode ? loc.t('pwd_reset_title') : (widget.changeMode ? loc.t('pwd_change_title') : loc.t('pwd_setup_title')),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      // --- 头部锁图标 ---
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: const Icon(Icons.lock_person_rounded, color: AppColors.button, size: 32),
                      ),
                      const SizedBox(height: 32),

                      // --- 动态输入框列表 ---
                      if (needOld) ...[
                        _buildManagedPillField(
                          id: 'old',
                          controller: _oldController,
                          hint: loc.t('pwd_old_hint'),
                          isObscure: _obscureOld,
                          onToggle: () => setState(() => _obscureOld = !_obscureOld),
                        ),
                        const SizedBox(height: 12),
                      ],

                      _buildManagedPillField(
                        id: 'new',
                        controller: _newController,
                        hint: loc.t('pwd_new_hint'),
                        isObscure: _obscureNew,
                        onToggle: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                      const SizedBox(height: 12),

                      _buildManagedPillField(
                        id: 'confirm',
                        controller: _confirmController,
                        hint: loc.t('pwd_confirm_hint'),
                        isObscure: _obscureConfirm,
                        onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),

                      // --- 忘记密码按钮 ---
                      if (needOld)
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: _forgotPasswordReset,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12, right: 12),
                              child: Text(
                                loc.t('pwd_forgot'),
                                style: const TextStyle(
                                  color: AppColors.button,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // --- 底部确认按钮 ---
              Padding(
                padding: const EdgeInsets.only(bottom: 24, top: 12),
                child: _buildPrimaryButton(
                  label: loc.t('done'),
                  onPressed: _submit,
                  isLoading: _submitting,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建带外置校验提示的输入框
  Widget _buildManagedPillField({
    required String id,
    required TextEditingController controller,
    required String hint,
    required bool isObscure,
    required VoidCallback onToggle,
  }) {
    final error = _fieldErrors[id];
    final hasError = error != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: AppRadii.pill,
            border: Border.all(
              color: hasError ? Colors.redAccent.withOpacity(0.5) : Colors.white.withOpacity(0.05),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: isObscure,
            onChanged: (_) {
              if (_fieldErrors.containsKey(id)) {
                setState(() => _fieldErrors.remove(id));
              }
            },
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              // 密码隐藏时增加间距感，显示时恢复正常
              letterSpacing: isObscure ? 2.0 : 0.5,
            ),
            cursorColor: AppColors.button,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.3),
                fontSize: 14,
                letterSpacing: 0,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              border: InputBorder.none,
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: Icon(
                    isObscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 20,
                    color: AppColors.textSecondary.withOpacity(0.4),
                  ),
                  onPressed: onToggle,
                ),
              ),
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: hasError ? 28 : 0,
          padding: const EdgeInsets.only(left: 20, top: 6),
          child: hasError
              ? Text(
            error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          )
              : null,
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : () {
        HapticFeedback.mediumImpact();
        onPressed();
      },
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: isLoading ? AppColors.button.withOpacity(0.5) : AppColors.button,
          borderRadius: AppRadii.pill,
          boxShadow: [
            if (!isLoading)
              BoxShadow(
                color: AppColors.button.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          )
              : Text(
            label,
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