const { query } = require('../db/connection');

async function authenticateMerchant(req, res, next) {
  const apiKey = req.headers['x-api-key'] || req.headers['authorization']?.replace('Bearer ', '');

  if (!apiKey) {
    return res.status(401).json({
      error: 'Missing API key',
      message: 'Provide your API key via X-Api-Key header or Authorization: Bearer <key>'
    });
  }

  try {
    const result = await query(
      'SELECT id, name, status FROM merchants WHERE api_key = $1',
      [apiKey]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid API key' });
    }

    const merchant = result.rows[0];

    if (merchant.status !== 'active') {
      return res.status(403).json({
        error: 'Merchant account suspended',
        status: merchant.status
      });
    }

    req.merchant = merchant;
    next();
  } catch (err) {
    console.error('[AUTH] Database error during auth:', err.message);
    return res.status(500).json({ error: 'Authentication service unavailable' });
  }
}

module.exports = { authenticateMerchant };
