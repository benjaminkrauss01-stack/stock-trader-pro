import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/news_service_extended.dart';
import '../utils/constants.dart';

class NewsHubScreen extends StatefulWidget {
  const NewsHubScreen({super.key});

  @override
  State<NewsHubScreen> createState() => _NewsHubScreenState();
}

class _NewsHubScreenState extends State<NewsHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ExtendedNewsService _newsService = ExtendedNewsService();

  List<NewsArticle> _marketNews = [];
  List<NewsArticle> _cryptoNews = [];
  List<NewsArticle> _politicalNews = [];
  List<EconomicEvent> _economicEvents = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Technology',
    'Healthcare',
    'Finance',
    'Energy',
    'Consumer',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllNews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllNews() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      _newsService.getMarketNews(),
      _newsService.getCryptoNews(),
      _newsService.getPoliticalEconomicNews(),
      _newsService.getEconomicEvents(),
    ]);

    setState(() {
      _marketNews = results[0] as List<NewsArticle>;
      _cryptoNews = results[1] as List<NewsArticle>;
      _politicalNews = results[2] as List<NewsArticle>;
      _economicEvents = results[3] as List<EconomicEvent>;
      _isLoading = false;
    });
  }

  Future<void> _loadCategoryNews(String category) async {
    if (category == 'All') {
      await _loadAllNews();
      return;
    }

    setState(() => _isLoading = true);
    final news = await _newsService.getSectorNews(category);
    setState(() {
      _marketNews = news;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'News Hub',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: _loadAllNews,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Markets'),
            Tab(text: 'Crypto'),
            Tab(text: 'Economy'),
            Tab(text: 'Calendar'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMarketNewsTab(),
                _buildNewsListTab(_cryptoNews, 'Crypto'),
                _buildNewsListTab(_politicalNews, 'Economy & Politics'),
                _buildEconomicCalendar(),
              ],
            ),
    );
  }

  Widget _buildMarketNewsTab() {
    return Column(
      children: [
        // Category Filter
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isSelected = category == _selectedCategory;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedCategory = category);
                    _loadCategoryNews(category);
                  },
                  backgroundColor: AppColors.card,
                  selectedColor: AppColors.primary.withValues(alpha: 0.3),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  checkmarkColor: AppColors.primary,
                ),
              );
            },
          ),
        ),
        Expanded(
          child: _buildNewsList(_marketNews),
        ),
      ],
    );
  }

  Widget _buildNewsListTab(List<NewsArticle> news, String title) {
    return RefreshIndicator(
      onRefresh: _loadAllNews,
      color: AppColors.primary,
      child: _buildNewsList(news),
    );
  }

  Widget _buildNewsList(List<NewsArticle> news) {
    if (news.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: AppColors.textHint),
            SizedBox(height: 16),
            Text(
              'No news available',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: news.length,
      itemBuilder: (context, index) {
        final article = news[index];
        return _NewsCard(article: article);
      },
    );
  }

  Widget _buildEconomicCalendar() {
    final highImpact = _economicEvents.where((e) => e.impact == EventImpact.high).toList();
    final mediumImpact = _economicEvents.where((e) => e.impact == EventImpact.medium).toList();
    final lowImpact = _economicEvents.where((e) => e.impact == EventImpact.low).toList();

    return RefreshIndicator(
      onRefresh: _loadAllNews,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Text(
                  'High Impact Events',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...highImpact.map((e) => _EventCard(event: e, impactColor: Colors.red)),
          if (mediumImpact.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 24, bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Medium Impact Events',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ...mediumImpact.map((e) => _EventCard(event: e, impactColor: Colors.orange)),
          ],
          if (lowImpact.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 24, bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.circle, color: Colors.grey, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Low Impact Events',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ...lowImpact.map((e) => _EventCard(event: e, impactColor: Colors.grey)),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsArticle article;

  const _NewsCard({required this.article});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openArticle(article.link),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (article.source != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        article.source!,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                  Text(
                    article.timeAgo,
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      article.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (article.thumbnail != null) ...[
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        article.thumbnail!,
                        width: 80,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ],
              ),
              if (article.summary != null) ...[
                const SizedBox(height: 8),
                Text(
                  article.summary!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (article.relatedSymbols.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: article.relatedSymbols.take(5).map((symbol) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.cardLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        symbol,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openArticle(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _EventCard extends StatelessWidget {
  final EconomicEvent event;
  final Color impactColor;

  const _EventCard({required this.event, required this.impactColor});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: impactColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: impactColor, width: 1),
                  ),
                  child: Text(
                    event.country,
                    style: TextStyle(
                      color: impactColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cardLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    event.category,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  event.formattedDate,
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              event.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildValueColumn('Previous', event.previous),
                _buildValueColumn('Forecast', event.forecast),
                _buildValueColumn('Actual', event.actual ?? '-'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueColumn(String label, String? value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textHint,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value ?? '-',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
