#!/bin/bash

# Stock Info App - Remote Deployment Script
# ==========================================

SERVER="192.168.1.230"
USER="root"
REMOTE_DIR="/opt/stock-info"

echo "🚀 Deploying Stock Info App to $SERVER"
echo "======================================="
echo ""

# Check SSH connection
echo "📡 Testing SSH connection..."
ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no $USER@$SERVER "echo 'Connection OK'" || {
    echo "❌ Cannot connect to server. Please check:"
    echo "   - Server is running"
    echo "   - SSH is enabled"
    echo "   - Credentials are correct"
    exit 1
}

echo ""
echo "📁 Creating remote directory..."
ssh $USER@$SERVER "mkdir -p $REMOTE_DIR"

echo ""
echo "📦 Copying project files..."
rsync -avz --progress \
    --exclude '.git' \
    --exclude 'build' \
    --exclude '.dart_tool' \
    --exclude '.idea' \
    --exclude '*.tar' \
    /home/stakratech/Dokumente/stock_info/ $USER@$SERVER:$REMOTE_DIR/

echo ""
echo "🐳 Checking Docker on remote server..."
ssh $USER@$SERVER "docker --version" || {
    echo "📥 Installing Docker..."
    ssh $USER@$SERVER "curl -fsSL https://get.docker.com | sh"
}

echo ""
echo "🔨 Building Docker image on server..."
ssh $USER@$SERVER "cd $REMOTE_DIR && docker-compose down 2>/dev/null; docker-compose up -d --build"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "🌐 App available at: http://$SERVER:8080"
echo ""
echo "📋 Useful commands on the server:"
echo "   ssh $USER@$SERVER"
echo "   cd $REMOTE_DIR"
echo "   docker-compose logs -f"
echo "   docker-compose down"
