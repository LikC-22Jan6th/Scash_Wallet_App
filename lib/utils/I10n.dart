import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class L10n {
  final Locale locale;

  L10n(this.locale);

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = L10nDelegate();

  static const Map<String, Map<String, String>> _localizedValues = {
    'zh': {
      // ----- Common -----
      'app_name': 'Scash Wallet',
      'ok': '好的',
      'cancel': '取消',
      'done': '完成',
      'close': '关闭',
      'retry': '重试',
      'unknown': '未知',
      'confirm': '确认',

      // Toast type labels
      'toast_info': '提示',
      'toast_success': '成功',
      'toast_error': '错误',

      // Generic toasts
      'toast_network_timeout': '网络连接超时',
      'toast_network_error': '网络异常',
      'toast_request_failed': '请求失败，请稍后重试',
      'toast_operation_failed': '操作失败，请重试',
      'toast_server_error': '服务器异常，请稍后重试',
      'toast_service_unavailable': '服务暂时不可用，请稍后重试',
      'toast_invalid_address_amount': '请输入有效的地址和金额',
      'toast_insufficient_balance_fee': '余额不足以支付转账及手续费',
      'toast_transfer_failed': '转账失败',
      'toast_address_copied': '地址已复制',
      'toast_mnemonic_copied': '助记词已复制到剪贴板',

      // ----- Onboarding -----
      'welcome': '欢迎',
      'app_intro': '你的去中心化钱包',
      'create_or_add_wallet': '请创建或导入一个钱包开始使用',
      'create_wallet': '创建钱包',
      'import_wallet': '导入钱包',
      'create_wallet_desc': '生成新的助记词并创建钱包',
      'import_wallet_desc': '使用已有助记词导入钱包',
      'start': '开始',

      // ----- Wallet / Home -----
      'wallet': '钱包',
      'history': '历史',
      'all': '全部',
      'sent': '发送',
      'received': '接收',
      'switch_wallet': '切换钱包',
      'add_wallet': '添加钱包',
      'availableBalance': '可用余额',
      'balanceReminder': '余额不足',
      'send': '发送',
      'receive': '接收',
      'scan': '扫描',
      'enterTheAddress': '请输入地址',
      'broadcast': '广播成功',
      'finish': '完成',
      'market_price': '市场价格',
      'assets': '资产',
      'confirmAndSend': '确认并发送',
      'version': '版本',
      'default_wallet_name': '钱包',
      'imported_wallet_name': '钱包',
      'wallet_updated': '钱包已更新',

      // ----- Transactions -----
      'no_transactions': '暂无交易记录',
      'pending': '待处理',
      'confirmation_in_progress': '确认中',
      'confirmations_label': '确认数',
      'tx_broadcast_wait': '交易已广播，等待区块确认...',
      'tx_details': '详细',
      'status': '状态',
      'time': '时间',

      // ----- browser -----
      'browser': '浏览器',
      'browser_home': '首页',
      'browser_search_hint': '搜索或输入地址',
      'browser_top_picks': '精选',
      'browser_explore': '探索生态',
      'browser_defi': '去中心化金融',
      'browser_open': '打开',

      // ----- Receive page -----
      'receive_scash_title': '接收 Scash',
      'receive_scash_warning': '仅支持 Scash 网络资产，转入其他资产可能无法找回',
      'receive_copy_tip': '点击复制收款地址',
      'receive_confirm_warning': '请确认收款地址无误，Scash 交易一经发出不可撤回。',
      'receive_init_failed': '初始化失败',
      'receive_no_wallet_address': '未找到有效的钱包地址',

      // ----- Scan page -----
      'scan_qr_title': '扫描二维码',
      'scan_light_tip': '轻触照亮',
      'scan_invalid_title': '无效地址',
      'scan_invalid_desc': '扫描到的二维码格式不正确，请确保它是 Scash 地址。',

      // ----- Settings -----
      'settings': '设置',
      'language': '语言',
      'security': '安全设置',
      'lang_zh': '中文',
      'lang_en': 'English',

      // ----- Security -----
      'security_title': '安全设置',
      'security_account_section': '账户安全',
      'security_tips_section': '安全提示',
      'security_set_password': '设置密码',
      'security_change_password': '修改密码',
      'security_password_set': '已设置',
      'security_password_not_set': '未设置（建议立即设置）',
      'security_biometric_unlock': '生物识别解锁',
      'security_fingerprint_unlock': '指纹解锁',
      'security_faceid_unlock': 'Face ID 解锁',
      'security_bio_quick_unlock': '使用系统生物识别快速解锁',
      'security_unavailable': '此设备不可用',
      'security_bio_unavailable': '生物识别不可用',
      'security_bio_failed': '生物识别失败',
      'security_tip_text': '请妥善保管助记词与密码，建议开启应用密码与生物识别，提高安全性。',
      'pwd_forgot': '忘记密码？',
      'pwd_forgot_desc': '通过生物识别验证后可重置密码',
      'pwd_reset_title': '重置密码',
      'pwd_reset_ready': '验证成功，请设置新密码',
      'pwd_bio_reason_reset': '验证生物识别以重置应用密码',
      'pwd_bio_required': '需要生物识别验证才能重置密码',
      'pwd_reset_failed': '重置失败，请重试',

      // ----- Delete -----
      'delete_wallet': '删除钱包',
      'delete_wallet_desc': '删除当前钱包及本地数据',
      'delete_wallet_confirm_title': '确认删除钱包？',
      'delete_wallet_confirm_body': '此操作不可恢复，请确保已备份助记词。',
      'delete': '删除',
      'wallet_deleted': '钱包已删除',

      // ----- Password setup page -----
      'pwd_setup_title': '设置应用密码',
      'pwd_change_title': '修改应用密码',
      'pwd_old_label': '旧密码',
      'pwd_old_hint': '请输入旧密码',
      'pwd_new_label': '新密码',
      'pwd_new_hint': '请输入新密码',
      'pwd_confirm_label': '确认密码',
      'pwd_confirm_hint': '请再次输入新密码',
      'pwd_required_before_wallet': '请先设置密码后再进入钱包',
      'pwd_old_wrong': '旧密码不正确',
      'pwd_min_len': '密码至少 6 位',
      'pwd_mismatch': '两次输入的密码不一致',
      'pwd_save_success': '密码已保存',
      'pwd_change_success': '密码已修改',
      'pwd_save_failed': '保存失败，请重试',
      'pwd_change_failed': '修改失败，请重试',

      // ----- Import wallet page -----
      'input_mnemonic': '请输入助记词',
      'restore_mnemonic': '输入助记词恢复钱包',
      'mnemonic_empty': '助记词不能为空',
      'mnemonic_too_short': '助记词数量不足（至少 12 个单词）',
      'mnemonic_invalid': '助记词不正确或无法派生地址',

      // ----- Create wallet page -----
      'create_wallet_title': '创建新钱包',
      'create_wallet_mnemonic_tip': '下面是你的助记词，用于恢复钱包。\n请务必妥善保存，切勿泄露。',
      'copy_mnemonic': '复制助记词',
      'i_backed_up': '我已安全备份',
      'wallet_creating_wait': '钱包还在创建中，请稍候',
      'create_wallet_failed': '创建钱包失败',

      // ----- Send page -----
      'send_invalid': '请输入有效的地址和金额',
      'send_insufficient': '余额不足以支付转账及手续费',
      'send_failed_generic': '转账失败，请稍后重试',

      // ----- Asset chart page -----
      'estimated_value': '估算价值',

      // ----- Backup mnemonic page -----
      'backup_mnemonic': '备份助记词',
      'backup_mnemonic_desc': '查看并备份当前钱包助记词',
      'backup_mnemonic_title': '备份助记词',
      'backup_mnemonic_warning': '助记词等同于资产所有权，请离线抄写并妥善保存，切勿截图/上传/分享给任何人。',
      'backup_mnemonic_copy': '复制助记词',
      'backup_mnemonic_copied': '助记词已复制到剪贴板',
      'backup_mnemonic_reveal': '点击显示助记词',
      'backup_mnemonic_hide': '点击隐藏助记词',
      'mnemonic_not_found': '未找到助记词，请先创建或导入钱包',

      // ----- Tx Auth (SendPage) -----
      'tx_auth_reason': '请验证以确认转账',
      'tx_auth_failed': '认证失败，已取消转账',
      'tx_auth_pwd_title': '输入 App 密码',
      'tx_auth_pwd_hint': '请输入密码',
      'tx_auth_pwd_wrong': '密码错误',
      'tx_auth_confirm': '确认',
    },

    'en': {
      // ----- Common -----
      'app_name': 'Scash Wallet',
      'ok': 'OK',
      'cancel': 'Cancel',
      'done': 'Done',
      'close': 'Close',
      'retry': 'Retry',
      'unknown': 'Unknown',
      'confirm': 'Confirm',

      // Toast type labels
      'toast_info': 'Info',
      'toast_success': 'Success',
      'toast_error': 'Error',

      // Generic toasts
      'toast_network_timeout': 'Network timeout',
      'toast_network_error': 'Network error',
      'toast_request_failed': 'Request failed. Please try again.',
      'toast_server_error': 'Server error. Please try again later.',
      'toast_service_unavailable': 'Service temporarily unavailable. Please try again.',
      'toast_operation_failed': 'Operation failed. Please try again.',
      'toast_invalid_address_amount': 'Enter a valid address and amount',
      'toast_insufficient_balance_fee': 'Insufficient balance for amount + fee',
      'toast_transfer_failed': 'Transfer failed',
      'toast_address_copied': 'Address copied',
      'toast_mnemonic_copied': 'Mnemonic copied',

      // ----- Onboarding -----
      'welcome': 'Welcome',
      'app_intro': 'Your decentralized wallet',
      'create_or_add_wallet': 'Create or import a wallet to get started',
      'create_wallet': 'Create wallet',
      'import_wallet': 'Import wallet',
      'create_wallet_desc': 'Generate a new mnemonic and create a wallet',
      'import_wallet_desc': 'Import an existing wallet with mnemonic',
      'start': 'Start',

      // ----- Wallet / Home -----
      'wallet': 'Wallet',
      'history': 'History',
      'all': 'All',
      'sent': 'Sent',
      'received': 'Received',
      'switch_wallet': 'Switch wallet',
      'add_wallet': 'Add wallet',
      'availableBalance': 'Available balance',
      'balanceReminder': 'Insufficient balance',
      'send': 'Send',
      'receive': 'Receive',
      'scan': 'Scan',
      'enterTheAddress': 'Enter address',
      'broadcast': 'Broadcasted',
      'finish': 'Finish',
      'market_price': 'Market price',
      'assets': 'Assets',
      'confirmAndSend': 'Confirm & Send',
      'version': 'Version',
      'default_wallet_name': 'wallet',
      'imported_wallet_name': 'wallet',
      'wallet_updated': 'Wallet Updated',

      // ----- Transactions -----
      'no_transactions': 'No transactions',
      'pending': 'Pending',
      'confirmation_in_progress': 'Confirming',
      'confirmations_label': 'Confirmations',
      'tx_broadcast_wait': 'Transaction broadcasted. Waiting for confirmations...',
      'tx_details': 'Details',
      'status': 'Status',
      'time': 'Time',

      // ----- browser -----
      'browser': 'Browser',
      'browser_home': 'Home',
      'browser_search_hint': 'Search or type URL',
      'browser_top_picks': 'Top Picks',
      'browser_explore': 'Explore Ecosystem',
      'browser_defi': 'DeFi',
      'browser_open': 'Open',

      // ----- Receive page -----
      'receive_scash_title': 'Receive Scash',
      'receive_scash_warning': 'Only Scash network assets are supported, and transferring to other assets may not be retrievable',
      'receive_copy_tip': 'Tap to copy receiving address',
      'receive_confirm_warning': 'Please confirm the address, Scash transactions are irreversible.',
      'receive_init_failed': 'Initialization failed',
      'receive_no_wallet_address': 'No valid wallet address',

      // ----- Scan page -----
      'scan_qr_title': 'Scan QR code',
      'scan_light_tip': 'Tap to light',
      'scan_invalid_title': 'Invalid address',
      'scan_invalid_desc': 'The QR code is not a valid Scash address.',

      // ----- Settings -----
      'settings': 'Settings',
      'language': 'Language',
      'security': 'Security',
      'lang_zh': '中文',
      'lang_en': 'English',
      'general': 'General',

      // ----- Security -----
      'security_title': 'Security',
      'security_account_section': 'Account',
      'security_tips_section': 'Tips',
      'security_set_password': 'Set password',
      'security_change_password': 'Change password',
      'security_password_set': 'Set',
      'security_password_not_set': 'Not set (recommended)',
      'security_biometric_unlock': 'Biometric unlock',
      'security_fingerprint_unlock': 'Fingerprint unlock',
      'security_faceid_unlock': 'Face ID unlock',
      'security_bio_quick_unlock': 'Use system biometrics for quick unlock',
      'security_unavailable': 'Unavailable on this device',
      'security_bio_unavailable': 'Biometrics unavailable',
      'security_bio_failed': 'Biometric failed',
      'security_tip_text': 'Keep your mnemonic and password safe, Enabling app lock and biometrics is recommended.',
      'pwd_forgot': 'Forgot password?',
      'pwd_forgot_desc': 'Reset after biometric verification',
      'pwd_reset_title': 'Reset password',
      'pwd_reset_ready': 'Verified. Please set a new password.',
      'pwd_bio_reason_reset': 'Verify biometrics to reset the app password',
      'pwd_bio_required': 'Biometric verification is required to reset password',
      'pwd_reset_failed': 'Reset failed. Please try again.',

      // ----- Delete -----
      'delete_wallet': 'Delete wallet',
      'delete_wallet_desc': 'Remove current wallet and local data',
      'delete_wallet_confirm_title': 'Delete this wallet?',
      'delete_wallet_confirm_body': 'This action is irreversible, Make sure you have backed up the mnemonic.',
      'delete': 'Delete',
      'wallet_deleted': 'Wallet deleted',

      // ----- Password setup page -----
      'pwd_setup_title': 'Set app password',
      'pwd_change_title': 'Change app password',
      'pwd_old_label': 'Old password',
      'pwd_old_hint': 'Enter old password',
      'pwd_new_label': 'New password',
      'pwd_new_hint': 'Enter new password',
      'pwd_confirm_label': 'Confirm password',
      'pwd_confirm_hint': 'Re-enter new password',
      'pwd_required_before_wallet': 'Set a password before entering the wallet',
      'pwd_old_wrong': 'Old password is incorrect',
      'pwd_min_len': 'Password must be at least 6 characters',
      'pwd_mismatch': 'Passwords do not match',
      'pwd_save_success': 'Password saved',
      'pwd_change_success': 'Password changed',
      'pwd_save_failed': 'Save failed. Please try again.',
      'pwd_change_failed': 'Change failed. Please try again.',

      // ----- Import wallet page -----
      'input_mnemonic': 'Enter mnemonic',
      'restore_mnemonic': 'Enter mnemonic to restore wallet',
      'mnemonic_empty': 'Mnemonic cannot be empty',
      'mnemonic_too_short': 'Mnemonic is too short (min 12 words)',
      'mnemonic_invalid': 'Invalid mnemonic or cannot derive address',

      // ----- Create wallet page -----
      'create_wallet_title': 'Create a new wallet',
      'create_wallet_mnemonic_tip': 'Below is your mnemonic to recover the wallet.\nStore it safely and never share it.',
      'copy_mnemonic': 'Copy mnemonic',
      'i_backed_up': 'I have backed it up',
      'wallet_creating_wait': 'Wallet is being created. Please wait.',
      'create_wallet_failed': 'Failed to create wallet',

      // ----- Send page -----
      'send_invalid': 'Enter a valid address and amount',
      'send_insufficient': 'Insufficient balance for amount + fee',
      'send_failed_generic': 'Transfer failed, Please try again.',

      // ----- Asset chart page -----
      'estimated_value': 'Estimated value',

      // ----- Backup mnemonic page -----
      'backup_mnemonic': 'Back up mnemonic',
      'backup_mnemonic_desc': 'View and back up the current wallet mnemonic',
      'backup_mnemonic_title': 'Back up mnemonic',
      'backup_mnemonic_warning': 'Your mnemonic is your ownership of funds, Write it down offline and keep it safe. Do NOT screenshot, upload, or share it.',
      'backup_mnemonic_copy': 'Copy mnemonic',
      'backup_mnemonic_copied': 'Mnemonic copied to clipboard',
      'backup_mnemonic_reveal': 'Tap to reveal mnemonic',
      'backup_mnemonic_hide': 'Tap to hide mnemonic',
      'mnemonic_not_found': 'Mnemonic not found, Please create or import a wallet first.',

      // ----- Tx Auth (SendPage) -----
      'tx_auth_reason': 'Authenticate to confirm transfer',
      'tx_auth_failed': 'Authentication failed. Transfer cancelled.',
      'tx_auth_pwd_title': 'Enter app password',
      'tx_auth_pwd_hint': 'Enter password',
      'tx_auth_pwd_wrong': 'Wrong password',
      'tx_auth_confirm': 'confirm',
    }
  };

  String t(String key) {
    final lang = locale.languageCode;
    return _localizedValues[lang]?[key] ?? _localizedValues['en']?[key] ?? key;
  }

  /// Optional: format template like "Hello {name}"
  String tArgs(String key, Map<String, String> args) {
    var s = t(key);
    args.forEach((k, v) {
      s = s.replaceAll('{$k}', v);
    });
    return s;
  }
}

class L10nDelegate extends LocalizationsDelegate<L10n> {
  const L10nDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<L10n> load(Locale locale) async => L10n(locale);

  @override
  bool shouldReload(LocalizationsDelegate old) => false;
}

class LocaleController extends ChangeNotifier {
  LocaleController._();
  static final LocaleController instance = LocaleController._();

  static const String _kLocaleKey = 'app_locale'; // 'zh' / 'en'

  Locale _currentLocale = const Locale('zh');
  Locale get currentLocale => _currentLocale;

  /// App 启动时调用：从本地读取上次选择的语言
  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final code = sp.getString(_kLocaleKey);
    if (code == 'en') {
      _currentLocale = const Locale('en');
    } else if (code == 'zh') {
      _currentLocale = const Locale('zh');
    } else {
      _currentLocale = const Locale('zh');
    }
  }

  Future<void> setLocale(Locale locale) async {
    final code = locale.languageCode;
    if (code != 'zh' && code != 'en') return;
    if (_currentLocale.languageCode == code) return;

    _currentLocale = Locale(code);
    notifyListeners();

    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLocaleKey, code);
  }
}
