class Stock {
  final String symbol;
  final String name;
  final double price;
  final double change;
  final double changePercent;
  final double high;
  final double low;
  final double open;
  final double previousClose;
  final int volume;
  final String? currency;
  final DateTime? lastUpdate;

  Stock({
    required this.symbol,
    required this.name,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.high,
    required this.low,
    required this.open,
    required this.previousClose,
    required this.volume,
    this.currency,
    this.lastUpdate,
  });

  bool get isPositive => change >= 0;

  factory Stock.fromYahooFinance(Map<String, dynamic> json) {
    final quote = json['quoteSummary']?['result']?[0]?['price'] ?? json;
    return Stock(
      symbol: quote['symbol'] ?? '',
      name: quote['shortName'] ?? quote['longName'] ?? '',
      price: _toDouble(quote['regularMarketPrice']),
      change: _toDouble(quote['regularMarketChange']),
      changePercent: _toDouble(quote['regularMarketChangePercent']),
      high: _toDouble(quote['regularMarketDayHigh']),
      low: _toDouble(quote['regularMarketDayLow']),
      open: _toDouble(quote['regularMarketOpen']),
      previousClose: _toDouble(quote['regularMarketPreviousClose']),
      volume: _toInt(quote['regularMarketVolume']),
      currency: quote['currency'],
      lastUpdate: DateTime.now(),
    );
  }

  factory Stock.fromQuoteResponse(Map<String, dynamic> json) {
    return Stock(
      symbol: json['symbol'] ?? '',
      name: json['shortName'] ?? json['longName'] ?? json['symbol'] ?? '',
      price: _toDouble(json['regularMarketPrice']),
      change: _toDouble(json['regularMarketChange']),
      changePercent: _toDouble(json['regularMarketChangePercent']),
      high: _toDouble(json['regularMarketDayHigh']),
      low: _toDouble(json['regularMarketDayLow']),
      open: _toDouble(json['regularMarketOpen']),
      previousClose: _toDouble(json['regularMarketPreviousClose']),
      volume: _toInt(json['regularMarketVolume']),
      currency: json['currency'],
      lastUpdate: DateTime.now(),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is Map) return (value['raw'] ?? 0).toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is Map) return (value['raw'] ?? 0).toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'name': name,
        'price': price,
        'change': change,
        'changePercent': changePercent,
        'high': high,
        'low': low,
        'open': open,
        'previousClose': previousClose,
        'volume': volume,
        'currency': currency,
      };
}

class StockCandle {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;

  StockCandle({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  bool get isBullish => close >= open;
}

class PortfolioPosition {
  final String symbol;
  final String name;
  final int shares;
  final double avgPrice;
  final double currentPrice;
  final DateTime purchaseDate;

  PortfolioPosition({
    required this.symbol,
    required this.name,
    required this.shares,
    required this.avgPrice,
    required this.currentPrice,
    required this.purchaseDate,
  });

  double get totalValue => shares * currentPrice;
  double get totalCost => shares * avgPrice;
  double get profit => totalValue - totalCost;
  double get profitPercent => totalCost > 0 ? (profit / totalCost) * 100 : 0;
  bool get isProfit => profit >= 0;

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'name': name,
        'shares': shares,
        'avgPrice': avgPrice,
        'currentPrice': currentPrice,
        'purchaseDate': purchaseDate.toIso8601String(),
      };

  factory PortfolioPosition.fromJson(Map<String, dynamic> json) {
    return PortfolioPosition(
      symbol: json['symbol'],
      name: json['name'],
      shares: json['shares'],
      avgPrice: json['avgPrice'],
      currentPrice: json['currentPrice'],
      purchaseDate: DateTime.parse(json['purchaseDate']),
    );
  }
}
