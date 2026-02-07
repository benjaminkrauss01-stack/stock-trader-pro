import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../utils/constants.dart';
import '../widgets/stock_card.dart';
import 'stock_detail_screen.dart';
import 'crypto_screen.dart';
import 'etf_screen.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TabBar at top
        SafeArea(
          bottom: false,
          child: Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.show_chart, size: 16),
                      SizedBox(width: 6),
                      Text('Aktien'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.currency_bitcoin, size: 16),
                      SizedBox(width: 6),
                      Text('Crypto'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pie_chart, size: 16),
                      SizedBox(width: 6),
                      Text('ETFs'),
                    ],
                  ),
                ),
              ],
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              dividerColor: AppColors.border,
            ),
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _StocksTab(),
              CryptoScreen(),
              ETFScreen(),
            ],
          ),
        ),
      ],
    );
  }
}

class _StocksTab extends StatelessWidget {
  const _StocksTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<StockProvider>(
      builder: (context, provider, _) {
        return RefreshIndicator(
          onRefresh: () => provider.refreshAll(),
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              // Market Indices
              _buildIndicesSection(context, provider),
              const SizedBox(height: 24),
              // Popular Stocks
              _buildPopularStocks(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIndicesSection(BuildContext context, StockProvider provider) {
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
          padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text(
            'Markt-Indizes',
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
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StockDetailScreen(symbol: stock.symbol),
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

  Widget _buildPopularStocks(BuildContext context) {
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
            'Beliebte Aktien',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...popularSymbols.map((stock) {
          final symbol = stock['symbol']!;
          final name = stock['name']!;
          return Card(
            color: AppColors.card,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            child: ListTile(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StockDetailScreen(symbol: symbol),
                ),
              ),
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
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textHint,
              ),
            ),
          );
        }),
      ],
    );
  }
}
