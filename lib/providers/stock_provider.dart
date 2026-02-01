import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/stock.dart';
import '../services/stock_api_service.dart';
import '../utils/constants.dart';

class StockProvider with ChangeNotifier {
  final StockApiService _apiService = StockApiService();

  List<Stock> _watchlistStocks = [];
  List<Stock> _indexStocks = [];
  Stock? _selectedStock;
  List<StockCandle> _chartData = [];
  final List<PortfolioPosition> _portfolio = [];
  List<Map<String, dynamic>> _searchResults = [];

  bool _isLoading = false;
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

  final List<String> _watchlistSymbols = List.from(DefaultStocks.watchlist);
  List<String> get watchlistSymbols => _watchlistSymbols;

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
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

  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      refreshAll();
    });
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
  }

  Future<void> loadWatchlist() async {
    try {
      _watchlistStocks = await _apiService.getMultipleQuotes(_watchlistSymbols);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load watchlist: $e';
      // Re-throw to be caught by the caller (initialize)
      rethrow;
    }
  }

  Future<void> loadIndices() async {
    try {
      _indexStocks = await _apiService.getMultipleQuotes(DefaultStocks.indices);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load indices: $e';
      // Re-throw to be caught by the caller (initialize)
      rethrow;
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([
      loadWatchlist(),
      loadIndices(),
      if (_selectedStock != null) refreshSelectedStock(),
    ]);
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

  void addToWatchlist(String symbol) {
    if (!_watchlistSymbols.contains(symbol)) {
      _watchlistSymbols.add(symbol);
      loadWatchlist();
    }
  }

  void removeFromWatchlist(String symbol) {
    _watchlistSymbols.remove(symbol);
    _watchlistStocks.removeWhere((s) => s.symbol == symbol);
    notifyListeners();
  }

  bool isInWatchlist(String symbol) {
    return _watchlistSymbols.contains(symbol);
  }

  void addToPortfolio(PortfolioPosition position) {
    _portfolio.add(position);
    notifyListeners();
  }

  void removeFromPortfolio(String symbol) {
    _portfolio.removeWhere((p) => p.symbol == symbol);
    notifyListeners();
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
