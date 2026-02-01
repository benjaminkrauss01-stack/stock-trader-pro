import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/stock.dart';
import '../models/analysis.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

/// Chart widget for analysis screen with historical prediction markers
class AnalysisChartWidget extends StatefulWidget {
  final List<StockCandle> candles;
  final MarketAnalysis? currentAnalysis;
  final List<MarketAnalysis> historicalAnalyses;
  final String selectedRange;
  final Function(String) onRangeChanged;

  const AnalysisChartWidget({
    super.key,
    required this.candles,
    this.currentAnalysis,
    this.historicalAnalyses = const [],
    required this.selectedRange,
    required this.onRangeChanged,
  });

  @override
  State<AnalysisChartWidget> createState() => _AnalysisChartWidgetState();
}

class _AnalysisChartWidgetState extends State<AnalysisChartWidget> {
  @override
  Widget build(BuildContext context) {
    if (widget.candles.isEmpty) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final spots = _createSpots();
    final minY = widget.candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    final maxY = widget.candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.15;

    final isPositive = widget.candles.last.close >= widget.candles.first.open;
    final chartColor = isPositive ? AppColors.profit : AppColors.loss;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.show_chart, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Kursverlauf mit Vorhersagen',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // Main chart
        SizedBox(
          height: 250,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, left: 8, top: 8),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.chartGrid,
                      strokeWidth: 0.5,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 55,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            Formatters.formatNumber(value),
                            style: const TextStyle(
                              color: AppColors.textHint,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (widget.candles.length / 4).ceil().toDouble(),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < widget.candles.length) {
                          final date = widget.candles[index].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _formatDateLabel(date),
                              style: const TextStyle(
                                color: AppColors.textHint,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (widget.candles.length - 1).toDouble(),
                minY: minY - padding,
                maxY: maxY + padding,
                extraLinesData: _buildPredictionLines(minY, maxY),
                rangeAnnotations: _buildPredictionZones(minY, maxY),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: AppColors.card,
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final candle = widget.candles[spot.spotIndex];
                        return LineTooltipItem(
                          '${Formatters.formatCurrency(candle.close)}\n${Formatters.formatDateTime(candle.date)}',
                          const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: chartColor,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          chartColor.withValues(alpha: 0.3),
                          chartColor.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildRangeSelector(),
        // Current prediction info
        if (widget.currentAnalysis != null) ...[
          const SizedBox(height: 16),
          _buildCurrentPredictionCard(),
        ],
        // Historical predictions list
        if (widget.historicalAnalyses.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildHistoricalPredictionsList(),
        ],
        // Legend
        const SizedBox(height: 12),
        _buildLegend(),
      ],
    );
  }

  /// Baut die Vorhersage-Zonen (farbige Bereiche im Chart)
  RangeAnnotations _buildPredictionZones(double minY, double maxY) {
    final List<HorizontalRangeAnnotation> horizontalAnnotations = [];

    // Alle historischen Analysen durchgehen
    for (final analysis in widget.historicalAnalyses) {
      final result = _getPredictionZoneForAnalysis(analysis, minY, maxY);
      if (result != null) {
        horizontalAnnotations.add(result);
      }
    }

    // Aktuelle Analyse
    if (widget.currentAnalysis != null) {
      final result = _getPredictionZoneForAnalysis(widget.currentAnalysis!, minY, maxY, isCurrent: true);
      if (result != null) {
        horizontalAnnotations.add(result);
      }
    }

    return RangeAnnotations(horizontalRangeAnnotations: horizontalAnnotations);
  }

  HorizontalRangeAnnotation? _getPredictionZoneForAnalysis(
    MarketAnalysis analysis,
    double minY,
    double maxY, {
    bool isCurrent = false,
  }) {
    // Finde den Candle-Index für das Analysedatum
    int? analysisIndex = _findCandleIndexForDate(analysis.analyzedAt);
    if (analysisIndex == null) return null;

    // Startpreis zum Zeitpunkt der Analyse
    final startPrice = widget.candles[analysisIndex].close;
    final targetPrice = startPrice * (1 + analysis.expectedMovePercent / 100);

    // Berechne Zielbereich (±2% vom Ziel)
    final targetHigh = targetPrice * 1.02;
    final targetLow = targetPrice * 0.98;

    // Prüfe ob im sichtbaren Bereich
    if (targetHigh < minY || targetLow > maxY) return null;

    // Farbe basierend auf Wahrscheinlichkeit (0-100)
    final color = _getConfidenceColor(analysis);

    // Transparenz basierend auf ob aktuell oder historisch
    final alpha = isCurrent ? 0.25 : 0.15;

    return HorizontalRangeAnnotation(
      y1: targetLow.clamp(minY, maxY),
      y2: targetHigh.clamp(minY, maxY),
      color: color.withValues(alpha: alpha),
    );
  }

  /// Erstellt vertikale Linien und horizontale Ziellinien
  ExtraLinesData _buildPredictionLines(double minY, double maxY) {
    final List<HorizontalLine> horizontalLines = [];
    final List<VerticalLine> verticalLines = [];

    // Aktuelle Analyse - prominente Linien
    if (widget.currentAnalysis != null && widget.candles.isNotEmpty) {
      final analysis = widget.currentAnalysis!;
      final currentPrice = widget.candles.last.close;
      final targetPrice = currentPrice * (1 + analysis.expectedMovePercent / 100);
      final color = _getConfidenceColor(analysis);

      // Horizontale Zielpreis-Linie
      if (targetPrice >= minY && targetPrice <= maxY) {
        horizontalLines.add(
          HorizontalLine(
            y: targetPrice,
            color: color,
            strokeWidth: 2.5,
            dashArray: [10, 5],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 4),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              labelResolver: (line) =>
                  'ZIEL ${targetPrice.toStringAsFixed(2)} (${analysis.expectedMovePercent >= 0 ? "+" : ""}${analysis.expectedMovePercent.toStringAsFixed(1)}%) | ${analysis.timeframeDays}T',
            ),
          ),
        );
      }

      // Aktuelle Preis-Linie
      horizontalLines.add(
        HorizontalLine(
          y: currentPrice,
          color: Colors.white.withValues(alpha: 0.6),
          strokeWidth: 1,
          dashArray: [4, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topLeft,
            padding: const EdgeInsets.only(left: 4),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
            labelResolver: (line) => 'AKTUELL',
          ),
        ),
      );
    }

