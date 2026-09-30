const express = require('express');
const bcrypt = require('bcrypt');
const crypto = require('crypto');
const { query } = require('../db/connection');
const { authenticateMerchant } = require('../middleware/auth');

const router = express.Router();

function generateApiKey() {
  return 'cp_live_' + crypto.randomBytes(24).toString('hex');
}

// POST /api/v1/merchants - register a new merchant (internal admin use)
router.post('/', async (req, res) => {
  const adminKey = req.headers['x-admin-key'];

  // Simple admin key check - replace with proper IAM in production
  if (adminKey !== process.env.ADMIN_API_KEY) {
    return res.status(403).json({ error: 'Forbidden' });
  }

  const { name, email, phone, gstin, settlement_account } = req.body;

  if (!name || !email) {
    return res.status(400).json({ error: 'name and email are required' });
  }

  const apiKey = generateApiKey();
  const apiKeyHash = await bcrypt.hash(apiKey, 10);

  try {
    const result = await query(
      `INSERT INTO merchants (name, email, phone, gstin, api_key, api_key_hash, settlement_account)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, name, email, status, created_at`,
      [name, email, phone || null, gstin || null, apiKey, apiKeyHash, settlement_account || null]
    );

    return res.status(201).json({
      merchant: result.rows[0],
      api_key: apiKey,
      message: 'Store this API key securely. It will not be shown again.'
    });
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Merchant with this email already exists' });
    }
    console.error('[MERCHANTS] Error creating merchant:', err);
    return res.status(500).json({ error: 'Failed to create merchant' });
  }
});

// GET /api/v1/merchants/me - get own merchant profile
router.get('/me', authenticateMerchant, async (req, res) => {
  try {
    const result = await query(
      `SELECT id, name, email, phone, gstin, status, settlement_account, created_at
       FROM merchants WHERE id = $1`,
      [req.merchant.id]
    );
    return res.json(result.rows[0]);
  } catch (err) {
    console.error('[MERCHANTS] Error fetching merchant:', err);
    return res.status(500).json({ error: 'Failed to fetch merchant details' });
  }
});

// GET /api/v1/merchants/me/stats - transaction summary
router.get('/me/stats', authenticateMerchant, async (req, res) => {
  try {
    const result = await query(
      `SELECT
         COUNT(*) FILTER (WHERE status = 'success') AS successful_count,
         COUNT(*) FILTER (WHERE status = 'failed') AS failed_count,
         COUNT(*) FILTER (WHERE status = 'pending') AS pending_count,
         COALESCE(SUM(amount) FILTER (WHERE status = 'success'), 0) AS total_collected,
         COALESCE(AVG(amount) FILTER (WHERE status = 'success'), 0) AS avg_transaction
       FROM transactions
       WHERE merchant_id = $1
         AND created_at > NOW() - INTERVAL '30 days'`,
      [req.merchant.id]
    );
    return res.json({ period: '30d', ...result.rows[0] });
  } catch (err) {
    console.error('[MERCHANTS] Error fetching stats:', err);
    return res.status(500).json({ error: 'Failed to fetch stats' });
  }
});

module.exports = router;
