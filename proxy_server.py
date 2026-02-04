#!/usr/bin/env python3
"""
CORS Proxy Server for Stock Trader Pro
Uses yfinance for reliable Yahoo Finance data
"""

from http.server import HTTPServer, SimpleHTTPRequestHandler
import urllib.request
import urllib.error
import json
import ssl
import yfinance as yf

class CORSProxyHandler(SimpleHTTPRequestHandler):
    def send_cors_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')

    def send_no_cache_headers(self):
        """Add headers to prevent browser and CDN caching"""
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_cors_headers()
        self.end_headers()

    def end_headers(self):
        """Override to add no-cache headers to all responses"""
        self.send_no_cache_headers()
        self.send_cors_headers()
        super().end_headers()

    def do_GET(self):
        # Serve static files from web directory
        if not self.path.startswith('/api/'):
            return super().do_GET()

        # Handle API proxy requests
        self.proxy_request()

    def proxy_request(self):
        # Parse the full path and query string
        if '?' in self.path:
            path_part, query_string = self.path.split('?', 1)
        else:
            path_part = self.path
            query_string = ''

        # Parse query parameters
        params = {}
        if query_string:
            for param in query_string.split('&'):
                if '=' in param:
                    key, value = param.split('=', 1)
                    params[key] = value

        # Remove '/api/' prefix
        api_path = path_part[5:]

        print(f'API Request: {api_path} with params: {params}')

        try:
            response_data = None

            # Yahoo Finance Chart API
            if api_path.startswith('yahoo/chart/'):
                symbol = api_path.replace('yahoo/chart/', '')
                response_data = self.get_chart_data(symbol, params)

            # Yahoo Finance Quote API
            elif api_path.startswith('yahoo/quote'):
                symbols = params.get('symbols', '').split(',')
                response_data = self.get_quote_data(symbols)

            # Yahoo Finance Search API
            elif api_path.startswith('yahoo/search'):
                query = params.get('q', '')
                response_data = self.search_symbols(query)

            # Yahoo Market Summary
            elif api_path.startswith('yahoo/market-summary'):
                response_data = self.get_market_summary()

            # Yahoo Trending
            elif api_path.startswith('yahoo/trending'):
                response_data = self.get_trending()

            # CoinGecko API (direct proxy)
            elif api_path.startswith('coingecko/'):
                endpoint = api_path[10:]
                url = f'https://api.coingecko.com/api/v3/{endpoint}'
                if query_string:
                    url += f'?{query_string}'
                response_data = self.proxy_external(url)

            else:
                self.send_error(404, f'Unknown API endpoint: {api_path}')
                return

            if response_data:
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_cors_headers()
                self.end_headers()
                self.wfile.write(json.dumps(response_data).encode())
            else:
                raise Exception('No data returned')

        except Exception as e:
            print(f'Error: {str(e)}')
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({'error': str(e)}).encode())

    def get_chart_data(self, symbol, params):
        """Get historical chart data using yfinance"""
        period = params.get('range', '1d')
        interval = params.get('interval', '1d')

        # Map period names
        period_map = {
            '1d': '1d', '5d': '5d', '1mo': '1mo', '3mo': '3mo',
            '6mo': '6mo', '1y': '1y', '2y': '2y', '5y': '5y', 'max': 'max'
        }
        period = period_map.get(period, '1mo')

        ticker = yf.Ticker(symbol)
        hist = ticker.history(period=period, interval=interval)

        if hist.empty:
            return {'chart': {'result': None, 'error': {'description': 'No data found'}}}

        timestamps = [int(ts.timestamp()) for ts in hist.index]

        return {
            'chart': {
                'result': [{
                    'meta': {
                        'symbol': symbol,
                        'currency': 'USD',
                        'regularMarketPrice': float(hist['Close'].iloc[-1]) if len(hist) > 0 else 0,
                    },
                    'timestamp': timestamps,
                    'indicators': {
                        'quote': [{
                            'open': hist['Open'].tolist(),
                            'high': hist['High'].tolist(),
                            'low': hist['Low'].tolist(),
                            'close': hist['Close'].tolist(),
                            'volume': hist['Volume'].tolist(),
                        }]
                    }
                }],
                'error': None
            }
        }

    def get_quote_data(self, symbols):
        """Get quote data for multiple symbols using yfinance"""
        results = []

        for symbol in symbols:
            if not symbol:
                continue
            try:
                ticker = yf.Ticker(symbol)
                info = ticker.info

                # Get fast info for current price
                fast_info = ticker.fast_info

                results.append({
                    'symbol': symbol,
                    'shortName': info.get('shortName', symbol),
                    'longName': info.get('longName', symbol),
                    'regularMarketPrice': fast_info.get('lastPrice', info.get('regularMarketPrice', 0)),
                    'regularMarketChange': info.get('regularMarketChange', 0),
                    'regularMarketChangePercent': info.get('regularMarketChangePercent', 0),
                    'regularMarketPreviousClose': fast_info.get('previousClose', info.get('regularMarketPreviousClose', 0)),
                    'regularMarketOpen': fast_info.get('open', info.get('regularMarketOpen', 0)),
                    'regularMarketDayHigh': fast_info.get('dayHigh', info.get('regularMarketDayHigh', 0)),
                    'regularMarketDayLow': fast_info.get('dayLow', info.get('regularMarketDayLow', 0)),
                    'regularMarketVolume': fast_info.get('lastVolume', info.get('regularMarketVolume', 0)),
                    'marketCap': fast_info.get('marketCap', info.get('marketCap', 0)),
                    'fiftyTwoWeekHigh': fast_info.get('yearHigh', info.get('fiftyTwoWeekHigh', 0)),
                    'fiftyTwoWeekLow': fast_info.get('yearLow', info.get('fiftyTwoWeekLow', 0)),
                    'currency': info.get('currency', 'USD'),
                    'exchange': info.get('exchange', ''),
                    'quoteType': info.get('quoteType', 'EQUITY'),
                })
            except Exception as e:
                print(f'Error fetching {symbol}: {e}')
                results.append({
                    'symbol': symbol,
                    'shortName': symbol,
                    'regularMarketPrice': 0,
                    'error': str(e)
                })

        return {'quoteResponse': {'result': results, 'error': None}}

    # Stock database with symbols and searchable names/keywords
    STOCK_DATABASE = [
        # Tech Giants
        {'symbol': 'AAPL', 'name': 'Apple Inc.', 'keywords': ['apple', 'iphone', 'mac', 'ipad']},
        {'symbol': 'MSFT', 'name': 'Microsoft Corporation', 'keywords': ['microsoft', 'windows', 'azure', 'xbox']},
        {'symbol': 'GOOGL', 'name': 'Alphabet Inc.', 'keywords': ['google', 'alphabet', 'youtube', 'android']},
        {'symbol': 'GOOG', 'name': 'Alphabet Inc. Class C', 'keywords': ['google', 'alphabet']},
        {'symbol': 'AMZN', 'name': 'Amazon.com Inc.', 'keywords': ['amazon', 'aws', 'prime']},
        {'symbol': 'META', 'name': 'Meta Platforms Inc.', 'keywords': ['meta', 'facebook', 'instagram', 'whatsapp']},
        {'symbol': 'NVDA', 'name': 'NVIDIA Corporation', 'keywords': ['nvidia', 'geforce', 'gpu', 'grafikkarte']},
        {'symbol': 'TSLA', 'name': 'Tesla Inc.', 'keywords': ['tesla', 'elon', 'musk', 'elektroauto']},
        {'symbol': 'AMD', 'name': 'Advanced Micro Devices', 'keywords': ['amd', 'ryzen', 'radeon', 'prozessor']},
        {'symbol': 'INTC', 'name': 'Intel Corporation', 'keywords': ['intel', 'prozessor', 'chip']},
        {'symbol': 'NFLX', 'name': 'Netflix Inc.', 'keywords': ['netflix', 'streaming']},
        {'symbol': 'ADBE', 'name': 'Adobe Inc.', 'keywords': ['adobe', 'photoshop', 'creative']},
        {'symbol': 'CRM', 'name': 'Salesforce Inc.', 'keywords': ['salesforce', 'crm', 'cloud']},
        {'symbol': 'ORCL', 'name': 'Oracle Corporation', 'keywords': ['oracle', 'database', 'java']},
        {'symbol': 'IBM', 'name': 'IBM Corporation', 'keywords': ['ibm', 'watson', 'mainframe']},
        {'symbol': 'CSCO', 'name': 'Cisco Systems Inc.', 'keywords': ['cisco', 'netzwerk', 'router']},
        {'symbol': 'QCOM', 'name': 'Qualcomm Inc.', 'keywords': ['qualcomm', 'snapdragon', 'chip']},
        {'symbol': 'TXN', 'name': 'Texas Instruments', 'keywords': ['texas', 'instruments', 'halbleiter']},
        {'symbol': 'AVGO', 'name': 'Broadcom Inc.', 'keywords': ['broadcom', 'chip', 'halbleiter']},
        {'symbol': 'MU', 'name': 'Micron Technology', 'keywords': ['micron', 'speicher', 'memory']},

        # Finance
        {'symbol': 'JPM', 'name': 'JPMorgan Chase & Co.', 'keywords': ['jpmorgan', 'chase', 'bank']},
        {'symbol': 'BAC', 'name': 'Bank of America Corp.', 'keywords': ['bank', 'america', 'bofa']},
        {'symbol': 'WFC', 'name': 'Wells Fargo & Co.', 'keywords': ['wells', 'fargo', 'bank']},
        {'symbol': 'GS', 'name': 'Goldman Sachs Group', 'keywords': ['goldman', 'sachs', 'investment']},
        {'symbol': 'MS', 'name': 'Morgan Stanley', 'keywords': ['morgan', 'stanley', 'investment']},
        {'symbol': 'V', 'name': 'Visa Inc.', 'keywords': ['visa', 'kreditkarte', 'payment']},
        {'symbol': 'MA', 'name': 'Mastercard Inc.', 'keywords': ['mastercard', 'kreditkarte', 'payment']},
        {'symbol': 'PYPL', 'name': 'PayPal Holdings Inc.', 'keywords': ['paypal', 'payment', 'venmo']},
        {'symbol': 'SQ', 'name': 'Block Inc.', 'keywords': ['block', 'square', 'payment', 'cash app']},
        {'symbol': 'BLK', 'name': 'BlackRock Inc.', 'keywords': ['blackrock', 'asset', 'etf']},

        # Healthcare
        {'symbol': 'JNJ', 'name': 'Johnson & Johnson', 'keywords': ['johnson', 'pharma', 'medizin']},
        {'symbol': 'UNH', 'name': 'UnitedHealth Group', 'keywords': ['united', 'health', 'versicherung']},
        {'symbol': 'PFE', 'name': 'Pfizer Inc.', 'keywords': ['pfizer', 'pharma', 'impfstoff']},
        {'symbol': 'MRK', 'name': 'Merck & Co.', 'keywords': ['merck', 'pharma', 'medikament']},
        {'symbol': 'ABBV', 'name': 'AbbVie Inc.', 'keywords': ['abbvie', 'pharma', 'humira']},
        {'symbol': 'LLY', 'name': 'Eli Lilly and Co.', 'keywords': ['lilly', 'eli', 'pharma', 'diabetes']},
        {'symbol': 'BMY', 'name': 'Bristol-Myers Squibb', 'keywords': ['bristol', 'myers', 'squibb', 'pharma']},
        {'symbol': 'AMGN', 'name': 'Amgen Inc.', 'keywords': ['amgen', 'biotech', 'pharma']},
        {'symbol': 'GILD', 'name': 'Gilead Sciences', 'keywords': ['gilead', 'biotech', 'hiv']},
        {'symbol': 'MRNA', 'name': 'Moderna Inc.', 'keywords': ['moderna', 'mrna', 'impfstoff', 'vaccine']},

        # Consumer
        {'symbol': 'WMT', 'name': 'Walmart Inc.', 'keywords': ['walmart', 'supermarkt', 'retail']},
        {'symbol': 'COST', 'name': 'Costco Wholesale Corp.', 'keywords': ['costco', 'großhandel', 'retail']},
        {'symbol': 'HD', 'name': 'Home Depot Inc.', 'keywords': ['home', 'depot', 'baumarkt']},
        {'symbol': 'TGT', 'name': 'Target Corporation', 'keywords': ['target', 'retail', 'supermarkt']},
        {'symbol': 'NKE', 'name': 'Nike Inc.', 'keywords': ['nike', 'sport', 'schuhe', 'sneaker']},
        {'symbol': 'SBUX', 'name': 'Starbucks Corporation', 'keywords': ['starbucks', 'kaffee', 'coffee']},
        {'symbol': 'MCD', 'name': 'McDonald\'s Corporation', 'keywords': ['mcdonald', 'burger', 'fastfood']},
        {'symbol': 'KO', 'name': 'Coca-Cola Company', 'keywords': ['coca', 'cola', 'coke', 'getränk']},
        {'symbol': 'PEP', 'name': 'PepsiCo Inc.', 'keywords': ['pepsi', 'cola', 'frito', 'lay']},
        {'symbol': 'PG', 'name': 'Procter & Gamble Co.', 'keywords': ['procter', 'gamble', 'pampers', 'gillette']},

        # Telecom & Media
        {'symbol': 'DIS', 'name': 'Walt Disney Company', 'keywords': ['disney', 'marvel', 'pixar', 'star wars']},
        {'symbol': 'T', 'name': 'AT&T Inc.', 'keywords': ['att', 'at&t', 'telekom']},
        {'symbol': 'VZ', 'name': 'Verizon Communications', 'keywords': ['verizon', 'telekom', 'mobilfunk']},
        {'symbol': 'TMUS', 'name': 'T-Mobile US Inc.', 'keywords': ['t-mobile', 'tmobile', 'mobilfunk']},
        {'symbol': 'CMCSA', 'name': 'Comcast Corporation', 'keywords': ['comcast', 'nbc', 'universal']},
        {'symbol': 'PARA', 'name': 'Paramount Global', 'keywords': ['paramount', 'cbs', 'film']},
        {'symbol': 'WBD', 'name': 'Warner Bros. Discovery', 'keywords': ['warner', 'bros', 'hbo', 'discovery']},

        # Automotive
        {'symbol': 'F', 'name': 'Ford Motor Company', 'keywords': ['ford', 'auto', 'mustang']},
        {'symbol': 'GM', 'name': 'General Motors Co.', 'keywords': ['general', 'motors', 'chevrolet', 'gmc']},
        {'symbol': 'TM', 'name': 'Toyota Motor Corp.', 'keywords': ['toyota', 'auto', 'lexus']},
        {'symbol': 'HMC', 'name': 'Honda Motor Co.', 'keywords': ['honda', 'auto', 'acura']},
        {'symbol': 'RIVN', 'name': 'Rivian Automotive', 'keywords': ['rivian', 'elektroauto', 'ev']},
        {'symbol': 'LCID', 'name': 'Lucid Group Inc.', 'keywords': ['lucid', 'elektroauto', 'ev']},

        # Energy
        {'symbol': 'XOM', 'name': 'Exxon Mobil Corp.', 'keywords': ['exxon', 'mobil', 'öl', 'oil']},
        {'symbol': 'CVX', 'name': 'Chevron Corporation', 'keywords': ['chevron', 'öl', 'oil', 'gas']},
        {'symbol': 'COP', 'name': 'ConocoPhillips', 'keywords': ['conoco', 'phillips', 'öl']},
        {'symbol': 'SLB', 'name': 'Schlumberger Ltd.', 'keywords': ['schlumberger', 'öl', 'drilling']},

        # E-Commerce & Social
        {'symbol': 'SHOP', 'name': 'Shopify Inc.', 'keywords': ['shopify', 'ecommerce', 'online shop']},
        {'symbol': 'ETSY', 'name': 'Etsy Inc.', 'keywords': ['etsy', 'handmade', 'marketplace']},
        {'symbol': 'EBAY', 'name': 'eBay Inc.', 'keywords': ['ebay', 'auktion', 'marketplace']},
        {'symbol': 'PINS', 'name': 'Pinterest Inc.', 'keywords': ['pinterest', 'social', 'bilder']},
        {'symbol': 'SNAP', 'name': 'Snap Inc.', 'keywords': ['snap', 'snapchat', 'social']},
        {'symbol': 'TWTR', 'name': 'Twitter Inc.', 'keywords': ['twitter', 'x', 'social']},
        {'symbol': 'SPOT', 'name': 'Spotify Technology', 'keywords': ['spotify', 'musik', 'streaming']},
        {'symbol': 'RBLX', 'name': 'Roblox Corporation', 'keywords': ['roblox', 'gaming', 'metaverse']},
        {'symbol': 'U', 'name': 'Unity Software Inc.', 'keywords': ['unity', 'gaming', 'engine']},

        # Travel & Airlines
        {'symbol': 'DAL', 'name': 'Delta Air Lines', 'keywords': ['delta', 'airline', 'flug']},
        {'symbol': 'UAL', 'name': 'United Airlines', 'keywords': ['united', 'airline', 'flug']},
        {'symbol': 'AAL', 'name': 'American Airlines', 'keywords': ['american', 'airline', 'flug']},
        {'symbol': 'LUV', 'name': 'Southwest Airlines', 'keywords': ['southwest', 'airline', 'flug']},
        {'symbol': 'ABNB', 'name': 'Airbnb Inc.', 'keywords': ['airbnb', 'unterkunft', 'travel']},
        {'symbol': 'BKNG', 'name': 'Booking Holdings', 'keywords': ['booking', 'hotel', 'travel']},
        {'symbol': 'EXPE', 'name': 'Expedia Group', 'keywords': ['expedia', 'travel', 'hotel']},
        {'symbol': 'MAR', 'name': 'Marriott International', 'keywords': ['marriott', 'hotel']},
        {'symbol': 'HLT', 'name': 'Hilton Worldwide', 'keywords': ['hilton', 'hotel']},

        # Semiconductor & AI
        {'symbol': 'TSM', 'name': 'Taiwan Semiconductor', 'keywords': ['taiwan', 'tsmc', 'chip', 'semiconductor']},
        {'symbol': 'ASML', 'name': 'ASML Holding', 'keywords': ['asml', 'lithographie', 'chip']},
        {'symbol': 'ARM', 'name': 'Arm Holdings', 'keywords': ['arm', 'chip', 'prozessor', 'mobile']},
        {'symbol': 'MRVL', 'name': 'Marvell Technology', 'keywords': ['marvell', 'chip', 'data center']},
        {'symbol': 'LRCX', 'name': 'Lam Research Corp.', 'keywords': ['lam', 'research', 'semiconductor']},
        {'symbol': 'AMAT', 'name': 'Applied Materials', 'keywords': ['applied', 'materials', 'semiconductor']},
        {'symbol': 'KLAC', 'name': 'KLA Corporation', 'keywords': ['kla', 'semiconductor', 'inspection']},
        {'symbol': 'PLTR', 'name': 'Palantir Technologies', 'keywords': ['palantir', 'ai', 'daten', 'analytics']},
        {'symbol': 'AI', 'name': 'C3.ai Inc.', 'keywords': ['c3', 'ai', 'artificial intelligence']},

        # Crypto & Fintech
        {'symbol': 'COIN', 'name': 'Coinbase Global', 'keywords': ['coinbase', 'crypto', 'bitcoin', 'exchange']},
        {'symbol': 'MSTR', 'name': 'MicroStrategy Inc.', 'keywords': ['microstrategy', 'bitcoin', 'btc']},
        {'symbol': 'HOOD', 'name': 'Robinhood Markets', 'keywords': ['robinhood', 'trading', 'broker']},
        {'symbol': 'SOFI', 'name': 'SoFi Technologies', 'keywords': ['sofi', 'fintech', 'bank']},
        {'symbol': 'AFRM', 'name': 'Affirm Holdings', 'keywords': ['affirm', 'buy now pay later', 'bnpl']},

        # Indices & ETFs
        {'symbol': 'SPY', 'name': 'SPDR S&P 500 ETF', 'keywords': ['spy', 's&p', 'sp500', 'index', 'etf']},
        {'symbol': 'QQQ', 'name': 'Invesco QQQ Trust', 'keywords': ['qqq', 'nasdaq', 'tech', 'etf']},
        {'symbol': 'IWM', 'name': 'iShares Russell 2000', 'keywords': ['iwm', 'russell', 'small cap', 'etf']},
        {'symbol': 'DIA', 'name': 'SPDR Dow Jones ETF', 'keywords': ['dia', 'dow', 'jones', 'etf']},
        {'symbol': 'VOO', 'name': 'Vanguard S&P 500 ETF', 'keywords': ['voo', 's&p', 'vanguard', 'etf']},
        {'symbol': 'VTI', 'name': 'Vanguard Total Stock', 'keywords': ['vti', 'total', 'market', 'etf']},
        {'symbol': 'ARKK', 'name': 'ARK Innovation ETF', 'keywords': ['ark', 'innovation', 'cathie', 'wood']},

        # German/European Stocks
        {'symbol': 'SAP', 'name': 'SAP SE', 'keywords': ['sap', 'software', 'erp', 'deutschland']},
        {'symbol': 'ASML', 'name': 'ASML Holding NV', 'keywords': ['asml', 'niederlande', 'chip']},
        {'symbol': 'NVO', 'name': 'Novo Nordisk', 'keywords': ['novo', 'nordisk', 'ozempic', 'diabetes']},
    ]

    def search_symbols(self, query):
        """Search for symbols by symbol or company name"""
        if not query:
            return {'quotes': [], 'news': []}

        try:
            results = []
            news_results = []
            query_lower = query.lower()
            query_upper = query.upper()
            added_symbols = set()

            # 1. Exact symbol match (highest priority)
            for stock in self.STOCK_DATABASE:
                if stock['symbol'].upper() == query_upper:
                    results.append({
                        'symbol': stock['symbol'],
                        'shortname': stock['name'],
                        'longname': stock['name'],
                        'exchange': 'NASDAQ/NYSE',
                        'quoteType': 'EQUITY',
                        'score': 100000,
                    })
                    added_symbols.add(stock['symbol'])
                    break

            # 2. Search in company names and keywords
            for stock in self.STOCK_DATABASE:
                if stock['symbol'] in added_symbols:
                    continue

                score = 0
                name_lower = stock['name'].lower()

                # Check if query matches start of symbol
                if stock['symbol'].upper().startswith(query_upper):
                    score = 80000
                # Check if query matches start of name
                elif name_lower.startswith(query_lower):
                    score = 70000
                # Check if query is in name
                elif query_lower in name_lower:
                    score = 60000
                # Check keywords
                else:
                    for keyword in stock.get('keywords', []):
                        if query_lower in keyword.lower():
                            score = 50000
                            break
                        if keyword.lower().startswith(query_lower):
                            score = 55000
                            break

                if score > 0:
                    results.append({
                        'symbol': stock['symbol'],
                        'shortname': stock['name'],
                        'longname': stock['name'],
                        'exchange': 'NASDAQ/NYSE',
                        'quoteType': 'EQUITY',
                        'score': score,
                    })
                    added_symbols.add(stock['symbol'])

            # 3. If still no results, try yfinance lookup
            if not results:
                try:
                    ticker = yf.Ticker(query_upper)
                    info = ticker.info
                    if info.get('symbol'):
                        results.append({
                            'symbol': info.get('symbol', query_upper),
                            'shortname': info.get('shortName', query_upper),
                            'longname': info.get('longName', query_upper),
                            'exchange': info.get('exchange', ''),
                            'quoteType': info.get('quoteType', 'EQUITY'),
                            'score': 40000,
                        })
                except:
                    pass

            # Sort by score and limit to 15 results
            results.sort(key=lambda x: x.get('score', 0), reverse=True)
            results = results[:15]

            # Get news for the top result
            if results:
                try:
                    top_symbol = results[0]['symbol']
                    ticker = yf.Ticker(top_symbol)
                    news = ticker.news
                    if news:
                        for article in news[:10]:
                            news_results.append(self._format_news_article(article))
                except:
                    pass

            return {'quotes': results, 'news': news_results}
        except Exception as e:
            print(f'Search error: {e}')
            return {'quotes': [], 'news': []}

    def _format_news_article(self, article):
        """Format a yfinance news article to Yahoo Finance API format"""
        # yfinance returns nested structure with 'content' key
        content = article.get('content', article)

        # Extract thumbnail URL
        thumbnail = None
        thumb_data = content.get('thumbnail', {})
        if thumb_data:
            resolutions = thumb_data.get('resolutions', [])
            if resolutions and len(resolutions) > 0:
                thumbnail = {'resolutions': [{'url': resolutions[0].get('url', '')}]}

        # Parse publish time
        pub_time = 0
        pub_date = content.get('pubDate', '')
        if pub_date:
            try:
                from datetime import datetime
                dt = datetime.fromisoformat(pub_date.replace('Z', '+00:00'))
                pub_time = int(dt.timestamp())
            except:
                pass

        # Get link from canonicalUrl
        link = ''
        canonical = content.get('canonicalUrl', {})
        if canonical:
            link = canonical.get('url', '')

        return {
            'uuid': content.get('id', article.get('id', str(hash(content.get('title', ''))))),
            'title': content.get('title', ''),
            'summary': content.get('summary', ''),
            'publisher': content.get('provider', {}).get('displayName', 'Unknown'),
            'link': link,
            'providerPublishTime': pub_time,
            'type': content.get('contentType', 'STORY'),
            'thumbnail': thumbnail,
            'relatedTickers': [],
        }

    def get_market_summary(self):
        """Get market summary for major indices"""
        indices = ['^GSPC', '^DJI', '^IXIC', '^RUT', '^VIX']
        results = []

        for symbol in indices:
            try:
                ticker = yf.Ticker(symbol)
                info = ticker.info
                fast_info = ticker.fast_info

                name_map = {
                    '^GSPC': 'S&P 500',
                    '^DJI': 'Dow Jones',
                    '^IXIC': 'NASDAQ',
                    '^RUT': 'Russell 2000',
                    '^VIX': 'VIX',
                }

                results.append({
                    'symbol': symbol,
                    'shortName': name_map.get(symbol, info.get('shortName', symbol)),
                    'regularMarketPrice': fast_info.get('lastPrice', 0),
                    'regularMarketChange': info.get('regularMarketChange', 0),
                    'regularMarketChangePercent': info.get('regularMarketChangePercent', 0),
                })
            except Exception as e:
                print(f'Error fetching {symbol}: {e}')

        return {'marketSummaryResponse': {'result': results}}

    def get_trending(self):
        """Get trending tickers"""
        # Return some popular tickers as trending
        trending = ['AAPL', 'TSLA', 'NVDA', 'AMD', 'GOOGL', 'MSFT', 'META', 'AMZN']
        results = []

        for symbol in trending:
            results.append({'symbol': symbol})

        return {'finance': {'result': [{'quotes': results}]}}

    def proxy_external(self, url):
        """Proxy external API requests"""
        req = urllib.request.Request(url)
        req.add_header('User-Agent', 'Mozilla/5.0')
        req.add_header('Accept', 'application/json')

        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

        with urllib.request.urlopen(req, timeout=30, context=ctx) as response:
            return json.loads(response.read())


def run_server(port=8080, directory='build/web'):
    import os

    # Change to the specified directory
    if os.path.exists(directory):
        os.chdir(directory)
        print(f'Serving files from: {os.getcwd()}')
    else:
        print(f'Warning: Directory {directory} does not exist')
        print(f'Serving from current directory: {os.getcwd()}')

    server = HTTPServer(('0.0.0.0', port), CORSProxyHandler)
    print(f'\n=== Stock Trader Pro Server (yfinance) ===')
    print(f'Server running on http://localhost:{port}')
    print(f'Using yfinance for reliable data access')
    print(f'\nPress Ctrl+C to stop')
    print(f'==========================================\n')

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\nServer stopped.')
        server.shutdown()

if __name__ == '__main__':
    import sys
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    directory = sys.argv[2] if len(sys.argv) > 2 else 'build/web'
    run_server(port, directory)
