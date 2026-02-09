import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'app_radii.dart';

class AppBottomDrawer {
  static Future<T?> show<T>(
      BuildContext context, {
        required Widget child,
        double maxHeightFactor = 0.85,
        Color? barrierColor,
        bool isScrollControlled = true,
        bool useRootNavigator = false,
        bool isDismissible = true,
        bool enableDrag = true,
        bool showHandle = true,
      }) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      barrierColor: barrierColor ?? Colors.black.withOpacity(0.75),
      builder: (_) => _AppBottomDrawerContainer(
        maxHeightFactor: maxHeightFactor,
        showHandle: showHandle,
        child: child,
      ),
    );
  }
}

class _AppBottomDrawerContainer extends StatelessWidget {
  final Widget child;
  final double maxHeightFactor;
  final bool showHandle;

  const _AppBottomDrawerContainer({
    super.key,
    required this.child,
    required this.maxHeightFactor,
    required this.showHandle,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxH = media.size.height * maxHeightFactor;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: AppRadii.sheet,
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 0.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showHandle) ...[
                  const SizedBox(height: 12),
                  _handle(),
                  const SizedBox(height: 8),
                ],
                Flexible(
                  fit: FlexFit.loose,
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _handle() {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: AppRadii.pill,
      ),
    );
  }
}