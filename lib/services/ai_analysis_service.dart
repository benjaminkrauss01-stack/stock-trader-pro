import 'dart:convert';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/analysis.dart';

class AIAnalysisService {
  static final AIAnalysisService _instance = AIAnalysisService._internal();
  factory AIAnalysisService() => _instance;
  AIAnalysisService._internal() {
    OpenAI.apiKey = _apiKey;
    OpenAI.showLogs = false;
    OpenAI.showResponsesLogs = false;
  }

  String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';

  Future<MarketAnalysis> analyzeAsset({
    required String symbol,
    required String assetType,
    required List<PricePoint> priceHistory,
    required List<NewsEvent> recentNews,
    required List<SignificantMove> significantMoves,
    String? customPromptTemplate,
  }) async {
    final prompt = _buildAnalysisPrompt(
      symbol: symbol,
      assetType: assetType,
      priceHistory: priceHistory,
      recentNews: recentNews,
      significantMoves: significantMoves,
      customPromptTemplate: customPromptTemplate,
    );

    final systemMessage = OpenAIChatCompletionChoiceMessageModel(
      content: [
        OpenAIChatCompletionChoiceMessageContentItemModel.text(
          'Du bist ein quantitativer Finanzanalyst mit Expertise in technischer Analyse, Sentiment-Analyse und statistischer Mustererkennung. '
          'Deine Aufgabe: Datengetriebene Prognosen mit kalibrierten Wahrscheinlichkeiten. '
          'WICHTIGE REGELN:\n'
          '- Confidence 0-30: Kaum erkennbare Muster, unklar\n'
          '- Confidence 31-55: Leichte Tendenz, gemischte Signale\n'
          '- Confidence 56-75: Klare Muster mit mehreren übereinstimmenden Signalen\n'
          '- Confidence 76-100: NUR bei starker Konvergenz von Technik + News + Momentum\n'
          '- Sei bei NEUTRAL nicht ängstlich — wähle eine Richtung wenn >55% der Signale dafür sprechen\n'
          '- expected_move_percent soll REALISTISCH sein (typisch: 2-8% in 7-30 Tagen)\n'
          '- timeframe_days: 7 bei kurzfristigen Katalysatoren, 14-30 bei Trend-Signalen\n'
          'Antworte NUR mit dem verlangten JSON.',
        ),
      ],
      role: OpenAIChatMessageRole.system,
    );

    final userMessage = OpenAIChatCompletionChoiceMessageModel(
      content: [
        OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
      ],
      role: OpenAIChatMessageRole.user,
    );

    final response = await _callOpenAI([systemMessage, userMessage]);
    return _parseAnalysisResponse(response, symbol, assetType);
  }

  String _buildAnalysisPrompt({
    required String symbol,
    required String assetType,
    required List<PricePoint> priceHistory,
    required List<NewsEvent> recentNews,
    required List<SignificantMove> significantMoves,
    String? customPromptTemplate,
  }) {
    final priceData = priceHistory
        .map(
          (p) =>
              '${p.date.toIso8601String().split('T')[0]}: \$${p.close.toStringAsFixed(2)} (${p.changePercent >= 0 ? '+' : ''}${p.changePercent.toStringAsFixed(2)}%)',
        )
        .join('\n');

    final newsData = recentNews
        .map(
          (n) =>
              '${n.date.toIso8601String().split('T')[0]}: ${n.headline} [${n.source}] - Sentiment: ${n.sentiment}',
        )
        .join('\n');

    // Signifikante Bewegungen MIT den Nachrichten der 7 Tage davor
    final movesWithPrecedingNews = significantMoves.map((m) {
      final moveInfo = '${m.date.toIso8601String().split('T')[0]}: ${m.changePercent >= 0 ? '+' : ''}${m.changePercent.toStringAsFixed(2)}% move from \$${m.priceFrom.toStringAsFixed(2)} to \$${m.priceTo.toStringAsFixed(2)}';

      if (m.precedingNews.isEmpty) {
        return '$moveInfo\n  Vorhergehende Nachrichten (7 Tage): Keine';
      }

      final precedingNewsStr = m.precedingNews
          .map((n) => '    - ${n.date.toIso8601String().split('T')[0]}: ${n.headline} [${n.source}] - Sentiment: ${n.sentiment}')
          .join('\n');

      return '$moveInfo\n  Vorhergehende Nachrichten (7 Tage):\n$precedingNewsStr';
    }).join('\n\n');

    // Database prompt is required - no hardcoded fallback
    if (customPromptTemplate == null || customPromptTemplate.isEmpty) {
      throw Exception('Kein KI-Analyse Prompt in der Datenbank gefunden. Bitte im Admin Panel konfigurieren.');
    }

    return customPromptTemplate
        .replaceAll('{symbol}', symbol)
        .replaceAll('{assetType}', assetType)
        .replaceAll('{priceData}', priceData)
        .replaceAll('{newsData}', newsData)
        .replaceAll('{movesWithPrecedingNews}', movesWithPrecedingNews);
  }

