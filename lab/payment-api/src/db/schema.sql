-- CeruleanPay Database Schema
-- Version: 2.1.0
-- Run this against PostgreSQL 14+ to initialize the database

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Merchants registered on the platform
CREATE TABLE IF NOT EXISTS merchants (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name          VARCHAR(200) NOT NULL,
    email         VARCHAR(255) UNIQUE NOT NULL,
    phone         VARCHAR(20),
    gstin         VARCHAR(15),
    api_key       VARCHAR(64) UNIQUE NOT NULL,
    api_key_hash  VARCHAR(128) NOT NULL,
    status        VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'pending')),
    settlement_account VARCHAR(50),
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_merchants_api_key ON merchants(api_key);
CREATE INDEX IF NOT EXISTS idx_merchants_email ON merchants(email);

-- Payment transactions
CREATE TABLE IF NOT EXISTS transactions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    merchant_id     UUID NOT NULL REFERENCES merchants(id),
    order_id        VARCHAR(100),
    amount          NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    currency        VARCHAR(3) DEFAULT 'INR',
    status          VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'success', 'failed', 'refunded')),
    payment_method  VARCHAR(30) CHECK (payment_method IN ('upi', 'card', 'netbanking', 'wallet')),
    upi_vpa         VARCHAR(100),
    card_last4      VARCHAR(4),
    card_network    VARCHAR(20),
    gateway_txn_id  VARCHAR(100),
    failure_reason  VARCHAR(500),
    metadata        JSONB DEFAULT '{}',
    initiated_at    TIMESTAMPTZ DEFAULT NOW(),
    completed_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transactions_merchant ON transactions(merchant_id);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status);
CREATE INDEX IF NOT EXISTS idx_transactions_created ON transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_order ON transactions(order_id);

-- Settlement batches
CREATE TABLE IF NOT EXISTS settlements (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    merchant_id     UUID NOT NULL REFERENCES merchants(id),
    amount          NUMERIC(12, 2) NOT NULL,
    fee             NUMERIC(12, 2) DEFAULT 0,
    net_amount      NUMERIC(12, 2) NOT NULL,
    status          VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    utr             VARCHAR(50),
    settled_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Webhook endpoints configured by merchants
CREATE TABLE IF NOT EXISTS webhooks (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    merchant_id     UUID NOT NULL REFERENCES merchants(id),
    url             VARCHAR(500) NOT NULL,
    secret          VARCHAR(128) NOT NULL,
    events          TEXT[] DEFAULT '{"payment.success", "payment.failed"}',
    active          BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Audit log for all API operations
CREATE TABLE IF NOT EXISTS audit_log (
    id              BIGSERIAL PRIMARY KEY,
    merchant_id     UUID REFERENCES merchants(id),
    action          VARCHAR(100) NOT NULL,
    resource_type   VARCHAR(50),
    resource_id     UUID,
    ip_address      INET,
    user_agent      VARCHAR(500),
    request_body    JSONB,
    response_code   INTEGER,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_merchant ON audit_log(merchant_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_log(created_at DESC);

-- Update trigger for updated_at columns
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER merchants_updated_at
    BEFORE UPDATE ON merchants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER transactions_updated_at
    BEFORE UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
