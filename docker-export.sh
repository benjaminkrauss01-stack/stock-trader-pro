#!/bin/bash

# Stock Info App - Docker Export Script
# ======================================
# Exports the Docker image as a .tar file for transfer to another system

set -e

IMAGE_NAME="stock-info-app"
EXPORT_FILE="stock-info-app.tar"

echo "🔨 Building Docker image..."
docker build -t $IMAGE_NAME .

echo ""
echo "📦 Exporting image to $EXPORT_FILE..."
docker save -o $EXPORT_FILE $IMAGE_NAME

echo ""
echo "✅ Export complete!"
echo "   File: $EXPORT_FILE"
echo "   Size: $(du -h $EXPORT_FILE | cut -f1)"
echo ""
echo "📋 To load on another system:"
echo "   docker load -i $EXPORT_FILE"
echo ""
echo "🚀 To run on the other system:"
echo "   docker run -d -p 8080:80 --name stock-info-app stock-info-app"
