import 'dart:convert';

enum AnalysisDirection { bullish, bearish, neutral }

class PricePoint {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double changePercent;
  final int volume;

  PricePoint({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.changePercent,
    required this.volume,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'open': open,
    'high': high,
    'low': low,
    'close': close,
    'changePercent': changePercent,
    'volume': volume,
  };

  factory PricePoint.fromJson(Map<String, dynamic> json) => PricePoint(
    date: DateTime.parse(json['date']),
    open: (json['open'] ?? 0).toDouble(),
    high: (json['high'] ?? 0).toDouble(),
    low: (json['low'] ?? 0).toDouble(),
    close: (json['close'] ?? 0).toDouble(),
    changePercent: (json['changePercent'] ?? 0).toDouble(),
    volume: json['volume'] ?? 0,
  );
}

class NewsEvent {
  final DateTime date;
  final String headline;
  final String source;
  final String sentiment;
  final String? url;
  final List<String> relatedSymbols;

  NewsEvent({
    required this.date,
    required this.headline,
    required this.source,
    required this.sentiment,
    this.url,
    this.relatedSymbols = const [],
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'headline': headline,
    'source': source,
    'sentiment': sentiment,
    'url': url,
    'relatedSymbols': relatedSymbols,
  };

  factory NewsEvent.fromJson(Map<String, dynamic> json) => NewsEvent(
    date: DateTime.parse(json['date']),
    headline: json['headline'] ?? '',
    source: json['source'] ?? '',
    sentiment: json['sentiment'] ?? 'neutral',
    url: json['url'],
    relatedSymbols: List<String>.from(json['relatedSymbols'] ?? []),
  );
}

class SignificantMove {
  final DateTime date;
  final double priceFrom;
  final double priceTo;
  final double changePercent;
  final String? triggerEvent;
  final List<NewsEvent> precedingNews; // News der 7 Tage vor der Bewegung

  SignificantMove({
    required this.date,
    required this.priceFrom,
    required this.priceTo,
    required this.changePercent,
    this.triggerEvent,
    this.precedingNews = const [],
  });

  bool get isPositive => changePercent >= 0;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'priceFrom': priceFrom,
    'priceTo': priceTo,
    'changePercent': changePercent,
    'triggerEvent': triggerEvent,
    'precedingNews': precedingNews.map((n) => n.toJson()).toList(),
  };

  factory SignificantMove.fromJson(Map<String, dynamic> json) => SignificantMove(
    date: DateTime.parse(json['date']),
    priceFrom: (json['priceFrom'] ?? 0).toDouble(),
    priceTo: (json['priceTo'] ?? 0).toDouble(),
    changePercent: (json['changePercent'] ?? 0).toDouble(),
    triggerEvent: json['triggerEvent'],
    precedingNews: (json['precedingNews'] as List?)
        ?.map((n) => NewsEvent.fromJson(n))
        .toList() ?? [],
  );
}

class HistoricalPattern {
  final String pattern;
  final DateTime occurredBefore;
  final String resultedIn;
  final double relevanceScore;

  HistoricalPattern({
    required this.pattern,
    required this.occurredBefore,
    required this.resultedIn,
    required this.relevanceScore,
  });

  Map<String, dynamic> toJson() => {
    'pattern': pattern,
    'occurredBefore': occurredBefore.toIso8601String(),
    'resultedIn': resultedIn,
    'relevanceScore': relevanceScore,
  };

  factory HistoricalPattern.fromJson(Map<String, dynamic> json) => HistoricalPattern(
    pattern: json['pattern'] ?? '',
    occurredBefore: DateTime.tryParse(json['occurredBefore'] ?? '') ?? DateTime.now(),
    resultedIn: json['resultedIn'] ?? '',
    relevanceScore: (json['relevanceScore'] ?? 0).toDouble(),
  );
}

class NewsCorrelation {
  final String newsEvent;
  final String priceImpact;
  final int delayDays;

  NewsCorrelation({
    required this.newsEvent,
    required this.priceImpact,
    required this.delayDays,
  });

  Map<String, dynamic> toJson() => {
    'newsEvent': newsEvent,
    'priceImpact': priceImpact,
    'delayDays': delayDays,
  };

