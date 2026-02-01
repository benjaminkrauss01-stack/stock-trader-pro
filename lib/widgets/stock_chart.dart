import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/stock.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

class StockChart extends StatefulWidget {
  final List<StockCandle> candles;
  final String selectedRange;
  final Function(String) onRangeChanged;

  const StockChart({
    super.key,
    required this.candles,
    required this.selectedRange,
    required this.onRangeChanged,
  });

  @override
  State<StockChart> createState() => _StockChartState();
}

class _StockChartState extends State<StockChart> {
  int? _touchedIndex;

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
    final padding = (maxY - minY) * 0.1;

    final isPositive = widget.candles.last.close >= widget.candles.first.open;
    final chartColor = isPositive ? AppColors.profit : AppColors.loss;

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, top: 16),
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
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          Formatters.formatNumber(value),
                          style: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 10,
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
                lineTouchData: LineTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      if (event is FlTapUpEvent || event is FlPanEndEvent) {
                        _touchedIndex = null;
                      } else if (response?.lineBarSpots != null &&
                          response!.lineBarSpots!.isNotEmpty) {
                        _touchedIndex = response.lineBarSpots!.first.spotIndex;
                      }
                    });
                  },
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
        const SizedBox(height: 16),
        _buildRangeSelector(),
        if (_touchedIndex != null) ...[
          const SizedBox(height: 16),
          _buildCandleInfo(widget.candles[_touchedIndex!]),
        ],
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
    return '${date.month}/${date.day}';
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.card,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  range,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
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

  Widget _buildCandleInfo(StockCandle candle) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem('Open', Formatters.formatNumber(candle.open)),
          _buildInfoItem('High', Formatters.formatNumber(candle.high)),
          _buildInfoItem('Low', Formatters.formatNumber(candle.low)),
          _buildInfoItem('Close', Formatters.formatNumber(candle.close)),
          _buildInfoItem('Vol', Formatters.formatVolume(candle.volume)),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
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
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