    // Historische Analysen - Marker am Analysedatum
    for (final analysis in widget.historicalAnalyses) {
      final index = _findCandleIndexForDate(analysis.analyzedAt);
      if (index == null) continue;

      final color = _getConfidenceColor(analysis);
      final startPrice = widget.candles[index].close;
      final targetPrice = startPrice * (1 + analysis.expectedMovePercent / 100);

      // Vertikale Linie am Analysedatum
      verticalLines.add(
        VerticalLine(
          x: index.toDouble(),
          color: color.withValues(alpha: 0.9),
          strokeWidth: 3,
          dashArray: [8, 4],
          label: VerticalLineLabel(
            show: true,
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(bottom: 8),
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              backgroundColor: color.withValues(alpha: 0.9),
            ),
            labelResolver: (line) =>
                ' ${analysis.expectedMovePercent >= 0 ? "+" : ""}${analysis.expectedMovePercent.toStringAsFixed(1)}% | ${analysis.timeframeDays}T | ${analysis.confidence.toInt()}% ',
          ),
        ),
      );

      // Horizontale Ziellinie (weniger prominent)
      if (targetPrice >= minY && targetPrice <= maxY) {
        horizontalLines.add(
          HorizontalLine(
            y: targetPrice,
            color: color.withValues(alpha: 0.6),
            strokeWidth: 1.5,
            dashArray: [6, 4],
          ),
        );
      }
    }

    return ExtraLinesData(
      horizontalLines: horizontalLines,
      verticalLines: verticalLines,
    );
  }

  /// Findet den Candle-Index für ein Datum
  int? _findCandleIndexForDate(DateTime date) {
    int? closestIndex;
    int minDiff = 999999;

    for (int i = 0; i < widget.candles.length; i++) {
      final diff = widget.candles[i].date.difference(date).inHours.abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIndex = i;
      }
    }

    // Nur zurückgeben wenn innerhalb von 72 Stunden
    return (closestIndex != null && minDiff < 72) ? closestIndex : null;
  }

  /// Farbe basierend auf Konfidenz/Wahrscheinlichkeit
  Color _getConfidenceColor(MarketAnalysis analysis) {
    // Kombiniere Richtung mit Wahrscheinlichkeit für die Farbe
    final probability = analysis.probabilitySignificantMove;

    if (analysis.direction == AnalysisDirection.bullish) {
      // Grün-Skala: Je höher die Wahrscheinlichkeit, desto leuchtender
      if (probability >= 70) {
        return const Color(0xFF00E676); // Helles Grün
      } else if (probability >= 50) {
        return const Color(0xFF4CAF50); // Standard Grün
      } else {
        return const Color(0xFF81C784); // Blasses Grün
      }
    } else if (analysis.direction == AnalysisDirection.bearish) {
      // Rot-Skala: Je höher die Wahrscheinlichkeit, desto leuchtender
      if (probability >= 70) {
        return const Color(0xFFFF5252); // Helles Rot
      } else if (probability >= 50) {
        return const Color(0xFFF44336); // Standard Rot
      } else {
        return const Color(0xFFE57373); // Blasses Rot
      }
    } else {
      return Colors.grey;
    }
  }

  /// Karte für aktuelle Vorhersage
  Widget _buildCurrentPredictionCard() {
    final analysis = widget.currentAnalysis!;
    final color = _getConfidenceColor(analysis);
    final currentPrice = widget.candles.isNotEmpty ? widget.candles.last.close : 0.0;
    final targetPrice = currentPrice * (1 + analysis.expectedMovePercent / 100);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                analysis.direction == AnalysisDirection.bullish
                    ? Icons.trending_up
                    : Icons.trending_down,
                color: color,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AKTUELLE VORHERSAGE',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '${currentPrice.toStringAsFixed(2)} → ${targetPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Erwartete Bewegung Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${analysis.expectedMovePercent >= 0 ? "+" : ""}${analysis.expectedMovePercent.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Info-Zeile
          Row(
            children: [
              _buildInfoChip(Icons.schedule, '${analysis.timeframeDays} Tage', Colors.blue),
              const SizedBox(width: 8),
              _buildInfoChip(
                Icons.analytics,
                '${analysis.probabilitySignificantMove.toInt()}% Wahrsch.',
                _getProbabilityColor(analysis.probabilitySignificantMove),
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                Icons.verified,
                '${analysis.confidence.toInt()}% Konfidenz',
                _getProbabilityColor(analysis.confidence),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Color _getProbabilityColor(double probability) {
    if (probability >= 70) {
      return const Color(0xFF00E676); // Grün
    } else if (probability >= 50) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  /// Liste der historischen Vorhersagen
  Widget _buildHistoricalPredictionsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 8),
              Text(
                'FRÜHERE VORHERSAGEN (${widget.historicalAnalyses.length})',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...widget.historicalAnalyses.take(5).map((analysis) {
            return _buildHistoricalPredictionItem(analysis);
          }),
        ],
      ),
    );
  }

  Widget _buildHistoricalPredictionItem(MarketAnalysis analysis) {
    final color = _getConfidenceColor(analysis);
    final dateStr = '${analysis.analyzedAt.day}.${analysis.analyzedAt.month}.${analysis.analyzedAt.year}';

    // Prüfe ob Vorhersage korrekt war (wenn Zeitraum abgelaufen)
    final endDate = analysis.analyzedAt.add(Duration(days: analysis.timeframeDays));
    final isExpired = DateTime.now().isAfter(endDate);
    String? resultText;
    Color? resultColor;

    if (isExpired) {
      final startIndex = _findCandleIndexForDate(analysis.analyzedAt);
      final endIndex = _findCandleIndexForDate(endDate);

      if (startIndex != null && endIndex != null && endIndex < widget.candles.length) {
        final startPrice = widget.candles[startIndex].close;
        final endPrice = widget.candles[endIndex].close;
        final actualMove = ((endPrice - startPrice) / startPrice) * 100;

        final wasCorrect = (analysis.direction == AnalysisDirection.bullish && actualMove > 0) ||
            (analysis.direction == AnalysisDirection.bearish && actualMove < 0);

        resultText = wasCorrect ? '✓ Korrekt' : '✗ Falsch';
        resultColor = wasCorrect ? AppColors.profit : AppColors.loss;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Richtungsindikator
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                analysis.direction == AnalysisDirection.bullish
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                color: color,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${analysis.expectedMovePercent >= 0 ? "+" : ""}${analysis.expectedMovePercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'in ${analysis.timeframeDays} Tagen',
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Wahrscheinlichkeits-Badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _getProbabilityColor(analysis.probabilitySignificantMove).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${analysis.probabilitySignificantMove.toInt()}%',
                  style: TextStyle(
                    color: _getProbabilityColor(analysis.probabilitySignificantMove),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (resultText != null) ...[
                const SizedBox(height: 4),
                Text(
                  resultText,
                  style: TextStyle(
                    color: resultColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Legende für die Farben
  Widget _buildLegend() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLegendItem(const Color(0xFF00E676), '≥70%'),
          _buildLegendItem(const Color(0xFF4CAF50), '50-70%'),
          _buildLegendItem(const Color(0xFF81C784), '<50%'),
          const SizedBox(width: 16),
          _buildLegendItem(const Color(0xFFFF5252), '≥70%'),
          _buildLegendItem(const Color(0xFFF44336), '50-70%'),
          _buildLegendItem(const Color(0xFFE57373), '<50%'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textHint,
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  List<FlSpot> _createSpots() {
    return widget.candles.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.close);
    }).toList();
  }

  String _formatDateLabel(DateTime date) {
    if (widget.selectedRange == '1D' || widget.selectedRange == '5D') {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}.${date.month}';
  }

  Widget _buildRangeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: ChartRanges.ranges.keys.map((range) {
          final isSelected = range == widget.selectedRange;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => widget.onRangeChanged(range),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.card,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  range,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