  factory NewsCorrelation.fromJson(Map<String, dynamic> json) => NewsCorrelation(
    newsEvent: json['newsEvent'] ?? '',
    priceImpact: json['priceImpact'] ?? '',
    delayDays: json['delayDays'] ?? 0,
  );
}

class NewsPattern {
  final String patternType; // z.B. "earnings_warning", "analyst_downgrade", "sector_news"
  final String description;
  final int historicalOccurrences; // Wie oft dieses Pattern vor Bewegungen auftrat
  final double avgSubsequentMove; // Durchschnittliche Bewegung nach diesem Pattern
  final List<String> matchedCurrentNews; // Aktuelle News die diesem Pattern entsprechen
  final double matchConfidence; // 0-100

  NewsPattern({
    required this.patternType,
    required this.description,
    required this.historicalOccurrences,
    required this.avgSubsequentMove,
    required this.matchedCurrentNews,
    required this.matchConfidence,
  });

  Map<String, dynamic> toJson() => {
    'patternType': patternType,
    'description': description,
    'historicalOccurrences': historicalOccurrences,
    'avgSubsequentMove': avgSubsequentMove,
    'matchedCurrentNews': matchedCurrentNews,
    'matchConfidence': matchConfidence,
  };

  factory NewsPattern.fromJson(Map<String, dynamic> json) => NewsPattern(
    patternType: json['pattern_type'] ?? json['patternType'] ?? '',
    description: json['description'] ?? '',
    historicalOccurrences: json['historical_occurrences'] ?? json['historicalOccurrences'] ?? 0,
    avgSubsequentMove: (json['avg_subsequent_move'] ?? json['avgSubsequentMove'] ?? 0).toDouble(),
    matchedCurrentNews: List<String>.from(json['matched_current_news'] ?? json['matchedCurrentNews'] ?? []),
    matchConfidence: (json['match_confidence'] ?? json['matchConfidence'] ?? 0).toDouble(),
  );
}

class MarketAnalysis {
  final String symbol;
  final String assetType;
  final DateTime analyzedAt;
  final AnalysisDirection direction;
  final double confidence;
  final double probabilitySignificantMove;
  final double expectedMovePercent;
  final int timeframeDays;
  final List<String> keyTriggers;
  final List<HistoricalPattern> historicalPatterns;
  final List<NewsCorrelation> newsCorrelations;
  final List<NewsPattern> newsPatterns; // Erkannte News-Patterns
  final List<String> riskFactors;
  final String recommendation;
  final String summary;
  final bool alertEnabled;
  final double? priceAtAnalysis;

  MarketAnalysis({
    required this.symbol,
    required this.assetType,
    required this.analyzedAt,
    required this.direction,
    required this.confidence,
    required this.probabilitySignificantMove,
    required this.expectedMovePercent,
    required this.timeframeDays,
    required this.keyTriggers,
    required this.historicalPatterns,
    required this.newsCorrelations,
    this.newsPatterns = const [],
    required this.riskFactors,
    required this.recommendation,
    required this.summary,
    this.alertEnabled = false,
    this.priceAtAnalysis,
  });

  /// Berechnet den Zielwert basierend auf Preis und erwarteter Bewegung
  double? get targetPrice {
    if (priceAtAnalysis == null) return null;
    return priceAtAnalysis! * (1 + expectedMovePercent / 100);
  }

  String get directionText {
    switch (direction) {
      case AnalysisDirection.bullish:
        return 'BULLISH';
      case AnalysisDirection.bearish:
        return 'BEARISH';
      case AnalysisDirection.neutral:
        return 'NEUTRAL';
    }
  }

  String get directionEmoji {
    switch (direction) {
      case AnalysisDirection.bullish:
        return '↑';
      case AnalysisDirection.bearish:
        return '↓';
      case AnalysisDirection.neutral:
        return '→';
    }
  }

