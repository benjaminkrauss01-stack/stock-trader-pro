#!/bin/bash
# Start Stock Trader Pro Server with CORS Proxy

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if build/web exists
if [ ! -d "build/web" ]; then
    echo "Error: build/web directory not found. Please run 'flutter build web' first."
    exit 1
fi

# Kill any existing server on port 8080
echo "Stopping any existing server on port 8080..."
pkill -f "proxy_server.py" 2>/dev/null || true
fuser -k 8080/tcp 2>/dev/null || true
sleep 1

# Start the proxy server
echo "Starting Stock Trader Pro server..."
python3 proxy_server.py 8080 build/web
