const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME || 'ceruleanpay',
  user: process.env.DB_USER || 'cerulean_app',
  password: process.env.DB_PASSWORD,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false
});

pool.on('error', (err) => {
  console.error('[DB] Unexpected error on idle client:', err);
});

async function testConnection() {
  const client = await pool.connect();
  try {
    const result = await client.query('SELECT NOW()');
    console.log('[DB] Connected. Server time:', result.rows[0].now);
  } finally {
    client.release();
  }
}

async function query(text, params) {
  const start = Date.now();
  const res = await pool.query(text, params);
  const duration = Date.now() - start;
  if (duration > 1000) {
    console.warn('[DB] Slow query detected:', { text, duration, rows: res.rowCount });
  }
  return res;
}

module.exports = { pool, query, testConnection };
