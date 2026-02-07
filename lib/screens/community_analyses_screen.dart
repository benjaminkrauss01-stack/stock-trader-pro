import 'package:flutter/material.dart';
import '../models/analysis.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/app_bar_actions.dart';
import '../providers/analysis_provider.dart';
import 'package:provider/provider.dart';
import 'dashboard_screen.dart';

class CommunityAnalysesScreen extends StatefulWidget {
  const CommunityAnalysesScreen({super.key});

  @override
  State<CommunityAnalysesScreen> createState() => _CommunityAnalysesScreenState();
}

enum SortMode { newest, largestMove, highestConfidence }
enum FilterDirection { all, bullish, bearish, neutral }
enum FilterAssetType { all, stock, crypto, etf }

class _CommunityAnalysesScreenState extends State<CommunityAnalysesScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  List<Map<String, dynamic>> _allAnalyses = [];
  bool _isLoading = true;
  String? _error;

  SortMode _sortMode = SortMode.largestMove;
  FilterDirection _filterDirection = FilterDirection.all;
  FilterAssetType _filterAssetType = FilterAssetType.all;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _loadAnalyses();
  }

  Future<void> _loadAnalyses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _supabaseService.getCommunityAnalyses(limit: 30);
      setState(() {
        _allAnalyses = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Fehler beim Laden: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredAndSorted {
    var filtered = List<Map<String, dynamic>>.from(_allAnalyses);

    // Filter by direction
    if (_filterDirection != FilterDirection.all) {
      filtered = filtered.where((a) {
        final dir = a['direction'] as String? ?? '';
        switch (_filterDirection) {
          case FilterDirection.bullish:
            return dir == 'bullish';
          case FilterDirection.bearish:
            return dir == 'bearish';
          case FilterDirection.neutral:
            return dir == 'neutral';
          default:
            return true;
        }
      }).toList();
    }

    // Filter by asset type
    if (_filterAssetType != FilterAssetType.all) {
      filtered = filtered.where((a) {
        final type = a['asset_type'] as String? ?? '';
        switch (_filterAssetType) {
          case FilterAssetType.stock:
            return type == 'Stock';
          case FilterAssetType.crypto:
            return type == 'Crypto';
          case FilterAssetType.etf:
            return type == 'ETF';
          default:
            return true;
        }
      }).toList();
    }

    // Sort
    switch (_sortMode) {
      case SortMode.newest:
        filtered.sort((a, b) {
          final dateA = DateTime.tryParse(a['analyzed_at'] ?? '') ?? DateTime(2000);
          final dateB = DateTime.tryParse(b['analyzed_at'] ?? '') ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });
        break;
      case SortMode.largestMove:
        filtered.sort((a, b) {
          final moveA = ((a['expected_move_percent'] as num?) ?? 0).toDouble().abs();
          final moveB = ((b['expected_move_percent'] as num?) ?? 0).toDouble().abs();
          return moveB.compareTo(moveA);
        });
        break;
      case SortMode.highestConfidence:
        filtered.sort((a, b) {
          final confA = ((a['confidence'] as num?) ?? 0).toDouble();
          final confB = ((b['confidence'] as num?) ?? 0).toDouble();
          return confB.compareTo(confA);
        });
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadAnalyses,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: AppColors.background,
              title: const Row(
                children: [
                  Icon(Icons.public, color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Text(
                    'Community Analysen',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actions: buildCommonAppBarActions(context),
            ),
            // Sort & Filter Bar
            SliverToBoxAdapter(
              child: _buildSortFilterBar(),
            ),
            // Content
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.loss),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadAnalyses,
                        child: const Text('Erneut versuchen'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_filteredAndSorted.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics_outlined, size: 64, color: AppColors.textHint),
                      SizedBox(height: 16),
                      Text(
                        'Keine Analysen gefunden',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Ändere die Filter oder versuche es später erneut',
                        style: TextStyle(color: AppColors.textHint, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == _filteredAndSorted.length) {
                      return const SizedBox(height: 100);
                    }
                    return _buildAnalysisCard(_filteredAndSorted[index], index);
                  },
                  childCount: _filteredAndSorted.length + 1,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Result count
          Text(
            '${_filteredAndSorted.length} Analysen',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          // Sortierung
          Row(
            children: [
              const Icon(Icons.sort, size: 14, color: AppColors.textHint),
              const SizedBox(width: 6),
              const Text(
                'Sortierung',
                style: TextStyle(color: AppColors.textHint, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSortChip('Größte Bewegung', SortMode.largestMove),
                const SizedBox(width: 6),
                _buildSortChip('Neueste', SortMode.newest),
                const SizedBox(width: 6),
                _buildSortChip('Höchste Konfidenz', SortMode.highestConfidence),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Richtung
          Row(
            children: [
              const Icon(Icons.trending_flat, size: 14, color: AppColors.textHint),
              const SizedBox(width: 6),
              const Text(
                'Richtung',
                style: TextStyle(color: AppColors.textHint, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDirectionChip('Alle', FilterDirection.all),
                const SizedBox(width: 6),
                _buildDirectionChip('Bullish ↑', FilterDirection.bullish),
                const SizedBox(width: 6),
                _buildDirectionChip('Bearish ↓', FilterDirection.bearish),
                const SizedBox(width: 6),
                _buildDirectionChip('Neutral →', FilterDirection.neutral),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Asset-Typ
          Row(
            children: [
              const Icon(Icons.category_outlined, size: 14, color: AppColors.textHint),
              const SizedBox(width: 6),
              const Text(
                'Asset-Typ',
                style: TextStyle(color: AppColors.textHint, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildAssetChip('Alle', FilterAssetType.all),
                const SizedBox(width: 6),
                _buildAssetChip('Aktien', FilterAssetType.stock),
                const SizedBox(width: 6),
                _buildAssetChip('Crypto', FilterAssetType.crypto),
                const SizedBox(width: 6),
                _buildAssetChip('ETF', FilterAssetType.etf),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, SortMode mode) {
    final isActive = _sortMode == mode;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isActive,
      onSelected: (_) {
        setState(() {
          _sortMode = mode;
          _expandedIndex = null;
        });
      },
      selectedColor: Colors.deepPurple,
      backgroundColor: AppColors.card,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isActive ? Colors.deepPurple : AppColors.border,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildDirectionChip(String label, FilterDirection direction) {
    final isActive = _filterDirection == direction;
    Color chipColor;
    switch (direction) {
      case FilterDirection.bullish:
        chipColor = AppColors.profit;
        break;
      case FilterDirection.bearish:
        chipColor = AppColors.loss;
        break;
      case FilterDirection.neutral:
        chipColor = AppColors.neutral;
        break;
      default:
        chipColor = AppColors.primary;
    }

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : AppColors.textSecondary,
          fontSize: 11,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isActive,
      onSelected: (_) {
        setState(() {
          _filterDirection = direction;
          _expandedIndex = null;
        });
      },
      selectedColor: chipColor,
      backgroundColor: AppColors.card,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isActive ? chipColor : AppColors.border,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildAssetChip(String label, FilterAssetType type) {
    final isActive = _filterAssetType == type;
    Color chipColor;
    switch (type) {
      case FilterAssetType.crypto:
        chipColor = Colors.orange;
        break;
      case FilterAssetType.etf:
        chipColor = Colors.teal;
        break;
      case FilterAssetType.stock:
        chipColor = AppColors.primary;
        break;
      default:
        chipColor = AppColors.primary;
    }

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : AppColors.textSecondary,
          fontSize: 11,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isActive,
      onSelected: (_) {
        setState(() {
          _filterAssetType = type;
          _expandedIndex = null;
        });
      },
      selectedColor: chipColor,
      backgroundColor: AppColors.card,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isActive ? chipColor : AppColors.border,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildAnalysisCard(Map<String, dynamic> data, int index) {
    final symbol = data['symbol'] as String? ?? '';
    final assetType = data['asset_type'] as String? ?? 'Stock';
    final directionStr = data['direction'] as String? ?? 'neutral';
    final confidence = ((data['confidence'] as num?) ?? 0).toDouble();
    final expectedMove = ((data['expected_move_percent'] as num?) ?? 0).toDouble();
    final recommendation = data['recommendation'] as String? ?? '';
    final summary = data['summary'] as String? ?? '';
    final analyzedAt = DateTime.tryParse(data['analyzed_at'] ?? '') ?? DateTime.now();
    final priceAtAnalysis = (data['price_at_analysis'] as num?)?.toDouble();
    final wasCorrect = data['was_correct'] as bool?;
    final keyTriggers = _parseJsonList(data['key_triggers']);
    final riskFactors = _parseJsonList(data['risk_factors']);

    final direction = AnalysisDirection.values.firstWhere(
      (e) => e.name == directionStr,
      orElse: () => AnalysisDirection.neutral,
    );

    Color directionColor;
    String directionEmoji;
    switch (direction) {
      case AnalysisDirection.bullish:
        directionColor = AppColors.profit;
        directionEmoji = '↑';
        break;
      case AnalysisDirection.bearish:
        directionColor = AppColors.loss;
        directionEmoji = '↓';
        break;
      case AnalysisDirection.neutral:
        directionColor = AppColors.neutral;
        directionEmoji = '→';
        break;
    }

    Color assetColor;
    IconData assetIcon;
    String assetLabel;
    switch (assetType) {
      case 'Crypto':
        assetColor = Colors.orange;
        assetIcon = Icons.currency_bitcoin;
        assetLabel = 'Crypto';
        break;
      case 'ETF':
        assetColor = Colors.teal;
        assetIcon = Icons.account_balance;
        assetLabel = 'ETF';
        break;
      default:
        assetColor = AppColors.primary;
        assetIcon = Icons.show_chart;
        assetLabel = 'Aktie';
    }

    final isExpanded = _expandedIndex == index;
    final targetPrice = priceAtAnalysis != null
        ? priceAtAnalysis * (1 + expectedMove / 100)
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded ? directionColor.withValues(alpha: 0.5) : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          // Header (always visible)
          InkWell(
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? null : index;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Direction indicator
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: directionColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        directionEmoji,
                        style: TextStyle(fontSize: 22, color: directionColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Symbol & Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              symbol,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: assetColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(assetIcon, color: assetColor, size: 10),
                                  const SizedBox(width: 3),
                                  Text(
                                    assetLabel,
                                    style: TextStyle(
                                      color: assetColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (wasCorrect != null) ...[
                              const SizedBox(width: 6),
                              Icon(
                                wasCorrect ? Icons.check_circle : Icons.cancel,
                                color: wasCorrect ? AppColors.profit : AppColors.loss,
                                size: 14,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              '${expectedMove >= 0 ? "+" : ""}${expectedMove.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: directionColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Konfidenz: ${confidence.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 11, color: AppColors.textHint),
                            const SizedBox(width: 3),
                            Text(
                              _formatTimestamp(analyzedAt),
                              style: const TextStyle(
                                color: AppColors.textHint,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Expand icon
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (isExpanded) ...[
            const Divider(color: AppColors.cardLight, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price info
                  if (priceAtAnalysis != null) ...[
                    _buildInfoRow('Kurs bei Analyse', Formatters.formatCurrency(priceAtAnalysis)),
                    if (targetPrice != null)
                      _buildInfoRow('Zielwert', Formatters.formatCurrency(targetPrice)),
                  ],
                  _buildInfoRow('Empfehlung', recommendation),
                  const SizedBox(height: 8),
                  // Summary
                  const Text(
                    'Zusammenfassung',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  // Key Triggers
                  if (keyTriggers.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Auslöser',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...keyTriggers.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ', style: TextStyle(color: directionColor, fontSize: 12)),
                          Expanded(
                            child: Text(
                              t,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                  // Risk Factors
                  if (riskFactors.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Risiken',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...riskFactors.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: Colors.amber, fontSize: 12)),
                          Expanded(
                            child: Text(
                              r,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                  const SizedBox(height: 12),
                  // Action button - start own analysis
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _startAnalysis(context, symbol, assetType),
                      icon: const Icon(Icons.psychology, size: 18),
                      label: const Text('Eigene Analyse starten'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _parseJsonList(dynamic data) {
    if (data == null) return [];
    if (data is List) return data.map((e) => e.toString()).toList();
    return [];
  }

  String _formatTimestamp(DateTime date) {
    final d = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    final t = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '$d $t';
  }

  void _startAnalysis(BuildContext context, String symbol, String assetType) {
    context.read<AnalysisProvider>().setSymbolForAnalysis(symbol, assetType);
    final state = context.findAncestorStateOfType<DashboardScreenState>();
    state?.setTabIndex(2);
  }
}
