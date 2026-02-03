import 'package:flutter/foundation.dart';
import '../models/analysis.dart';
import '../models/stock.dart';
import '../services/ai_analysis_service.dart';
import '../services/alert_service.dart';
import '../services/pattern_detection_service.dart';
import '../services/stock_api_service.dart';
import '../services/news_service_extended.dart';
import '../services/historical_news_service.dart';
import '../services/supabase_service.dart';

class AnalysisProvider extends ChangeNotifier {
  final AIAnalysisService _aiService = AIAnalysisService();
  final AlertService _alertService = AlertService();
  final PatternDetectionService _patternService = PatternDetectionService();
  final StockApiService _stockService = StockApiService();
  final ExtendedNewsService _newsService = ExtendedNewsService();
  final HistoricalNewsService _historicalNewsService = HistoricalNewsService();
  final SupabaseService _supabaseService = SupabaseService();

  List<MarketAnalysis> _savedAnalyses = [];
  List<TriggerAlert> _activeAlerts = [];
  MarketAnalysis? _currentAnalysis;
  List<StockCandle> _currentChartData = [];
  String _currentChartRange = '3M';
  bool _isAnalyzing = false;
  String? _error;
  Map<String, dynamic> _statistics = {};

  // Analysis limit tracking
  int _remainingAnalyses = 5;
  String _subscriptionTier = 'free';
  bool _limitReached = false;

  // Symbol und Asset-Type für Quick-Analyse von anderen Screens
  String? _pendingSymbol;
  String? _pendingAssetType;

  List<MarketAnalysis> get savedAnalyses => _savedAnalyses;
  List<TriggerAlert> get activeAlerts => _activeAlerts;
  MarketAnalysis? get currentAnalysis => _currentAnalysis;
  List<StockCandle> get currentChartData => _currentChartData;
  String get currentChartRange => _currentChartRange;
  bool get isAnalyzing => _isAnalyzing;
  String? get error => _error;
  Map<String, dynamic> get statistics => _statistics;
  String? get pendingSymbol => _pendingSymbol;
  String? get pendingAssetType => _pendingAssetType;
  int get remainingAnalyses => _remainingAnalyses;
  String get subscriptionTier => _subscriptionTier;
  bool get limitReached => _limitReached;

  /// Setzt ein Symbol für die Analyse (wird von anderen Screens aufgerufen)
  void setSymbolForAnalysis(String symbol, String assetType) {
    _pendingSymbol = symbol;
    _pendingAssetType = assetType;
    notifyListeners();
  }

  /// Löscht das pending Symbol nach Verwendung
  void clearPendingSymbol() {
    _pendingSymbol = null;
    _pendingAssetType = null;
  }

  /// Holt alle historischen Analysen für ein Symbol (sortiert nach Datum)
  List<MarketAnalysis> getHistoricalAnalysesForSymbol(String symbol) {
    return _savedAnalyses
        .where((a) => a.symbol.toUpperCase() == symbol.toUpperCase())
        .toList()
      ..sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
  }

  Future<void> initialize() async {
    await _alertService.init();
    await loadSavedData();
    await updateLimitsFromSupabase();
  }

