import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class NewsService {
  final http.Client _client;

  NewsService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<NewsArticle>> getStockNews(String symbol) async {
    try {
      final url = '${ApiConfig.yahooSearchUrl}?q=$symbol&newsCount=10&quotesCount=0';
      final response = await _client.get(
        Uri.parse(url),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final news = data['news'] as List? ?? [];
        return news.map((n) => NewsArticle.fromJson(n)).toList();
      }
    } catch (e) {
      // print('Error fetching news: $e');
    }
    return [];
  }

  Future<List<NewsArticle>> getMarketNews() async {
    try {
      final url = '${ApiConfig.yahooSearchUrl}?q=stock%20market&newsCount=20&quotesCount=0';
      final response = await _client.get(
        Uri.parse(url),
        headers: ApiConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final news = data['news'] as List? ?? [];
        return news.map((n) => NewsArticle.fromJson(n)).toList();
      }
    } catch (e) {
      // print('Error fetching market news: $e');
    }
    return [];
  }
}

class NewsArticle {
  final String uuid;
  final String title;
  final String? publisher;
  final String? link;
  final DateTime? publishedAt;
  final String? thumbnail;
  final List<String> relatedTickers;

  NewsArticle({
    required this.uuid,
    required this.title,
    this.publisher,
    this.link,
    this.publishedAt,
    this.thumbnail,
    this.relatedTickers = const [],
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    DateTime? publishedAt;
    if (json['providerPublishTime'] != null) {
      publishedAt = DateTime.fromMillisecondsSinceEpoch(
        (json['providerPublishTime'] as int) * 1000,
      );
    }

    return NewsArticle(
      uuid: json['uuid'] ?? '',
      title: json['title'] ?? '',
      publisher: json['publisher'],
      link: json['link'],
      publishedAt: publishedAt,
      thumbnail: json['thumbnail']?['resolutions']?[0]?['url'],
      relatedTickers: (json['relatedTickers'] as List?)
              ?.map((t) => t.toString())
              .toList() ??
          [],
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
