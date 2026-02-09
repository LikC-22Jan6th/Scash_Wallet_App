import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/colors.dart';
import 'app_routes.dart';
import '../../utils/I10n.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = LocaleController.instance;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'Scash Wallet',
          debugShowCheckedModeBanner: false,

          // 多语言：跟随 LocaleController
          locale: controller.currentLocale,
          supportedLocales: const [Locale('zh'), Locale('en')],
          localizationsDelegates: const [
            L10nDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          // 主题
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: AppColors.background,
            canvasColor: AppColors.background,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.background,
              background: AppColors.background,
              brightness: Brightness.dark,
            ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              },
            ),
          ),

          initialRoute: AppRoutes.splash,
          routes: AppRoutes.routes,
        );
      },
    );
  }
}
