import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../../src/core/theme/colors.dart';
import '../../../../../src/core/widgets/app_scaffold.dart';
import '../../../../../utils/I10n.dart';
import '../../../../core/widgets/app_radii.dart';

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final WebViewController _controller;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  int _progress = 0;
  bool _showHome = true;
  bool _canGoBack = false;
  bool _canGoForward = false;

  String _currentUrl = '';
  bool _editingAddress = false;

  static const String _searchEngine = 'https://duckduckgo.com/?q=';
  static const double _searchBarHeight = 56;

  // 数据配置：title/subtitle 建议在 UI 渲染时根据需要做进一步国际化
  final List<_DappItem> _topPicks = const [
    _DappItem(
      title: 'Scash.world',
      subtitle: 'Scash ecosystem portal',
      url: 'https://scash.world',
      icon: Icons.public,
    ),
    _DappItem(
      title: 'Explorer',
      subtitle: 'Block explorer',
      url: 'https://explorer.scash.network',
      icon: Icons.travel_explore,
    ),
  ];

  final List<_DappItem> _defi = const [
    _DappItem(
      title: 'OurBit',
      subtitle: 'Trade SCASH/USDT',
      url: 'https://www.ourbit.com/zh-CN/exchange/SCASH_USDT?_from=search',
      icon: Icons.currency_exchange_rounded,
    ),
    _DappItem(
      title: 'CoinGecko',
      subtitle: 'Market data',
      url: 'https://www.coingecko.com/en/coins/satoshi-cash-network',
      icon: Icons.analytics_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initController();

    // 地址栏：聚焦展开完整 URL；失焦显示 host
    _searchFocus.addListener(() {
      if (!mounted) return;

      if (_showHome) return;

      if (_searchFocus.hasFocus) {
        _editingAddress = true;
        final full = _currentUrl.isNotEmpty ? _currentUrl : _searchController.text;
        _setAddressText(full, selectAll: true);
      } else {
        _editingAddress = false;
        _updateAddressBar();
      }
    });
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (!mounted) return;
            setState(() => _progress = p.clamp(0, 100));
          },
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _progress = 0;
              _currentUrl = url;
            });
            _syncNavState();
            _updateAddressBar();
          },
          onPageFinished: (url) async {
            final real = await _controller.currentUrl();
            _currentUrl = (real == null || real.isEmpty) ? url : real;

            await _syncNavState();
            if (!mounted) return;
            setState(() => _progress = 100);
            _updateAddressBar();
          },
          onWebResourceError: (_) async {
            await _syncNavState();
            _updateAddressBar();
          },
        ),
      );
  }

  Future<void> _syncNavState() async {
    if (!mounted) return;
    final b = await _controller.canGoBack();
    final f = await _controller.canGoForward();
    if (!mounted) return;
    setState(() {
      _canGoBack = b;
      _canGoForward = f;
    });
  }

  void _setAddressText(String text, {bool selectAll = false}) {
    _searchController.text = text;
    _searchController.selection = selectAll
        ? TextSelection(baseOffset: 0, extentOffset: text.length)
        : TextSelection.collapsed(offset: text.length);
  }

  String _displayForUrl(String url) {
    final u = Uri.tryParse(url);
    if (u == null) return url;
    if (u.host.isNotEmpty) return u.host;
    return url;
  }

  /// Web 模式下把当前页面 URL 同步回输入框（默认显示 host）
  Future<void> _updateAddressBar() async {
    if (!mounted) return;
    if (_showHome) return;

    // 用户正在编辑时不要强行覆盖输入
    if (_searchFocus.hasFocus || _editingAddress) return;

    final url = _currentUrl.isNotEmpty ? _currentUrl : await _controller.currentUrl();
    if (url == null || url.isEmpty) return;

    _setAddressText(_displayForUrl(url));
  }

  bool _looksLikeUrl(String input) {
    final s = input.trim().toLowerCase();
    if (s.startsWith('http://') || s.startsWith('https://')) return true;
    if (s.contains(' ') || !s.contains('.')) return false;
    return !s.endsWith('.');
  }

  String _normalizeUrl(String input) {
    final s = input.trim();
    return (s.startsWith('http://') || s.startsWith('https://')) ? s : 'https://$s';
  }

  Future<void> _submitSearch(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;

    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();

    final url = _looksLikeUrl(text)
        ? _normalizeUrl(text)
        : '$_searchEngine${Uri.encodeComponent(text)}';

    await _openUrl(url, switchToWeb: true);
  }

  Future<void> _openUrl(String url, {required bool switchToWeb}) async {
    if (switchToWeb) {
      setState(() => _showHome = false);

      // 先把即将打开的 url 写进输入框，让用户立刻看到
      _currentUrl = url;
      _setAddressText(url);
    }

    try {
      await _controller.loadRequest(Uri.parse(url));
    } catch (_) {
      // ignore parse errors
    }

    await _syncNavState();
    _updateAddressBar();
  }

  Future<void> _handleBack() async {
    if (_showHome) return;

    if (await _controller.canGoBack()) {
      await _controller.goBack();
      await _syncNavState();
      _updateAddressBar();
    } else {
      setState(() => _showHome = true);
      _searchController.clear(); // 回到 Home 再清空
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _goHomeKeepSession() async {
    setState(() => _showHome = true);
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _closeTab() async {
    FocusScope.of(context).unfocus();

    try {
      // 兼容 webview_flutter 4.13.1：没有 stopLoading()，直接加载空白页即可中断当前加载
      await _controller.loadRequest(Uri.parse('about:blank'));
    } catch (_) {}

    setState(() {
      _showHome = true;
      _progress = 0;
      _currentUrl = '';
      _canGoBack = false;
      _canGoForward = false;
    });

    _searchController.clear();
  }


  bool get _hasRealPage {
    final u = _currentUrl.trim();
    if (u.isEmpty) return false;
    return !(u == 'about:blank' || u.startsWith('about:blank'));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = L10n.of(context);

    final mq = MediaQuery.of(context);
    final safeTop = mq.padding.top;
    final safeBottom = mq.padding.bottom;
    final keyboard = mq.viewInsets.bottom;

    // 顶部纯黑任务栏高度（状态栏 + toolbar 高度）
    final topBarHeight = safeTop + kToolbarHeight;

    // 搜索栏底部：键盘弹起时跟随上移
    final floatingBarBottom = (keyboard > 0 ? keyboard : safeBottom) + 16;

    // 内容底部 padding：避免被浮动搜索栏遮挡（不跟键盘一起抬）
    final contentBottomPadding = (safeBottom + 16) + _searchBarHeight + 20;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: WillPopScope(
        onWillPop: () async {
          // 修复：键盘“∨/返回键”优先收起键盘，不触发网页返回
          if (keyboard > 0 || _searchFocus.hasFocus) {
            FocusScope.of(context).unfocus();
            return false;
          }

          if (_showHome) return true;

          await _handleBack();
          return false;
        },
        child: AppScaffold(
          statusBarIconBrightness: Brightness.light,
          useSafeArea: false,
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              // 关键修复：不要用 AnimatedCrossFade 包 PlatformView
              // 用 LayoutBuilder + SizedBox + IndexedStack 保证子组件拿到有限高度
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final fallback = MediaQuery.of(context).size;
                    final w = constraints.hasBoundedWidth ? constraints.maxWidth : fallback.width;
                    final h = constraints.hasBoundedHeight ? constraints.maxHeight : fallback.height;

                    return SizedBox(
                      width: w,
                      height: h,
                      child: IndexedStack(
                        index: _showHome ? 0 : 1,
                        children: [
                          _buildHome(contentBottomPadding, topBarHeight, l10n),
                          _buildWebView(contentBottomPadding, topBarHeight),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // 顶部纯黑遮挡条
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: IgnorePointer(
                  child: Container(
                    height: topBarHeight,
                    color: Colors.black,
                  ),
                ),
              ),

              // Web 模式加载进度条
              if (!_showHome && _progress < 100)
                Positioned(
                  left: 0,
                  right: 0,
                  top: topBarHeight,
                  child: LinearProgressIndicator(
                    value: _progress / 100.0,
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blueAccent.withOpacity(0.8),
                    ),
                  ),
                ),

              // 底部浮动搜索栏（随键盘上移）
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                left: 16,
                right: 16,
                bottom: floatingBarBottom,
                child: _buildSearchBar(l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebView(double bottomPadding, double topBarHeight) {
    // 保证 PlatformView 拿到有限尺寸
    return SizedBox.expand(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: EdgeInsets.only(
            top: topBarHeight,
            bottom: bottomPadding,
          ),
          child: WebViewWidget(controller: _controller),
        ),
      ),
    );
  }

  Widget _buildHome(double bottomPadding, double topBarHeight, L10n l10n) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16,
        topBarHeight + 20,
        16,
        bottomPadding,
      ),
      children: [
        _buildHeroCard(l10n),
        const SizedBox(height: 12),
        _buildSectionTitle(l10n.t('browser_top_picks')),
        const SizedBox(height: 12),
        ..._topPicks
            .map(
              (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => _openUrl(item.url, switchToWeb: true),
              child: _buildPickCard(item),
            ),
          ),
        )
            .toList(),

        const SizedBox(height: 24),

        _buildSectionTitle(l10n.t('browser_explore')),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 20,
            crossAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemCount: _defi.length,
          itemBuilder: (context, index) => _buildMiniDapp(_defi[index]),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildHeroCard(L10n l10n) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: AppRadii.r20,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2962FF).withOpacity(0.9),
            const Color(0xFF7B1FA2).withOpacity(0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 25,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              Icons.auto_awesome,
              size: 120,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.t('browser'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.t('app_intro'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickCard(_DappItem item) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.5),
        borderRadius: AppRadii.r20,
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildIconContainer(item.icon, size: 48, iconSize: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: Colors.white.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniDapp(_DappItem item) {
    return GestureDetector(
      onTap: () => _openUrl(item.url, switchToWeb: true),
      child: Column(
        children: [
          _buildIconContainer(item.icon, size: 60, iconSize: 28, isMini: true),
          const SizedBox(height: 10),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconContainer(
      IconData icon, {
        double size = 56,
        double iconSize = 26,
        bool isMini = false,
      }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isMini ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.05),
        borderRadius: AppRadii.r16,
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }

  Widget _buildSearchBar(L10n l10n) {
    final bool webMode = !_showHome;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: _searchBarHeight,
          decoration: BoxDecoration(
            color: AppColors.card.withOpacity(0.75),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),

              _buildBarButton(
                icon: webMode ? Icons.arrow_back_ios_new_rounded : Icons.search_rounded,
                color: (webMode && !_canGoBack) ? Colors.white24 : Colors.white70,
                onTap: webMode
                    ? () {
                  // 编辑时优先收键盘，不网页返回
                  if (_searchFocus.hasFocus) {
                    FocusScope.of(context).unfocus();
                    return;
                  }
                  _handleBack();
                }
                    : () => _searchFocus.requestFocus(),
              ),

              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  textInputAction: TextInputAction.search,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    hintText: l10n.t('browser_search_hint'),
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onTap: () {
                    // Web 模式下点输入框，自动全选当前 URL（如果当前显示的是 host，listener 会展开 full）
                    if (!_showHome) {
                      final t = _searchController.text;
                      _searchController.selection =
                          TextSelection(baseOffset: 0, extentOffset: t.length);
                    }
                  },
                  onSubmitted: _submitSearch,
                ),
              ),

              if (webMode) ...[
                // Home：回推荐页（保留会话）
                _buildBarButton(
                  icon: Icons.home_rounded,
                  onTap: _goHomeKeepSession,
                ),

                // 可选：Forward（如果你不想要可删）
                _buildBarButton(
                  icon: Icons.arrow_forward_ios_rounded,
                  color: _canGoForward ? Colors.white70 : Colors.white24,
                  onTap: _canGoForward
                      ? () async {
                    await _controller.goForward();
                    await _syncNavState();
                    _updateAddressBar();
                  }
                      : null,
                ),

                _buildBarButton(
                  icon: Icons.refresh_rounded,
                  onTap: () => _controller.reload(),
                ),

                // close：关闭标签页（about:blank + 清空会话）
                _buildBarButton(
                  icon: Icons.close_rounded,
                  onTap: _closeTab,
                ),
              ] else
                _buildBarButton(
                  icon: Icons.arrow_forward_rounded,
                  onTap: () => _submitSearch(_searchController.text),
                  color: Colors.blueAccent,
                ),

              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarButton({
    required IconData icon,
    VoidCallback? onTap,
    Color? color,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: color ?? Colors.white70, size: 20),
      splashRadius: 24,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }
}

class _DappItem {
  final String title;
  final String subtitle;
  final String url;
  final IconData icon;
  const _DappItem({
    required this.title,
    required this.subtitle,
    required this.url,
    required this.icon,
  });
}
