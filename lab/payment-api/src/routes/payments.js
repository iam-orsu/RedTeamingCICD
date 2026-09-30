const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { query } = require('../db/connection');
const { authenticateMerchant } = require('../middleware/auth');

const router = express.Router();

// POST /api/v1/payments - initiate a payment
router.post('/', authenticateMerchant, async (req, res) => {
  const { amount, currency = 'INR', payment_method, order_id, upi_vpa, card_last4, card_network, metadata = {} } = req.body;

  if (!amount || isNaN(amount) || Number(amount) <= 0) {
    return res.status(400).json({ error: 'Invalid amount. Must be a positive number.' });
  }

  if (!payment_method) {
    return res.status(400).json({ error: 'payment_method is required (upi, card, netbanking, wallet)' });
  }

  const txnId = uuidv4();

  try {
    const result = await query(
      `INSERT INTO transactions
        (id, merchant_id, order_id, amount, currency, status, payment_method, upi_vpa, card_last4, card_network, metadata)
       VALUES ($1, $2, $3, $4, $5, 'pending', $6, $7, $8, $9, $10)
       RETURNING id, amount, currency, status, payment_method, created_at`,
      [txnId, req.merchant.id, order_id || null, amount, currency, payment_method,
       upi_vpa || null, card_last4 || null, card_network || null, JSON.stringify(metadata)]
    );

    const txn = result.rows[0];

    // Simulate async processing - in production this calls the payment gateway
    setTimeout(() => processPayment(txnId), 2000);

    return res.status(201).json({
      transaction_id: txn.id,
      status: txn.status,
      amount: txn.amount,
      currency: txn.currency,
      payment_method: txn.payment_method,
      created_at: txn.created_at,
      message: 'Payment initiated. Poll /api/v1/payments/' + txn.id + ' for status.'
    });
  } catch (err) {
    console.error('[PAYMENTS] Error creating transaction:', err);
    return res.status(500).json({ error: 'Failed to initiate payment' });
  }
});

// GET /api/v1/payments/:id - get transaction status
router.get('/:id', authenticateMerchant, async (req, res) => {
  try {
    const result = await query(
      `SELECT id, order_id, amount, currency, status, payment_method,
              upi_vpa, card_last4, card_network, gateway_txn_id,
              failure_reason, metadata, initiated_at, completed_at, created_at
       FROM transactions
       WHERE id = $1 AND merchant_id = $2`,
      [req.params.id, req.merchant.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Transaction not found' });
    }

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('[PAYMENTS] Error fetching transaction:', err);
    return res.status(500).json({ error: 'Failed to fetch transaction' });
  }
});

// GET /api/v1/payments - list transactions with pagination
router.get('/', authenticateMerchant, async (req, res) => {
  const page = parseInt(req.query.page || '1');
  const limit = Math.min(parseInt(req.query.limit || '20'), 100);
  const offset = (page - 1) * limit;
  const status = req.query.status;

  try {
    let whereClause = 'WHERE merchant_id = $1';
    let params = [req.merchant.id];

    if (status) {
      whereClause += ' AND status = $2';
      params.push(status);
    }

    const countResult = await query(
      `SELECT COUNT(*) FROM transactions ${whereClause}`,
      params
    );

    const dataResult = await query(
      `SELECT id, order_id, amount, currency, status, payment_method,
              initiated_at, completed_at, created_at
       FROM transactions ${whereClause}
       ORDER BY created_at DESC
       LIMIT ${limit} OFFSET ${offset}`,
      params
    );

    return res.json({
      data: dataResult.rows,
      pagination: {
        page,
        limit,
        total: parseInt(countResult.rows[0].count),
        pages: Math.ceil(parseInt(countResult.rows[0].count) / limit)
      }
    });
  } catch (err) {
    console.error('[PAYMENTS] Error listing transactions:', err);
    return res.status(500).json({ error: 'Failed to list transactions' });
  }
});

// POST /api/v1/payments/:id/refund
router.post('/:id/refund', authenticateMerchant, async (req, res) => {
  try {
    const result = await query(
      `SELECT id, amount, status, merchant_id FROM transactions WHERE id = $1 AND merchant_id = $2`,
      [req.params.id, req.merchant.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Transaction not found' });
    }

    const txn = result.rows[0];

    if (txn.status !== 'success') {
      return res.status(400).json({ error: 'Only successful transactions can be refunded' });
    }

    await query(
      `UPDATE transactions SET status = 'refunded', updated_at = NOW() WHERE id = $1`,
      [req.params.id]
    );

    return res.json({ message: 'Refund initiated', transaction_id: req.params.id });
  } catch (err) {
    console.error('[PAYMENTS] Error processing refund:', err);
    return res.status(500).json({ error: 'Failed to process refund' });
  }
});

async function processPayment(txnId) {
  // Simulate gateway response (90% success rate in demo)
  const success = Math.random() > 0.1;
  const status = success ? 'success' : 'failed';
  const gatewayTxnId = success ? `PAY${Date.now()}` : null;
  const failureReason = success ? null : 'Insufficient funds';

  try {
    await query(
      `UPDATE transactions
       SET status = $1, gateway_txn_id = $2, failure_reason = $3, completed_at = NOW(), updated_at = NOW()
       WHERE id = $4`,
      [status, gatewayTxnId, failureReason, txnId]
    );
  } catch (err) {
    console.error('[PAYMENTS] Error updating transaction status:', err);
  }
}

module.exports = router;
