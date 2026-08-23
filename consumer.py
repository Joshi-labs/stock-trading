#!/usr/bin/env python3
"""
Stock Trade Consumer
Consumes from Redpanda, processes trades, writes to PostgreSQL
"""

import json
import logging
import psycopg2
from psycopg2.extras import execute_values
from kafka import KafkaConsumer
from kafka.errors import KafkaError

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

BROKER = "redpanda:9092"
TOPIC = "stock-trades"
GROUP_ID = "trading-consumer"

DB_CONFIG = {
    "host": "postgres",
    "database": "trading_db",
    "user": "trading_user",
    "password": "trading_password",
    "port": 5432
}

def get_db_connection():
    """Create PostgreSQL connection"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except Exception as e:
        logger.error(f"❌ DB Connection Error: {e}")
        return None

def process_trade(trade, conn):
    """Process a single trade and update database"""
    try:
        cursor = conn.cursor()
        
        user_id = trade['user_id']
        ticker = trade['ticker']
        trade_type = trade['type']
        quantity = trade['quantity']
        price = trade['price']
        total_amount = quantity * price
        timestamp = trade['timestamp']
        
        # 1. Insert transaction
        cursor.execute("""
            INSERT INTO transactions 
            (user_id, wallet_id, ticker, transaction_type, quantity, price, total_amount, transaction_timestamp)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """, (user_id, user_id, ticker, trade_type, quantity, price, total_amount, timestamp))
        
        # 2. Update wallet balance
        if trade_type == "BUY":
            cursor.execute("""
                UPDATE wallets 
                SET balance = balance - %s, updated_at = NOW()
                WHERE user_id = %s
            """, (total_amount, user_id))
        else:  # SELL
            cursor.execute("""
                UPDATE wallets 
                SET balance = balance + %s, updated_at = NOW()
                WHERE user_id = %s
            """, (total_amount, user_id))
        
        # 3. Update or insert holdings
        if trade_type == "BUY":
            cursor.execute("""
                INSERT INTO holdings (user_id, wallet_id, ticker, quantity, avg_purchase_price, updated_at)
                VALUES (%s, %s, %s, %s, %s, NOW())
                ON CONFLICT (user_id, ticker) 
                DO UPDATE SET 
                    quantity = holdings.quantity + EXCLUDED.quantity,
                    avg_purchase_price = (
                        (holdings.quantity * holdings.avg_purchase_price + %s * %s) / 
                        (holdings.quantity + %s)
                    ),
                    updated_at = NOW()
            """, (user_id, user_id, ticker, quantity, price, quantity, price, quantity))
        else:  # SELL
            cursor.execute("""
                UPDATE holdings 
                SET quantity = quantity - %s, updated_at = NOW()
                WHERE user_id = %s AND ticker = %s
            """, (quantity, user_id, ticker))
        
        conn.commit()
        return True
        
    except Exception as e:
        conn.rollback()
        logger.error(f"❌ DB Error processing trade: {e}")
        return False
    finally:
        cursor.close()

def start_consumer():
    """Start Kafka consumer and process messages"""
    logger.info(f"Connecting to Redpanda at {BROKER}...")
    
    consumer = KafkaConsumer(
        TOPIC,
        bootstrap_servers=BROKER,
        group_id=GROUP_ID,
        value_deserializer=lambda m: json.loads(m.decode('utf-8')),
        auto_offset_reset='earliest',
        max_poll_records=10
    )
    
    logger.info(f"✅ Connected to Redpanda. Waiting for messages...\n")
    
    db_conn = get_db_connection()
    if not db_conn:
        logger.error("Failed to connect to database. Exiting.")
        return
    
    trade_count = 0
    try:
        for message in consumer:
            trade = message.value
            
            if process_trade(trade, db_conn):
                trade_count += 1
                logger.info(f"#{trade_count} ✅ {trade['ticker']:6} {trade['type']:4} | "
                           f"Qty: {trade['quantity']:3} | Price: ${trade['price']:8.2f} | "
                           f"User: {trade['user_id']} | Total: ${trade['quantity'] * trade['price']:10.2f}")
            else:
                logger.warning(f"⚠️  Failed to process: {trade['ticker']} {trade['type']}")
    
    except KeyboardInterrupt:
        logger.info("\n⏹  Consumer stopped")
    except KafkaError as e:
        logger.error(f"❌ Kafka Error: {e}")
    finally:
        consumer.close()
        db_conn.close()
        logger.info(f"Processed {trade_count} trades total")

if __name__ == "__main__":
    start_consumer()