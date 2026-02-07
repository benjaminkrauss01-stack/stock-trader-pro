import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../utils/constants.dart';
import 'watchlist_screen.dart';
import 'community_analyses_screen.dart';
import 'analysis_screen.dart';
import 'assets_screen.dart';
import 'news_hub_screen.dart';
import 'portfolio_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final Map<int, Widget> _cachedTabs = {};

  void setTabIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildBody() {
    _cachedTabs.putIfAbsent(_currentIndex, () {
      switch (_currentIndex) {
        case 0: return const WatchlistScreen();
        case 1: return const CommunityAnalysesScreen();
        case 2: return const AnalysisScreen();
        case 3: return const AssetsScreen();
        case 4: return const NewsHubScreen();
        case 5: return const PortfolioScreen();
        default: return const WatchlistScreen();
      }
    });

    final entries = _cachedTabs.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final activeIndex = entries.indexWhere((e) => e.key == _currentIndex);

    return IndexedStack(
      index: activeIndex,
      children: entries.map((e) => e.value).toList(),
    );
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
          _buildBody(),
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
            icon: Icon(Icons.star_border_outlined),
            selectedIcon: Icon(Icons.star),
            label: 'Watchlist',
          ),
          NavigationDestination(
            icon: Icon(Icons.public_outlined),
            selectedIcon: Icon(Icons.public),
            label: 'Analysen',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology),
            label: 'KI-Analyse',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance),
            label: 'Assets',
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
