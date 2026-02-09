import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:ui' show FontFeature;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../utils/I10n.dart';
import '../../../../core/widgets/app_radii.dart';
import '../../domain/asset.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../../../../services/wallet_service.dart';
import '../../../../core/widgets/app_scaffold.dart';

class AssetChartPage extends StatefulWidget {
  final Asset asset;
  final WalletService walletService;

  const AssetChartPage({
    super.key,
    required this.asset,
    required this.walletService,
  });

  @override
  State<AssetChartPage> createState() => _AssetChartPageState();
}

class _AssetChartPageState extends State<AssetChartPage> {
  List<FlSpot> _spots = [];
  bool _isLoading = true;
  String _selectedPeriod = '1D';

  final Map<String, List<FlSpot>> _dataCache = {};

  double? _hoverPrice;
  DateTime? _hoverTime;

  double? _fixedMinY;
  double? _fixedMaxY;

  // 缓存 Key：带上 symbol（避免未来多资产串缓存）
  late final String _chartKeyPrefix;

  final Map<String, String> _periodDays = {
    '1H': '1',
    '1D': '1',
    '1W': '7',
    '1M': '30',
    '1Y': '365',
  };

  String _formatCompact(double value, {int fractionDigits = 4}) {
    return value
        .toStringAsFixed(fractionDigits)
        .replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
  }

  @override
  void initState() {
    super.initState();
    _chartKeyPrefix = 'cache_chart_v2_${widget.asset.symbol}_';
    _initializeChartData();
  }

  /// 核心加载流程
  Future<void> _initializeChartData() async {
    // 1) 优先读取磁盘缓存（默认周期）
    final disk = await _loadPersistentCacheFor(_selectedPeriod);
    if (mounted && disk.isNotEmpty) {
      setState(() {
        _spots = disk;
        _dataCache[_selectedPeriod] = disk;
        _isLoading = false;
        _computeFixedYRange(disk);
      });
    }

    // 2) 拉取/刷新（如果有缓存则静默刷新；没缓存则显示 loading）
    unawaited(_loadData(_selectedPeriod));

    // 3) 预热其他常用周期（不影响主流程）
    unawaited(_preloadData(['1W', '1M']));
  }

  /// 从磁盘读取 JSON 缓存（按 period）
  Future<List<FlSpot>> _loadPersistentCacheFor(String period) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('$_chartKeyPrefix$period');
      if (jsonStr == null) return [];

      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      final spots = decoded
          .map((e) => FlSpot(
        (e['x'] as num).toDouble(),
        (e['y'] as num).toDouble(),
      ))
          .toList();

