class ETF {
  final String symbol;
  final String name;
  final double price;
  final double change;
  final double changePercent;
  final double nav;
  final double expenseRatio;
  final double aum;
  final String category;
  final String? issuer;
  final int volume;
  final double high;
  final double low;
  final double ytdReturn;
  final double oneYearReturn;
  final double threeYearReturn;
  final List<ETFHolding> topHoldings;

  ETF({
    required this.symbol,
    required this.name,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.nav,
    required this.expenseRatio,
    required this.aum,
    required this.category,
    this.issuer,
    required this.volume,
    required this.high,
    required this.low,
    required this.ytdReturn,
    required this.oneYearReturn,
    required this.threeYearReturn,
    this.topHoldings = const [],
  });

  bool get isPositive => change >= 0;

  static List<ETF> getPopularETFs() {
    return [
      ETF(
        symbol: 'SPY',
        name: 'SPDR S&P 500 ETF Trust',
        price: 478.50,
        change: 2.35,
        changePercent: 0.49,
        nav: 478.42,
        expenseRatio: 0.0945,
        aum: 450000000000,
        category: 'Large Cap Blend',
        issuer: 'State Street',
        volume: 65000000,
        high: 479.80,
        low: 476.20,
        ytdReturn: 24.5,
        oneYearReturn: 26.2,
        threeYearReturn: 10.1,
        topHoldings: [
          ETFHolding(symbol: 'AAPL', name: 'Apple Inc.', weight: 7.2),
          ETFHolding(symbol: 'MSFT', name: 'Microsoft Corp.', weight: 6.8),
          ETFHolding(symbol: 'AMZN', name: 'Amazon.com Inc.', weight: 3.4),
          ETFHolding(symbol: 'NVDA', name: 'NVIDIA Corp.', weight: 3.2),
          ETFHolding(symbol: 'GOOGL', name: 'Alphabet Inc.', weight: 2.1),
        ],
      ),
      ETF(
        symbol: 'QQQ',
        name: 'Invesco QQQ Trust',
        price: 405.20,
        change: 3.15,
        changePercent: 0.78,
        nav: 405.10,
        expenseRatio: 0.20,
        aum: 200000000000,
        category: 'Large Cap Growth',
        issuer: 'Invesco',
        volume: 45000000,
        high: 407.50,
        low: 402.80,
        ytdReturn: 52.3,
        oneYearReturn: 55.1,
        threeYearReturn: 12.5,
        topHoldings: [
          ETFHolding(symbol: 'AAPL', name: 'Apple Inc.', weight: 11.2),
          ETFHolding(symbol: 'MSFT', name: 'Microsoft Corp.', weight: 10.5),
          ETFHolding(symbol: 'AMZN', name: 'Amazon.com Inc.', weight: 5.8),
          ETFHolding(symbol: 'NVDA', name: 'NVIDIA Corp.', weight: 4.9),
          ETFHolding(symbol: 'META', name: 'Meta Platforms', weight: 4.2),
        ],
      ),
      ETF(
        symbol: 'VTI',
        name: 'Vanguard Total Stock Market ETF',
        price: 245.80,
        change: 1.20,
        changePercent: 0.49,
        nav: 245.75,
        expenseRatio: 0.03,
        aum: 350000000000,
        category: 'Total Market',
        issuer: 'Vanguard',
        volume: 4500000,
        high: 246.50,
        low: 244.30,
        ytdReturn: 23.8,
        oneYearReturn: 25.5,
        threeYearReturn: 9.8,
        topHoldings: [
          ETFHolding(symbol: 'AAPL', name: 'Apple Inc.', weight: 6.5),
          ETFHolding(symbol: 'MSFT', name: 'Microsoft Corp.', weight: 6.1),
          ETFHolding(symbol: 'AMZN', name: 'Amazon.com Inc.', weight: 3.0),
          ETFHolding(symbol: 'NVDA', name: 'NVIDIA Corp.', weight: 2.8),
          ETFHolding(symbol: 'GOOGL', name: 'Alphabet Inc.', weight: 1.9),
        ],
      ),
      ETF(
        symbol: 'IWM',
        name: 'iShares Russell 2000 ETF',
        price: 198.50,
        change: -0.85,
        changePercent: -0.43,
        nav: 198.45,
        expenseRatio: 0.19,
        aum: 60000000000,
        category: 'Small Cap Blend',
        issuer: 'BlackRock',
        volume: 25000000,
        high: 200.20,
        low: 197.80,
        ytdReturn: 15.2,
        oneYearReturn: 16.8,
        threeYearReturn: 2.5,
        topHoldings: [],
      ),
      ETF(
        symbol: 'VWO',
        name: 'Vanguard FTSE Emerging Markets ETF',
        price: 42.30,
        change: 0.25,
        changePercent: 0.59,
        nav: 42.28,
        expenseRatio: 0.08,
        aum: 80000000000,
        category: 'Emerging Markets',
        issuer: 'Vanguard',
        volume: 12000000,
        high: 42.80,
        low: 42.00,
        ytdReturn: 8.5,
        oneYearReturn: 10.2,
        threeYearReturn: -2.1,
        topHoldings: [],
      ),
      ETF(
        symbol: 'GLD',
        name: 'SPDR Gold Shares',
        price: 188.50,
        change: 1.80,
        changePercent: 0.96,
        nav: 188.45,
        expenseRatio: 0.40,
        aum: 55000000000,
        category: 'Commodities',
        issuer: 'State Street',
        volume: 8000000,
        high: 189.20,
        low: 186.50,
        ytdReturn: 12.8,
        oneYearReturn: 14.5,
        threeYearReturn: 6.2,
        topHoldings: [],
      ),
      ETF(
        symbol: 'TLT',
        name: 'iShares 20+ Year Treasury Bond ETF',
        price: 95.80,
        change: -0.45,
        changePercent: -0.47,
        nav: 95.75,
        expenseRatio: 0.15,
        aum: 40000000000,
        category: 'Long-Term Bond',
        issuer: 'BlackRock',
        volume: 20000000,
        high: 96.50,
        low: 95.20,
        ytdReturn: -5.2,
        oneYearReturn: -8.5,
        threeYearReturn: -12.8,
        topHoldings: [],
      ),
      ETF(
        symbol: 'XLK',
        name: 'Technology Select Sector SPDR',
        price: 195.30,
        change: 2.10,
        changePercent: 1.09,
        nav: 195.25,
        expenseRatio: 0.10,
        aum: 55000000000,
        category: 'Technology',
        issuer: 'State Street',
        volume: 8500000,
        high: 196.80,
        low: 193.50,
        ytdReturn: 55.2,
        oneYearReturn: 58.5,
        threeYearReturn: 15.2,
        topHoldings: [
          ETFHolding(symbol: 'AAPL', name: 'Apple Inc.', weight: 22.5),
          ETFHolding(symbol: 'MSFT', name: 'Microsoft Corp.', weight: 21.8),
          ETFHolding(symbol: 'NVDA', name: 'NVIDIA Corp.', weight: 6.2),
          ETFHolding(symbol: 'AVGO', name: 'Broadcom Inc.', weight: 4.8),
          ETFHolding(symbol: 'ADBE', name: 'Adobe Inc.', weight: 3.5),
        ],
      ),
      ETF(
        symbol: 'XLF',
        name: 'Financial Select Sector SPDR',
        price: 38.90,
        change: 0.35,
        changePercent: 0.91,
        nav: 38.88,
        expenseRatio: 0.10,
        aum: 35000000000,
        category: 'Financials',
        issuer: 'State Street',
        volume: 45000000,
        high: 39.20,
        low: 38.50,
        ytdReturn: 10.5,
        oneYearReturn: 12.2,
        threeYearReturn: 8.5,
        topHoldings: [
          ETFHolding(symbol: 'BRK.B', name: 'Berkshire Hathaway', weight: 13.5),
          ETFHolding(symbol: 'JPM', name: 'JPMorgan Chase', weight: 10.2),
          ETFHolding(symbol: 'V', name: 'Visa Inc.', weight: 8.5),
          ETFHolding(symbol: 'MA', name: 'Mastercard', weight: 7.2),
          ETFHolding(symbol: 'BAC', name: 'Bank of America', weight: 4.8),
        ],
      ),
      ETF(
        symbol: 'XLE',
        name: 'Energy Select Sector SPDR',
        price: 85.20,
        change: -1.25,
        changePercent: -1.45,
        nav: 85.15,
        expenseRatio: 0.10,
        aum: 38000000000,
        category: 'Energy',
        issuer: 'State Street',
        volume: 18000000,
        high: 86.80,
        low: 84.50,
        ytdReturn: -2.5,
        oneYearReturn: 1.2,
        threeYearReturn: 25.5,
        topHoldings: [
          ETFHolding(symbol: 'XOM', name: 'Exxon Mobil', weight: 23.5),
          ETFHolding(symbol: 'CVX', name: 'Chevron Corp.', weight: 18.2),
          ETFHolding(symbol: 'SLB', name: 'Schlumberger', weight: 4.8),
          ETFHolding(symbol: 'COP', name: 'ConocoPhillips', weight: 4.5),
          ETFHolding(symbol: 'EOG', name: 'EOG Resources', weight: 4.2),
        ],
      ),
    ];
  }
}

