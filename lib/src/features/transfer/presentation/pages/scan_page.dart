import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../../utils/I10n.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_radii.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../../core/widgets/app_scaffold.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with SingleTickerProviderStateMixin {
  bool _isScanned = false;
  bool _isHandlingInvalid = false;
  bool _torchOn = false;

  late final MobileScannerController _cameraController;
  late final AnimationController _animController;
  late final Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _scanAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  String? _parseScashAddress(String rawValue) {
    String value = rawValue.trim();
    if (value.contains(':')) {
      value = value.split(':').last.split('?').first;
    }
    return value.toLowerCase().startsWith('scash') ? value : null;
  }

  Future<void> _handleInvalidQr() async {
    if (_isHandlingInvalid) return;
    _isHandlingInvalid = true;
    HapticFeedback.heavyImpact();
    if (mounted) {
      TopToast.error(context, L10n.of(context).t('scan_invalid_desc'));
    }
    await Future.delayed(const Duration(seconds: 2));
    _isHandlingInvalid = false;
  }

  @override
  Widget build(BuildContext context) {
    final double scanAreaSize = MediaQuery.of(context).size.width * 0.7;
    final loc = L10n.of(context);

    return AppScaffold(
      statusBarIconBrightness: Brightness.light,
      useSafeArea: false,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          loc.t('scan_qr_title'),
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 底层相机预览
          MobileScanner(
            controller: _cameraController,
            onDetect: (capture) async {
              if (_isScanned || _isHandlingInvalid) return;
              final barcode = capture.barcodes.firstOrNull;
              final rawValue = barcode?.rawValue;
              if (rawValue == null) return;

              final address = _parseScashAddress(rawValue);
              if (address != null) {
                _isScanned = true;
                HapticFeedback.mediumImpact();
                Navigator.pop(context, address);
              } else {
                _handleInvalidQr();
              }
            },
          ),

          // 磨砂玻璃层与镂空挖孔
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.5),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  // 模糊层背景
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        backgroundBlendMode: BlendMode.dstOut,
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: scanAreaSize,
                      height: scanAreaSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 装饰层 (边角、扫描线)
          Center(
            child: SizedBox(
              width: scanAreaSize,
              height: scanAreaSize,
              child: Stack(
                children: [
                  _buildModernCorner(Alignment.topLeft),
                  _buildModernCorner(Alignment.topRight),
                  _buildModernCorner(Alignment.bottomLeft),
                  _buildModernCorner(Alignment.bottomRight),
                  AnimatedBuilder(
                    animation: _scanAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: _scanAnimation.value * (scanAreaSize - 10),
                        left: 20,
                        right: 20,
                        child: _buildGlowLine(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 底部面板 (文案、闪光灯)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  loc.t('scan_light_tip'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                  ),
                ),
                const SizedBox(height: 30),
                GestureDetector(
                  onTap: () async {
                    await _cameraController.toggleTorch();
                    setState(() => _torchOn = !_torchOn);
                    HapticFeedback.lightImpact();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _torchOn ? AppColors.button : Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                      boxShadow: _torchOn
                          ? [BoxShadow(color: AppColors.button.withOpacity(0.5), blurRadius: 20, spreadRadius: 2)]
                          : [],
                    ),
                    child: Icon(
                      _torchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowLine() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                AppColors.button.withOpacity(0.01),
                AppColors.button,
                AppColors.button.withOpacity(0.01),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.button.withOpacity(0.8),
                blurRadius: 12,
                spreadRadius: 2,
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernCorner(Alignment alignment) {
    const double radius = 24.0;
    const double thickness = 5.0;
    const double length = 32.0;

    return Align(
      alignment: alignment,
      child: Container(
        width: length,
        height: length,
        decoration: BoxDecoration(
          border: Border(
            top: (alignment.y < 0) ? const BorderSide(color: AppColors.button, width: thickness) : BorderSide.none,
            bottom: (alignment.y > 0) ? const BorderSide(color: AppColors.button, width: thickness) : BorderSide.none,
            left: (alignment.x < 0) ? const BorderSide(color: AppColors.button, width: thickness) : BorderSide.none,
            right: (alignment.x > 0) ? const BorderSide(color: AppColors.button, width: thickness) : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: (alignment == Alignment.topLeft) ? const Radius.circular(radius) : Radius.zero,
            topRight: (alignment == Alignment.topRight) ? const Radius.circular(radius) : Radius.zero,
            bottomLeft: (alignment == Alignment.bottomLeft) ? const Radius.circular(radius) : Radius.zero,
            bottomRight: (alignment == Alignment.bottomRight) ? const Radius.circular(radius) : Radius.zero,
          ),
        ),
      ),
    );
  }
}