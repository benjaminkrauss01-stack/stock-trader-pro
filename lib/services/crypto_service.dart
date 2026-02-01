import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'api_config.dart';

class CryptoService {
  final http.Client _client;

  CryptoService({http.Client? client}) : _client = client ?? http.Client();

  String _getBaseUrl() {
    if (kIsWeb) {
      return ApiConfig.coingeckoUrl;
    }
    return 'https://api.coingecko.com/api/v3';
  }

  Future<List<Cryptocurrency>> getTopCryptos({int limit = 50}) async {
    try {
      final baseUrl = _getBaseUrl();
      final url = '$baseUrl/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=$limit&page=1&sparkline=true&price_change_percentage=1h,24h,7d';
      final response = await _client.get(
        Uri.parse(url),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((c) => Cryptocurrency.fromJson(c)).toList();
      } else {
        // print('Crypto API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // print('Error fetching crypto data: $e');
    }
    return [];
  }

  Future<Cryptocurrency?> getCryptoDetails(String id) async {
    try {
      final baseUrl = _getBaseUrl();
      final url = '$baseUrl/coins/$id?localization=false&tickers=false&community_data=false&developer_data=false';
      final response = await _client.get(
        Uri.parse(url),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Cryptocurrency.fromDetailJson(data);
      } else {
        // print('Crypto details API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // print('Error fetching crypto details: $e');
    }
    return null;
  }

  Future<List<List<double>>> getCryptoChart(String id, {int days = 7}) async {
    try {
      final baseUrl = _getBaseUrl();
      final url = '$baseUrl/coins/$id/market_chart?vs_currency=usd&days=$days';
      final response = await _client.get(
        Uri.parse(url),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prices = data['prices'] as List;
        return prices.map<List<double>>((p) => [p[0].toDouble(), p[1].toDouble()]).toList();
      } else {
        // print('Crypto chart API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // print('Error fetching crypto chart: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> getGlobalData() async {
    try {
      final baseUrl = _getBaseUrl();
      final url = '$baseUrl/global';
      final response = await _client.get(
        Uri.parse(url),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        // print('Global crypto API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // print('Error fetching global crypto data: $e');
    }
    return {};
  }

  Future<List<TrendingCrypto>> getTrending() async {
    try {
      final baseUrl = _getBaseUrl();
      final url = '$baseUrl/search/trending';
      final response = await _client.get(
        Uri.parse(url),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coins = data['coins'] as List? ?? [];
        return coins.map((c) => TrendingCrypto.fromJson(c['item'])).toList();
      } else {
        // print('Trending crypto API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // print('Error fetching trending crypto: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> searchCrypto(String query) async {
    try {
      final baseUrl = _getBaseUrl();
      final url = '$baseUrl/search?query=$query';
      final response = await _client.get(
        Uri.parse(url),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coins = data['coins'] as List? ?? [];
        return coins.map((c) => {
          'id': c['id'],
          'symbol': c['symbol']?.toString().toUpperCase() ?? '',
          'name': c['name'],
          'thumb': c['thumb'],
          'market_cap_rank': c['market_cap_rank'],
        }).toList();
      } else {
        // print('Search crypto API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // print('Error searching crypto: $e');
    }
    return [];
  }
}

class Cryptocurrency {
  final String id;
  final String symbol;
  final String name;
  final String? image;
  final double price;
  final double marketCap;
  final int marketCapRank;
  final double volume24h;
  final double change1h;
  final double change24h;
  final double change7d;
  final double high24h;
  final double low24h;
  final double? ath;
  final double? athChangePercent;
  final List<double> sparkline;
  final double circulatingSupply;
  final double? totalSupply;

  Cryptocurrency({
    required this.id,
    required this.symbol,
    required this.name,
    this.image,
    required this.price,
    required this.marketCap,
    required this.marketCapRank,
    required this.volume24h,
    required this.change1h,
    required this.change24h,
    required this.change7d,
    required this.high24h,
    required this.low24h,
    this.ath,
    this.athChangePercent,
    this.sparkline = const [],
    required this.circulatingSupply,
    this.totalSupply,
  });

  bool get isPositive24h => change24h >= 0;

  factory Cryptocurrency.fromJson(Map<String, dynamic> json) {
    return Cryptocurrency(
      id: json['id'] ?? '',
      symbol: (json['symbol'] ?? '').toString().toUpperCase(),
      name: json['name'] ?? '',
      image: json['image'],
      price: (json['current_price'] ?? 0).toDouble(),
      marketCap: (json['market_cap'] ?? 0).toDouble(),
      marketCapRank: json['market_cap_rank'] ?? 0,
      volume24h: (json['total_volume'] ?? 0).toDouble(),
      change1h: (json['price_change_percentage_1h_in_currency'] ?? 0).toDouble(),
      change24h: (json['price_change_percentage_24h'] ?? 0).toDouble(),
      change7d: (json['price_change_percentage_7d_in_currency'] ?? 0).toDouble(),
      high24h: (json['high_24h'] ?? 0).toDouble(),
      low24h: (json['low_24h'] ?? 0).toDouble(),
      ath: json['ath']?.toDouble(),
      athChangePercent: json['ath_change_percentage']?.toDouble(),
      sparkline: (json['sparkline_in_7d']?['price'] as List?)
              ?.map<double>((p) => (p as num).toDouble())
              .toList() ??
          [],
      circulatingSupply: (json['circulating_supply'] ?? 0).toDouble(),
      totalSupply: json['total_supply']?.toDouble(),
    );
  }

  factory Cryptocurrency.fromDetailJson(Map<String, dynamic> json) {
    final marketData = json['market_data'] ?? {};
    return Cryptocurrency(
      id: json['id'] ?? '',
      symbol: (json['symbol'] ?? '').toString().toUpperCase(),
      name: json['name'] ?? '',
      image: json['image']?['large'],
      price: (marketData['current_price']?['usd'] ?? 0).toDouble(),
      marketCap: (marketData['market_cap']?['usd'] ?? 0).toDouble(),
      marketCapRank: json['market_cap_rank'] ?? 0,
      volume24h: (marketData['total_volume']?['usd'] ?? 0).toDouble(),
      change1h: (marketData['price_change_percentage_1h_in_currency']?['usd'] ?? 0).toDouble(),
      change24h: (marketData['price_change_percentage_24h'] ?? 0).toDouble(),
      change7d: (marketData['price_change_percentage_7d'] ?? 0).toDouble(),
      high24h: (marketData['high_24h']?['usd'] ?? 0).toDouble(),
      low24h: (marketData['low_24h']?['usd'] ?? 0).toDouble(),
      ath: marketData['ath']?['usd']?.toDouble(),
      athChangePercent: marketData['ath_change_percentage']?['usd']?.toDouble(),
      circulatingSupply: (marketData['circulating_supply'] ?? 0).toDouble(),
      totalSupply: marketData['total_supply']?.toDouble(),
    );
  }
}

class TrendingCrypto {
  final String id;
  final String symbol;
  final String name;
  final String? thumb;
  final int marketCapRank;
  final double? priceBtc;

  TrendingCrypto({
    required this.id,
    required this.symbol,
    required this.name,
    this.thumb,
    required this.marketCapRank,
    this.priceBtc,
  });

  factory TrendingCrypto.fromJson(Map<String, dynamic> json) {
    return TrendingCrypto(
      id: json['id'] ?? '',
      symbol: (json['symbol'] ?? '').toString().toUpperCase(),
      name: json['name'] ?? '',
      thumb: json['thumb'],
      marketCapRank: json['market_cap_rank'] ?? 0,
      priceBtc: json['price_btc']?.toDouble(),
    );
  }
}
