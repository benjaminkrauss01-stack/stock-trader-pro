import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'api_config.dart';

class _NewsCacheEntry {
  final List<NewsArticle> data;
  final DateTime cachedAt;
  _NewsCacheEntry(this.data) : cachedAt = DateTime.now();
  bool get isExpired => DateTime.now().difference(cachedAt) > const Duration(minutes: 10);
}

class ExtendedNewsService {
  final http.Client _client;
  static final Map<String, _NewsCacheEntry> _cache = {};

  ExtendedNewsService({http.Client? client}) : _client = client ?? http.Client();

  String _getYahooSearchUrl(String query) {
    if (kIsWeb) {
      return '${ApiConfig.yahooSearchUrl}?q=$query&newsCount=20&quotesCount=0';
    }
    return 'https://query1.finance.yahoo.com/v1/finance/search?q=$query&newsCount=20&quotesCount=0';
  }

  // Yahoo Finance News
  Future<List<NewsArticle>> getYahooNews(String query) async {
    try {
      final url = _getYahooSearchUrl(query);
      final response = await _client.get(
        Uri.parse(url),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final news = data['news'] as List? ?? [];
        return news.map((n) => NewsArticle.fromYahoo(n)).toList();
      } else {
        // print('Yahoo News API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // print('Error fetching Yahoo news: $e');
    }
    return [];
  }

  // Market News from multiple sources
  Future<List<NewsArticle>> getMarketNews({String category = 'general'}) async {
    final cached = _cache['market'];
    if (cached != null && !cached.isExpired) return cached.data;

    try {
      final queries = ['stock market news', 'market update', 'financial news'];
      final results = await Future.wait(
        queries.map((q) => getYahooNews(q))
      );

      final allNews = results.expand((x) => x).toList();
      final seen = <String>{};
      final deduped = allNews.where((n) => seen.add(n.uuid)).toList()
        ..sort((a, b) =>
          (b.publishedAt ?? DateTime.now()).compareTo(a.publishedAt ?? DateTime.now())
        );
      _cache['market'] = _NewsCacheEntry(deduped);
      return deduped;
    } catch (e) {
      if (cached != null) return cached.data;
    }
    return [];
  }

  // Economic Calendar News
  Future<List<EconomicEvent>> getEconomicEvents() async {
    // Simulated economic events - in production, use a real API
    return [
      EconomicEvent(
        title: 'Federal Reserve Interest Rate Decision',
        country: 'US',
        date: DateTime.now().add(const Duration(days: 2)),
        impact: EventImpact.high,
        category: 'Interest Rate',
        previous: '5.50%',
        forecast: '5.50%',
      ),
      EconomicEvent(
        title: 'Non-Farm Payrolls',
        country: 'US',
        date: DateTime.now().add(const Duration(days: 5)),
        impact: EventImpact.high,
        category: 'Employment',
        previous: '199K',
        forecast: '180K',
      ),
      EconomicEvent(
        title: 'CPI Year-over-Year',
        country: 'US',
        date: DateTime.now().add(const Duration(days: 7)),
        impact: EventImpact.high,
        category: 'Inflation',
        previous: '3.1%',
        forecast: '2.9%',
      ),
      EconomicEvent(
        title: 'ECB Interest Rate Decision',
        country: 'EU',
        date: DateTime.now().add(const Duration(days: 10)),
        impact: EventImpact.high,
        category: 'Interest Rate',
        previous: '4.50%',
        forecast: '4.25%',
      ),
      EconomicEvent(
        title: 'GDP Growth Rate QoQ',
        country: 'US',
        date: DateTime.now().add(const Duration(days: 14)),
        impact: EventImpact.medium,
        category: 'GDP',
        previous: '4.9%',
        forecast: '2.5%',
      ),
      EconomicEvent(
        title: 'Retail Sales MoM',
        country: 'US',
        date: DateTime.now().add(const Duration(days: 3)),
        impact: EventImpact.medium,
        category: 'Consumer',
        previous: '0.3%',
        forecast: '0.4%',
      ),
      EconomicEvent(
        title: 'Unemployment Rate',
        country: 'US',
        date: DateTime.now().add(const Duration(days: 5)),
        impact: EventImpact.high,
        category: 'Employment',
        previous: '3.7%',
        forecast: '3.8%',
      ),
      EconomicEvent(
        title: 'Consumer Confidence',
        country: 'US',
        date: DateTime.now().add(const Duration(days: 8)),
        impact: EventImpact.medium,
        category: 'Consumer',
        previous: '102.0',
        forecast: '104.0',
      ),
    ];
  }

  // Sector News
  Future<List<NewsArticle>> getSectorNews(String sector) async {
    final sectorQueries = {
      'Technology': 'technology stocks AAPL MSFT GOOGL',
      'Healthcare': 'healthcare pharma biotech stocks',
      'Finance': 'banking financial stocks JPM GS',
      'Energy': 'oil gas energy stocks XOM CVX',
      'Consumer': 'retail consumer stocks AMZN WMT',
      'Industrial': 'industrial manufacturing stocks',
      'Real Estate': 'real estate REIT stocks',
      'Utilities': 'utilities stocks electric power',
      'Materials': 'materials mining stocks',
      'Communications': 'telecom media stocks META NFLX',
    };

    final query = sectorQueries[sector] ?? sector;
    return getYahooNews(query);
  }

  // Political/Economic News
  Future<List<NewsArticle>> getPoliticalEconomicNews() async {
    final cached = _cache['political'];
    if (cached != null && !cached.isExpired) return cached.data;

    final queries = [
      'federal reserve policy',
      'economic policy',
      'trade tariffs',
      'government fiscal',
    ];

    final results = await Future.wait(
      queries.map((q) => getYahooNews(q))
    );

    final allNews = results.expand((x) => x).toList();
    final seen = <String>{};
    final deduped = allNews.where((n) => seen.add(n.uuid)).toList()
      ..sort((a, b) => (b.publishedAt ?? DateTime.now()).compareTo(a.publishedAt ?? DateTime.now()));
    _cache['political'] = _NewsCacheEntry(deduped);
    return deduped;
  }

  // Crypto News
  Future<List<NewsArticle>> getCryptoNews() async {
    final cached = _cache['crypto'];
    if (cached != null && !cached.isExpired) return cached.data;

    final result = await getYahooNews('bitcoin ethereum crypto cryptocurrency');
    _cache['crypto'] = _NewsCacheEntry(result);
    return result;
  }

  /// Get news for a specific symbol
  Future<List<NewsArticle>> getNewsForSymbol(String symbol) async {
    return getYahooNews(symbol);
  }
}

class NewsArticle {
  final String uuid;
  final String title;
  final String? summary;
  final String? link;
  final String? thumbnail;
  final DateTime? publishedAt;
  final String? source;
  final NewsCategory category;
  final List<String> relatedSymbols;

