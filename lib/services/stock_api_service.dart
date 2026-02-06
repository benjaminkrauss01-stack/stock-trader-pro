import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/stock.dart';
import 'api_config.dart';

class _CacheEntry<T> {
  final T data;
  final DateTime cachedAt;
  _CacheEntry(this.data) : cachedAt = DateTime.now();
  bool isExpired(Duration ttl) => DateTime.now().difference(cachedAt) > ttl;
}

class StockApiService {
  final http.Client _client;

  // In-Memory Caches
  final Map<String, _CacheEntry<List<Stock>>> _quotesCache = {};
  final Map<String, _CacheEntry<List<StockCandle>>> _chartCache = {};
  static const _quotesTtl = Duration(seconds: 30);
  static const _chartTtl = Duration(minutes: 5);

  StockApiService({http.Client? client}) : _client = client ?? http.Client();

  String _getChartUrl(String symbol, String interval, String range) {
    if (kIsWeb) {
      return '${ApiConfig.yahooChartUrl}/$symbol?interval=$interval&range=$range';
    }
    return 'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=$interval&range=$range';
  }

  String _getQuoteUrl(String symbols) {
    if (kIsWeb) {
      return '${ApiConfig.yahooQuoteUrl}?symbols=$symbols';
    }
    return 'https://query1.finance.yahoo.com/v1/finance/quote?symbols=$symbols';
  }

  String _getSearchUrl(String query) {
    if (kIsWeb) {
      return '${ApiConfig.yahooSearchUrl}?q=$query&quotesCount=10&newsCount=0';
    }
    return 'https://query1.finance.yahoo.com/v1/finance/search?q=$query&quotesCount=10&newsCount=0';
  }

  Future<Stock?> getQuote(String symbol) async {
    try {
      final url = _getChartUrl(symbol, '1d', '1d');
      final response = await _client.get(
        Uri.parse(url),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['chart']?['result']?[0];
        if (result != null) {
          final meta = result['meta'];
          final quote = result['indicators']?['quote']?[0];

          return Stock(
            symbol: meta['symbol'] ?? symbol,
            name: meta['shortName'] ?? meta['longName'] ?? symbol,
            price: (meta['regularMarketPrice'] ?? 0).toDouble(),
            change: ((meta['regularMarketPrice'] ?? 0) - (meta['previousClose'] ?? 0)).toDouble(),
            changePercent: meta['previousClose'] != null && meta['previousClose'] != 0
                ? (((meta['regularMarketPrice'] ?? 0) - meta['previousClose']) / meta['previousClose'] * 100)
                : 0.0,
            high: (meta['regularMarketDayHigh'] ?? quote?['high']?.last ?? 0).toDouble(),
            low: (meta['regularMarketDayLow'] ?? quote?['low']?.last ?? 0).toDouble(),
            open: (meta['regularMarketOpen'] ?? quote?['open']?.first ?? 0).toDouble(),
            previousClose: (meta['previousClose'] ?? 0).toDouble(),
            volume: (meta['regularMarketVolume'] ?? 0).toInt(),
            currency: meta['currency'],
            lastUpdate: DateTime.now(),
          );
        }
      } else {
        // print('Stock API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // print('Error fetching quote for $symbol: $e');
    }
    return null;
  }

  Future<List<Stock>> getMultipleQuotes(List<String> symbols) async {
    final cacheKey = symbols.toList()..sort();
    final key = cacheKey.join(',');
    final cached = _quotesCache[key];
    if (cached != null && !cached.isExpired(_quotesTtl)) {
      return cached.data;
    }

    try {
      final url = _getQuoteUrl(key);
      final response = await _client.get(
        Uri.parse(url),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['quoteResponse']?['result'] as List? ?? [];
        final stocks = results.map((q) => Stock.fromQuoteResponse(q)).toList();
        _quotesCache[key] = _CacheEntry(stocks);
        return stocks;
      }
    } catch (e) {
      // Return cached data on error if available
      if (cached != null) return cached.data;
    }
    return [];
  }

  Future<List<StockCandle>> getHistoricalData(
    String symbol, {
    String interval = '1d',
    String range = '1mo',
  }) async {
    final cacheKey = '$symbol:$range:$interval';
    final cached = _chartCache[cacheKey];
    if (cached != null && !cached.isExpired(_chartTtl)) {
      return cached.data;
    }

    try {
      final url = _getChartUrl(symbol, interval, range);
      final response = await _client.get(
        Uri.parse(url),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['chart']?['result']?[0];
        if (result != null) {
          final timestamps = result['timestamp'] as List? ?? [];
          final quote = result['indicators']?['quote']?[0];

          if (quote != null) {
            final opens = quote['open'] as List? ?? [];
            final highs = quote['high'] as List? ?? [];
            final lows = quote['low'] as List? ?? [];
            final closes = quote['close'] as List? ?? [];
            final volumes = quote['volume'] as List? ?? [];

            List<StockCandle> candles = [];
            for (int i = 0; i < timestamps.length; i++) {
              if (opens[i] != null && closes[i] != null) {
                candles.add(StockCandle(
                  date: DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000),
                  open: (opens[i] ?? 0).toDouble(),
                  high: (highs[i] ?? 0).toDouble(),
                  low: (lows[i] ?? 0).toDouble(),
                  close: (closes[i] ?? 0).toDouble(),
                  volume: (volumes[i] ?? 0).toInt(),
                ));
              }
            }
            _chartCache[cacheKey] = _CacheEntry(candles);
            return candles;
          }
        }
      }
    } catch (e) {
      if (cached != null) return cached.data;
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> searchStocks(String query) async {
    try {
      final url = _getSearchUrl(query);
      final response = await _client.get(
        Uri.parse(url),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final quotes = data['quotes'] as List? ?? [];
        return quotes
            .where((q) =>
                q['quoteType'] == 'EQUITY' ||
                q['quoteType'] == 'ETF' ||
                q['quoteType'] == 'INDEX' ||
                q['quoteType'] == 'MUTUALFUND' ||
                q['quoteType'] == 'CRYPTOCURRENCY')
            .map((q) => {
                  'symbol': q['symbol'],
                  'name': q['shortname'] ?? q['longname'] ?? q['symbol'],
                  'exchange': q['exchange'],
                  'type': q['quoteType'],
                })
            .toList();
      } else {
        // print('Search API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // print('Error searching stocks: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getMarketSummary() async {
    try {
      String url;
      if (kIsWeb) {
        url = '/api/yahoo/market-summary';
      } else {
        url = 'https://query1.finance.yahoo.com/v1/finance/market/get-summary?region=US';
      }
      final response = await _client.get(
        Uri.parse(url),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      // print('Error fetching market summary: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getTrendingStocks() async {
    try {
      String url;
      if (kIsWeb) {
        url = '/api/yahoo/trending';
      } else {
        url = 'https://query1.finance.yahoo.com/v1/finance/trending/US';
      }
      final response = await _client.get(
        Uri.parse(url),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final quotes = data['finance']?['result']?[0]?['quotes'] as List? ?? [];
        return quotes.map((q) => q as Map<String, dynamic>).toList();
      }
    } catch (e) {
      // print('Error fetching trending stocks: $e');
    }
    return [];
  }

  /// Alias for getHistoricalData - used by analysis service
  Future<List<StockCandle>> getChartData(String symbol, String range, String interval) async {
    return getHistoricalData(symbol, range: range, interval: interval);
  }
}
