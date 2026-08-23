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

echo "🔧 Updating docker-compose.ec2.yml with username: $GITHUB_USER"
sed -i "s/YOUR_GITHUB_USERNAME/$GITHUB_USER/g" docker-compose.ec2.yml

echo "📝 Creating init.sql if missing..."
if [ ! -f "init.sql" ]; then
    cat > init.sql << 'SQLEOF'
CREATE TABLE IF NOT EXISTS users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS wallets (
    wallet_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    balance DECIMAL(15, 2) DEFAULT 50000.00,
    currency VARCHAR(10) DEFAULT 'USD',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS transactions (
    transaction_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    wallet_id INTEGER NOT NULL REFERENCES wallets(wallet_id) ON DELETE CASCADE,
    ticker VARCHAR(10) NOT NULL,
    transaction_type VARCHAR(10) NOT NULL CHECK (transaction_type IN ('BUY', 'SELL')),
    quantity INTEGER NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    total_amount DECIMAL(15, 2) NOT NULL,
    transaction_timestamp TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_id ON transactions(user_id);
CREATE INDEX idx_ticker ON transactions(ticker);
CREATE INDEX idx_transaction_timestamp ON transactions(transaction_timestamp);

CREATE TABLE IF NOT EXISTS holdings (
    holding_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    wallet_id INTEGER NOT NULL REFERENCES wallets(wallet_id) ON DELETE CASCADE,
    ticker VARCHAR(10) NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 0,
    avg_purchase_price DECIMAL(10, 2) NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, ticker)
);

CREATE INDEX idx_user_ticker ON holdings(user_id, ticker);

INSERT INTO users (username, email) VALUES 
    ('trader_alice', 'alice@example.com'),
    ('trader_bob', 'bob@example.com'),
    ('trader_charlie', 'charlie@example.com')
ON CONFLICT DO NOTHING;

INSERT INTO wallets (user_id, balance) 
SELECT user_id, 50000.00 FROM users
ON CONFLICT DO NOTHING;
SQLEOF
    echo "✅ init.sql created"
else
    echo "✅ init.sql already exists"
fi

echo "🛑 Stopping old services (if running)..."
docker compose -f docker-compose.ec2.yml down 2>/dev/null || true

echo "📥 Pulling latest images from GHCR..."
docker compose -f docker-compose.ec2.yml pull

echo "🚀 Starting services..."
docker compose -f docker-compose.ec2.yml up -d

echo ""
echo "⏳ Waiting for services to be healthy (20s)..."
sleep 20

echo ""
echo "================================"
echo "✅ Deployment Complete!"
echo "================================"
echo ""

echo "📊 Service Status:"
docker compose -f docker-compose.ec2.yml ps

echo ""
echo "📋 Quick Checks:"
docker compose -f docker-compose.ec2.yml exec postgres psql -U trading_user -d trading_db -c "SELECT COUNT(*) as users FROM users;" 2>/dev/null || echo "⚠️  DB not ready yet, check logs in 10s"

echo ""
echo "📋 Useful Commands:"
echo "  Follow all logs:      docker compose -f docker-compose.ec2.yml logs -f"
echo "  Follow generator:     docker compose -f docker-compose.ec2.yml logs -f trade_generator"
echo "  Follow consumer:      docker compose -f docker-compose.ec2.yml logs -f trade_consumer"
echo "  Check status:         docker compose -f docker-compose.ec2.yml ps"
echo "  Stop services:        docker compose -f docker-compose.ec2.yml down"
echo "  Query database:       docker compose -f docker-compose.ec2.yml exec postgres psql -U trading_user -d trading_db"
echo ""
echo "✅ Run this to monitor: docker compose -f docker-compose.ec2.yml logs -f"