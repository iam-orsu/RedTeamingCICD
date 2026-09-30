const express = require('express');
const { pool } = require('../db/connection');

const router = express.Router();

// GET /health - basic liveness probe
router.get('/', async (req, res) => {
  try {
    const client = await pool.connect();
    await client.query('SELECT 1');
    client.release();

    return res.json({
      status: 'ok',
      version: require('../../package.json').version,
      timestamp: new Date().toISOString(),
      db: 'connected'
    });
  } catch (err) {
    return res.status(503).json({
      status: 'degraded',
      db: 'disconnected',
      error: err.message
    });
  }
});

// GET /health/ready - readiness probe for Kubernetes / App Service
router.get('/ready', async (req, res) => {
  try {
    const client = await pool.connect();
    const result = await client.query('SELECT COUNT(*) FROM merchants WHERE status = $1', ['active']);
    client.release();

    return res.json({
      status: 'ready',
      active_merchants: parseInt(result.rows[0].count)
    });
  } catch (err) {
    return res.status(503).json({ status: 'not_ready', error: err.message });
  }
});

module.exports = router;
