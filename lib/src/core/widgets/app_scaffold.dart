import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 一个包裹[脚手架]的包裹器，可以设置状态栏颜色和图标亮度。
class AppScaffold extends StatelessWidget {
  final Widget body;
  final Color backgroundColor;
  final Brightness statusBarIconBrightness;
  final bool useSafeArea;
  final Widget? bottomBar;

  final PreferredSizeWidget? appBar;

  final bool extendBody;

  final bool extendBodyBehindAppBar;
  
  final bool? resizeToAvoidBottomInset;

  const AppScaffold({
    super.key,
    required this.body,
    this.backgroundColor = Colors.white,
    this.statusBarIconBrightness = Brightness.dark,
    this.useSafeArea = true,
    this.bottomBar,
    this.appBar,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.resizeToAvoidBottomInset,
  });

  @override
  Widget build(BuildContext context) {
    final Widget content = useSafeArea ? SafeArea(child: body) : body;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: statusBarIconBrightness, // Android
        statusBarBrightness: statusBarIconBrightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark, // iOS
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: appBar,
        extendBody: extendBody,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        body: content,
        bottomNavigationBar: bottomBar,
      ),
    );
  }
}
