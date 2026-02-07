import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../providers/analysis_provider.dart';
import '../utils/constants.dart';
import 'stock_detail_screen.dart';
import 'dashboard_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Search Stocks',
          style: TextStyle(color: AppColors.textPrimary),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by symbol or company name...',
                hintStyle: const TextStyle(color: AppColors.textHint),
                prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textHint),
                        onPressed: () {
                          _searchController.clear();
                          context.read<StockProvider>().clearSearch();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              onChanged: (value) {
                setState(() {});
                if (value.length >= 2) {
                  context.read<StockProvider>().searchStocks(value);
                } else {
                  context.read<StockProvider>().clearSearch();
                }
              },
            ),
          ),
          Expanded(
            child: Consumer<StockProvider>(
              builder: (context, provider, _) {
                final results = provider.searchResults;

                if (_searchController.text.isEmpty) {
                  return _buildPopularStocks(provider);
                }

                if (results.isEmpty && _searchController.text.length >= 2) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: AppColors.textHint,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No stocks found',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final result = results[index];
                    final symbol = result['symbol'] ?? '';
                    final name = result['name'] ?? '';
                    final exchange = result['exchange'] ?? '';
                    final quoteType = result['type'] ?? 'EQUITY';
                    final isInWatchlist = provider.isInWatchlist(symbol);

                    return Card(
                      color: AppColors.card,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => _navigateToDetail(context, symbol),
                        leading: CircleAvatar(
                          backgroundColor: quoteType == 'CRYPTOCURRENCY'
                              ? Colors.orange.withValues(alpha: 0.2)
                              : quoteType == 'ETF'
                                  ? Colors.teal.withValues(alpha: 0.2)
                                  : AppColors.primary.withValues(alpha: 0.2),
                          child: Icon(
                            quoteType == 'CRYPTOCURRENCY'
                                ? Icons.currency_bitcoin
                                : quoteType == 'ETF'
                                    ? Icons.account_balance
                                    : Icons.show_chart,
                            color: quoteType == 'CRYPTOCURRENCY'
                                ? Colors.orange
                                : quoteType == 'ETF'
                                    ? Colors.teal
                                    : AppColors.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          symbol,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: quoteType == 'CRYPTOCURRENCY'
                                        ? Colors.orange.withValues(alpha: 0.2)
                                        : quoteType == 'ETF'
                                            ? Colors.teal.withValues(alpha: 0.2)
                                            : AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    quoteType == 'CRYPTOCURRENCY'
                                        ? 'Crypto'
                                        : quoteType == 'ETF'
                                            ? 'ETF'
                                            : quoteType == 'MUTUALFUND'
                                                ? 'Fonds'
                                                : quoteType == 'INDEX'
                                                    ? 'Index'
                                                    : 'Aktie',
                                    style: TextStyle(
                                      color: quoteType == 'CRYPTOCURRENCY'
                                          ? Colors.orange
                                          : quoteType == 'ETF'
                                              ? Colors.teal
                                              : AppColors.textHint,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  exchange,
                                  style: const TextStyle(
                                    color: AppColors.textHint,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.psychology, color: AppColors.primary),
                              tooltip: 'KI-Analyse',
                              onPressed: () {
                                final assetType = quoteType == 'CRYPTOCURRENCY'
                                    ? 'Crypto'
                                    : quoteType == 'ETF'
                                        ? 'ETF'
                                        : 'Stock';
                                _startAnalysis(context, symbol, assetType);
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                isInWatchlist ? Icons.star : Icons.star_border,
                                color: isInWatchlist ? Colors.amber : AppColors.textHint,
                              ),
                              onPressed: () {
                                if (isInWatchlist) {
                                  provider.removeFromWatchlist(symbol);
                                } else {
                                  final assetType = quoteType == 'CRYPTOCURRENCY'
                                      ? 'Crypto'
                                      : quoteType == 'ETF'
                                          ? 'ETF'
                                          : 'Stock';
                                  provider.addToWatchlist(symbol, assetType: assetType);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularStocks(StockProvider provider) {
    final popularSymbols = [
      {'symbol': 'AAPL', 'name': 'Apple Inc.'},
      {'symbol': 'GOOGL', 'name': 'Alphabet Inc.'},
      {'symbol': 'MSFT', 'name': 'Microsoft Corporation'},
      {'symbol': 'AMZN', 'name': 'Amazon.com Inc.'},
      {'symbol': 'NVDA', 'name': 'NVIDIA Corporation'},
      {'symbol': 'META', 'name': 'Meta Platforms Inc.'},
      {'symbol': 'TSLA', 'name': 'Tesla Inc.'},
      {'symbol': 'BRK-B', 'name': 'Berkshire Hathaway'},
      {'symbol': 'JPM', 'name': 'JPMorgan Chase & Co.'},
      {'symbol': 'V', 'name': 'Visa Inc.'},
      {'symbol': 'AMD', 'name': 'Advanced Micro Devices'},
      {'symbol': 'NFLX', 'name': 'Netflix Inc.'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Popular Stocks',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: popularSymbols.length,
            itemBuilder: (context, index) {
              final stock = popularSymbols[index];
              final symbol = stock['symbol']!;
              final name = stock['name']!;
              final isInWatchlist = provider.isInWatchlist(symbol);

              return Card(
                color: AppColors.card,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => _navigateToDetail(context, symbol),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      symbol[0],
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    symbol,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.psychology, color: AppColors.primary),
                        tooltip: 'KI-Analyse',
                        onPressed: () => _startAnalysis(context, symbol, 'Stock'),
                      ),
                      IconButton(
                        icon: Icon(
                          isInWatchlist ? Icons.star : Icons.star_border,
                          color: isInWatchlist ? Colors.amber : AppColors.textHint,
                        ),
                        onPressed: () {
                          if (isInWatchlist) {
                            provider.removeFromWatchlist(symbol);
                          } else {
                            provider.addToWatchlist(symbol);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _navigateToDetail(BuildContext context, String symbol) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockDetailScreen(symbol: symbol),
      ),
    );
  }

  void _startAnalysis(BuildContext context, String symbol, String assetType) {
    context.read<AnalysisProvider>().setSymbolForAnalysis(symbol, assetType);
    // Pop zurück zum Dashboard und zum KI-Analyse Tab wechseln
    Navigator.of(context).pop();
    final state = context.findAncestorStateOfType<DashboardScreenState>();
    state?.setTabIndex(2);
  }
}
