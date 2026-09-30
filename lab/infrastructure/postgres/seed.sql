-- CeruleanPay seed data for lab environment
-- Creates test merchants and realistic transaction history
-- DO NOT use in production

-- Test merchants
INSERT INTO merchants (id, name, email, phone, gstin, api_key, api_key_hash, status, settlement_account)
VALUES
  ('a1b2c3d4-0001-0001-0001-000000000001',
   'TechMart Electronics',
   'payments@techmart.in',
   '+91-9876543210',
   '29ABCDE1234F1Z5',
   'cp_live_aa1bb2cc3dd4ee5ff6gg7hh8ii9jj0kk1ll2mm3nn4oo5pp6',
   '$2b$10$placeholder_hash_techmart_001',
   'active',
   'HDFC000012345678'),
  ('a1b2c3d4-0002-0002-0002-000000000002',
   'QuickBite Food Delivery',
   'finance@quickbite.co.in',
   '+91-8765432109',
   '27FGHIJ5678K2A6',
   'cp_live_bb2cc3dd4ee5ff6gg7hh8ii9jj0kk1ll2mm3nn4oo5pp6qq7',
   '$2b$10$placeholder_hash_quickbite_002',
   'active',
   'ICIC000098765432'),
  ('a1b2c3d4-0003-0003-0003-000000000003',
   'Sunrise Pharmacy Chain',
   'accounts@sunrisepharm.com',
   '+91-7654321098',
   '36KLMNO9012P3B7',
   'cp_live_cc3dd4ee5ff6gg7hh8ii9jj0kk1ll2mm3nn4oo5pp6qq7rr8',
   '$2b$10$placeholder_hash_sunrise_003',
   'active',
   'SBIN000056789012'),
  ('a1b2c3d4-0004-0004-0004-000000000004',
   'Fashion Forward',
   'billing@fashionforward.in',
   '+91-6543210987',
   '33PQRST3456Q4C8',
   'cp_live_dd4ee5ff6gg7hh8ii9jj0kk1ll2mm3nn4oo5pp6qq7rr8ss9',
   '$2b$10$placeholder_hash_fashion_004',
   'suspended',
   'AXIS000034567890')
ON CONFLICT (id) DO NOTHING;

-- Realistic transaction history (last 30 days)
INSERT INTO transactions (id, merchant_id, order_id, amount, currency, status, payment_method, upi_vpa, gateway_txn_id, initiated_at, completed_at)
VALUES
  ('t0000001-0001-0001-0001-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'TM-ORD-20241001-001', 45999.00, 'INR', 'success', 'upi', 'customer1@okaxis', 'PAY20241001001', NOW() - INTERVAL '29 days', NOW() - INTERVAL '29 days' + INTERVAL '3 seconds'),
  ('t0000001-0001-0001-0001-000000000002', 'a1b2c3d4-0001-0001-0001-000000000001', 'TM-ORD-20241002-002', 12500.50, 'INR', 'success', 'card', NULL, 'PAY20241002002', NOW() - INTERVAL '28 days', NOW() - INTERVAL '28 days' + INTERVAL '5 seconds'),
  ('t0000001-0001-0001-0001-000000000003', 'a1b2c3d4-0001-0001-0001-000000000001', 'TM-ORD-20241003-003', 89000.00, 'INR', 'success', 'upi', 'business@ybl', 'PAY20241003003', NOW() - INTERVAL '27 days', NOW() - INTERVAL '27 days' + INTERVAL '2 seconds'),
  ('t0000001-0001-0001-0001-000000000004', 'a1b2c3d4-0001-0001-0001-000000000001', 'TM-ORD-20241004-004', 3299.00, 'INR', 'failed', 'netbanking', NULL, NULL, NOW() - INTERVAL '26 days', NOW() - INTERVAL '26 days' + INTERVAL '10 seconds'),
  ('t0000001-0001-0001-0001-000000000005', 'a1b2c3d4-0001-0001-0001-000000000001', 'TM-ORD-20241005-005', 155000.00, 'INR', 'success', 'card', NULL, 'PAY20241005005', NOW() - INTERVAL '25 days', NOW() - INTERVAL '25 days' + INTERVAL '4 seconds'),
  ('t0000002-0002-0002-0002-000000000001', 'a1b2c3d4-0002-0002-0002-000000000002', 'QB-20241001-1001', 450.00, 'INR', 'success', 'upi', 'user2@paytm', 'PAY20241001101', NOW() - INTERVAL '29 days', NOW() - INTERVAL '29 days' + INTERVAL '1 second'),
  ('t0000002-0002-0002-0002-000000000002', 'a1b2c3d4-0002-0002-0002-000000000002', 'QB-20241001-1002', 850.00, 'INR', 'success', 'upi', 'user3@gpay', 'PAY20241001102', NOW() - INTERVAL '29 days', NOW() - INTERVAL '29 days' + INTERVAL '1 second'),
  ('t0000002-0002-0002-0002-000000000003', 'a1b2c3d4-0002-0002-0002-000000000002', 'QB-20241002-1003', 1200.50, 'INR', 'success', 'wallet', NULL, 'PAY20241002103', NOW() - INTERVAL '28 days', NOW() - INTERVAL '28 days' + INTERVAL '2 seconds'),
  ('t0000002-0002-0002-0002-000000000004', 'a1b2c3d4-0002-0002-0002-000000000002', 'QB-20241003-1004', 320.00, 'INR', 'failed', 'upi', 'user4@phonepe', NULL, NOW() - INTERVAL '27 days', NOW() - INTERVAL '27 days' + INTERVAL '30 seconds'),
  ('t0000002-0002-0002-0002-000000000005', 'a1b2c3d4-0002-0002-0002-000000000002', 'QB-20241003-1005', 680.00, 'INR', 'success', 'upi', 'user5@okicici', 'PAY20241003105', NOW() - INTERVAL '27 days', NOW() - INTERVAL '27 days' + INTERVAL '1 second'),
  ('t0000003-0003-0003-0003-000000000001', 'a1b2c3d4-0003-0003-0003-000000000003', 'SP-RX-2024100001', 2450.00, 'INR', 'success', 'upi', 'patient1@sbi', 'PAY20241001201', NOW() - INTERVAL '29 days', NOW() - INTERVAL '29 days' + INTERVAL '2 seconds'),
  ('t0000003-0003-0003-0003-000000000002', 'a1b2c3d4-0003-0003-0003-000000000003', 'SP-RX-2024100002', 8900.00, 'INR', 'success', 'card', NULL, 'PAY20241001202', NOW() - INTERVAL '29 days', NOW() - INTERVAL '29 days' + INTERVAL '4 seconds'),
  ('t0000003-0003-0003-0003-000000000003', 'a1b2c3d4-0003-0003-0003-000000000003', 'SP-RX-2024100003', 15600.75, 'INR', 'success', 'netbanking', NULL, 'PAY20241002203', NOW() - INTERVAL '28 days', NOW() - INTERVAL '28 days' + INTERVAL '8 seconds')
ON CONFLICT (id) DO NOTHING;

-- Grant table permissions to app user
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO cerulean_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO cerulean_app;
