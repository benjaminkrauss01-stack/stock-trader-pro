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

    def search_symbols(self, query):
        """Search for symbols using Yahoo Finance Search API - supports company names"""
        if not query:
            return {'quotes': [], 'news': []}

        try:
            import urllib.parse

            # Use Yahoo Finance Search API which supports company name search
            encoded_query = urllib.parse.quote(query)
            url = f'https://query1.finance.yahoo.com/v1/finance/search?q={encoded_query}&quotesCount=15&newsCount=5&enableFuzzyQuery=true&quotesQueryId=tss_match_phrase_query'

            req = urllib.request.Request(url)
            req.add_header('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
            req.add_header('Accept', 'application/json')

            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE

            with urllib.request.urlopen(req, timeout=10, context=ctx) as response:
                data = json.loads(response.read())

            # Extract quotes from response
            quotes = data.get('quotes', [])
            news = data.get('news', [])

            # Format quotes for our app
            results = []
            for q in quotes:
                quote_type = q.get('quoteType', '')
                # Include stocks, ETFs, indices, crypto
                if quote_type in ['EQUITY', 'ETF', 'INDEX', 'MUTUALFUND', 'CRYPTOCURRENCY']:
                    results.append({
                        'symbol': q.get('symbol', ''),
                        'shortname': q.get('shortname', q.get('symbol', '')),
                        'longname': q.get('longname', q.get('shortname', '')),
                        'exchange': q.get('exchange', ''),
                        'quoteType': quote_type,
                        'score': q.get('score', 0),
                    })

            # Format news
            news_results = []
            for n in news:
                news_results.append({
                    'uuid': n.get('uuid', ''),
                    'title': n.get('title', ''),
                    'publisher': n.get('publisher', ''),
                    'link': n.get('link', ''),
                    'providerPublishTime': n.get('providerPublishTime', 0),
                    'type': 'STORY',
                })

            # If no results from Yahoo, fallback to yfinance direct lookup
            if not results:
                try:
                    ticker = yf.Ticker(query.upper())
                    info = ticker.info
                    if info.get('symbol'):
                        results.append({
                            'symbol': info.get('symbol', query.upper()),
                            'shortname': info.get('shortName', query.upper()),
                            'longname': info.get('longName', query.upper()),
                            'exchange': info.get('exchange', ''),
                            'quoteType': info.get('quoteType', 'EQUITY'),
                            'score': 1000,
                        })
                except:
                    pass

            return {'quotes': results, 'news': news_results}

        except Exception as e:
            print(f'Search error: {e}')
            # Fallback to yfinance on error
            try:
                ticker = yf.Ticker(query.upper())
                info = ticker.info
                if info.get('symbol'):
                    return {
                        'quotes': [{
                            'symbol': info.get('symbol', query.upper()),
                            'shortname': info.get('shortName', query.upper()),
                            'longname': info.get('longName', query.upper()),
                            'exchange': info.get('exchange', ''),
                            'quoteType': info.get('quoteType', 'EQUITY'),
                            'score': 1000,
                        }],
                        'news': []
                    }
            except:
                pass
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
