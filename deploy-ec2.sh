#!/bin/bash

set -e

echo "================================"
echo "Stock Trading - EC2 Deployment"
echo "================================"
echo ""

# Check if docker compose is installed
if ! command -v docker compose &> /dev/null; then
    echo "❌ docker compose not found. Install Docker first."
    exit 1
fi

# GitHub username
if [ -z "$1" ]; then
    echo "Usage: ./deploy-ec2.sh YOUR_GITHUB_USERNAME"
    echo ""
    echo "Example: ./deploy-ec2.sh joshi-labs"
    exit 1
fi

GITHUB_USER=$1
REPO_NAME="stock-trading"

echo "🔧 Updating docker-compose.ec2.yml with username: $GITHUB_USER"
sed -i "s/YOUR_GITHUB_USERNAME/$GITHUB_USER/g" docker-compose.ec2.yml

echo "📥 Pulling latest images from GHCR..."
docker compose -f docker-compose.ec2.yml pull

echo "🚀 Starting services..."
docker compose -f docker-compose.ec2.yml up -d

echo ""
echo "================================"
echo "✅ Deployment Complete!"
echo "================================"
echo ""

# Wait for services to be ready
echo "⏳ Waiting for services to be healthy (10s)..."
sleep 10

echo "📊 Service Status:"
docker compose -f docker-compose.ec2.yml ps

echo ""
echo "📋 Useful Commands:"
echo "  docker compose -f docker-compose.ec2.yml logs -f"
echo "  docker compose -f docker-compose.ec2.yml ps"
echo "  docker compose -f docker-compose.ec2.yml down"
echo ""
echo "✅ Ready! Check logs: docker compose -f docker-compose.ec2.yml logs -f"