  NewsArticle({
    required this.uuid,
    required this.title,
    this.summary,
    this.link,
    this.thumbnail,
    this.publishedAt,
    this.source,
    this.category = NewsCategory.general,
    this.relatedSymbols = const [],
  });

  factory NewsArticle.fromYahoo(Map<String, dynamic> json) {
    DateTime? publishedAt;
    if (json['providerPublishTime'] != null) {
      publishedAt = DateTime.fromMillisecondsSinceEpoch(
        (json['providerPublishTime'] as int) * 1000,
      );
    }

    return NewsArticle(
      uuid: json['uuid'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? '',
      summary: json['summary'],
      link: json['link'],
      thumbnail: json['thumbnail']?['resolutions']?[0]?['url'],
      publishedAt: publishedAt,
      source: json['publisher'],
      relatedSymbols: (json['relatedTickers'] as List?)
              ?.map((t) => t.toString())
              .toList() ?? [],
    );
  }

  String get timeAgo {
    if (publishedAt == null) return '';
    final diff = DateTime.now().difference(publishedAt!);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

enum NewsCategory {
  general,
  market,
  crypto,
  forex,
  economy,
  politics,
  technology,
  healthcare,
  energy,
}

class EconomicEvent {
  final String title;
  final String country;
  final DateTime date;
  final EventImpact impact;
  final String category;
  final String? previous;
  final String? forecast;
  final String? actual;

  EconomicEvent({
    required this.title,
    required this.country,
    required this.date,
    required this.impact,
    required this.category,
    this.previous,
    this.forecast,
    this.actual,
  });

  String get formattedDate {
    final now = DateTime.now();
    final diff = date.difference(now);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Tomorrow';
    if (diff.inDays < 7) return 'In ${diff.inDays} days';
    return '${date.month}/${date.day}';
  }
}

enum EventImpact { low, medium, high }
