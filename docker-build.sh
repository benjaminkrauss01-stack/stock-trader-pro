#!/bin/bash

# Stock Info App - Docker Build Script
# =====================================

set -e

IMAGE_NAME="stock-info-app"
CONTAINER_NAME="stock-info-app"
PORT="${1:-8080}"

echo "🔨 Building Docker image..."
docker build -t $IMAGE_NAME .

echo ""
echo "✅ Build complete!"
echo ""
echo "📦 To run the container:"
echo "   docker run -d -p $PORT:80 --name $CONTAINER_NAME $IMAGE_NAME"
echo ""
echo "🐳 Or use docker-compose:"
echo "   docker-compose up -d --build"
echo ""
echo "🌐 App will be available at: http://localhost:$PORT"