      spots.sort((a, b) => a.x.compareTo(b.x));
      return spots;
    } catch (e) {
      debugPrint('读取图表缓存失败($period): $e');
      return [];
    }
  }

  /// 保存数据到磁盘
  Future<void> _savePersistentCache(String period, List<FlSpot> spots) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded =
      jsonEncode(spots.map((e) => {'x': e.x, 'y': e.y}).toList());
      await prefs.setString('$_chartKeyPrefix$period', encoded);
    } catch (e) {
      debugPrint('保存图表缓存失败($period): $e');
    }
  }

  Future<void> _preloadData(List<String> periods) async {
    for (final p in periods) {
      if (_dataCache.containsKey(p)) continue;

      // 先尝试磁盘（减少不必要网络）
      final disk = await _loadPersistentCacheFor(p);
      if (disk.isNotEmpty) {
        _dataCache[p] = disk;
        continue;
      }

      try {
        final rawData =
        await widget.walletService.getPriceHistory(days: _periodDays[p]!);
        final processed = _processRawData(rawData, p);
        if (processed.isEmpty) continue;

        _dataCache[p] = processed;
        unawaited(_savePersistentCache(p, processed));
      } catch (_) {}
    }
  }

  List<FlSpot> _processRawData(List<dynamic> rawData, String period) {
    if (rawData.isEmpty) return [];

    List<FlSpot> points = rawData
        .map((item) => FlSpot(
      (item['time'] as num).toDouble(),
      (item['price'] as num).toDouble(),
    ))
        .toList();

    // 1H：从 1D 数据中截取最近 60 分钟
    if (period == '1H') {
      final sixtyMinutesAgo =
          DateTime.now().millisecondsSinceEpoch - (60 * 60 * 1000);
      points = points.where((p) => p.x >= sixtyMinutesAgo).toList();
    }

    points.sort((a, b) => a.x.compareTo(b.x));
    return points;
  }

  void _computeFixedYRange(List<FlSpot> spots) {
    if (spots.isEmpty) return;
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    final rawPadding = (maxY - minY) * 0.15;
    final padding =
    rawPadding == 0 ? (minY.abs() * 0.02 + 0.0001) : rawPadding;

    _fixedMinY = minY - padding;
    _fixedMaxY = maxY + padding;
  }

  Future<void> _loadData(String period) async {
    // 内存缓存：立即显示 + 后台更新
    final mem = _dataCache[period];
    if (mem != null && mem.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _selectedPeriod = period;
        _spots = mem;
        _isLoading = false;
        _computeFixedYRange(mem);
      });
      unawaited(_backgroundUpdate(period));
      return;
    }

    // 磁盘缓存：立即显示 + 后台更新
    final disk = await _loadPersistentCacheFor(period);
    if (disk.isNotEmpty) {
      _dataCache[period] = disk;
      if (!mounted) return;
      setState(() {
        _selectedPeriod = period;
        _spots = disk;
        _isLoading = false;
        _computeFixedYRange(disk);
      });
      unawaited(_backgroundUpdate(period));
      return;
    }

    // 没任何数据：才转圈
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _selectedPeriod = period;
      _spots = [];
      _fixedMinY = null;
      _fixedMaxY = null;
      _clearHover();
    });

    try {
      final rawData =
      await widget.walletService.getPriceHistory(days: _periodDays[period]!);
      if (!mounted) return;

      final processedPoints = _processRawData(rawData, period);

      _dataCache[period] = processedPoints;
      unawaited(_savePersistentCache(period, processedPoints));

      _computeFixedYRange(processedPoints);

      setState(() {
        _spots = processedPoints;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      TopToast.errorKey(context, 'toast_request_failed');
    }
  }

  Future<void> _backgroundUpdate(String period) async {
    try {
      final rawData =
      await widget.walletService.getPriceHistory(days: _periodDays[period]!);
      final updated = _processRawData(rawData, period);

      // 不要用空数据覆盖已有图表
      if (updated.isEmpty) return;

      _dataCache[period] = updated;
      unawaited(_savePersistentCache(period, updated));

      if (mounted && _selectedPeriod == period) {
        setState(() {
          _spots = updated;
          _computeFixedYRange(updated);
        });
      }
    } catch (_) {}
  }

  // --- 交互与 UI 构建 ---

  void _updateHoverFromSpot(FlSpot spot) {
    final newPrice = spot.y;
    final newTime = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
    if (_hoverPrice == newPrice && _hoverTime == newTime) return;

    setState(() {
      _hoverPrice = newPrice;
      _hoverTime = newTime;
    });
  }

  void _clearHover() {
    if (_hoverPrice == null && _hoverTime == null) return;
    setState(() {
      _hoverPrice = null;
      _hoverTime = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      statusBarIconBrightness: Brightness.light,
      useSafeArea: false,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 30),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.35,
            child: (_isLoading && _spots.isEmpty)
                ? const Center(
                child: CircularProgressIndicator(color: AppColors.button))
                : AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildFlChart(key: ValueKey(_selectedPeriod)),
            ),
          ),
          Expanded(child: _buildFunctionalArea()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final loc = L10n.of(context);

    final String priceText = _hoverPrice != null
        ? _formatCompact(_hoverPrice!)
        : _formatCompact(widget.asset.price, fractionDigits: 4);

    final String timeText = _hoverTime != null
        ? DateFormat(_selectedPeriod == '1H' ? 'HH:mm:ss' : 'MM-dd HH:mm')
        .format(_hoverTime!)
        : '$_selectedPeriod · ${loc.t('market_price')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 70, // 固定 Header 高度，避免因文字高度/行距变化引起跳动
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '\$$priceText',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.button,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 48,
              height: 48,
              child: (widget.asset.logo != null)
                  ? Hero(
                tag: 'asset_logo',
                child: Image.asset(widget.asset.logo!, width: 48, height: 48),
              )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlChart({Key? key}) {
    if (_spots.isEmpty) return const SizedBox();
    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          touchCallback: (event, response) {
            if (event is FlPanEndEvent || event is FlTapUpEvent) {
              _clearHover();
              return;
            }
            if (response?.lineBarSpots != null &&
                response!.lineBarSpots!.isNotEmpty) {
              _updateHoverFromSpot(response.lineBarSpots!.first);
            }
          },
          handleBuiltInTouches: true,
          getTouchedSpotIndicator: (barData, indicators) => indicators
              .map(
                (i) => TouchedSpotIndicatorData(
              FlLine(
                  color: AppColors.button.withOpacity(0.3),
                  strokeWidth: 2,
                  dashArray: [5, 5]),
              FlDotData(show: true),
            ),
          )
              .toList(),
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            getTooltipItems: (s) => s.map((_) => null).toList(),
          ),
        ),
        titlesData: const FlTitlesData(show: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        minY: _fixedMinY,
        maxY: _fixedMaxY,
        lineBarsData: [
          LineChartBarData(
            spots: _spots,
            isCurved: true,
            color: AppColors.button,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.button.withOpacity(0.3),
                  Colors.transparent
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionalArea() {
    final loc = L10n.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['1H', '1D', '1W', '1M', '1Y'].map((range) {
              final isSelected = _selectedPeriod == range;
              return GestureDetector(
                onTap: () => _loadData(range),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.button.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: AppRadii.pill,
                  ),
                  child: Text(
                    range,
                    style: TextStyle(
                      color: isSelected ? AppColors.button : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _buildInfoTile(
            loc.t('availableBalance'),
            '${_formatCompact(widget.asset.balance, fractionDigits: 6)} SCASH',
          ),
          _buildInfoTile(
            loc.t('estimated_value'),
            '\$${_formatCompact(widget.asset.price * widget.asset.balance, fractionDigits: 4)}',
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 16)),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
