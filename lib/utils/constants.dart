import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF1E88E5);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color secondary = Color(0xFF26A69A);

  static const Color profit = Color(0xFF4CAF50);
  static const Color loss = Color(0xFFE53935);
  static const Color neutral = Color(0xFF9E9E9E);

  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color card = Color(0xFF252525);
  static const Color cardLight = Color(0xFF2D2D2D);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textHint = Color(0xFF757575);

  static const Color divider = Color(0xFF424242);
  static const Color border = Color(0xFF333333);

  static const Color chartLine = Color(0xFF2196F3);
  static const Color chartFill = Color(0x402196F3);
  static const Color chartGrid = Color(0xFF333333);
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class AppDurations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}

class DefaultStocks {
  static const List<String> watchlist = [
    'AAPL',
    'GOOGL',
    'MSFT',
    'AMZN',
    'NVDA',
    'META',
    'TSLA',
    'BRK-B',
    'JPM',
    'V',
  ];

  static const List<String> indices = [
    '^GSPC',   // S&P 500
    '^DJI',    // Dow Jones
    '^IXIC',   // NASDAQ
    '^RUT',    // Russell 2000
    '^VIX',    // VIX
  ];

  static const Map<String, String> indexNames = {
    '^GSPC': 'S&P 500',
    '^DJI': 'Dow Jones',
    '^IXIC': 'NASDAQ',
    '^RUT': 'Russell 2000',
    '^VIX': 'VIX',
  };
}

class ChartRanges {
  static const Map<String, String> ranges = {
    '1D': '1d',
    '5D': '5d',
    '1M': '1mo',
    '3M': '3mo',
    '6M': '6mo',
    'YTD': 'ytd',
    '1Y': '1y',
    '5Y': '5y',
    'MAX': 'max',
  };

  static const Map<String, String> intervals = {
    '1d': '5m',
    '5d': '15m',
    '1mo': '1h',
    '3mo': '1d',
    '6mo': '1d',
    'ytd': '1d',
    '1y': '1d',
    '5y': '1wk',
    'max': '1mo',
  };
}
