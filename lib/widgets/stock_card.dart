import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

class StockCard extends StatelessWidget {
  final Stock stock;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onAnalyze;
  final bool showVolume;
  final bool compact;

  const StockCard({
    super.key,
    required this.stock,
    this.onTap,
    this.onLongPress,
    this.onAnalyze,
    this.showVolume = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final changeColor = stock.isPositive ? AppColors.profit : AppColors.loss;

    if (compact) {
      return _buildCompactCard(context, changeColor);
    }

    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock.symbol,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stock.name,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (showVolume)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Volume',
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        Formatters.formatVolume(stock.volume),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.formatCurrency(stock.price, currency: stock.currency),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: changeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        Formatters.formatChange(stock.change, stock.changePercent),
                        style: TextStyle(
                          color: changeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (onAnalyze != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onAnalyze,
                  icon: const Icon(
                    Icons.psychology,
                    color: Colors.deepPurple,
                    size: 24,
                  ),
                  tooltip: 'KI-Analyse',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.deepPurple.withValues(alpha: 0.15),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCard(BuildContext context, Color changeColor) {
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    stock.symbol,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    stock.isPositive ? Icons.trending_up : Icons.trending_down,
                    color: changeColor,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                Formatters.formatCurrency(stock.price, currency: stock.currency),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                Formatters.formatPercent(stock.changePercent),
                style: TextStyle(
                  color: changeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class IndexCard extends StatelessWidget {
  final Stock index;
  final VoidCallback? onTap;

  const IndexCard({
    super.key,
    required this.index,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final changeColor = index.isPositive ? AppColors.profit : AppColors.loss;
    final indexName = DefaultStocks.indexNames[index.symbol] ?? index.name;

    return Card(
      color: AppColors.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                indexName,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Text(
                Formatters.formatNumber(index.price),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    index.isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: changeColor,
                    size: 18,
                  ),
                  Flexible(
                    child: Text(
                      Formatters.formatPercent(index.changePercent),
                      style: TextStyle(
                        color: changeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
