-- CeruleanPay PostgreSQL initialization
-- This file runs once on first container start

\c ceruleanpay

-- Create application user with least privilege (read + write, no DDL)
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'cerulean_app') THEN
    CREATE ROLE cerulean_app WITH LOGIN PASSWORD 'PLACEHOLDER_SET_BY_DOCKER_COMPOSE';
  END IF;
END
$$;

GRANT CONNECT ON DATABASE ceruleanpay TO cerulean_app;
GRANT USAGE ON SCHEMA public TO cerulean_app;
