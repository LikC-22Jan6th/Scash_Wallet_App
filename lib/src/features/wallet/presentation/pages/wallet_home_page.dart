import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../../src/core/theme/colors.dart';
import 'browser_page.dart';
import 'wallet_list_page.dart';
import '../../../../../src/features/transactions/presentation/pages/transaction_list_page.dart';
import '../../../../../utils/I10n.dart';
import '../../../../../src/core/widgets/app_scaffold.dart';

class WalletHomePage extends StatefulWidget {
  const WalletHomePage({super.key});

  @override
  State<WalletHomePage> createState() => _WalletHomePageState();
}

class _WalletHomePageState extends State<WalletHomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const WalletListPage(),
    const TransactionListPage(),
    const BrowserPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      statusBarIconBrightness: Brightness.light,
      useSafeArea: false,
      extendBody: true,
      backgroundColor: AppColors.background, // 保持背景颜色不变
       // 极其重要：让 Body 内容延伸到底部任务栏后面
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      // 使用带毛玻璃效果的透明容器包装 BottomNavigationBar
      bottomBar: _buildGlassEffectBar(),
    );
  }

  Widget _buildGlassEffectBar() {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return ClipRect(
      child: BackdropFilter(
        // 模糊强度，sigma 越高越朦胧
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 20),
        child: Container(
          // 透明背景色：
          // 这里使用完全透明或极低透明度的背景，保证毛玻璃效果透出后面的内容
          color: AppColors.background.withOpacity(0.55),
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Theme(
            data: Theme.of(context).copyWith(
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              type: BottomNavigationBarType.fixed,
              // 设置为透明，否则会遮挡毛玻璃效果
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: AppColors.button,
              unselectedItemColor: AppColors.textSecondary,
              showUnselectedLabels: true,
              enableFeedback: false,
              selectedLabelStyle: const TextStyle(fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.wallet),
                  label: L10n.of(context).t('wallet'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.swap_horiz),
                  label: L10n.of(context).t('history'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.explore_outlined),
                  label: L10n.of(context).t('browser'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}