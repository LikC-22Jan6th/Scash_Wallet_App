// Flutter 基础库，里面有 WidgetBuilder
import 'package:flutter/material.dart';

// 引入启动页
// 注意：这里引的是页面文件，不是路由
import '../../src/features/splash/presentation/pages/splash_page.dart';
import '../../src/features/onboarding/presentation/pages/onboarding_page.dart';
import '../../src/features/transactions/presentation/pages/transaction_list_page.dart';
import '../../src/features/wallet/presentation/pages/wallet_home_page.dart';
import '../../src/features/wallet/presentation/pages/create_wallet_page.dart';
import '../../src/features/wallet/presentation/pages/import_wallet_page.dart';
import '../../src/features/wallet/presentation/pages/wallet_list_page.dart';
import '../features/wallet/presentation/pages/browser_page.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String createwalletpage = '/createwalletpage';
  static const String importwalletpage = '/importwalletpage';
  static const String walletHomePage = '/WalletHomePage';
  static const String walletlistpage = '/WalletListPage';
  static const String transactionListPage = '/TransactionListPage';
  static const String browser = '/browser';

  static final Map<String, WidgetBuilder> routes = {
    splash: (context) => const SplashPage(),
    onboarding: (context) => const OnboardingPage(), // 引导页
    createwalletpage: (context) => const CreateWalletPage(), // 创建钱包
    importwalletpage: (context) => const ImportWalletPage(), // 创建钱包
    walletHomePage: (context) => const WalletHomePage(),// 钱包首页
    walletlistpage: (context) => const WalletListPage(),// 资产界面
    transactionListPage: (context) =>  TransactionListPage(),// 交易列表
    browser: (context) => const BrowserPage(),// 浏览器
  };
}
