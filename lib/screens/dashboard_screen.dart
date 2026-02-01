import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../providers/analysis_provider.dart';
import '../utils/constants.dart';
import '../widgets/stock_card.dart';
import 'stock_detail_screen.dart';
import 'portfolio_screen.dart';
import 'crypto_screen.dart';
import 'etf_screen.dart';
import 'news_hub_screen.dart';
import 'analysis_screen.dart';
import 'search_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  void setTabIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StockProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: const [
              _HomeTab(),
              CryptoScreen(),
              ETFScreen(),
              AnalysisScreen(),
              NewsHubScreen(),
              PortfolioScreen(),
            ],
          ),
          // Disclaimer Sticker
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _DisclaimerBanner(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.2),
        selectedIndex: _currentIndex,
        height: 70,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: 'Stocks',
          ),
          NavigationDestination(
            icon: Icon(Icons.currency_bitcoin_outlined),
            selectedIcon: Icon(Icons.currency_bitcoin),
            label: 'Crypto',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'ETFs',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology),
            label: 'KI-Analyse',
          ),
          NavigationDestination(
            icon: Icon(Icons.newspaper_outlined),
            selectedIcon: Icon(Icons.newspaper),
            label: 'News',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Portfolio',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

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
                  Icon(Icons.trending_up, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Stock Trader Pro',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search, color: AppColors.textPrimary),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SearchScreen()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
                  onPressed: () => context.read<StockProvider>().refreshAll(),
                ),
              ],
            ),
            // Quick Actions
            SliverToBoxAdapter(
              child: _buildQuickActions(context),
            ),
            const SliverToBoxAdapter(
              child: _IndicesSection(),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Watchlist',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Consumer<StockProvider>(
                      builder: (context, provider, _) {
                        return Text(
                          '${provider.watchlistStocks.length} Stocks',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 8),
            ),
            const _WatchlistSection(),
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _QuickActionCard(
            icon: Icons.psychology,
            label: 'KI-Analyse',
            color: Colors.deepPurple,
            onTap: () => _navigateToTab(context, 3),
          ),
          const SizedBox(width: 12),
          _QuickActionCard(
            icon: Icons.currency_bitcoin,
            label: 'Crypto',
            color: Colors.orange,
            onTap: () => _navigateToTab(context, 1),
          ),
          const SizedBox(width: 12),
          _QuickActionCard(
            icon: Icons.pie_chart,
            label: 'ETFs',
            color: Colors.blue,
            onTap: () => _navigateToTab(context, 2),
          ),
          const SizedBox(width: 12),
          _QuickActionCard(
            icon: Icons.newspaper,
            label: 'News',
            color: Colors.teal,
            onTap: () => _navigateToTab(context, 4),
          ),
        ],
      ),
    );
  }

  void _navigateToTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<DashboardScreenState>();
    state?.setTabIndex(index);
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IndicesSection extends StatelessWidget {
  const _IndicesSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<StockProvider>(
      builder: (context, provider, _) {
        if (provider.indexStocks.isEmpty) {
          return const SizedBox(
            height: 100,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                'Market Indices',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: provider.indexStocks.length,
                itemBuilder: (context, index) {
                  final stock = provider.indexStocks[index];
                  return SizedBox(
                    width: 140,
                    child: IndexCard(
                      index: stock,
                      onTap: () => _navigateToDetail(context, stock.symbol),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
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
}

class _WatchlistSection extends StatelessWidget {
  const _WatchlistSection();

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
                  const Icon(
                    Icons.playlist_add,
                    size: 64,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your watchlist is empty',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Stocks werden automatisch geladen',
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
                      content: Text('${stock.symbol} removed from watchlist'),
                      action: SnackBarAction(
                        label: 'Undo',
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
      MaterialPageRoute(
        builder: (_) => StockDetailScreen(symbol: symbol),
      ),
    );
  }

  void _navigateToAnalysis(BuildContext context, String symbol, String assetType) {
    // Symbol im Provider setzen
    context.read<AnalysisProvider>().setSymbolForAnalysis(symbol, assetType);
    // Zum KI-Analyse Tab navigieren (Index 3)
    final state = context.findAncestorStateOfType<DashboardScreenState>();
    state?.setTabIndex(3);
  }
}

class _DisclaimerBanner extends StatelessWidget {
  const _DisclaimerBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade800.withValues(alpha: 0.9),
            Colors.orange.shade700.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, color: Colors.white, size: 14),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Keine Finanzberatung - Nur zu Informationszwecken',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
