import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../utils/I10n.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_radii.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../profile/presentation/pages/set_app_password_page.dart';
import '../../../../core/widgets/app_scaffold.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  static const String _kPrefFingerprint = 'security_fingerprint_enabled';
  static const String _kPrefFaceId = 'security_faceid_enabled';
  static const String _kSecPwdSalt = 'security_app_lock_salt';
  static const String _kSecPwdHash = 'security_app_lock_hash';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _hasPassword = false;
  bool _fingerprintEnabled = false;
  bool _faceIdEnabled = false;
  bool _supportsFingerprint = false;
  bool _supportsFaceId = false;
  bool _supportsAnyBiometric = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadPasswordState(),
      _loadBiometricPrefs(),
      _refreshBiometricSupport(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadPasswordState() async {
    final salt = await _secureStorage.read(key: _kSecPwdSalt);
    final hash = await _secureStorage.read(key: _kSecPwdHash);
    _hasPassword = (salt != null && salt.isNotEmpty && hash != null && hash.isNotEmpty);
  }

  Future<void> _loadBiometricPrefs() async {
    final sp = await SharedPreferences.getInstance();
    _fingerprintEnabled = sp.getBool(_kPrefFingerprint) ?? false;
    _faceIdEnabled = sp.getBool(_kPrefFaceId) ?? false;
  }

  Future<void> _saveBiometricPref(String key, bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(key, value);
  }

  Future<void> _refreshBiometricSupport() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      if (!canCheck || !supported) return;
      final types = await _localAuth.getAvailableBiometrics();
      _supportsFingerprint = types.contains(BiometricType.fingerprint);
      _supportsFaceId = types.contains(BiometricType.face);
      _supportsAnyBiometric = _supportsFingerprint || _supportsFaceId || types.contains(BiometricType.strong);
    } catch (e) {
      _supportsAnyBiometric = false;
    }
  }

  Future<bool> _biometricAuth({required String reason}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
            useErrorDialogs: true
        ),
      );
    } catch (e) {
      return false;
    }
  }

  /// 进入重置/修改流程的逻辑
  Future<void> _openSetOrChangePassword() async {
    final loc = L10n.of(context);

    if (_hasPassword && (_fingerprintEnabled || _faceIdEnabled)) {
      final authenticated = await _biometricAuth(reason: loc.t('security_auth_to_change'));
      if (!authenticated) return; // 验证失败或取消，直接返回，不破坏任何现有数据
    }

    final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => SetAppPasswordPage(
                requiredSetup: false,
                changeMode: _hasPassword
            )
        )
    );

    if (result == true) {
      await _loadPasswordState();
      if (mounted) {
        setState(() {});
        TopToast.show(
            context,
            message: loc.t(_hasPassword ? 'pwd_change_success' : 'pwd_save_success'),
            type: TopToastType.success
        );
      }
    }
  }

  Future<void> _toggleAndroidBiometric(bool enable) async {
    if (!_supportsAnyBiometric) return;
    final ok = await _biometricAuth(reason: L10n.of(context).t('security_title'));
    if (!ok) {
      if (mounted) setState(() => _fingerprintEnabled = !enable);
      return;
    }
    setState(() => _fingerprintEnabled = enable);
    await _saveBiometricPref(_kPrefFingerprint, enable);
  }

  Future<void> _toggleIosFaceId(bool enable) async {
    if (!_supportsFaceId) return;
    final ok = await _biometricAuth(reason: L10n.of(context).t('security_title'));
    if (!ok) {
      if (mounted) setState(() => _faceIdEnabled = !enable);
      return;
    }
    setState(() => _faceIdEnabled = enable);
    await _saveBiometricPref(_kPrefFaceId, enable);
  }

  @override
  Widget build(BuildContext context) {
    final loc = L10n.of(context);
    return AppScaffold(
      statusBarIconBrightness: Brightness.light,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(loc.t('security_title'),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator(color: AppColors.textSecondary))
          : ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 16),
          _sectionTitle(loc.t('security_account_section')),
          const SizedBox(height: 8),
          _buildOptionTile(
            icon: Icons.lock_outline_rounded,
            title: _hasPassword ? loc.t('security_change_password') : loc.t('security_set_password'),
            subtitle: _hasPassword ? loc.t('security_password_set') : loc.t('security_password_not_set'),
            onTap: _openSetOrChangePassword,
          ),
          if (Platform.isAndroid)
            _buildOptionTile(
              icon: Icons.fingerprint_rounded,
              title: _supportsFingerprint ? loc.t('security_fingerprint_unlock') : loc.t('security_biometric_unlock'),
              subtitle: _supportsAnyBiometric ? loc.t('security_bio_quick_unlock') : loc.t('security_unavailable'),
              trailing: _buildSwitch(_fingerprintEnabled, _supportsAnyBiometric, (v) => _toggleAndroidBiometric(v)),
            ),
          if (Platform.isIOS)
            _buildOptionTile(
              icon: Icons.face_rounded,
              title: loc.t('security_faceid_unlock'),
              subtitle: _supportsFaceId ? loc.t('security_faceid_quick_unlock') : loc.t('security_unavailable'),
              trailing: _buildSwitch(_faceIdEnabled, _supportsFaceId, (v) => _toggleIosFaceId(v)),
            ),
          const SizedBox(height: 32),
          _sectionTitle(loc.t('security_tips_section')),
          const SizedBox(height: 12),
          _buildTipsCard(loc.t('security_tip_text')),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadii.r16,
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.r16,
          highlightColor: AppColors.highlight,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.button.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.button, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                trailing ?? const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitch(bool value, bool enabled, Function(bool) onChanged) {
    return CupertinoSwitch(
      value: value,
      activeColor: AppColors.button,
      trackColor: Colors.white.withOpacity(0.1),
      onChanged: enabled ? onChanged : null,
    );
  }

  Widget _buildTipsCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: AppRadii.r16,
        border: Border.all(color: Colors.white.withOpacity(0.05), style: BorderStyle.solid),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}