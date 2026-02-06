import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/stock.dart';
import '../providers/analysis_provider.dart';
import '../providers/stock_provider.dart';
import '../services/crypto_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import 'dashboard_screen.dart';
import '../widgets/app_bar_actions.dart';

class CryptoScreen extends StatefulWidget {
  const CryptoScreen({super.key});

  @override
  State<CryptoScreen> createState() => _CryptoScreenState();
}

class _CryptoScreenState extends State<CryptoScreen> {
  final CryptoService _cryptoService = CryptoService();
  final TextEditingController _searchController = TextEditingController();
  List<Cryptocurrency> _cryptos = [];
  List<Cryptocurrency> _filteredCryptos = [];
  List<TrendingCrypto> _trending = [];
  Map<String, dynamic> _globalData = {};
  bool _isLoading = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      _cryptoService.getTopCryptos(limit: 50),
      _cryptoService.getTrending(),
      _cryptoService.getGlobalData(),
    ]);

    setState(() {
      _cryptos = results[0] as List<Cryptocurrency>;
      _filteredCryptos = _cryptos;
      _trending = results[1] as List<TrendingCrypto>;
      _globalData = results[2] as Map<String, dynamic>;
      _isLoading = false;
    });
  }

  void _filterCryptos(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      if (query.isEmpty) {
        _filteredCryptos = _cryptos;
      } else {
        final q = query.toLowerCase();
        _filteredCryptos = _cryptos.where((c) =>
            c.symbol.toLowerCase().contains(q) ||
            c.name.toLowerCase().contains(q)).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Krypto-Märkte',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          ...buildCommonAppBarActions(context),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: CustomScrollView(
                slivers: [
                  // Search bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Crypto suchen...',
                          hintStyle: const TextStyle(color: AppColors.textHint),
                          prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: AppColors.textHint),
                                  onPressed: () {
                                    _searchController.clear();
                                    _filterCryptos('');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: AppColors.card,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: _filterCryptos,
                      ),
                    ),
                  ),
                  if (!_isSearching) ...[
                    SliverToBoxAdapter(child: _buildGlobalStats()),
                    SliverToBoxAdapter(child: _buildTrendingSection()),
                  ],
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text(
                        _isSearching
                            ? '${_filteredCryptos.length} Ergebnisse'
                            : 'Top Kryptowährungen',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _CryptoCard(
                        crypto: _filteredCryptos[index],
                        onTap: () => _showCryptoDetail(_filteredCryptos[index]),
                        onAnalyze: () => _navigateToAnalysis(context, _filteredCryptos[index].symbol),
                      ),
                      childCount: _filteredCryptos.length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
    );
  }

  Widget _buildGlobalStats() {
    final totalMarketCap = _globalData['total_market_cap']?['usd'] ?? 0;
    final totalVolume = _globalData['total_volume']?['usd'] ?? 0;
    final btcDominance = _globalData['market_cap_percentage']?['btc'] ?? 0;
    final ethDominance = _globalData['market_cap_percentage']?['eth'] ?? 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withValues(alpha: 0.3),
            Colors.deepOrange.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Globaler Krypto-Markt',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            Formatters.formatMarketCap(totalMarketCap.toDouble()),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatChip('24h Volumen', Formatters.formatMarketCap(totalVolume.toDouble())),
              _buildStatChip('BTC', '${btcDominance.toStringAsFixed(1)}%'),
              _buildStatChip('ETH', '${ethDominance.toStringAsFixed(1)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textHint, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingSection() {
    if (_trending.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                'Trending',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _trending.length,
            itemBuilder: (context, index) {
              final crypto = _trending[index];
              return Container(
                width: 140,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Card(
                  color: AppColors.card,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (crypto.thumb != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  crypto.thumb!,
                                  width: 24,
                                  height: 24,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.currency_bitcoin,
                                    color: Colors.orange,
                                    size: 24,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                crypto.symbol,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          crypto.name,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCryptoDetail(Cryptocurrency crypto) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CryptoDetailSheet(crypto: crypto),
    );
  }

  void _navigateToAnalysis(BuildContext context, String symbol) {
    // Symbol im Provider setzen (Crypto-Symbol für yfinance: z.B. BTC -> BTC-USD)
    final yfinanceSymbol = '$symbol-USD';
    context.read<AnalysisProvider>().setSymbolForAnalysis(yfinanceSymbol, 'Crypto');
    // Zum KI-Analyse Tab navigieren (Index 3)
    final state = context.findAncestorStateOfType<DashboardScreenState>();
    state?.setTabIndex(3);
  }
}

class _CryptoCard extends StatelessWidget {
  final Cryptocurrency crypto;
  final VoidCallback onTap;
  final VoidCallback? onAnalyze;

  const _CryptoCard({required this.crypto, required this.onTap, this.onAnalyze});

  String get _watchlistSymbol => '${crypto.symbol.toUpperCase()}-USD';

  @override
  Widget build(BuildContext context) {
    final changeColor = crypto.isPositive24h ? AppColors.profit : AppColors.loss;

    return Consumer<StockProvider>(
      builder: (context, stockProvider, _) {
        final isInWatchlist = stockProvider.isInWatchlist(_watchlistSymbol);

        return Card(
          color: AppColors.card,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Rank
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${crypto.marketCapRank}',
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  // Icon & Name
                  if (crypto.image != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        crypto.image!,
                        width: 32,
                        height: 32,
                        errorBuilder: (_, _, _) => Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.cardLight,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.currency_bitcoin, size: 20, color: Colors.orange),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          crypto.symbol,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          crypto.name,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Sparkline
                  if (crypto.sparkline.isNotEmpty)
                    SizedBox(
                      width: 60,
                      height: 30,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: crypto.sparkline
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(e.key.toDouble(), e.value))
                                  .toList(),
                              isCurved: true,
                              color: changeColor,
                              barWidth: 1.5,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(show: false),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  // Price
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatPrice(crypto.price),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: changeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            Formatters.formatPercent(crypto.change24h),
                            style: TextStyle(
                              color: changeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Watchlist star
                  IconButton(
                    onPressed: () {
                      if (isInWatchlist) {
                        stockProvider.removeFromWatchlist(_watchlistSymbol);
                      } else {
                        stockProvider.addToWatchlist(_watchlistSymbol, assetType: 'Crypto');
                      }
                    },
                    icon: Icon(
                      isInWatchlist ? Icons.star : Icons.star_border,
                      color: isInWatchlist ? Colors.amber : AppColors.textHint,
                      size: 22,
                    ),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                    tooltip: isInWatchlist ? 'Aus Watchlist entfernen' : 'Zur Watchlist',
                  ),
                  if (onAnalyze != null) ...[
                    IconButton(
                      onPressed: onAnalyze,
                      icon: const Icon(
                        Icons.psychology,
                        color: Colors.deepPurple,
                        size: 24,
                      ),
                      tooltip: 'KI-Analyse',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.deepPurple.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatPrice(double price) {
    if (price >= 1) return Formatters.formatCurrency(price);
    if (price >= 0.01) return '\$${price.toStringAsFixed(4)}';
    return '\$${price.toStringAsFixed(8)}';
  }
}

class _CryptoDetailSheet extends StatelessWidget {
  final Cryptocurrency crypto;

  const _CryptoDetailSheet({required this.crypto});

  String get _portfolioSymbol => '${crypto.symbol.toUpperCase()}-USD';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textHint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Header
              Row(
                children: [
                  if (crypto.image != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.network(crypto.image!, width: 48, height: 48),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          crypto.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          crypto.symbol,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#${crypto.marketCapRank}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Price
              Text(
                _formatPrice(crypto.price),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildChangeChip('1h', crypto.change1h),
                  const SizedBox(width: 8),
                  _buildChangeChip('24h', crypto.change24h),
                  const SizedBox(width: 8),
                  _buildChangeChip('7d', crypto.change7d),
                ],
              ),
              const SizedBox(height: 24),
              // Virtual Buy/Sell Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showTradeDialog(context, true),
                      icon: const Icon(Icons.shopping_cart_outlined, size: 18, color: Colors.white),
                      label: const Text(
                        'Virtuell kaufen',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.profit,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showTradeDialog(context, false),
                      icon: const Icon(Icons.sell_outlined, size: 18, color: Colors.white),
                      label: const Text(
                        'Virtuell verkaufen',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.loss,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Stats
              _buildStatRow('Marktkapitalisierung', Formatters.formatMarketCap(crypto.marketCap)),
              _buildStatRow('24h Volumen', Formatters.formatMarketCap(crypto.volume24h)),
              _buildStatRow('24h Hoch', _formatPrice(crypto.high24h)),
              _buildStatRow('24h Tief', _formatPrice(crypto.low24h)),
              if (crypto.ath != null)
                _buildStatRow('Allzeithoch', _formatPrice(crypto.ath!)),
              if (crypto.athChangePercent != null)
                _buildStatRow('Vom ATH', Formatters.formatPercent(crypto.athChangePercent!)),
              _buildStatRow(
                'Umlaufmenge',
                '${Formatters.formatVolume(crypto.circulatingSupply.toInt())} ${crypto.symbol}',
              ),
              if (crypto.totalSupply != null)
                _buildStatRow(
                  'Gesamtmenge',
                  '${Formatters.formatVolume(crypto.totalSupply!.toInt())} ${crypto.symbol}',
                ),
            ],
          ),
        );
      },
    );
  }

  void _showTradeDialog(BuildContext context, bool isBuy) {
    final sharesController = TextEditingController();
    int shares = 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final total = shares * crypto.price;
          return Padding(
            padding: EdgeInsets.only(
              left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.textHint, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '📊 Virtuelles Portfolio',
                    style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${isBuy ? 'Virtuell kaufen' : 'Virtuell verkaufen'}: ${crypto.symbol}',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aktueller Kurs: ${_formatPrice(crypto.price)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: sharesController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Anzahl Coins',
                    labelStyle: const TextStyle(color: AppColors.textHint),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    filled: true,
                    fillColor: AppColors.card,
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      shares = int.tryParse(value) ?? 0;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Geschätzter Gesamtwert', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      Text(Formatters.formatCurrency(total), style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: shares > 0
                        ? () {
                            final provider = Provider.of<StockProvider>(ctx, listen: false);
                            if (isBuy) {
                              provider.addToPortfolio(
                                PortfolioPosition(
                                  symbol: _portfolioSymbol,
                                  name: crypto.name,
                                  shares: shares,
                                  avgPrice: crypto.price,
                                  currentPrice: crypto.price,
                                  purchaseDate: DateTime.now(),
                                ),
                              );
                            }
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isBuy
                                      ? '$shares ${crypto.symbol} zum virtuellen Portfolio hinzugefügt'
                                      : '$shares ${crypto.symbol} virtuell verkauft',
                                ),
                                backgroundColor: isBuy ? AppColors.profit : AppColors.loss,
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isBuy ? AppColors.profit : AppColors.loss,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      isBuy ? 'Virtuell kaufen bestätigen' : 'Virtuell verkaufen bestätigen',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChangeChip(String label, double value) {
    final color = value >= 0 ? AppColors.profit : AppColors.loss;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: ${Formatters.formatPercent(value)}',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1) return Formatters.formatCurrency(price);
    if (price >= 0.01) return '\$${price.toStringAsFixed(4)}';
    return '\$${price.toStringAsFixed(8)}';
  }
}
