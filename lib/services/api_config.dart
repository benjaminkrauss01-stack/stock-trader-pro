import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // Use local proxy for web builds to avoid CORS issues
  static String get baseUrl {
    if (kIsWeb) {
      // In web, use relative URL to proxy
      return '/api';
    }
    // For native apps, use direct URLs
    return '';
  }

  static String get yahooChartUrl {
    if (kIsWeb) {
      return '/api/yahoo/chart';
    }
    return 'https://query1.finance.yahoo.com/v8/finance/chart';
  }

  static String get yahooQuoteUrl {
    if (kIsWeb) {
      return '/api/yahoo/quote';
    }
    return 'https://query1.finance.yahoo.com/v1/finance/quote';
  }

  static String get yahooSearchUrl {
    if (kIsWeb) {
      return '/api/yahoo/search';
    }
    return 'https://query1.finance.yahoo.com/v1/finance/search';
  }

  static String get coingeckoUrl {
    if (kIsWeb) {
      return '/api/coingecko';
    }
    return 'https://api.coingecko.com/api/v3';
  }

  static Map<String, String> get defaultHeaders {
    return {
      'Accept': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    };
  }
}