  Future<String> _callOpenAI(
    List<OpenAIChatCompletionChoiceMessageModel> messages,
  ) async {
    try {
      final chatCompletion = await OpenAI.instance.chat.create(
        model: 'gpt-4o-mini',
        responseFormat: {"type": "json_object"},
        messages: messages,
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('AI-Analyse Timeout: Die Anfrage hat zu lange gedauert (>60s). Bitte versuchen Sie es erneut.');
        },
      );
      return chatCompletion.choices.first.message.content?.first.text ?? '';
    } catch (e) {
      rethrow;
    }
  }

  MarketAnalysis _parseAnalysisResponse(
    String response,
    String symbol,
    String assetType,
  ) {
    try {
      final data = jsonDecode(response);

      final direction = _parseDirection(data['direction']);
      var movePercent = (data['expected_move_percent'] ?? 0).toDouble();

      // Vorzeichen-Korrektur: bearish muss negativ sein, bullish positiv
      if (direction == AnalysisDirection.bearish && movePercent > 0) {
        movePercent = -movePercent;
      } else if (direction == AnalysisDirection.bullish && movePercent < 0) {
        movePercent = movePercent.abs();
      }

      return MarketAnalysis(
        symbol: symbol,
        assetType: assetType,
        analyzedAt: DateTime.now(),
        direction: direction,
        confidence: (data['confidence'] ?? 50).toDouble(),
        probabilitySignificantMove:
            (data['probability_significant_move'] ?? 0).toDouble(),
        expectedMovePercent: movePercent,
        timeframeDays: data['timeframe_days'] ?? 7,
        keyTriggers: List<String>.from(data['key_triggers'] ?? []),
        historicalPatterns: (data['historical_patterns'] as List?)
                ?.map(
                  (p) => HistoricalPattern(
                    pattern: p['pattern'] ?? '',
                    occurredBefore:
                        DateTime.tryParse(p['occurred_before'] ?? '') ??
                            DateTime.now(),
                    resultedIn: p['resulted_in'] ?? '',
                    relevanceScore: (p['relevance_score'] ?? 0).toDouble(),
                  ),
                )
                .toList() ??
            [],
        newsCorrelations: (data['news_correlations'] as List?)
                ?.map(
                  (n) => NewsCorrelation(
                    newsEvent: n['news_event'] ?? '',
                    priceImpact: n['price_impact'] ?? '',
                    delayDays: n['delay_days'] ?? 0,
                  ),
                )
                .toList() ??
            [],
        newsPatterns: (data['news_patterns'] as List?)
                ?.map(
                  (p) => NewsPattern(
                    patternType: p['pattern_type'] ?? '',
                    description: p['description'] ?? '',
                    historicalOccurrences: p['historical_occurrences'] ?? 0,
                    avgSubsequentMove: (p['avg_subsequent_move'] ?? 0).toDouble(),
                    matchedCurrentNews: List<String>.from(p['matched_current_news'] ?? []),
                    matchConfidence: (p['match_confidence'] ?? 0).toDouble(),
                  ),
                )
                .toList() ??
            [],
        riskFactors: List<String>.from(data['risk_factors'] ?? []),
        recommendation: data['recommendation'] ?? '',
        summary: data['summary'] ?? '',
      );
    } catch (e) {
      // Fallback
      return MarketAnalysis(
        symbol: symbol,
        assetType: assetType,
        analyzedAt: DateTime.now(),
        direction: AnalysisDirection.neutral,
        confidence: 0,
        probabilitySignificantMove: 0,
        expectedMovePercent: 0,
        timeframeDays: 0,
        keyTriggers: [],
        historicalPatterns: [],
        newsCorrelations: [],
        newsPatterns: [],
        riskFactors: ['Analyse fehlgeschlagen'],
        recommendation: 'Bitte erneut versuchen',
        summary: 'Die Analyse konnte nicht durchgeführt werden.',
      );
    }
  }

  AnalysisDirection _parseDirection(String? direction) {
    switch (direction?.toUpperCase()) {
      case 'BULLISH':
        return AnalysisDirection.bullish;
      case 'BEARISH':
        return AnalysisDirection.bearish;
      default:
        return AnalysisDirection.neutral;
    }
  }

  Future<String> getQuickInsight(String symbol, String question) async {
    final systemMessage = OpenAIChatCompletionChoiceMessageModel(
      content: [
        OpenAIChatCompletionChoiceMessageContentItemModel.text(
          'Beantworte die folgende Frage zu $symbol kurz und präzise. Halte die Antwort unter 100 Wörtern.',
        ),
      ],
      role: OpenAIChatMessageRole.system,
    );

    final userMessage = OpenAIChatCompletionChoiceMessageModel(
      content: [
        OpenAIChatCompletionChoiceMessageContentItemModel.text(question),
      ],
      role: OpenAIChatMessageRole.user,
    );

    return await _callOpenAI([systemMessage, userMessage]);
  }
}
