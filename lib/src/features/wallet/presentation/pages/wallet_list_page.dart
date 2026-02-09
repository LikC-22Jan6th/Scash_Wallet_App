import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 核心组件与主题
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_radii.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_bottom_drawer.dart';
import '../../../../core/widgets/top_toast.dart';

// 业务页面与服务
import '../../../../../services/wallet_service.dart';
import '../../../../../services/storage_service.dart';
import '../../../../../utils/I10n.dart';
import '../../../../../utils/event_bus.dart';

import '../../../wallet/domain/wallet.dart';
import '../../../wallet/domain/asset.dart';
import '../../../wallet/presentation/pages/asset_chart_page.dart';
import '../../../wallet/presentation/pages/import_wallet_page.dart';
import '../../../wallet/presentation/pages/create_wallet_page.dart';
import '../../../transfer/presentation/pages/receive_page.dart';
import '../../../transfer/presentation/pages/send_page.dart';
import '../../../transfer/presentation/pages/scan_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';

class WalletListPage extends StatefulWidget {
  const WalletListPage({super.key});

  @override
  State<WalletListPage> createState() => _WalletListPageState();
}

class _WalletListPageState extends State<WalletListPage>
    with WidgetsBindingObserver {
  late final WalletService walletService;
  final StorageService _storageService = StorageService();

  bool _isLoading = false;
  List<Wallet> wallets = [];
  Wallet? currentWallet;

  List<Asset> assets = [
    Asset(
      symbol: 'Scash',
      balance: 0.0,
      price: 0.0,
      logo: 'assets/images/scash-logo.png',
    ),
  ];

  int _selectedWalletIndex = 0;

  /// 用于刷新竞态控制（切换钱包/多次刷新时防止旧请求回写）
  int _refreshToken = 0;

  double _totalUSD = 0;
  double _totalSCash = 0;
  bool _didPrecacheLogo = false;

  // 仅缓存 balance/usd；price 交给 WalletService.getScashPrice（全局缓存）
  static const String _cachePrefix = 'cache_v1_';

  DateTime? _lastResumeRefreshAt;
  StreamSubscription? _refreshSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    walletService = WalletService();
    _setupEventListeners();
    _initializeWallet();
  }

  void _setupEventListeners() {
    // 发送成功/其他页面触发刷新：只做后端刷新，不做任何余额扣减
    _refreshSubscription = EventBus().on<RefreshWalletEvent>().listen((event) {
      if (!mounted) return;
      _refreshAllData(showLoading: false, silent: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    // 防抖：避免某些机型短时间多次触发 resumed
    final now = DateTime.now();
    if (_lastResumeRefreshAt != null &&
        now.difference(_lastResumeRefreshAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastResumeRefreshAt = now;

    // 串行：先缓存兜底展示，再静默刷新，避免“刷新完又被缓存覆盖”
    Future.microtask(() async {
      await _loadLocalCache();
      await _refreshAllData(showLoading: false, silent: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didPrecacheLogo) {
      _didPrecacheLogo = true;
      precacheImage(const AssetImage('assets/images/scash-logo.png'), context);
    }
  }

  String _formatCompact(double value, {int fractionDigits = 6}) {
    if (value == 0) return "0";
    return value
        .toStringAsFixed(fractionDigits)
        .replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
  }

  // --- 核心逻辑：加载与缓存 ---

  Future<void> _initializeWallet() async {
    final updatedWallets = await _storageService.getWalletList();
    if (updatedWallets.isEmpty) {
      if (mounted) {
        setState(() {
          wallets = [];
          currentWallet = null;
          _totalSCash = 0;
          _totalUSD = 0;
        });
      }
      return;
    }

    final idx = await _storageService.getCurrentWalletIndex();
    final safeIndex = idx.clamp(0, updatedWallets.length - 1);

    if (!mounted) return;

    setState(() {
      wallets = updatedWallets;
      _selectedWalletIndex = safeIndex;
      currentWallet = updatedWallets[safeIndex];
    });

    // 立即加载本地缓存（秒开显示数据）
    await _loadLocalCache();

    // 后台静默刷新最新数据（以 /balance 与 getScashPrice 为准）
    _refreshAllData(showLoading: _shouldShowLoadingOnInit(), silent: true);
  }

  bool _shouldShowLoadingOnInit() {
    final currentPrice = assets.isNotEmpty ? assets[0].price : 0.0;
    return _totalSCash <= 0 && currentPrice <= 0;
  }

  Future<void> _loadLocalCache() async {
    if (currentWallet == null) return;

    final prefs = await SharedPreferences.getInstance();
    final String addr = currentWallet!.address;

    final cachedScash = prefs.getDouble('${_cachePrefix}bal_$addr') ?? 0.0;
    final cachedUsd = prefs.getDouble('${_cachePrefix}usd_$addr') ?? 0.0;

    final hasAnyCache = cachedScash > 0 || cachedUsd > 0;
    if (!mounted || !hasAnyCache) return;

    final double currentPrice = assets.isNotEmpty ? assets[0].price : 0.0;
    final double effectiveUsd = cachedUsd > 0
        ? cachedUsd
        : (currentPrice > 0 ? cachedScash * currentPrice : _totalUSD);

    setState(() {
      if (cachedScash >= 0) _totalSCash = cachedScash;
      if (effectiveUsd >= 0) _totalUSD = effectiveUsd;

      assets = [
        Asset(
          symbol: 'Scash',
          balance: cachedScash,
          price: currentPrice,
          logo: 'assets/images/scash-logo.png',
        ),
      ];
    });
  }

  Future<void> _saveToCache({
    required double bal,
    double? usd,
  }) async {
    if (currentWallet == null) return;
    final prefs = await SharedPreferences.getInstance();
    final String addr = currentWallet!.address;

    await prefs.setDouble('${_cachePrefix}bal_$addr', bal);

    // usd 只有有效时才写，避免把缓存污染成 0
    if (usd != null && usd > 0) {
      await prefs.setDouble('${_cachePrefix}usd_$addr', usd);
    }
  }

  Future<void> _refreshAllData({
    required bool showLoading,
    bool silent = false,
  }) async {
    final wallet = currentWallet;
    if (wallet == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final String addr = wallet.address; // 固化地址（防切换竞态）
    final int requestToken = ++_refreshToken;

    if (showLoading && mounted) setState(() => _isLoading = true);

    try {
      // 余额必须尽量更新；价格失败不应阻断余额更新
      final balanceFuture = walletService.getBalance(addr);
      final priceFuture = walletService
          .getScashPrice()
          .then<double?>((v) => v is num ? v.toDouble() : null)
          .catchError((_) => null);

      final balanceData = await balanceFuture;
      final double? fetchedPrice = await priceFuture;

      if (!mounted || requestToken != _refreshToken) return;
      if (currentWallet?.address != addr) return;

      final double bal = (balanceData['balance'] as num).toDouble();

      final double prevPrice = assets.isNotEmpty ? assets[0].price : 0.0;
      final double effectivePrice =
      (fetchedPrice != null && fetchedPrice > 0) ? fetchedPrice : prevPrice;

      final bool hasValidPrice = effectivePrice > 0;
      final double usd = hasValidPrice ? bal * effectivePrice : _totalUSD;

      setState(() {
        _totalSCash = bal;

        if (hasValidPrice) {
          _totalUSD = usd;
          assets = [
            Asset(
              symbol: 'Scash',
              balance: bal,
              price: effectivePrice,
              logo: 'assets/images/scash-logo.png',
            ),
          ];
        } else {
          assets = [
            Asset(
              symbol: 'Scash',
              balance: bal,
              price: prevPrice,
              logo: 'assets/images/scash-logo.png',
            ),
          ];
        }

        _isLoading = false;
      });

      await _saveToCache(
        bal: bal,
        usd: hasValidPrice ? usd : null,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (!silent && _totalSCash == 0) {
          TopToast.errorKey(context, 'toast_service_unavailable');
        }
      }
    }
  }

  // --- UI 构建 ---

  @override
  Widget build(BuildContext context) {
    final loc = L10n.of(context);
    return AppScaffold(
      statusBarIconBrightness: Brightness.light,
      useSafeArea: false,
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          _buildSliverAppBar(),
          _buildRefreshControl(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildTotalBalanceSection(loc),
                  const SizedBox(height: 32),
                  _buildActionButtons(loc),
                  const SizedBox(height: 40),
                  Text(
                    loc.t('assets'),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildAssetItem(assets[index]),
                childCount: assets.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.background,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: _buildHeaderWalletButton(),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined,
              color: AppColors.textPrimary),
          onPressed: () async {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => SettingsPage()),
            );
            if (result == true && mounted) {
              _refreshAllData(showLoading: true, silent: true);
            }
          },
        ),
      ],
    );
  }

  Widget _buildRefreshControl() {
    return CupertinoSliverRefreshControl(
      onRefresh: () => _refreshAllData(showLoading: false, silent: false),
      builder: (context, refreshState, pulledExtent,
          refreshTriggerPullDistance, refreshIndicatorExtent) {
        return Center(
          child: Opacity(
            opacity:
            (pulledExtent / refreshTriggerPullDistance).clamp(0.0, 1.0),
            child: const CupertinoActivityIndicator(
              radius: 10,
              color: AppColors.textSecondary,
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderWalletButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _openWalletBottomSheet();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: AppRadii.pill,
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                currentWallet?.name ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalBalanceSection(L10n loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: double.infinity),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${_formatCompact(_totalSCash)} SCASH',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '≈ \$${_formatCompact(_totalUSD, fractionDigits: 4)}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (_isLoading) ...[
          const SizedBox(height: 24),
          const CupertinoActivityIndicator(radius: 8, color: AppColors.button),
        ],
      ],
    );
  }

  Widget _buildActionButtons(L10n loc) {
    return Row(
      children: [
        _actionItem(
          loc.t('receive'),
          Icons.south_west_rounded,
              () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReceivePage()),
          ),
        ),
        const SizedBox(width: 16),
        _actionItem(
          loc.t('send'),
          Icons.north_east_rounded,
              () async {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => const SendPage()),
            );
            // 不做乐观扣减：仅触发一次后端刷新
            if (result == true && mounted) {
              _refreshAllData(showLoading: false, silent: true);
            }
          },
        ),
        const SizedBox(width: 16),
        _actionItem(loc.t('scan'), Icons.qr_code_scanner_rounded, _handleScan),
      ],
    );
  }

  Widget _actionItem(String label, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Column(
          children: [
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Icon(icon, color: AppColors.button, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetItem(Asset asset) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AssetChartPage(asset: asset, walletService: walletService),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          child: Row(
            children: [
              Image.asset(asset.logo!, width: 42, height: 42),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.symbol,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      asset.price > 0
                          ? '\$${_formatCompact(asset.price, fractionDigits: 4)}'
                          : '--',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCompact(asset.balance),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    asset.price > 0
                        ? '\$${_formatCompact(asset.usdValue, fractionDigits: 4)}'
                        : '--',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _switchWallet(int index) async {
    HapticFeedback.mediumImpact();

    // 立刻失效所有在途请求，避免旧钱包刷新回写 UI
    _refreshToken++;

    setState(() {
      _selectedWalletIndex = index;
      currentWallet = wallets[index];
      _isLoading = true;
    });

    await _storageService.saveCurrentWalletIndex(index);
    await _loadLocalCache();

    if (mounted) setState(() => _isLoading = false);

    _refreshAllData(showLoading: true, silent: true);
  }

  void _openWalletBottomSheet() {
    AppBottomDrawer.show(
      context,
      maxHeightFactor: 0.65,
      child: _WalletSelectorSheet(
        wallets: wallets,
        selectedIndex: _selectedWalletIndex,
        onSelected: (index) {
          Navigator.pop(context);
          _switchWallet(index);
        },
        onAddClick: () {
          Navigator.pop(context);
          Future.delayed(
            const Duration(milliseconds: 250),
            _openAddWalletOptions,
          );
        },
      ),
    );
  }

  void _openAddWalletOptions() {
    AppBottomDrawer.show(
      context,
      maxHeightFactor: 0.50,
      child: _AddWalletOptionsSheet(),
    );
  }

  Future<void> _handleScan() async {
    final address = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (address != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SendPage(initialAddress: address),
        ),
      );
    }
  }
}

// --- 辅助 Sheet 组件 ---

class _WalletSelectorSheet extends StatelessWidget {
  final List<Wallet> wallets;
  final int selectedIndex;
  final Function(int) onSelected;
  final VoidCallback onAddClick;

  const _WalletSelectorSheet({
    required this.wallets,
    required this.selectedIndex,
    required this.onSelected,
    required this.onAddClick,
  });

  @override
  Widget build(BuildContext context) {
    final loc = L10n.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            loc.t('switch_wallet'),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: wallets.length,
            itemBuilder: (context, index) {
              final w = wallets[index];
              final isSel = selectedIndex == index;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  borderRadius: AppRadii.r16,
                  color: isSel
                      ? AppColors.button.withOpacity(0.1)
                      : AppColors.card,
                  border: Border.all(
                    color: isSel
                        ? AppColors.button.withOpacity(0.5)
                        : Colors.white.withOpacity(0.05),
                  ),
                ),
                child: ListTile(
                  onTap: () => onSelected(index),
                  title: Text(
                    w.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    w.address.length > 20
                        ? '${w.address.substring(0, 8)}...${w.address.substring(w.address.length - 8)}'
                        : w.address,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  trailing: isSel
                      ? const Icon(Icons.check_circle_rounded,
                      color: AppColors.button, size: 20)
                      : null,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: onAddClick,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.button,
                borderRadius: AppRadii.pill,
              ),
              child: Center(
                child: Text(
                  loc.t('add_wallet'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

class _AddWalletOptionsSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              loc.t('add_wallet'),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _optionTile(
            context,
            Icons.add_circle_outline_rounded,
            loc.t('create_wallet'),
            loc.t('create_wallet_desc'),
                () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateWalletPage()),
              );
            },
          ),
          const SizedBox(height: 12),
          _optionTile(
            context,
            Icons.file_download_outlined,
            loc.t('import_wallet'),
            loc.t('import_wallet_desc'),
                () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ImportWalletPage()),
              );
            },
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _optionTile(
      BuildContext context,
      IconData icon,
      String title,
      String sub,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: AppRadii.r16,
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.button.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.button, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textSecondary, size: 14),
          ],
        ),
      ),
    );
  }
}
