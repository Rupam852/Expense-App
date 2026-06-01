import pg from 'pg';
import dotenv from 'dotenv';

dotenv.config();

const { Pool } = pg;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false
  }
});

// Helper for running queries
export const query = (text, params) => pool.query(text, params);

// Initialize DB tables
export const initDB = async () => {
  try {
    console.log('Initializing PostgreSQL tables...');

    // 1. Users Table
    await query(`
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255),
        name VARCHAR(255),
        photo_url TEXT,
        google_id VARCHAR(255) UNIQUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // 2. Expenses Table (with soft delete and client-generated primary key VARCHAR(36))
    await query(`
      CREATE TABLE IF NOT EXISTS expenses (
        id VARCHAR(36) PRIMARY KEY,
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        amount NUMERIC(12, 2) NOT NULL,
        currency VARCHAR(3) DEFAULT 'INR',
        category VARCHAR(50) NOT NULL,
        description TEXT,
        transaction_date TIMESTAMP NOT NULL,
        receipt_url TEXT,
        is_recurring BOOLEAN DEFAULT FALSE,
        recurrence_period VARCHAR(20) DEFAULT 'none',
        is_deleted BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // 3. Budgets Table
    await query(`
      CREATE TABLE IF NOT EXISTS budgets (
        id VARCHAR(36) PRIMARY KEY,
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        category VARCHAR(50) NOT NULL,
        amount_limit NUMERIC(12, 2) NOT NULL,
        month_year VARCHAR(7) NOT NULL, -- Format: YYYY-MM
        is_deleted BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    // Run schema migrations for users and budgets
    await query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS google_id VARCHAR(255) UNIQUE;`);
    await query(`ALTER TABLE budgets ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE;`);

    // 4. Payment Details Table
    await query(`
      CREATE TABLE IF NOT EXISTS payment_details (
        id VARCHAR(36) PRIMARY KEY,
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        upi_id VARCHAR(255),
        qr_code_url TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // 5. Deleted Records Queue Table
    await query(`
      CREATE TABLE IF NOT EXISTS deleted_records (
        id VARCHAR(36) PRIMARY KEY,
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        table_name VARCHAR(50) NOT NULL,
        deleted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    console.log('Database tables successfully verified/created!');
  } catch (error) {
    console.error('Error initializing database:', error);
    throw error;
  }
};

export default pool;
