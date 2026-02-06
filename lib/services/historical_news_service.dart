import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/analysis.dart';

/// Service für historische Finanznachrichten via Polygon.io API
/// Basic Plan: 2 Jahre historische Daten
/// Free Tier: 5 API calls/minute
class HistoricalNewsService {
  static final HistoricalNewsService _instance = HistoricalNewsService._internal();
  factory HistoricalNewsService() => _instance;
  HistoricalNewsService._internal();

  final http.Client _client = http.Client();

  static const String _baseUrl = 'https://api.polygon.io/v2/reference/news';
  static const String _cacheKeyPrefix = 'polygon_news_';
  static const Duration _cacheDuration = Duration(days: 7);

  String get _apiKey => dotenv.env['POLYGON_API_KEY'] ?? '';

  /// Holt historische News für ein Symbol (bis zu 2 Jahre mit Basic Plan)
  Future<List<NewsEvent>> getHistoricalNews(
    String symbol, {
    int years = 2,
    bool forceRefresh = false,
  }) async {
    if (_apiKey.isEmpty) {
      // print('Polygon API Key nicht konfiguriert');
      return [];
    }

    // Cache prüfen
    if (!forceRefresh) {
      final cachedNews = await _getCachedNews(symbol);
      if (cachedNews != null) {
        // print('Verwende gecachte News für $symbol (${cachedNews.length} Artikel)');
        return cachedNews;
      }
    }

    final allNews = <NewsEvent>[];
    String? nextUrl;
    int pageCount = 0;
    const maxPages = 20; // Limit um API-Calls zu sparen

    // Berechne Startdatum (2 Jahre zurück)
    final startDate = DateTime.now().subtract(Duration(days: years * 365));
    final startDateStr = startDate.toIso8601String().split('T')[0];

    // Erste Anfrage
    var url = '$_baseUrl?ticker=$symbol&published_utc.gte=$startDateStr&limit=1000&sort=published_utc&order=desc&apiKey=$_apiKey';

    while (url.isNotEmpty && pageCount < maxPages) {
      try {
        final response = await _client.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final results = data['results'] as List? ?? [];

          if (results.isEmpty) break;

          for (final article in results) {
            allNews.add(_parseArticle(article));
          }

          // Pagination
          nextUrl = data['next_url'];
          if (nextUrl != null && nextUrl.isNotEmpty) {
            // API Key an next_url anhängen
            url = '$nextUrl&apiKey=$_apiKey';
          } else {
            url = '';
          }

          pageCount++;
        } else if (response.statusCode == 429) {
          // Rate limit erreicht — warte und retry
          await Future.delayed(const Duration(seconds: 12));
        } else {
          // print('Polygon API Error: ${response.statusCode}');
          break;
        }
      } catch (e) {
        // print('Request Error: $e');
        break;
      }
    }

    // Duplikate entfernen und sortieren
    final uniqueNews = _removeDuplicates(allNews);
    uniqueNews.sort((a, b) => b.date.compareTo(a.date));

    // In Cache speichern
    if (uniqueNews.isNotEmpty) {
      await _cacheNews(symbol, uniqueNews);
    }

    // print('${uniqueNews.length} historische News für $symbol geladen');
    return uniqueNews;
  }

  NewsEvent _parseArticle(Map<String, dynamic> article) {
    DateTime date;
    try {
      date = DateTime.parse(article['published_utc'] ?? '');
    } catch (e) {
      date = DateTime.now();
    }

    final title = article['title'] ?? '';
    final description = article['description'] ?? '';

    // Sentiment analysieren
    final sentiment = _analyzeSentiment('$title $description');

    // Tickers extrahieren
    final tickers = (article['tickers'] as List?)?.cast<String>() ?? [];

    return NewsEvent(
      date: date,
      headline: title,
      source: article['publisher']?['name'] ?? 'Unknown',
      sentiment: sentiment,
      url: article['article_url'],
      relatedSymbols: tickers,
    );
  }

  String _analyzeSentiment(String text) {
    final textLower = text.toLowerCase();

    final positiveWords = [
      'surge', 'jump', 'gain', 'rise', 'high', 'record', 'beat', 'exceed',
      'growth', 'profit', 'success', 'bullish', 'rally', 'boom', 'upgrade',
      'buy', 'outperform', 'strong', 'positive', 'soar', 'climb', 'advance',
      'breakthrough', 'optimistic', 'upbeat', 'recovery'
    ];

    final negativeWords = [
      'fall', 'drop', 'crash', 'loss', 'decline', 'low', 'miss', 'fail',
      'concern', 'risk', 'bearish', 'selloff', 'plunge', 'downgrade',
      'sell', 'underperform', 'weak', 'negative', 'warning', 'tumble',
      'slump', 'plummet', 'worry', 'fear', 'layoff', 'cut'
    ];

    int positiveCount = positiveWords.where((w) => textLower.contains(w)).length;
    int negativeCount = negativeWords.where((w) => textLower.contains(w)).length;

    if (positiveCount > negativeCount) return 'positive';
    if (negativeCount > positiveCount) return 'negative';
    return 'neutral';
  }

  List<NewsEvent> _removeDuplicates(List<NewsEvent> news) {
    final seen = <String>{};
    return news.where((n) {
      final key = '${n.date.toIso8601String().substring(0, 10)}_${n.headline.hashCode}';
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();
  }

  // === Caching Methoden ===

  Future<List<NewsEvent>?> _getCachedNews(String symbol) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$symbol';
      final timestampKey = '${cacheKey}_timestamp';

      final timestamp = prefs.getInt(timestampKey);
      if (timestamp == null) return null;

      final cacheAge = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(timestamp)
      );

      if (cacheAge > _cacheDuration) {
        return null;
      }

      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson == null) return null;

      final List<dynamic> decoded = json.decode(cachedJson);
      return decoded.map((item) => NewsEvent.fromJson(item)).toList();
    } catch (e) {
      return null;
    }
  }

  Future<void> _cacheNews(String symbol, List<NewsEvent> news) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$symbol';
      final timestampKey = '${cacheKey}_timestamp';

      final jsonData = json.encode(news.map((n) => n.toJson()).toList());
      await prefs.setString(cacheKey, jsonData);
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Cache write error - ignore
    }
  }

  /// Löscht den Cache für ein Symbol
  Future<void> clearCache(String symbol) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$symbol';
      await prefs.remove(cacheKey);
      await prefs.remove('${cacheKey}_timestamp');
    } catch (e) {
      // Ignore
    }
  }

  /// Löscht den gesamten News-Cache
  Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_cacheKeyPrefix));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      // Ignore
    }
  }

  /// Prüft ob ein API Key konfiguriert ist
  bool get hasApiKey => _apiKey.isNotEmpty;

  /// Gibt die Cache-Statistiken zurück
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKeys = prefs.getKeys().where(
        (k) => k.startsWith(_cacheKeyPrefix) && !k.endsWith('_timestamp')
      ).toList();

      int totalArticles = 0;
      final symbols = <String>[];

      for (final key in cacheKeys) {
        final symbol = key.replaceFirst(_cacheKeyPrefix, '');
        symbols.add(symbol);

        final cachedJson = prefs.getString(key);
        if (cachedJson != null) {
          final List<dynamic> decoded = json.decode(cachedJson);
          totalArticles += decoded.length;
        }
      }

      return {
        'cachedSymbols': symbols,
        'totalArticles': totalArticles,
        'cacheCount': cacheKeys.length,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
