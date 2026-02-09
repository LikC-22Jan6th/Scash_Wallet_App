import 'dart:async';
import 'package:flutter/material.dart';
import 'package:scash_wallet/utils/I10n.dart';

import 'app_radii.dart';

enum TopToastType { info, success, error }

// 顶部弹出框
class TopToast {
  static OverlayEntry? _activeEntry;

  static void show(
      BuildContext context, {
        required String message,
        TopToastType type = TopToastType.info,
        Duration duration = const Duration(seconds: 2),
      }) {
    _activeEntry?.remove();
    _activeEntry = null;

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TopToastEntry(
        message: message,
        type: type,
        duration: duration,
        onDismissed: () {
          if (_activeEntry == entry) _activeEntry = null;
          entry.remove();
        },
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);
  }

  static void info(BuildContext c, String msg, {Duration? duration}) => show(
    c,
    message: msg,
    type: TopToastType.info,
    duration: duration ?? const Duration(seconds: 2),
  );

  static void success(BuildContext c, String msg, {Duration? duration}) => show(
    c,
    message: msg,
    type: TopToastType.success,
    duration: duration ?? const Duration(seconds: 2),
  );

  static void error(BuildContext c, String msg, {Duration? duration}) => show(
    c,
    message: msg,
    type: TopToastType.error,
    duration: duration ?? const Duration(seconds: 3),
  );

  // ==========================
  // i18n: key 版本（页面里直接传 key）
  // ==========================
  static void showKey(
      BuildContext context, {
        required String key,
        TopToastType type = TopToastType.info,
        Duration duration = const Duration(seconds: 2),
      }) {
    final msg = L10n.of(context).t(key);
    show(context, message: msg, type: type, duration: duration);
  }

  static void infoKey(BuildContext c, String key, {Duration? duration}) =>
      showKey(c, key: key, type: TopToastType.info, duration: duration ?? const Duration(seconds: 2));

  static void successKey(BuildContext c, String key, {Duration? duration}) =>
      showKey(c, key: key, type: TopToastType.success, duration: duration ?? const Duration(seconds: 2));

  static void errorKey(BuildContext c, String key, {Duration? duration}) =>
      showKey(c, key: key, type: TopToastType.error, duration: duration ?? const Duration(seconds: 3));
}

class _TopToastEntry extends StatefulWidget {
  final String message;
  final TopToastType type;
  final Duration duration;
  final VoidCallback onDismissed;

  const _TopToastEntry({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_TopToastEntry> createState() => _TopToastEntryState();
}

class _TopToastEntryState extends State<_TopToastEntry> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 180),
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1.0),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  );

  Timer? _timer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;

    if (!mounted) return;
    await _controller.reverse();
    if (!mounted) return;
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    IconData icon;
    Color accent;
    switch (widget.type) {
      case TopToastType.success:
        icon = Icons.check_circle_rounded;
        accent = cs.tertiary;
        break;
      case TopToastType.error:
        icon = Icons.error_rounded;
        accent = cs.error;
        break;
      case TopToastType.info:
      default:
        icon = Icons.info_rounded;
        accent = cs.primary;
        break;
    }

    final bg = Theme.of(context).cardColor;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: true,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SlideTransition(
              position: _slide,
              child: FadeTransition(
                opacity: _fade,
                child: GestureDetector(
                  onTap: _dismiss, // 点整条收起
                  onVerticalDragUpdate: (d) {
                    if (d.primaryDelta != null && d.primaryDelta! < -6) _dismiss(); // 上滑收起
                  },
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 520),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: AppRadii.r16,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                          color: Colors.black.withOpacity(0.12),
                        ),
                      ],
                      border: Border.all(color: accent.withOpacity(0.25), width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, size: 20, color: accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
