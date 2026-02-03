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
          'Du bist ein erfahrener Finanzanalyst. Antworte NUR mit dem verlangten JSON, keinen weiteren Erklärungen.',
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

    // Use custom prompt template if provided, otherwise use default
    if (customPromptTemplate != null && customPromptTemplate.isNotEmpty) {
      return customPromptTemplate
          .replaceAll('{symbol}', symbol)
          .replaceAll('{assetType}', assetType)
          .replaceAll('{priceData}', priceData)
          .replaceAll('{newsData}', newsData)
          .replaceAll('{movesWithPrecedingNews}', movesWithPrecedingNews);
    }

    return '''
Analysiere die folgenden Daten für $symbol ($assetType) und identifiziere Muster.

## PREISVERLAUF (letzte 90 Tage)
$priceData

## SIGNIFIKANTE BEWEGUNGEN (>5%) MIT VORHERGEHENDEN NACHRICHTEN
Für jede signifikante Bewegung sind die Nachrichten der 7 Tage davor aufgelistet.
Analysiere diese Nachrichten, um wiederkehrende Muster zu erkennen, die Bewegungen vorhersagen.

$movesWithPrecedingNews

## AKTUELLE NACHRICHTEN (letzte 7 Tage)
Vergleiche diese mit den Mustern aus den vorhergehenden Nachrichten bei signifikanten Bewegungen.
$newsData

## AUFGABE
1. Analysiere die Nachrichten VOR jeder signifikanten Bewegung und identifiziere wiederkehrende Muster
   - Welche Arten von Nachrichten (Themen, Sentiment, Quellen) traten häufig vor Bewegungen auf?
   - Gibt es typische Zeitverzögerungen zwischen bestimmten Nachrichtentypen und Preisbewegungen?
2. Vergleiche die aktuellen Nachrichten mit diesen historischen Mustern
   - Welche aktuellen Nachrichten ähneln den Mustern, die früher zu Bewegungen führten?
   - Wie hoch ist die Übereinstimmung?
3. Bewerte die Wahrscheinlichkeit einer baldigen signifikanten Bewegung basierend auf den erkannten Mustern
4. Gib eine klare Richtungsindikation (BULLISH/BEARISH/NEUTRAL)

## ANTWORT FORMAT (JSON)
{
  "direction": "BULLISH" | "BEARISH" | "NEUTRAL",
  "confidence": 0-100,
  "probability_significant_move": 0-100,
  "expected_move_percent": number,
  "timeframe_days": number,
  "key_triggers": ["trigger1", "trigger2"],
  "historical_patterns": [
    {
      "pattern": "beschreibung",
      "occurred_before": "datum",
      "resulted_in": "beschreibung der folge",
      "relevance_score": 0-100
    }
  ],
  "news_correlations": [
    {
      "news_event": "headline",
      "price_impact": "beschreibung",
      "delay_days": number
    }
  ],
  "news_patterns": [
    {
      "pattern_type": "z.B. earnings_warning, analyst_sentiment, sector_rotation, regulatory_news",
      "description": "Beschreibung des erkannten Musters in den Nachrichten vor Bewegungen",
      "historical_occurrences": number,
      "avg_subsequent_move": number,
      "matched_current_news": ["headline1 die diesem Muster entspricht", "headline2"],
      "match_confidence": 0-100
    }
  ],
  "risk_factors": ["risiko1", "risiko2"],
  "recommendation": "kurze handlungsempfehlung",
  "summary": "2-3 Sätze Zusammenfassung mit Fokus auf erkannte News-Patterns"
}
''';
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

      return MarketAnalysis(
        symbol: symbol,
        assetType: assetType,
        analyzedAt: DateTime.now(),
        direction: _parseDirection(data['direction']),
        confidence: (data['confidence'] ?? 50).toDouble(),
        probabilitySignificantMove:
            (data['probability_significant_move'] ?? 0).toDouble(),
        expectedMovePercent: (data['expected_move_percent'] ?? 0).toDouble(),
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
