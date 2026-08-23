#!/usr/bin/env python3
"""
Stock Trade Generator
Produces realistic stock trade messages to Redpanda
"""

import json
import time
import random
from datetime import datetime
from kafka import KafkaProducer
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

BROKER = "redpanda:9092"
TOPIC = "stock-trades"

TICKERS = ["AAPL", "GOOGL", "MSFT", "TSLA", "AMZN", "META", "NVDA", "AMD"]
USERS = [1, 2, 3]
PRICES = {
    "AAPL": 180,
    "GOOGL": 140,
    "MSFT": 370,
    "TSLA": 240,
    "AMZN": 170,
    "META": 330,
    "NVDA": 850,
    "AMD": 160
}

def generate_trade():
    """Generate a realistic stock trade"""
    ticker = random.choice(TICKERS)
    base_price = PRICES[ticker]
    
    trade = {
        "user_id": random.choice(USERS),
        "ticker": ticker,
        "type": random.choice(["BUY", "SELL"]),
        "quantity": random.randint(1, 100),
        "price": round(base_price + random.uniform(-5, 5), 2),
        "timestamp": datetime.now().isoformat()
    }
    return trade

def start_producer():
    """Start Kafka producer and send trades"""
    logger.info(f"Connecting to Redpanda at {BROKER}...")
    
    producer = KafkaProducer(
        bootstrap_servers=BROKER,
        value_serializer=lambda v: json.dumps(v).encode('utf-8'),
        retries=3
    )
    
    logger.info(f"✅ Connected. Generating trades to topic '{TOPIC}'...\n")
    
    trade_count = 0
    try:
        while True:
            trade = generate_trade()
            
            future = producer.send(TOPIC, value=trade)
            record_metadata = future.get(timeout=10)
            
            trade_count += 1
            logger.info(f"#{trade_count} | {trade['ticker']:6} {trade['type']:4} | "
                       f"Qty: {trade['quantity']:3} | Price: ${trade['price']:8.2f} | "
                       f"User: {trade['user_id']} | Partition: {record_metadata.partition}")
            
            time.sleep(random.uniform(0.5, 2))  # Random delay 0.5-2 seconds
            
    except KeyboardInterrupt:
        logger.info("\n⏹  Generator stopped")
    except Exception as e:
        logger.error(f"❌ Error: {e}")
    finally:
        producer.close()
        logger.info(f"Generated {trade_count} trades total")

if __name__ == "__main__":
    start_producer()