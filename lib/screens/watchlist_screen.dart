import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../providers/analysis_provider.dart';
import '../utils/constants.dart';
import '../widgets/stock_card.dart';
import 'stock_detail_screen.dart';
import 'dashboard_screen.dart';
import '../widgets/app_bar_actions.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => context.read<StockProvider>().refreshAll(),
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: AppColors.background,
              title: const Row(
                children: [
                  Icon(Icons.star, color: Colors.amber),
                  SizedBox(width: 8),
                  Text(
                    'Watchlist',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actions: [
                ...buildCommonAppBarActions(context),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
                  onPressed: () => context.read<StockProvider>().refreshAll(),
                ),
              ],
            ),
            // Analysis Limit Banner
            SliverToBoxAdapter(
              child: Consumer<AnalysisProvider>(
                builder: (context, analysisProvider, _) {
                  return _buildAnalysisLimitBanner(context, analysisProvider);
                },
              ),
            ),
            // Watchlist Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Consumer<StockProvider>(
                  builder: (context, provider, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Meine Watchlist',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${provider.watchlistStocks.length} Titel',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            // Watchlist Items
            const _WatchlistContent(),
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisLimitBanner(BuildContext context, AnalysisProvider analysisProvider) {
    final remaining = analysisProvider.remainingAnalyses;
    final tier = analysisProvider.subscriptionTier;
    final maxAnalyses = tier == 'free' ? 5 : (tier == 'pro' ? 100 : -1);

    if (maxAnalyses == -1) {
      return const SizedBox.shrink();
    }

    final used = maxAnalyses - remaining;
    final percent = used / maxAnalyses;

    Color bannerColor;
    if (percent >= 0.9) {
      bannerColor = Colors.red.shade700;
    } else if (percent >= 0.7) {
      bannerColor = Colors.orange.shade600;
    } else {
      bannerColor = Colors.blue.shade600;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.15),
        border: Border.all(color: bannerColor, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology, color: bannerColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'KI-Analyse Limit',
                style: TextStyle(
                  color: bannerColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                '${remaining.toString()} verbleibend',
                style: TextStyle(
                  color: bannerColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              backgroundColor: bannerColor.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(bannerColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$used / $maxAnalyses Analysen verwendet',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchlistContent extends StatelessWidget {
  const _WatchlistContent();

  @override
  Widget build(BuildContext context) {
    return Consumer<StockProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.watchlistStocks.isEmpty) {
          return const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        if (provider.watchlistStocks.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.playlist_add, size: 64, color: AppColors.textHint),
                  const SizedBox(height: 16),
                  const Text(
                    'Deine Watchlist ist leer',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nutze die Suche, um Titel hinzuzufügen',
                    style: TextStyle(color: AppColors.textHint, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final stock = provider.watchlistStocks[index];
              return Dismissible(
                key: Key(stock.symbol),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: AppColors.loss,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  provider.removeFromWatchlist(stock.symbol);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${stock.symbol} entfernt'),
                      action: SnackBarAction(
                        label: 'Rückgängig',
                        onPressed: () => provider.addToWatchlist(stock.symbol),
                      ),
                    ),
                  );
                },
                child: StockCard(
                  stock: stock,
                  showVolume: true,
                  onTap: () => _navigateToDetail(context, stock.symbol),
                  onAnalyze: () => _navigateToAnalysis(context, stock.symbol, 'Stock'),
                ),
              );
            },
            childCount: provider.watchlistStocks.length,
          ),
        );
      },
    );
  }

  void _navigateToDetail(BuildContext context, String symbol) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StockDetailScreen(symbol: symbol)),
    );
  }

  void _navigateToAnalysis(BuildContext context, String symbol, String assetType) {
    context.read<AnalysisProvider>().setSymbolForAnalysis(symbol, assetType);
    final state = context.findAncestorStateOfType<DashboardScreenState>();
    state?.setTabIndex(2); // KI-Analyse is now index 2
  }
}
