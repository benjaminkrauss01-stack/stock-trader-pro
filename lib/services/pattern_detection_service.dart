import '../models/analysis.dart';
import '../models/stock.dart';

class PatternDetectionService {
  static final PatternDetectionService _instance = PatternDetectionService._internal();
  factory PatternDetectionService() => _instance;
  PatternDetectionService._internal();

  static const double significantMoveThreshold = 5.0;

  List<SignificantMove> detectSignificantMoves(List<StockCandle> candles) {
    final moves = <SignificantMove>[];

    for (int i = 1; i < candles.length; i++) {
      final prevClose = candles[i - 1].close;
      final currClose = candles[i].close;
      final changePercent = ((currClose - prevClose) / prevClose) * 100;

      if (changePercent.abs() >= significantMoveThreshold) {
        moves.add(SignificantMove(
          date: candles[i].date,
          priceFrom: prevClose,
          priceTo: currClose,
          changePercent: changePercent,
        ));
      }
    }

    return moves;
  }

  List<SignificantMove> detectMultiDayMoves(List<StockCandle> candles, {int days = 3}) {
    final moves = <SignificantMove>[];

    for (int i = days; i < candles.length; i++) {
      final startClose = candles[i - days].close;
      final endClose = candles[i].close;
      final changePercent = ((endClose - startClose) / startClose) * 100;

      if (changePercent.abs() >= significantMoveThreshold) {
        moves.add(SignificantMove(
          date: candles[i].date,
          priceFrom: startClose,
          priceTo: endClose,
          changePercent: changePercent,
        ));
      }
    }

    return moves;
  }

  List<PricePoint> convertToPricePoints(List<StockCandle> candles) {
    final points = <PricePoint>[];

    for (int i = 0; i < candles.length; i++) {
      double changePercent = 0;
      if (i > 0) {
        changePercent = ((candles[i].close - candles[i - 1].close) / candles[i - 1].close) * 100;
      }

      points.add(PricePoint(
        date: candles[i].date,
        open: candles[i].open,
        high: candles[i].high,
        low: candles[i].low,
        close: candles[i].close,
        changePercent: changePercent,
        volume: candles[i].volume,
      ));
    }

    return points;
  }

  Map<String, dynamic> analyzeVolatility(List<StockCandle> candles) {
    if (candles.isEmpty) return {'volatility': 0, 'trend': 'neutral'};

    final returns = <double>[];
    for (int i = 1; i < candles.length; i++) {
      returns.add((candles[i].close - candles[i - 1].close) / candles[i - 1].close);
    }

    final mean = returns.reduce((a, b) => a + b) / returns.length;
    final variance = returns.map((r) => (r - mean) * (r - mean)).reduce((a, b) => a + b) / returns.length;
    final volatility = variance * 100;

    String trend = 'neutral';
    final recentReturns = returns.skip(returns.length - 5).toList();
    if (recentReturns.isNotEmpty) {
      final recentMean = recentReturns.reduce((a, b) => a + b) / recentReturns.length;
      if (recentMean > 0.005) trend = 'bullish';
      if (recentMean < -0.005) trend = 'bearish';
    }

    return {
      'volatility': volatility,
      'trend': trend,
      'avgReturn': mean * 100,
    };
  }

  List<String> detectTechnicalPatterns(List<StockCandle> candles) {
    final patterns = <String>[];

    if (candles.length < 20) return patterns;

    // Simple Moving Average Crossover
    final sma10 = _calculateSMA(candles, 10);
    final sma20 = _calculateSMA(candles, 20);

    if (sma10.length >= 2 && sma20.length >= 2) {
      final prevSma10 = sma10[sma10.length - 2];
      final currSma10 = sma10.last;
      final prevSma20 = sma20[sma20.length - 2];
      final currSma20 = sma20.last;

      if (prevSma10 < prevSma20 && currSma10 > currSma20) {
        patterns.add('Golden Cross (SMA10 crossed above SMA20) - Bullish Signal');
      }
      if (prevSma10 > prevSma20 && currSma10 < currSma20) {
        patterns.add('Death Cross (SMA10 crossed below SMA20) - Bearish Signal');
      }
    }

    // RSI
    final rsi = _calculateRSI(candles, 14);
    if (rsi != null) {
      if (rsi < 30) patterns.add('RSI Oversold ($rsi) - Potential Reversal Up');
      if (rsi > 70) patterns.add('RSI Overbought ($rsi) - Potential Reversal Down');
    }

    // Support/Resistance
    final recent = candles.skip(candles.length - 20).toList();
    final highs = recent.map((c) => c.high).toList()..sort();
    final lows = recent.map((c) => c.low).toList()..sort();
    final currentPrice = candles.last.close;

    final resistance = highs.last;
    final support = lows.first;

    if ((currentPrice - support) / support < 0.02) {
      patterns.add('Near Support Level (\$${support.toStringAsFixed(2)})');
    }
    if ((resistance - currentPrice) / currentPrice < 0.02) {
      patterns.add('Near Resistance Level (\$${resistance.toStringAsFixed(2)})');
    }

    // Volume Spike
    if (candles.length >= 10) {
      final avgVolume = candles.skip(candles.length - 10).take(9).map((c) => c.volume).reduce((a, b) => a + b) / 9;
      final lastVolume = candles.last.volume;

      if (lastVolume > avgVolume * 2) {
        patterns.add('Volume Spike (${(lastVolume / avgVolume).toStringAsFixed(1)}x average)');
      }
    }

    return patterns;
  }

  List<double> _calculateSMA(List<StockCandle> candles, int period) {
    final sma = <double>[];
    for (int i = period - 1; i < candles.length; i++) {
      final sum = candles.skip(i - period + 1).take(period).map((c) => c.close).reduce((a, b) => a + b);
      sma.add(sum / period);
    }
    return sma;
  }

  double? _calculateRSI(List<StockCandle> candles, int period) {
    if (candles.length < period + 1) return null;

    var gains = 0.0;
    var losses = 0.0;

    for (int i = candles.length - period; i < candles.length; i++) {
      final change = candles[i].close - candles[i - 1].close;
      if (change > 0) {
        gains += change;
      } else {
        losses += change.abs();
      }
    }

    if (losses == 0) return 100;

    final rs = gains / losses;
    return 100 - (100 / (1 + rs));
  }

  bool checkTriggerConditions(List<String> triggers, List<NewsEvent> recentNews, List<StockCandle> recentCandles) {
    int matchedTriggers = 0;

    for (final trigger in triggers) {
      final triggerLower = trigger.toLowerCase();

      // Check news for trigger keywords
      for (final news in recentNews) {
        if (news.headline.toLowerCase().contains(triggerLower) ||
            news.sentiment.toLowerCase().contains(triggerLower)) {
          matchedTriggers++;
          break;
        }
      }

      // Check technical patterns
      final patterns = detectTechnicalPatterns(recentCandles);
      for (final pattern in patterns) {
        if (pattern.toLowerCase().contains(triggerLower)) {
          matchedTriggers++;
          break;
        }
      }
    }

    // Trigger if at least 50% of conditions match
    return matchedTriggers >= (triggers.length / 2);
  }
}
