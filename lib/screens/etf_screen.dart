import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/etf.dart';
import '../providers/analysis_provider.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import 'dashboard_screen.dart';

class ETFScreen extends StatefulWidget {
  const ETFScreen({super.key});

  @override
  State<ETFScreen> createState() => _ETFScreenState();
}

class _ETFScreenState extends State<ETFScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<ETF> _etfs = ETF.getPopularETFs();
  final List<Sector> _sectors = Sector.getSectors();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'ETFs & Sectors',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Popular ETFs'),
            Tab(text: 'Sectors'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildETFList(),
          _buildSectorList(),
        ],
      ),
    );
  }

  Widget _buildETFList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _etfs.length,
      itemBuilder: (context, index) {
        final etf = _etfs[index];
        return _ETFCard(
          etf: etf,
          onTap: () => _showETFDetail(etf),
          onAnalyze: () => _navigateToAnalysis(context, etf.symbol),
        );
      },
    );
  }

  Widget _buildSectorList() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPerformanceHeader('1D'),
              _buildPerformanceHeader('1W'),
              _buildPerformanceHeader('1M'),
              _buildPerformanceHeader('YTD'),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _sectors.length,
            itemBuilder: (context, index) {
              final sector = _sectors[index];
              return _SectorCard(sector: sector);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceHeader(String label) {
    return SizedBox(
      width: 50,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textHint,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showETFDetail(ETF etf) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ETFDetailSheet(etf: etf),
    );
  }

  void _navigateToAnalysis(BuildContext context, String symbol) {
    // Symbol im Provider setzen
    context.read<AnalysisProvider>().setSymbolForAnalysis(symbol, 'ETF');
    // Zum KI-Analyse Tab navigieren (Index 3)
    final state = context.findAncestorStateOfType<DashboardScreenState>();
    state?.setTabIndex(3);
  }
}

class _ETFCard extends StatelessWidget {
  final ETF etf;
  final VoidCallback onTap;
  final VoidCallback? onAnalyze;

  const _ETFCard({required this.etf, required this.onTap, this.onAnalyze});

  @override
  Widget build(BuildContext context) {
    final changeColor = etf.isPositive ? AppColors.profit : AppColors.loss;

    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              etf.symbol,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                etf.category,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          etf.name,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.formatCurrency(etf.price),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: changeColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          Formatters.formatChange(etf.change, etf.changePercent),
                          style: TextStyle(
                            color: changeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (onAnalyze != null) ...[
                    const SizedBox(width: 8),
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
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoChip('AUM', Formatters.formatMarketCap(etf.aum)),
                  _buildInfoChip('Exp. Ratio', '${etf.expenseRatio.toStringAsFixed(2)}%'),
                  _buildInfoChip('YTD', Formatters.formatPercent(etf.ytdReturn)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textHint, fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SectorCard extends StatelessWidget {
  final Sector sector;

  const _SectorCard({required this.sector});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sector.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    sector.etfSymbol,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            _buildPerformanceCell(sector.performance1D),
            _buildPerformanceCell(sector.performance1W),
            _buildPerformanceCell(sector.performance1M),
            _buildPerformanceCell(sector.performanceYTD),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCell(double value) {
    final color = value >= 0 ? AppColors.profit : AppColors.loss;
    return SizedBox(
      width: 55,
      child: Text(
        Formatters.formatPercent(value),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ETFDetailSheet extends StatelessWidget {
  final ETF etf;

  const _ETFDetailSheet({required this.etf});

  @override
  Widget build(BuildContext context) {
    final changeColor = etf.isPositive ? AppColors.profit : AppColors.loss;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
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
              Text(
                etf.symbol,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                etf.name,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              // Price
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.formatCurrency(etf.price),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: changeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      Formatters.formatChange(etf.change, etf.changePercent),
                      style: TextStyle(
                        color: changeColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Performance
              const Text(
                'Performance',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPerformanceChip('YTD', etf.ytdReturn),
                  _buildPerformanceChip('1Y', etf.oneYearReturn),
                  _buildPerformanceChip('3Y', etf.threeYearReturn),
                ],
              ),
              const SizedBox(height: 24),
              // Stats
              _buildStatRow('NAV', Formatters.formatCurrency(etf.nav)),
              _buildStatRow('AUM', Formatters.formatMarketCap(etf.aum)),
              _buildStatRow('Expense Ratio', '${etf.expenseRatio.toStringAsFixed(2)}%'),
              _buildStatRow('Category', etf.category),
              if (etf.issuer != null) _buildStatRow('Issuer', etf.issuer!),
              _buildStatRow('Volume', Formatters.formatVolume(etf.volume)),
              _buildStatRow('Day High', Formatters.formatCurrency(etf.high)),
              _buildStatRow('Day Low', Formatters.formatCurrency(etf.low)),
              const SizedBox(height: 24),
              // Top Holdings
              if (etf.topHoldings.isNotEmpty) ...[
                const Text(
                  'Top Holdings',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...etf.topHoldings.map((holding) => _buildHoldingRow(holding)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPerformanceChip(String label, double value) {
    final color = value >= 0 ? AppColors.profit : AppColors.loss;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textHint, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            Formatters.formatPercent(value),
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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

  Widget _buildHoldingRow(ETFHolding holding) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                holding.symbol.substring(0, holding.symbol.length.clamp(0, 2)),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holding.symbol,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  holding.name,
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
          Text(
            '${holding.weight.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