class ETFHolding {
  final String symbol;
  final String name;
  final double weight;

  ETFHolding({
    required this.symbol,
    required this.name,
    required this.weight,
  });
}

class Sector {
  final String name;
  final String etfSymbol;
  final double performance1D;
  final double performance1W;
  final double performance1M;
  final double performanceYTD;

  Sector({
    required this.name,
    required this.etfSymbol,
    required this.performance1D,
    required this.performance1W,
    required this.performance1M,
    required this.performanceYTD,
  });

  static List<Sector> getSectors() {
    return [
      Sector(name: 'Technology', etfSymbol: 'XLK', performance1D: 1.2, performance1W: 3.5, performance1M: 8.2, performanceYTD: 52.5),
      Sector(name: 'Healthcare', etfSymbol: 'XLV', performance1D: 0.5, performance1W: 1.2, performance1M: 2.8, performanceYTD: 5.2),
      Sector(name: 'Financials', etfSymbol: 'XLF', performance1D: 0.8, performance1W: 2.1, performance1M: 4.5, performanceYTD: 10.8),
      Sector(name: 'Consumer Disc.', etfSymbol: 'XLY', performance1D: 0.9, performance1W: 2.8, performance1M: 5.2, performanceYTD: 38.5),
      Sector(name: 'Communication', etfSymbol: 'XLC', performance1D: 1.1, performance1W: 3.2, performance1M: 6.8, performanceYTD: 48.2),
      Sector(name: 'Industrials', etfSymbol: 'XLI', performance1D: 0.6, performance1W: 1.8, performance1M: 3.5, performanceYTD: 15.2),
      Sector(name: 'Consumer Staples', etfSymbol: 'XLP', performance1D: 0.3, performance1W: 0.8, performance1M: 1.5, performanceYTD: -2.5),
      Sector(name: 'Energy', etfSymbol: 'XLE', performance1D: -1.2, performance1W: -2.5, performance1M: -5.8, performanceYTD: -3.2),
      Sector(name: 'Utilities', etfSymbol: 'XLU', performance1D: 0.2, performance1W: 0.5, performance1M: 1.2, performanceYTD: -8.5),
      Sector(name: 'Real Estate', etfSymbol: 'XLRE', performance1D: 0.4, performance1W: 1.0, performance1M: 2.5, performanceYTD: 8.2),
      Sector(name: 'Materials', etfSymbol: 'XLB', performance1D: 0.5, performance1W: 1.5, performance1M: 3.2, performanceYTD: 10.5),
    ];
  }
}
