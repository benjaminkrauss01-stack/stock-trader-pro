import 'dart:async';
import 'package:flutter/widgets.dart';
import '../models/stock.dart';
import '../services/stock_api_service.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';

class StockProvider with ChangeNotifier, WidgetsBindingObserver {
  final StockApiService _apiService = StockApiService();
  final SupabaseService _supabaseService = SupabaseService();

  List<Stock> _watchlistStocks = [];
  List<Stock> _indexStocks = [];
  Stock? _selectedStock;
  List<StockCandle> _chartData = [];
  List<PortfolioPosition> _portfolio = [];
  List<Map<String, dynamic>> _searchResults = [];

  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;
  String _selectedRange = '1M';
  Timer? _refreshTimer;

  List<Stock> get watchlistStocks => _watchlistStocks;
  List<Stock> get indexStocks => _indexStocks;
  Stock? get selectedStock => _selectedStock;
  List<StockCandle> get chartData => _chartData;
  List<PortfolioPosition> get portfolio => _portfolio;
  List<Map<String, dynamic>> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  String get selectedRange => _selectedRange;

  double get portfolioTotalValue =>
      _portfolio.fold(0, (sum, pos) => sum + pos.totalValue);
  double get portfolioTotalCost =>
      _portfolio.fold(0, (sum, pos) => sum + pos.totalCost);
  double get portfolioTotalProfit => portfolioTotalValue - portfolioTotalCost;
  double get portfolioProfitPercent => portfolioTotalCost > 0
      ? (portfolioTotalProfit / portfolioTotalCost) * 100
      : 0;

  List<String> _watchlistSymbols = List.from(DefaultStocks.watchlist);
  List<String> get watchlistSymbols => _watchlistSymbols;

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load data from Supabase first
      await syncFromSupabase();

      await Future.wait([
        loadWatchlist(),
        loadIndices(),
      ]);
    } catch (e) {
      _error = 'Failed to initialize data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
      startAutoRefresh();
    }
  }

  /// Synchronisiert Watchlist und Portfolio von Supabase
  Future<void> syncFromSupabase() async {
    _isSyncing = true;
    notifyListeners();

    try {
      // Load watchlist from Supabase
      final cloudWatchlist = await _supabaseService.getWatchlist();
      if (cloudWatchlist.isNotEmpty) {
        _watchlistSymbols = cloudWatchlist;
      }

      // Load portfolio from Supabase
      final cloudPortfolio = await _supabaseService.getPortfolio();
      if (cloudPortfolio.isNotEmpty) {
        _portfolio = cloudPortfolio;
        await updatePortfolioPrices();
      }
    } catch (e) {
      debugPrint('Error syncing from Supabase: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void startAutoRefresh() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      refreshAll();
    });
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _refreshTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      refreshAll();
      startAutoRefresh();
    }
  }

  Future<void> loadWatchlist({bool notify = true}) async {
    try {
      _watchlistStocks = await _apiService.getMultipleQuotes(_watchlistSymbols);
      if (notify) notifyListeners();
    } catch (e) {
      _error = 'Failed to load watchlist: $e';
      rethrow;
    }
  }

  Future<void> loadIndices({bool notify = true}) async {
    try {
      _indexStocks = await _apiService.getMultipleQuotes(DefaultStocks.indices);
      if (notify) notifyListeners();
    } catch (e) {
      _error = 'Failed to load indices: $e';
      rethrow;
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([
      loadWatchlist(notify: false),
      loadIndices(notify: false),
      if (_selectedStock != null) refreshSelectedStock(),
    ]);
    notifyListeners();
  }

  Future<void> selectStock(String symbol) async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedStock = await _apiService.getQuote(symbol);
      await loadChartData(symbol);
    } catch (e) {
      _error = 'Failed to load stock: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshSelectedStock() async {
    if (_selectedStock == null) return;
    try {
      _selectedStock = await _apiService.getQuote(_selectedStock!.symbol);
      notifyListeners();
    } catch (e) {
      // print('Error refreshing selected stock: $e');
    }
  }

  Future<void> loadChartData(String symbol) async {
    try {
      final range = ChartRanges.ranges[_selectedRange] ?? '1mo';
      final interval = ChartRanges.intervals[range] ?? '1d';
      _chartData = await _apiService.getHistoricalData(
        symbol,
        range: range,
        interval: interval,
      );
      notifyListeners();
    } catch (e) {
      // print('Error loading chart data: $e');
    }
  }

  void setChartRange(String range) {
    _selectedRange = range;
    if (_selectedStock != null) {
      loadChartData(_selectedStock!.symbol);
    }
    notifyListeners();
  }

  Future<void> searchStocks(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    try {
      _searchResults = await _apiService.searchStocks(query);
    } catch (e) {
      _searchResults = [];
    }
    notifyListeners();
  }

  Future<void> addToWatchlist(String symbol, {String assetType = 'Stock'}) async {
    if (!_watchlistSymbols.contains(symbol)) {
      _watchlistSymbols.add(symbol);
      loadWatchlist();

      // Sync to Supabase
      try {
        await _supabaseService.addToWatchlist(symbol, assetType: assetType);
      } catch (e) {
        debugPrint('Error adding to cloud watchlist: $e');
      }
    }
  }

  Future<void> removeFromWatchlist(String symbol) async {
    _watchlistSymbols.remove(symbol);
    _watchlistStocks.removeWhere((s) => s.symbol == symbol);
    notifyListeners();

    // Sync to Supabase
    try {
      await _supabaseService.removeFromWatchlist(symbol);
    } catch (e) {
      debugPrint('Error removing from cloud watchlist: $e');
    }
  }

  bool isInWatchlist(String symbol) {
    return _watchlistSymbols.contains(symbol);
  }

  Future<void> addToPortfolio(PortfolioPosition position) async {
    _portfolio.add(position);
    notifyListeners();

    // Sync to Supabase
    try {
      await _supabaseService.addPortfolioPosition(position);
    } catch (e) {
      debugPrint('Error adding to cloud portfolio: $e');
    }
  }

  Future<void> removeFromPortfolio(String symbol) async {
    _portfolio.removeWhere((p) => p.symbol == symbol);
    notifyListeners();

    // Sync to Supabase
    try {
      await _supabaseService.removePortfolioPosition(symbol);
    } catch (e) {
      debugPrint('Error removing from cloud portfolio: $e');
    }
  }

  Future<void> updatePortfolioPrices() async {
    if (_portfolio.isEmpty) return;

    final symbols = _portfolio.map((p) => p.symbol).toList();
    final quotes = await _apiService.getMultipleQuotes(symbols);

    for (int i = 0; i < _portfolio.length; i++) {
      final quote = quotes.firstWhere(
        (q) => q.symbol == _portfolio[i].symbol,
        orElse: () => quotes.first,
      );
      _portfolio[i] = PortfolioPosition(
        symbol: _portfolio[i].symbol,
        name: _portfolio[i].name,
        shares: _portfolio[i].shares,
        avgPrice: _portfolio[i].avgPrice,
        currentPrice: quote.price,
        purchaseDate: _portfolio[i].purchaseDate,
      );
    }
    notifyListeners();
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
