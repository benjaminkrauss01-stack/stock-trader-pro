import 'package:intl/intl.dart';

class Formatters {
  static final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  static final _numberFormat = NumberFormat('#,##0.00');
  static final _intFormat = NumberFormat('#,###');
  static final _dateFormat = DateFormat('MMM d, yyyy');
  static final _timeFormat = DateFormat('HH:mm:ss');
  static final _dateTimeFormat = DateFormat('MMM d, yyyy HH:mm');

  static String formatCurrency(double value, {String? currency}) {
    if (currency != null && currency != 'USD') {
      return NumberFormat.currency(symbol: _getCurrencySymbol(currency), decimalDigits: 2)
          .format(value);
    }
    return _currencyFormat.format(value);
  }

  static String formatPercent(double value) {
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)}%';
  }

  static String formatNumber(double value) {
    return _numberFormat.format(value);
  }

  static String formatInt(int value) {
    return _intFormat.format(value);
  }

  static String formatVolume(int volume) {
    if (volume >= 1000000000) {
      return '${(volume / 1000000000).toStringAsFixed(2)}B';
    } else if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(2)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(2)}K';
    }
    return formatInt(volume);
  }

  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  static String formatTime(DateTime time) {
    return _timeFormat.format(time);
  }

  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }

  static String formatChange(double change, double changePercent) {
    final sign = change >= 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(2)} ($sign${changePercent.toStringAsFixed(2)}%)';
  }

  static String formatMarketCap(double? marketCap) {
    if (marketCap == null) return 'N/A';
    if (marketCap >= 1e12) {
      return '\$${(marketCap / 1e12).toStringAsFixed(2)}T';
    } else if (marketCap >= 1e9) {
      return '\$${(marketCap / 1e9).toStringAsFixed(2)}B';
    } else if (marketCap >= 1e6) {
      return '\$${(marketCap / 1e6).toStringAsFixed(2)}M';
    }
    return _currencyFormat.format(marketCap);
  }

  static String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'EUR':
        return '\u20AC';
      case 'GBP':
        return '\u00A3';
      case 'JPY':
        return '\u00A5';
      case 'CHF':
        return 'CHF ';
      default:
        return '$currency ';
    }
  }
}
