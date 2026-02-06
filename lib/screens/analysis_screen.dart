import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/analysis.dart';
import '../providers/analysis_provider.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/analysis_chart_widget.dart';
import '../widgets/app_bar_actions.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _expandedSymbol; // Welches Symbol ist gerade ausgeklappt

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnalysisProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check for pending symbol from other screens - auto-start analysis
    final provider = context.watch<AnalysisProvider>();
    if (provider.pendingSymbol != null) {
      final symbol = provider.pendingSymbol!;
      final assetType = provider.pendingAssetType ?? 'Stock';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.clearPendingSymbol();
        provider.analyzeAsset(symbol: symbol, assetType: assetType);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Row(
          children: [
            Icon(Icons.psychology, color: AppColors.primary),
            SizedBox(width: 8),
            Text('KI-Analyse', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        actions: buildCommonAppBarActions(context),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Analyse'),
            Tab(text: 'Alerts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAnalyzeTab(),
          _buildAlertsTab(),
        ],
      ),
    );
  }

  Widget _buildAnalyzeTab() {
    return Consumer<AnalysisProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Limit Warning Banner
              if (provider.remainingAnalyses >= 0 && provider.remainingAnalyses < 2)
                _buildLimitWarningBanner(provider),
              if (provider.isAnalyzing) ...[
                const SizedBox(height: 24),
                _buildLoadingCard(),
              ],
              if (provider.error != null) ...[
                const SizedBox(height: 24),
                _buildErrorCard(provider),
              ],
              if (provider.currentAnalysis != null) ...[
                const SizedBox(height: 24),
                // Chart mit historischen Vorhersagen
                if (provider.currentChartData.isNotEmpty)
                  Card(
                    color: AppColors.card,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: AnalysisChartWidget(
                        candles: provider.currentChartData,
                        currentAnalysis: provider.currentAnalysis,
                        historicalAnalyses: provider.getHistoricalAnalysesForSymbol(
                          provider.currentAnalysis!.symbol,
                        ).where((a) => a.analyzedAt != provider.currentAnalysis!.analyzedAt).toList(),
                        selectedRange: provider.currentChartRange,
                        onRangeChanged: (range) {
                          provider.loadChartData(provider.currentAnalysis!.symbol, range);
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                _buildAnalysisResult(provider.currentAnalysis!),
              ],
              const SizedBox(height: 24),
              _buildStatisticsCard(provider),
              // Analyse-Historie gruppiert nach Symbol
              const SizedBox(height: 24),
              _buildAnalysisHistorySection(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 20),
            const Text(
              'KI analysiert...',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sammle Preisdaten, News und erkenne Muster...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(AnalysisProvider provider) {
    return Card(
      color: AppColors.loss.withValues(alpha: 0.2),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.loss),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                provider.error!,
                style: const TextStyle(color: AppColors.loss),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.loss),
              onPressed: () => provider.clearError(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisResult(MarketAnalysis analysis) {
    final directionColor = analysis.direction == AnalysisDirection.bullish
        ? AppColors.profit
        : analysis.direction == AnalysisDirection.bearish
            ? AppColors.loss
            : AppColors.neutral;

    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: directionColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    analysis.directionEmoji,
                    style: TextStyle(fontSize: 24, color: directionColor),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        analysis.symbol,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: directionColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              analysis.directionText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${analysis.confidence.toStringAsFixed(0)}% Konfidenz',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                analysis.summary,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Key Metrics
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Erwartete Bewegung',
                    '${analysis.expectedMovePercent >= 0 ? '+' : ''}${analysis.expectedMovePercent.toStringAsFixed(1)}%',
                    directionColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Wahrscheinlichkeit',
                    '${analysis.probabilitySignificantMove.toStringAsFixed(0)}%',
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Zeitraum',
                    '${analysis.timeframeDays} Tage',
                    AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Key Triggers
            if (analysis.keyTriggers.isNotEmpty) ...[
              const Text(
                'Erkannte Trigger',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: analysis.keyTriggers.map((trigger) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      trigger,
                      style: const TextStyle(color: AppColors.primary, fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Risk Factors
            if (analysis.riskFactors.isNotEmpty) ...[
              const Text(
                'Risikofaktoren',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...analysis.riskFactors.map((risk) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        risk,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 20),
            ],

            // Recommendation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    directionColor.withValues(alpha: 0.2),
                    directionColor.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: directionColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: directionColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      analysis.recommendation,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Alert Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final provider = context.read<AnalysisProvider>();
                  if (analysis.alertEnabled) {
                    provider.disableAlert(analysis.symbol);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Alert deaktiviert')),
                    );
                  } else {
                    provider.enableAlert(analysis);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Alert aktiviert! Du wirst benachrichtigt wenn Trigger erkannt werden.')),
                    );
                  }
                },
                icon: Icon(analysis.alertEnabled ? Icons.notifications_off : Icons.notifications_active),
                label: Text(analysis.alertEnabled ? 'Alert deaktivieren' : 'Alert aktivieren'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: analysis.alertEnabled ? AppColors.cardLight : Colors.orange,
                  foregroundColor: analysis.alertEnabled ? AppColors.textSecondary : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.textHint, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard(AnalysisProvider provider) {
    final stats = provider.statistics;
    if (stats.isEmpty) return const SizedBox.shrink();

    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistiken',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Analysen', '${stats['totalAnalyses'] ?? 0}', Icons.analytics),
                _buildStatItem('Aktive Alerts', '${stats['activeAlerts'] ?? 0}', Icons.notifications),
                _buildStatItem('Bullish', '${stats['bullishCount'] ?? 0}', Icons.trending_up, AppColors.profit),
                _buildStatItem('Bearish', '${stats['bearishCount'] ?? 0}', Icons.trending_down, AppColors.loss),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, [Color? color]) {
    return Column(
      children: [
        Icon(icon, color: color ?? AppColors.primary, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color ?? AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.textHint, fontSize: 10),
        ),
      ],
    );
  }

  /// Gruppiert Analysen nach Symbol und zeigt sie als einklappbare Karten an
  Widget _buildAnalysisHistorySection(AnalysisProvider provider) {
    // Gruppiere Analysen nach Symbol
    final Map<String, List<MarketAnalysis>> groupedAnalyses = {};
    for (final analysis in provider.savedAnalyses) {
      final symbol = analysis.symbol.toUpperCase();
      groupedAnalyses.putIfAbsent(symbol, () => []);
      groupedAnalyses[symbol]!.add(analysis);
    }

    // Sortiere jede Gruppe nach Datum (neueste zuerst)
    for (final symbol in groupedAnalyses.keys) {
      groupedAnalyses[symbol]!.sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
    }

    // Sortiere Symbole nach Anzahl der Analysen (meiste zuerst)
    final sortedSymbols = groupedAnalyses.keys.toList()
      ..sort((a, b) => groupedAnalyses[b]!.length.compareTo(groupedAnalyses[a]!.length));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(Icons.history, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Analyse-Historie',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // Trefferquote-Card (nur anzeigen wenn min. 3 evaluierte Analysen)
        if (provider.analysisAccuracy['total'] >= 3)
          _buildAccuracyCard(provider),
        if (sortedSymbols.isEmpty)
          Card(
            color: AppColors.card,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.analytics_outlined, size: 48, color: AppColors.textHint),
                  const SizedBox(height: 12),
                  const Text(
                    'Noch keine Analysen vorhanden',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Klicke auf das KI-Symbol bei einem Asset um eine Analyse zu starten',
                    style: TextStyle(
                      color: AppColors.textHint,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...sortedSymbols.map((symbol) {
            final analyses = groupedAnalyses[symbol]!;
            return _buildSymbolHistoryCard(symbol, analyses, provider);
          }),
      ],
    );
  }

  Widget _buildSymbolHistoryCard(
    String symbol,
    List<MarketAnalysis> analyses,
    AnalysisProvider provider,
  ) {
    final isExpanded = _expandedSymbol == symbol;
    final latestAnalysis = analyses.first;
    final directionColor = latestAnalysis.direction == AnalysisDirection.bullish
        ? AppColors.profit
        : latestAnalysis.direction == AnalysisDirection.bearish
            ? AppColors.loss
            : AppColors.neutral;

    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // Header (immer sichtbar)
          InkWell(
            onTap: () async {
              if (isExpanded) {
                setState(() => _expandedSymbol = null);
              } else {
                // Lade Chart-Daten für dieses Symbol
                await provider.loadChartData(symbol, '3M');
                if (mounted) {
                  setState(() => _expandedSymbol = symbol);
                }
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Symbol Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: directionColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        latestAnalysis.directionEmoji,
                        style: TextStyle(fontSize: 24, color: directionColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Symbol Info
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
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${analyses.length} ${analyses.length == 1 ? 'Analyse' : 'Analysen'}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Letzte: ${_formatDate(latestAnalysis.analyzedAt)} | ${latestAnalysis.expectedMovePercent >= 0 ? "+" : ""}${latestAnalysis.expectedMovePercent.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Refresh Button für neue Analyse mit Label
                  TextButton.icon(
                    onPressed: provider.isAnalyzing
                        ? null
                        : () {
                            provider.analyzeAsset(
                              symbol: symbol,
                              assetType: latestAnalysis.assetType,
                            );
                          },
                    icon: provider.isAnalyzing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(Icons.psychology, color: AppColors.primary, size: 18),
                    label: Text(
                      provider.isAnalyzing ? 'Läuft...' : 'Neu',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Expand Icon
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
          // Expandable Content
          if (isExpanded) ...[
            const Divider(color: AppColors.cardLight, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Chart
                  if (provider.currentChartData.isNotEmpty)
                    SizedBox(
                      height: 350,
                      child: AnalysisChartWidget(
                        candles: provider.currentChartData,
                        currentAnalysis: null,
                        historicalAnalyses: analyses,
                        selectedRange: provider.currentChartRange,
                        onRangeChanged: (range) {
                          provider.loadChartData(symbol, range);
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Tabelle der Analysen
                  _buildAnalysisTable(analyses, provider),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccuracyCard(AnalysisProvider provider) {
    final accuracy = provider.analysisAccuracy;
    final correct = accuracy['correct'] as int;
    final total = accuracy['total'] as int;
    final percent = accuracy['percent'] as double;

    // Aufschlüsselung nach Richtung
    final evaluated = provider.savedAnalyses.where((a) => a.wasCorrect != null).toList();
    final bullishCorrect = evaluated.where((a) => a.direction == AnalysisDirection.bullish && a.wasCorrect == true).length;
    final bullishTotal = evaluated.where((a) => a.direction == AnalysisDirection.bullish).length;
    final bearishCorrect = evaluated.where((a) => a.direction == AnalysisDirection.bearish && a.wasCorrect == true).length;
    final bearishTotal = evaluated.where((a) => a.direction == AnalysisDirection.bearish).length;

    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: percent >= 60 ? AppColors.profit : percent >= 40 ? Colors.orange : AppColors.loss,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'KI-Trefferquote',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: percent >= 60 ? AppColors.profit : percent >= 40 ? Colors.orange : AppColors.loss,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent / 100,
                backgroundColor: AppColors.cardLight,
                valueColor: AlwaysStoppedAnimation(
                  percent >= 60 ? AppColors.profit : percent >= 40 ? Colors.orange : AppColors.loss,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$correct von $total Analysen korrekt',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                Row(
                  children: [
                    if (bullishTotal > 0)
                      Text(
                        'Bull $bullishCorrect/$bullishTotal',
                        style: const TextStyle(color: AppColors.profit, fontSize: 11),
                      ),
                    if (bullishTotal > 0 && bearishTotal > 0)
                      const Text('  ', style: TextStyle(fontSize: 11)),
                    if (bearishTotal > 0)
                      Text(
                        'Bear $bearishCorrect/$bearishTotal',
                        style: const TextStyle(color: AppColors.loss, fontSize: 11),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisTable(List<MarketAnalysis> analyses, AnalysisProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Datum', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Richtung', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Bewegung', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Zielwert', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Wahrsch.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Status', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
                SizedBox(width: 40, child: Text('KI', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              ],
            ),
          ),
          // Rows
          ...analyses.asMap().entries.map((entry) {
            final index = entry.key;
            final analysis = entry.value;
            return _buildAnalysisTableRow(analysis, index.isEven, provider);
          }),
        ],
      ),
    );
  }

  Widget _buildAnalysisTableRow(MarketAnalysis analysis, bool isEven, AnalysisProvider provider) {
    final directionColor = analysis.direction == AnalysisDirection.bullish
        ? AppColors.profit
        : analysis.direction == AnalysisDirection.bearish
            ? AppColors.loss
            : AppColors.neutral;

    // Status basierend auf Evaluierung
    String statusText;
    Color statusColor;

    if (!analysis.isExpired) {
      statusText = 'Läuft';
      statusColor = Colors.orange;
    } else if (analysis.isEvaluated) {
      if (analysis.wasCorrect == true) {
        statusText = analysis.actualMovePercent != null
            ? '${analysis.actualMovePercent! >= 0 ? "+" : ""}${analysis.actualMovePercent!.toStringAsFixed(1)}%'
            : 'Richtig';
        statusColor = AppColors.profit;
      } else {
        statusText = analysis.actualMovePercent != null
            ? '${analysis.actualMovePercent! >= 0 ? "+" : ""}${analysis.actualMovePercent!.toStringAsFixed(1)}%'
            : 'Falsch';
        statusColor = AppColors.loss;
      }
    } else if (analysis.priceAtAnalysis == null) {
      statusText = '–';
      statusColor = AppColors.textSecondary;
    } else {
      statusText = 'Auswertung...';
      statusColor = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isEven ? AppColors.cardLight.withValues(alpha: 0.5) : Colors.transparent,
      ),
      child: Row(
        children: [
          // Datum
          Expanded(
            flex: 2,
            child: Text(
              '${analysis.analyzedAt.day}.${analysis.analyzedAt.month}.${analysis.analyzedAt.year.toString().substring(2)}',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            ),
          ),
          // Richtung
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(
                  analysis.direction == AnalysisDirection.bullish
                      ? Icons.trending_up
                      : analysis.direction == AnalysisDirection.bearish
                          ? Icons.trending_down
                          : Icons.trending_flat,
                  color: directionColor,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  analysis.direction == AnalysisDirection.bullish
                      ? 'Bull'
                      : analysis.direction == AnalysisDirection.bearish
                          ? 'Bear'
                          : 'Neutral',
                  style: TextStyle(color: directionColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Erwartete Bewegung
          Expanded(
            flex: 2,
            child: Text(
              '${analysis.expectedMovePercent >= 0 ? "+" : ""}${analysis.expectedMovePercent.toStringAsFixed(1)}%',
              style: TextStyle(
                color: directionColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Zielwert
          Expanded(
            flex: 2,
            child: analysis.targetPrice != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Formatters.formatCurrency(analysis.targetPrice!),
                        style: TextStyle(
                          color: directionColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (analysis.priceAtAnalysis != null)
                        Text(
                          'von ${Formatters.formatCurrency(analysis.priceAtAnalysis!)}',
                          style: const TextStyle(color: AppColors.textHint, fontSize: 9),
                        ),
                    ],
                  )
                : const Text(
                    '-',
                    style: TextStyle(color: AppColors.textHint, fontSize: 12),
                  ),
          ),
          // Wahrscheinlichkeit
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getProbabilityColorForTable(analysis.probabilitySignificantMove).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${analysis.probabilitySignificantMove.toInt()}%',
                style: TextStyle(
                  color: _getProbabilityColorForTable(analysis.probabilitySignificantMove),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Status
          Expanded(
            flex: 2,
            child: Row(
              children: [
                if (analysis.isEvaluated)
                  Icon(
                    analysis.wasCorrect == true ? Icons.check_circle : Icons.cancel,
                    color: statusColor,
                    size: 13,
                  ),
                if (analysis.isEvaluated) const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // KI Analyse Button
          SizedBox(
            width: 40,
            child: IconButton(
              onPressed: provider.isAnalyzing
                  ? null
                  : () {
                      provider.analyzeAsset(
                        symbol: analysis.symbol,
                        assetType: analysis.assetType,
                      );
                    },
              icon: provider.isAnalyzing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(Icons.psychology, size: 18),
              color: AppColors.primary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Neue KI-Analyse starten',
            ),
          ),
        ],
      ),
    );
  }

  Color _getProbabilityColorForTable(double probability) {
    if (probability >= 70) {
      return const Color(0xFF00E676);
    } else if (probability >= 50) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  Widget _buildAlertsTab() {
    return Consumer<AnalysisProvider>(
      builder: (context, provider, _) {
        if (provider.activeAlerts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_off, size: 64, color: AppColors.textHint),
                SizedBox(height: 16),
                Text(
                  'Keine aktiven Alerts',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                SizedBox(height: 8),
                Text(
                  'Analysiere ein Asset und aktiviere Alerts',
                  style: TextStyle(color: AppColors.textHint, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.activeAlerts.length,
          itemBuilder: (context, index) {
            final alert = provider.activeAlerts[index];
            return _buildAlertCard(alert, provider);
          },
        );
      },
    );
  }

  Widget _buildAlertCard(TriggerAlert alert, AnalysisProvider provider) {
    final directionColor = alert.expectedDirection == AnalysisDirection.bullish
        ? AppColors.profit
        : alert.expectedDirection == AnalysisDirection.bearish
            ? AppColors.loss
            : AppColors.neutral;

    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  alert.symbol,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: directionColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    alert.expectedDirection == AnalysisDirection.bullish ? 'BULLISH' : 'BEARISH',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Erwartete Bewegung: ${alert.expectedMovePercent >= 0 ? '+' : ''}${alert.expectedMovePercent.toStringAsFixed(1)}%',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'Trigger:',
              style: TextStyle(color: AppColors.textHint, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: alert.triggers.take(3).map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cardLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  t,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              )).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Erstellt: ${_formatDate(alert.createdAt)}',
                  style: const TextStyle(color: AppColors.textHint, fontSize: 11),
                ),
                TextButton(
                  onPressed: () => provider.disableAlert(alert.symbol),
                  child: const Text('Deaktivieren', style: TextStyle(color: AppColors.loss)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildLimitWarningBanner(AnalysisProvider provider) {
    final remaining = provider.remainingAnalyses;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade700.withValues(alpha: 0.15),
        border: Border.all(color: Colors.orange.shade700, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nur noch $remaining Analysen verfügbar!',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upgraden Sie auf Pro oder Ultimate für mehr Analysen',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
