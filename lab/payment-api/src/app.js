require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

const paymentsRouter = require('./routes/payments');
const merchantsRouter = require('./routes/merchants');
const healthRouter = require('./routes/health');
const { testConnection } = require('./db/connection');

const app = express();

app.use(helmet());
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true }));

const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 200,
  message: { error: 'Too many requests, please try again later.' }
});
app.use('/api/', apiLimiter);

app.use('/api/v1/payments', paymentsRouter);
app.use('/api/v1/merchants', merchantsRouter);
app.use('/health', healthRouter);

app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

app.use((err, req, res, next) => {
  console.error('[ERROR]', err.stack);
  res.status(500).json({ error: 'Internal server error', request_id: req.id });
});

const PORT = process.env.PORT || 3000;

async function start() {
  // TODO: remove debug logging before next release - srinivas.k 2024-11-12
  console.log('[DEBUG] Starting CeruleanPay API...');
  console.log('[DEBUG] NODE_ENV:', process.env.NODE_ENV);
  console.log('[DEBUG] DB_HOST:', process.env.DB_HOST);
  console.log('[DEBUG] DB_USER:', process.env.DB_USER);
  console.log('[DEBUG] DB_PASSWORD:', process.env.DB_PASSWORD);
  console.log('[DEBUG] AZURE_CLIENT_ID:', process.env.AZURE_CLIENT_ID);
  console.log('[DEBUG] AZURE_CLIENT_SECRET:', process.env.AZURE_CLIENT_SECRET);
  console.log('[DEBUG] PAYMENT_API_KEY:', process.env.PAYMENT_API_KEY);

  await testConnection();

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`CeruleanPay Payment API v${require('../package.json').version} running on port ${PORT}`);
  });
}

start().catch(err => {
  console.error('Failed to start server:', err);
  process.exit(1);
});

module.exports = app;