  MarketAnalysis copyWith({bool? alertEnabled, double? priceAtAnalysis}) {
    return MarketAnalysis(
      symbol: symbol,
      assetType: assetType,
      analyzedAt: analyzedAt,
      direction: direction,
      confidence: confidence,
      probabilitySignificantMove: probabilitySignificantMove,
      expectedMovePercent: expectedMovePercent,
      timeframeDays: timeframeDays,
      keyTriggers: keyTriggers,
      historicalPatterns: historicalPatterns,
      newsCorrelations: newsCorrelations,
      newsPatterns: newsPatterns,
      riskFactors: riskFactors,
      recommendation: recommendation,
      summary: summary,
      alertEnabled: alertEnabled ?? this.alertEnabled,
      priceAtAnalysis: priceAtAnalysis ?? this.priceAtAnalysis,
    );
  }

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'assetType': assetType,
    'analyzedAt': analyzedAt.toIso8601String(),
    'direction': direction.name,
    'confidence': confidence,
    'probabilitySignificantMove': probabilitySignificantMove,
    'expectedMovePercent': expectedMovePercent,
    'timeframeDays': timeframeDays,
    'keyTriggers': keyTriggers,
    'historicalPatterns': historicalPatterns.map((p) => p.toJson()).toList(),
    'newsCorrelations': newsCorrelations.map((n) => n.toJson()).toList(),
    'newsPatterns': newsPatterns.map((p) => p.toJson()).toList(),
    'riskFactors': riskFactors,
    'recommendation': recommendation,
    'summary': summary,
    'alertEnabled': alertEnabled,
    'priceAtAnalysis': priceAtAnalysis,
  };

  factory MarketAnalysis.fromJson(Map<String, dynamic> json) => MarketAnalysis(
    symbol: json['symbol'] ?? '',
    assetType: json['assetType'] ?? '',
    analyzedAt: DateTime.tryParse(json['analyzedAt'] ?? '') ?? DateTime.now(),
    direction: AnalysisDirection.values.firstWhere(
      (e) => e.name == json['direction'],
      orElse: () => AnalysisDirection.neutral,
    ),
    confidence: (json['confidence'] ?? 0).toDouble(),
    probabilitySignificantMove: (json['probabilitySignificantMove'] ?? 0).toDouble(),
    expectedMovePercent: (json['expectedMovePercent'] ?? 0).toDouble(),
    timeframeDays: json['timeframeDays'] ?? 0,
    keyTriggers: List<String>.from(json['keyTriggers'] ?? []),
    historicalPatterns: (json['historicalPatterns'] as List?)
        ?.map((p) => HistoricalPattern.fromJson(p))
        .toList() ?? [],
    newsCorrelations: (json['newsCorrelations'] as List?)
        ?.map((n) => NewsCorrelation.fromJson(n))
        .toList() ?? [],
    newsPatterns: (json['newsPatterns'] as List?)
        ?.map((p) => NewsPattern.fromJson(p))
        .toList() ?? [],
    riskFactors: List<String>.from(json['riskFactors'] ?? []),
    recommendation: json['recommendation'] ?? '',
    summary: json['summary'] ?? '',
    alertEnabled: json['alertEnabled'] ?? false,
    priceAtAnalysis: (json['priceAtAnalysis'] as num?)?.toDouble(),
  );

  String toJsonString() => jsonEncode(toJson());

  factory MarketAnalysis.fromJsonString(String jsonString) =>
      MarketAnalysis.fromJson(jsonDecode(jsonString));
}

class TriggerAlert {
  final String id;
  final String symbol;
  final String assetType;
  final List<String> triggers;
  final AnalysisDirection expectedDirection;
  final double expectedMovePercent;
  final DateTime createdAt;
  final DateTime? triggeredAt;
  final bool isActive;
  final String? notificationMessage;

  TriggerAlert({
    required this.id,
    required this.symbol,
    required this.assetType,
    required this.triggers,
    required this.expectedDirection,
    required this.expectedMovePercent,
    required this.createdAt,
    this.triggeredAt,
    this.isActive = true,
    this.notificationMessage,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'symbol': symbol,
    'assetType': assetType,
    'triggers': triggers,
    'expectedDirection': expectedDirection.name,
    'expectedMovePercent': expectedMovePercent,
    'createdAt': createdAt.toIso8601String(),
    'triggeredAt': triggeredAt?.toIso8601String(),
    'isActive': isActive,
    'notificationMessage': notificationMessage,
  };

  factory TriggerAlert.fromJson(Map<String, dynamic> json) => TriggerAlert(
    id: json['id'] ?? '',
    symbol: json['symbol'] ?? '',
    assetType: json['assetType'] ?? '',
    triggers: List<String>.from(json['triggers'] ?? []),
    expectedDirection: AnalysisDirection.values.firstWhere(
      (e) => e.name == json['expectedDirection'],
      orElse: () => AnalysisDirection.neutral,
    ),
    expectedMovePercent: (json['expectedMovePercent'] ?? 0).toDouble(),
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    triggeredAt: json['triggeredAt'] != null ? DateTime.tryParse(json['triggeredAt']) : null,
    isActive: json['isActive'] ?? true,
    notificationMessage: json['notificationMessage'],
  );
}
