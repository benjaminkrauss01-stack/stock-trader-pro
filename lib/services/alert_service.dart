import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/analysis.dart';

class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  static const String _analysisKey = 'saved_analyses';
  static const String _alertsKey = 'active_alerts';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ==================== ANALYSIS STORAGE ====================

  Future<void> saveAnalysis(MarketAnalysis analysis) async {
    final analyses = await getSavedAnalyses();

    // Check for duplicate (same symbol AND same timestamp within 1 minute)
    final isDuplicate = analyses.any((a) =>
        a.symbol == analysis.symbol &&
        a.analyzedAt.difference(analysis.analyzedAt).inMinutes.abs() < 1);

    if (!isDuplicate) {
      // Add new analysis (keep all historical analyses)
      analyses.add(analysis);
    }

    // Keep only last 20 analyses per symbol
    final groupedBySymbol = <String, List<MarketAnalysis>>{};
    for (final a in analyses) {
      groupedBySymbol.putIfAbsent(a.symbol, () => []).add(a);
    }

    final prunedAnalyses = <MarketAnalysis>[];
    for (final symbol in groupedBySymbol.keys) {
      final symbolAnalyses = groupedBySymbol[symbol]!;
      // Sort by date (newest first) and keep max 20 per symbol
      symbolAnalyses.sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
      prunedAnalyses.addAll(symbolAnalyses.take(20));
    }

    // Also limit total to 200 analyses
    prunedAnalyses.sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
    final finalAnalyses = prunedAnalyses.take(200).toList();

    await _prefs?.setString(
      _analysisKey,
      jsonEncode(finalAnalyses.map((a) => a.toJson()).toList()),
    );
  }

  Future<List<MarketAnalysis>> getSavedAnalyses() async {
    final json = _prefs?.getString(_analysisKey);
    if (json == null) return [];

    try {
      final list = jsonDecode(json) as List;
      return list.map((item) => MarketAnalysis.fromJson(item)).toList();
    } catch (e) {
      // print('Error loading analyses: $e');
      return [];
    }
  }

  Future<MarketAnalysis?> getAnalysisForSymbol(String symbol) async {
    final analyses = await getSavedAnalyses();
    try {
      return analyses.firstWhere((a) => a.symbol == symbol);
    } catch (e) {
      return null;
    }
  }

  /// Löscht ALLE Analysen für ein Symbol
  Future<void> deleteAnalysis(String symbol) async {
    final analyses = await getSavedAnalyses();
    analyses.removeWhere((a) => a.symbol == symbol);
    await _prefs?.setString(
      _analysisKey,
      jsonEncode(analyses.map((a) => a.toJson()).toList()),
    );
  }

  /// Löscht eine spezifische Analyse anhand von Symbol und Zeitstempel
  Future<void> deleteAnalysisById(String symbol, DateTime analyzedAt) async {
    final analyses = await getSavedAnalyses();
    analyses.removeWhere((a) =>
        a.symbol == symbol &&
        a.analyzedAt.difference(analyzedAt).inSeconds.abs() < 60);
    await _prefs?.setString(
      _analysisKey,
      jsonEncode(analyses.map((a) => a.toJson()).toList()),
    );
  }

  /// Holt die neueste Analyse für ein Symbol
  Future<MarketAnalysis?> getLatestAnalysisForSymbol(String symbol) async {
    final analyses = await getSavedAnalyses();
    final symbolAnalyses = analyses
        .where((a) => a.symbol.toUpperCase() == symbol.toUpperCase())
        .toList();
    if (symbolAnalyses.isEmpty) return null;
    symbolAnalyses.sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
    return symbolAnalyses.first;
  }

  // ==================== ALERT MANAGEMENT ====================

  Future<void> createAlert(MarketAnalysis analysis) async {
    final alerts = await getActiveAlerts();

    final alert = TriggerAlert(
      id: '${analysis.symbol}_${DateTime.now().millisecondsSinceEpoch}',
      symbol: analysis.symbol,
      assetType: analysis.assetType,
      triggers: analysis.keyTriggers,
      expectedDirection: analysis.direction,
      expectedMovePercent: analysis.expectedMovePercent,
      createdAt: DateTime.now(),
    );

    // Remove existing alert for same symbol
    alerts.removeWhere((a) => a.symbol == analysis.symbol);
    alerts.add(alert);

    await _saveAlerts(alerts);

    // Update analysis with alert enabled
    final updatedAnalysis = analysis.copyWith(alertEnabled: true);
    await saveAnalysis(updatedAnalysis);
  }

  Future<void> disableAlert(String symbol) async {
    final alerts = await getActiveAlerts();
    alerts.removeWhere((a) => a.symbol == symbol);
    await _saveAlerts(alerts);

    // Update analysis
    final analysis = await getAnalysisForSymbol(symbol);
    if (analysis != null) {
      final updatedAnalysis = analysis.copyWith(alertEnabled: false);
      await saveAnalysis(updatedAnalysis);
    }
  }

  Future<List<TriggerAlert>> getActiveAlerts() async {
    final json = _prefs?.getString(_alertsKey);
    if (json == null) return [];

    try {
      final list = jsonDecode(json) as List;
      return list
          .map((item) => TriggerAlert.fromJson(item))
          .where((a) => a.isActive)
          .toList();
    } catch (e) {
      // print('Error loading alerts: $e');
      return [];
    }
  }

  Future<void> _saveAlerts(List<TriggerAlert> alerts) async {
    await _prefs?.setString(
      _alertsKey,
      jsonEncode(alerts.map((a) => a.toJson()).toList()),
    );
  }

  Future<void> markAlertTriggered(String alertId, String message) async {
    final json = _prefs?.getString(_alertsKey);
    if (json == null) return;

    try {
      final list = jsonDecode(json) as List;
      final alerts = list.map((item) => TriggerAlert.fromJson(item)).toList();

      final index = alerts.indexWhere((a) => a.id == alertId);
      if (index != -1) {
        final alert = alerts[index];
        alerts[index] = TriggerAlert(
          id: alert.id,
          symbol: alert.symbol,
          assetType: alert.assetType,
          triggers: alert.triggers,
          expectedDirection: alert.expectedDirection,
          expectedMovePercent: alert.expectedMovePercent,
          createdAt: alert.createdAt,
          triggeredAt: DateTime.now(),
          isActive: false,
          notificationMessage: message,
        );
        await _saveAlerts(alerts);
      }
    } catch (e) {
      // print('Error marking alert triggered: $e');
    }
  }

  // ==================== ALERT CHECKING ====================

  Future<List<TriggerAlert>> checkAlerts(
    List<NewsEvent> recentNews,
    Map<String, List<PricePoint>> recentPrices,
  ) async {
    final alerts = await getActiveAlerts();
    final triggeredAlerts = <TriggerAlert>[];

    for (final alert in alerts) {
      final prices = recentPrices[alert.symbol];
      if (prices == null || prices.isEmpty) continue;

      // Check if any trigger conditions are met
      final triggerMatched = _checkTriggerMatch(alert, recentNews, prices);

      if (triggerMatched) {
        triggeredAlerts.add(alert);

        final direction = alert.expectedDirection == AnalysisDirection.bullish
            ? 'STEIGEN'
            : alert.expectedDirection == AnalysisDirection.bearish
                ? 'FALLEN'
                : 'BEWEGEN';

        final message = '''
ALERT: ${alert.symbol}
Trigger-Bedingungen erfüllt!
Erwartete Bewegung: $direction um ${alert.expectedMovePercent.toStringAsFixed(1)}%
Erkannte Trigger: ${alert.triggers.take(3).join(', ')}
''';

        await markAlertTriggered(alert.id, message);
      }
    }

    return triggeredAlerts;
  }

  bool _checkTriggerMatch(
    TriggerAlert alert,
    List<NewsEvent> recentNews,
    List<PricePoint> prices,
  ) {
    int matchedTriggers = 0;

    for (final trigger in alert.triggers) {
      final triggerLower = trigger.toLowerCase();

      // Check news headlines
      for (final news in recentNews) {
        final headlineLower = news.headline.toLowerCase();
        if (headlineLower.contains(triggerLower)) {
          matchedTriggers++;
          break;
        }

        // Check for related keywords
        final keywords = _extractKeywords(triggerLower);
        for (final keyword in keywords) {
          if (headlineLower.contains(keyword)) {
            matchedTriggers++;
            break;
          }
        }
      }

      // Check price patterns
      if (prices.length >= 5) {
        final recentChange = ((prices.last.close - prices.first.close) / prices.first.close) * 100;

        if (triggerLower.contains('steig') && recentChange > 2) matchedTriggers++;
        if (triggerLower.contains('fall') && recentChange < -2) matchedTriggers++;
        if (triggerLower.contains('volatil') && recentChange.abs() > 3) matchedTriggers++;
      }
    }

    // Trigger if at least 30% of conditions match
    return matchedTriggers >= (alert.triggers.length * 0.3).ceil();
  }

  List<String> _extractKeywords(String text) {
    // Extract meaningful keywords from trigger text
    final stopWords = ['und', 'oder', 'der', 'die', 'das', 'ein', 'eine', 'ist', 'sind', 'wird', 'werden'];
    return text
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3 && !stopWords.contains(w))
        .toList();
  }

  // ==================== STATISTICS ====================

  Future<Map<String, dynamic>> getStatistics() async {
    final analyses = await getSavedAnalyses();
    final alerts = await getActiveAlerts();

    int bullish = 0, bearish = 0, neutral = 0;
    double avgConfidence = 0;

    for (final a in analyses) {
      switch (a.direction) {
        case AnalysisDirection.bullish:
          bullish++;
          break;
        case AnalysisDirection.bearish:
          bearish++;
          break;
        case AnalysisDirection.neutral:
          neutral++;
          break;
      }
      avgConfidence += a.confidence;
    }

    if (analyses.isNotEmpty) {
      avgConfidence /= analyses.length;
    }

    return {
      'totalAnalyses': analyses.length,
      'activeAlerts': alerts.length,
      'bullishCount': bullish,
      'bearishCount': bearish,
      'neutralCount': neutral,
      'avgConfidence': avgConfidence,
    };
  }
}
