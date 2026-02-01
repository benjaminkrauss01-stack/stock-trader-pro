import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/stock.dart';
import '../providers/stock_provider.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/stock_chart.dart';

class StockDetailScreen extends StatefulWidget {
  final String symbol;

  const StockDetailScreen({super.key, required this.symbol});

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StockProvider>().selectStock(widget.symbol);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.symbol,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          Consumer<StockProvider>(
            builder: (context, provider, _) {
              final isInWatchlist = provider.isInWatchlist(widget.symbol);
              return IconButton(
                icon: Icon(
                  isInWatchlist ? Icons.star : Icons.star_border,
                  color: isInWatchlist ? Colors.amber : AppColors.textSecondary,
                ),
                onPressed: () {
                  if (isInWatchlist) {
                    provider.removeFromWatchlist(widget.symbol);
                  } else {
                    provider.addToWatchlist(widget.symbol);
                  }
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: () {
              context.read<StockProvider>().selectStock(widget.symbol);
            },
          ),
        ],
      ),
      body: Consumer<StockProvider>(
        builder: (context, provider, _) {
          final stock = provider.selectedStock;

          if (provider.isLoading && stock == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (stock == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load stock data',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.selectStock(widget.symbol),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final changeColor = stock.isPositive ? AppColors.profit : AppColors.loss;

          return RefreshIndicator(
            onRefresh: () => provider.selectStock(widget.symbol),
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with price
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stock.name,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              Formatters.formatCurrency(stock.price, currency: stock.currency),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: changeColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    stock.isPositive
                                        ? Icons.arrow_drop_up
                                        : Icons.arrow_drop_down,
                                    color: changeColor,
                                    size: 20,
                                  ),
                                  Text(
                                    Formatters.formatChange(
                                      stock.change,
                                      stock.changePercent,
                                    ),
                                    style: TextStyle(
                                      color: changeColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (stock.lastUpdate != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Last updated: ${Formatters.formatDateTime(stock.lastUpdate!)}',
                            style: const TextStyle(
                              color: AppColors.textHint,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Chart
                  StockChart(
                    candles: provider.chartData,
                    selectedRange: provider.selectedRange,
                    onRangeChanged: provider.setChartRange,
                  ),

                  const SizedBox(height: 24),

                  // Statistics
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Statistics',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStatsGrid(stock),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _showTradeDialog(context, 'Buy'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.profit,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Buy',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _showTradeDialog(context, 'Sell'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.loss,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Sell',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsGrid(Stock stock) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatItem('Open', Formatters.formatCurrency(stock.open))),
              Expanded(child: _buildStatItem('High', Formatters.formatCurrency(stock.high))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatItem('Low', Formatters.formatCurrency(stock.low))),
              Expanded(
                  child:
                      _buildStatItem('Prev Close', Formatters.formatCurrency(stock.previousClose))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatItem('Volume', Formatters.formatVolume(stock.volume))),
              Expanded(
                  child: _buildStatItem(
                      '52W Range', '${Formatters.formatNumber(stock.low)} - ${Formatters.formatNumber(stock.high)}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textHint,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showTradeDialog(BuildContext context, String action) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => TradeSheet(
        symbol: widget.symbol,
        action: action,
      ),
    );
  }
}

class TradeSheet extends StatefulWidget {
  final String symbol;
  final String action;

  const TradeSheet({
    super.key,
    required this.symbol,
    required this.action,
  });

  @override
  State<TradeSheet> createState() => _TradeSheetState();
}

class _TradeSheetState extends State<TradeSheet> {
  final _sharesController = TextEditingController();
  int _shares = 0;

  @override
  void dispose() {
    _sharesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StockProvider>(
      builder: (context, provider, _) {
        final stock = provider.selectedStock;
        if (stock == null) return const SizedBox.shrink();

        final total = _shares * stock.price;
        final isBuy = widget.action == 'Buy';

        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textHint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '${widget.action} ${widget.symbol}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Current Price: ${Formatters.formatCurrency(stock.price)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _sharesController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Number of Shares',
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
                  setState(() {
                    _shares = int.tryParse(value) ?? 0;
                  });
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Estimated Total',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      Formatters.formatCurrency(total),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _shares > 0
                      ? () {
                          if (isBuy) {
                            provider.addToPortfolio(
                              PortfolioPosition(
                                symbol: stock.symbol,
                                name: stock.name,
                                shares: _shares,
                                avgPrice: stock.price,
                                currentPrice: stock.price,
                                purchaseDate: DateTime.now(),
                              ),
                            );
                          }
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${widget.action} order for $_shares shares of ${widget.symbol} submitted',
                              ),
                              backgroundColor: isBuy ? AppColors.profit : AppColors.loss,
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBuy ? AppColors.profit : AppColors.loss,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Confirm ${widget.action}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
