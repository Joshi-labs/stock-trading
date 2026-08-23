-- init.sql
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