  /// Lädt aktuelle Limits von Supabase
  Future<void> updateLimitsFromSupabase() async {
    try {
      final profile = await _supabaseService.getProfile();
      if (profile != null) {
        _remainingAnalyses = profile.remainingAnalyses;
        _subscriptionTier = profile.subscriptionTier;
        _limitReached = !profile.canPerformAnalysis;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading limits from Supabase: $e');
    }
  }

  Future<void> loadSavedData() async {
    _savedAnalyses = await _alertService.getSavedAnalyses();
    _activeAlerts = await _alertService.getActiveAlerts();
    _statistics = await _alertService.getStatistics();
    notifyListeners();
  }

  /// Lädt Chart-Daten für ein Symbol mit neuem Zeitraum
  Future<void> loadChartData(String symbol, String range) async {
    try {
      final rangeMap = {
        '1D': '1d',
        '5D': '5d',
        '1M': '1mo',
        '3M': '3mo',
        '6M': '6mo',
        '1Y': '1y',
        '5Y': '5y',
      };
      final interval = range == '1D' ? '5m' : (range == '5D' ? '15m' : '1d');
      final candles = await _stockService.getChartData(
        symbol,
        rangeMap[range] ?? '3mo',
        interval,
      );
      _currentChartData = candles;
      _currentChartRange = range;
      notifyListeners();
    } catch (e) {
      // Keep existing data on error
    }
  }

  Future<MarketAnalysis?> analyzeAsset({
    required String symbol,
    required String assetType,
  }) async {
    _isAnalyzing = true;
    _error = null;
    _currentAnalysis = null;
    _currentChartData = [];
    notifyListeners();

    try {
      // Check analysis limit before proceeding
      final limitCheck = await _supabaseService.checkAnalysisLimit();
      final allowed = limitCheck['allowed'] as bool? ?? false;
      if (!allowed) {
        _error = 'Analysenlimit für diesen Monat erreicht. Upgrade auf Pro oder Ultimate Plan.';
        _isAnalyzing = false;
        notifyListeners();
        return null;
      }

      // 1. Fetch historical price data (90 days)
      final candles = await _stockService.getChartData(symbol, '3mo', '1d');

      if (candles.isEmpty) {
        throw Exception('Keine Preisdaten verfügbar für $symbol');
      }

      // Store chart data for display
      _currentChartData = candles;
      _currentChartRange = '3M';

      // 2. Convert to PricePoints
      final priceHistory = _patternService.convertToPricePoints(candles);

      // 3. Fetch news - historische News (2 Jahre) + aktuelle News
      List<NewsEvent> allNewsEvents = [];

      // 3a. Versuche historische News zu laden (falls API Key vorhanden)
      if (_historicalNewsService.hasApiKey) {
        final historicalNews = await _historicalNewsService.getHistoricalNews(symbol);
        allNewsEvents.addAll(historicalNews);
      }

      // 3b. Aktuelle News von Yahoo als Fallback/Ergänzung
      final recentArticles = await _newsService.getNewsForSymbol(symbol);
      final recentNewsEvents = recentArticles
          .map(
            (article) => NewsEvent(
              date: article.publishedAt ?? DateTime.now(),
              headline: article.title,
              source: article.source ?? 'Unknown',
              sentiment: _analyzeSentiment(article.title),
              url: article.link,
            ),
          )
          .toList();

      // Merge und Duplikate entfernen
      for (final news in recentNewsEvents) {
        final isDuplicate = allNewsEvents.any((n) =>
            n.headline == news.headline ||
            (n.date.difference(news.date).inHours.abs() < 24 &&
             n.headline.toLowerCase().contains(news.headline.toLowerCase().substring(0, 20))));
        if (!isDuplicate) {
          allNewsEvents.add(news);
        }
      }

      // Nach Datum sortieren (neueste zuerst)
      allNewsEvents.sort((a, b) => b.date.compareTo(a.date));

      // 4. Detect significant moves (>5%) and enrich with preceding news (7 days before each move)
      final rawSignificantMoves = _patternService.detectSignificantMoves(candles);
      final significantMoves = _enrichMovesWithPrecedingNews(rawSignificantMoves, allNewsEvents);

      // 5. Detect technical patterns
      _patternService.detectTechnicalPatterns(
        candles,
      );

      // Aktuelle News der letzten 7 Tage für den Prompt
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentNews = allNewsEvents.where((n) => n.date.isAfter(sevenDaysAgo)).toList();

      // 6. Fetch custom prompt from database (if available)
      final customPrompt = await _supabaseService.getAiPrompt();

      // 7. Call AI for deep analysis
      final analysis = await _aiService.analyzeAsset(
        symbol: symbol,
        assetType: assetType,
        priceHistory: priceHistory,
        recentNews: recentNews,
        significantMoves: significantMoves,
        customPromptTemplate: customPrompt,
      );

      // 8. Save analysis
      await _alertService.saveAnalysis(analysis);

      // Increment analysis count in Supabase and refresh local state
      await _supabaseService.incrementAnalysisCount();
      await updateLimitsFromSupabase();

      _currentAnalysis = analysis;
      _savedAnalyses = await _alertService.getSavedAnalyses();
      _statistics = await _alertService.getStatistics();

      _isAnalyzing = false;
      notifyListeners();

      return analysis;
    } catch (e) {
      _error = e.toString();
      _isAnalyzing = false;
      notifyListeners();
      return null;
    }
  }

  /// Ordnet jedem SignificantMove die News der 7 Tage davor zu
  List<SignificantMove> _enrichMovesWithPrecedingNews(
    List<SignificantMove> moves,
    List<NewsEvent> allNews,
  ) {
    const precedingDays = 7;

    return moves.map((move) {
      final moveDate = move.date;
      final startDate = moveDate.subtract(const Duration(days: precedingDays));

      // Finde alle News zwischen startDate und moveDate (exklusive moveDate)
      final precedingNews = allNews.where((news) {
        return news.date.isAfter(startDate) &&
            news.date.isBefore(moveDate);
      }).toList();

      // Sortiere nach Datum (älteste zuerst)
      precedingNews.sort((a, b) => a.date.compareTo(b.date));

      return SignificantMove(
        date: move.date,
        priceFrom: move.priceFrom,
        priceTo: move.priceTo,
        changePercent: move.changePercent,
        triggerEvent: move.triggerEvent,
        precedingNews: precedingNews,
      );
    }).toList();
  }

  String _analyzeSentiment(String text) {
    final textLower = text.toLowerCase();

    final positiveWords = [
      'surge',
      'jump',
      'gain',
      'rise',
      'high',
      'record',
      'beat',
      'exceed',
      'growth',
      'profit',
      'success',
      'bullish',
      'rally',
      'boom',
      'steigt',
      'gewinn',
      'erfolg',
      'rekord',
      'wachstum',
      'positiv',
    ];

    final negativeWords = [
      'fall',
      'drop',
      'crash',
      'loss',
      'decline',
      'low',
      'miss',
      'fail',
      'concern',
      'risk',
      'bearish',
      'selloff',
      'plunge',
      'fällt',
      'verlust',
      'risiko',
      'absturz',
      'krise',
      'negativ',
      'warnung',
    ];

    int positiveCount = 0;
    int negativeCount = 0;

    for (final word in positiveWords) {
      if (textLower.contains(word)) positiveCount++;
    }

    for (final word in negativeWords) {
      if (textLower.contains(word)) negativeCount++;
    }

    if (positiveCount > negativeCount) return 'positive';
    if (negativeCount > positiveCount) return 'negative';
    return 'neutral';
  }

  Future<void> enableAlert(MarketAnalysis analysis) async {
    await _alertService.createAlert(analysis);
    _activeAlerts = await _alertService.getActiveAlerts();
    _savedAnalyses = await _alertService.getSavedAnalyses();
    notifyListeners();
  }

  Future<void> disableAlert(String symbol) async {
    await _alertService.disableAlert(symbol);
    _activeAlerts = await _alertService.getActiveAlerts();
    _savedAnalyses = await _alertService.getSavedAnalyses();
    notifyListeners();
  }

  /// Löscht ALLE Analysen für ein Symbol
  Future<void> deleteAnalysis(String symbol) async {
    await _alertService.deleteAnalysis(symbol);
    await _alertService.disableAlert(symbol);
    _savedAnalyses = await _alertService.getSavedAnalyses();
    _activeAlerts = await _alertService.getActiveAlerts();
    _statistics = await _alertService.getStatistics();
    notifyListeners();
  }

  /// Löscht eine spezifische Analyse anhand von Symbol und Zeitstempel
  Future<void> deleteAnalysisById(String symbol, DateTime analyzedAt) async {
    await _alertService.deleteAnalysisById(symbol, analyzedAt);
    _savedAnalyses = await _alertService.getSavedAnalyses();
    _statistics = await _alertService.getStatistics();
    notifyListeners();
  }

  Future<List<TriggerAlert>> checkAllAlerts() async {
    final triggeredAlerts = <TriggerAlert>[];

    for (final alert in _activeAlerts) {
      try {
        // Fetch recent data
        final candles = await _stockService.getChartData(
          alert.symbol,
          '5d',
          '1d',
        );
        final pricePoints = _patternService.convertToPricePoints(candles);

        final newsArticles = await _newsService.getNewsForSymbol(alert.symbol);
        final newsEvents = newsArticles
            .map(
              (article) => NewsEvent(
                date: article.publishedAt ?? DateTime.now(),
                headline: article.title,
                source: article.source ?? 'Unknown',
                sentiment: _analyzeSentiment(article.title),
              ),
            )
            .toList();

        final triggered = await _alertService.checkAlerts(newsEvents, {
          alert.symbol: pricePoints,
        });

        triggeredAlerts.addAll(triggered);
      } catch (e) {
        // Skip this alert if there's an error
        continue;
      }
    }

    if (triggeredAlerts.isNotEmpty) {
      _activeAlerts = await _alertService.getActiveAlerts();
      notifyListeners();
    }

    return triggeredAlerts;
  }

  MarketAnalysis? getAnalysisForSymbol(String symbol) {
    try {
      return _savedAnalyses.firstWhere((a) => a.symbol == symbol);
    } catch (e) {
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearCurrentAnalysis() {
    _currentAnalysis = null;
    _currentChartData = [];
    notifyListeners();
  }
}
