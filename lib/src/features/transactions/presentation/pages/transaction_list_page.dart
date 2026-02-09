import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_radii.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../domain/transaction.dart';
import '../../../../../services/wallet_service.dart';
import '../../../../../services/storage_service.dart';
import '../../../../../utils/I10n.dart';
import '../../../../../utils/event_bus.dart';

class TransactionListPage extends StatefulWidget {
  const TransactionListPage({super.key});

  @override
  State<TransactionListPage> createState() => _TransactionListPageState();
}

class _TransactionListPageState extends State<TransactionListPage>
    with WidgetsBindingObserver {
  int _activeFilter = 0; // 0-All, 1-Sent, 2-Received
  List<Transaction> _allTransactions = [];
  bool _isLoading = true;

  /// 并发/切换钱包防护
  int _refreshToken = 0;

  final WalletService _walletService = WalletService();
  final StorageService _storageService = StorageService();

  StreamSubscription? _refreshSubscription;
  Timer? _pollingTimer;

  static const String _cachePrefix = 'cache_txs_v2_';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeTransactions();
    _setupEventListeners();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshSubscription?.cancel();
    _stopPolling();
    super.dispose();
  }

  // --- 生命周期：后台停轮询，前台恢复 ---

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _fetchTransactions(showLoading: false);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopPolling();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && !_isLoading) {
        _fetchTransactions(showLoading: false);
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// 事件监听
  void _setupEventListeners() {
    _refreshSubscription =
        EventBus().on<RefreshWalletEvent>().listen((event) {
          _fetchTransactions(showLoading: false);
        });
  }

  // --- 初始化与缓存 ---

  Future<void> _initializeTransactions() async {
    final wallet = await _storageService.getCurrentWallet();
    if (wallet == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 秒开：先读缓存
    await _loadLocalCache(wallet.address);

    // 后台刷新
    _fetchTransactions(showLoading: _allTransactions.isEmpty);
  }

  Future<void> _loadLocalCache(String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('$_cachePrefix$address');
      if (cachedJson == null || !mounted) return;

      final List<dynamic> decoded = jsonDecode(cachedJson);
      final cachedTxs = decoded
          .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .where((t) => t.isValid)
          .toList();

      if (cachedTxs.isNotEmpty) {
        setState(() {
          _allTransactions = cachedTxs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('读取交易缓存失败: $e');
    }
  }

  Future<void> _saveToCache(String address, List<Transaction> txs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final limited = txs.take(50).toList();
      final encoded =
      jsonEncode(limited.map((t) => t.toJson()).toList());
      await prefs.setString('$_cachePrefix$address', encoded);
    } catch (e) {
      debugPrint('保存交易缓存失败: $e');
    }
  }

  // --- 核心刷新逻辑（防竞态 + 去重 + 排序） ---

  Future<void> _fetchTransactions({bool showLoading = false}) async {
    final int token = ++_refreshToken;

    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final wallet = await _storageService.getCurrentWallet();
      final address = wallet?.address;
      if (address == null || address.isEmpty) {
        if (mounted) {
          setState(() {
            _allTransactions = [];
            _isLoading = false;
          });
        }
        return;
      }

      final String requestAddr = address; // 固化地址

      final txs = await _walletService.getTransactions(requestAddr);

      if (!mounted || token != _refreshToken) return;

      // 二次校验：当前钱包是否仍一致
      final current = await _storageService.getCurrentWallet();
      if (current?.address != requestAddr) return;

      // 去重（按 txHash）
      final Map<String, Transaction> dedup = {};
      for (final t in txs) {
        if (t.isValid) {
          dedup[t.txHash] = t;
        }
      }

      final List<Transaction> validTxs = dedup.values.toList()
        ..sort((a, b) {
          // pending / 无时间在最前，其余按时间倒序
          final at = a.timestamp;
          final bt = b.timestamp;
          if (at == null && bt == null) return 0;
          if (at == null) return -1;
          if (bt == null) return 1;
          return bt.compareTo(at);
        });

      setState(() {
        _allTransactions = validTxs;
        _isLoading = false;
      });

      // 不阻塞 UI
      unawaited(_saveToCache(requestAddr, validTxs));
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI 逻辑 ---

  Future<void> _onPullRefresh() async {
    await _fetchTransactions(showLoading: false);
  }

  List<Transaction> get _filteredTransactions {
    switch (_activeFilter) {
      case 1:
        return _allTransactions.where((t) => t.isSent).toList();
      case 2:
        return _allTransactions.where((t) => t.isReceived).toList();
      default:
        return _allTransactions;
    }
  }

  String _shortenHash(String hash) {
    if (hash.length < 12) return hash;
    return '${hash.substring(0, 8)}...${hash.substring(hash.length - 8)}';
  }

  @override
  Widget build(BuildContext context) {
    final loc = L10n.of(context);
    return AppScaffold(
      statusBarIconBrightness: Brightness.light,
      useSafeArea: false,
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background,
            scrolledUnderElevation: 0,
            toolbarHeight: 72,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  loc.t('history'),
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: _buildFilterBar(loc),
            ),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: _onPullRefresh,
            builder: (context, refreshState, pulledExtent,
                refreshTriggerPullDistance, refreshIndicatorExtent) {
              return Center(
                child: Opacity(
                  opacity:
                  (pulledExtent / refreshTriggerPullDistance)
                      .clamp(0.0, 1.0),
                  child: const CupertinoActivityIndicator(
                      radius: 10,
                      color: AppColors.textSecondary),
                ),
              );
            },
          ),
          if (_isLoading && _allTransactions.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                  child: CupertinoActivityIndicator(
                      color: AppColors.textSecondary)),
            )
          else
            ..._buildSliversForList(loc),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // --- 以下 UI 构建函数与你原版一致（未再改动） ---

  Widget _buildFilterBar(L10n loc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _filterChip(0, loc.t('all')),
          _filterChip(1, loc.t('sent')),
          _filterChip(2, loc.t('received')),
        ],
      ),
    );
  }

  Widget _filterChip(int index, String label) {
    final selected = _activeFilter == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _activeFilter = index);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.button : AppColors.card,
          borderRadius: AppRadii.pill,
          border: Border.all(
              color: selected
                  ? Colors.transparent
                  : Colors.white.withOpacity(0.05)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
            selected ? Colors.white : AppColors.textSecondary,
            fontSize: 14,
            fontWeight:
            selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSliversForList(L10n loc) {
    final txs = _filteredTransactions;
    if (txs.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(loc.t('no_transactions'),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
          ),
        ),
      ];
    }

    final Map<String, List<Transaction>> grouped = {};
    final locale =
    Localizations.localeOf(context).toLanguageTag();
    final isZh = locale.startsWith('zh');

    for (final tx in txs) {
      final key = tx.timestamp == null || tx.status == 'pending'
          ? loc.t('pending')
          : (isZh
          ? DateFormat('yyyy/MM/dd', locale)
          .format(tx.timestamp!)
          : DateFormat('dd MMMM yyyy', locale)
          .format(tx.timestamp!));
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    final keys = grouped.keys.toList();

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final groupKey = keys[index];
              final items = grouped[groupKey]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                        top: 24, bottom: 12, left: 4),
                    child: Text(
                      groupKey.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  ...items.map(
                          (tx) => _buildTransactionCard(tx, loc)),
                ],
              );
            },
            childCount: keys.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildTransactionCard(Transaction tx, L10n loc) {
    final isPending =
        tx.status == 'pending' || tx.confirmations <= 0;
    final isSent = tx.isSent;
    final mainColor = isPending
        ? Colors.orange
        : (isSent
        ? const Color(0xFFFF5252)
        : const Color(0xFF00E676));

    final title = isPending
        ? loc.t('confirmation_in_progress')
        : (isSent ? loc.t('sent') : loc.t('receive'));
    final icon =
    isSent ? Icons.arrow_upward : Icons.arrow_downward;
    final displayAmount =
        '${isSent ? '-' : '+'}${tx.amountText} SCASH';

    return Container(
      key: ValueKey(tx.txHash),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadii.r16,
        border: Border.all(
            color: isPending
                ? Colors.orange.withOpacity(0.3)
                : Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: mainColor.withOpacity(0.1),
                shape: BoxShape.circle),
            child: isPending
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.orange),
            )
                : Icon(icon, color: mainColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(_shortenHash(tx.txHash),
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(displayAmount,
                  style: TextStyle(
                      color: mainColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                isPending
                    ? loc.t('pending')
                    : '${tx.confirmations} ${loc.t('confirmations_label')}',
                style: TextStyle(
                    color:
                    isPending ? Colors.orange : AppColors.textSecondary,
                    fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
