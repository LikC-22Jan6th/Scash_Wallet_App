import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../../services/storage_service.dart';
import '../../../../app/app_routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_scaffold.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  final StorageService _storageService = StorageService();

  Timer? _timer;
  late final Future<bool> _hasWalletFuture;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack)),
    );

    _controller.forward();

    _hasWalletFuture = _checkHasWallet();

    _timer = Timer(const Duration(milliseconds: 2200), () async {
      final hasWallet = await _hasWalletFuture;
      if (!mounted) return;

      final targetRoute = hasWallet
          ? AppRoutes.walletHomePage
          : AppRoutes.onboarding;

      Navigator.of(context).pushReplacement(_fadeRoute(targetRoute));
    });
  }

  Future<bool> _checkHasWallet() async {
    try {
      final wallets = await _storageService.getWalletList();
      return wallets.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Route _fadeRoute(String routeName) {
    final builder = AppRoutes.routes[routeName];
    if (builder == null) return PageRouteBuilder(pageBuilder: (_, __, ___) => const SizedBox.shrink());

    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionDuration: const Duration(milliseconds: 800), // 稍微拉长，增加高级感
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: AppColors.background,
      useSafeArea: false,
      statusBarIconBrightness: Brightness.light,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'logo_hero',
                  child: Image.asset(
                    'assets/images/scash-logo.png',
                    width: 100,
                    height: 100,
                  ),
                ),
                const SizedBox(height: 24),
                // 字体风格对齐全应用风格
                const Text(
                  'Scash Wallet',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Secure • Decentralized',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withOpacity(0.5),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}