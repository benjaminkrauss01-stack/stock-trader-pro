#!/bin/bash

# Stock Trader Pro - Git-based Deployment Script
# ================================================
# Usage: ./deploy.sh [message]

set -e

SERVER="192.168.1.230"
USER="root"
REMOTE_DIR="/opt/stock-info"
BRANCH="main"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Stock Trader Pro - Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Check for uncommitted changes
echo -e "${YELLOW}[1/5]${NC} Checking git status..."
if [[ -n $(git status --porcelain) ]]; then
    echo -e "${YELLOW}Uncommitted changes detected. Committing...${NC}"
    git add -A

    # Use provided message or generate one
    COMMIT_MSG="${1:-Auto-deploy: $(date '+%Y-%m-%d %H:%M')}"
    git commit -m "$COMMIT_MSG"
    echo -e "${GREEN}Committed: $COMMIT_MSG${NC}"
else
    echo -e "${GREEN}Working directory clean${NC}"
fi

# Step 2: Push to remote (if configured)
echo ""
echo -e "${YELLOW}[2/5]${NC} Pushing to GitHub..."
if git remote get-url origin &>/dev/null; then
    git push origin $BRANCH
    echo -e "${GREEN}Pushed to origin/$BRANCH${NC}"
else
    echo -e "${YELLOW}No remote configured, skipping push${NC}"
fi

# Step 3: Connect to server and pull
echo ""
echo -e "${YELLOW}[3/5]${NC} Connecting to server..."
ssh -o ConnectTimeout=5 $USER@$SERVER "echo 'Connected'" || {
    echo -e "${RED}Cannot connect to server${NC}"
    exit 1
}

# Step 4: Pull on server or clone if not exists
echo ""
echo -e "${YELLOW}[4/5]${NC} Updating code on server..."

# Check if repo exists on server
REPO_URL=$(git remote get-url origin 2>/dev/null || echo "")

if [ -n "$REPO_URL" ]; then
    # Git-based deployment
    ssh $USER@$SERVER << EOF
        if [ -d "$REMOTE_DIR/.git" ]; then
            cd $REMOTE_DIR
            git fetch origin
            git reset --hard origin/$BRANCH
            echo "Code updated via git pull"
        else
            rm -rf $REMOTE_DIR
            git clone $REPO_URL $REMOTE_DIR
            echo "Repository cloned"
        fi
EOF
else
    # Fallback: rsync deployment
    echo -e "${YELLOW}No git remote, using rsync...${NC}"
    rsync -avz --progress \
        --exclude '.git' \
        --exclude 'build' \
        --exclude '.dart_tool' \
        --exclude '.idea' \
        --exclude '*.log' \
        --exclude '.env' \
        ./ $USER@$SERVER:$REMOTE_DIR/
fi

# Step 5: Restart services
echo ""
echo -e "${YELLOW}[5/5]${NC} Restarting services..."
ssh $USER@$SERVER << 'EOF'
    cd /opt/stock-info

    # Copy .env if exists locally but not on server
    if [ ! -f .env ] && [ -f .env.example ]; then
        cp .env.example .env
        echo "Created .env from example"
    fi

    # Restart Docker containers
    docker compose down 2>/dev/null || true
    docker compose up -d --build

    echo "Services restarted"
EOF

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "App URL: ${BLUE}https://stocks.padelbuddy.de${NC}"
echo ""
echo -e "Server commands:"
echo -e "  ${YELLOW}ssh $USER@$SERVER${NC}"
echo -e "  ${YELLOW}docker-compose -f $REMOTE_DIR/docker-compose.yml logs -f${NC}"
