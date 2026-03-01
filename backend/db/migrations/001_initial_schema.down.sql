-- ============================================================================
-- Unnati Retail OS — Schema Rollback
-- Copyright (c) 2026 Walsong Group. All rights reserved.
-- ============================================================================

DROP TRIGGER IF EXISTS trg_ledger_update_debt ON ledger_entries;
DROP TRIGGER IF EXISTS trg_staff_updated_at ON staff;
DROP TRIGGER IF EXISTS trg_customers_updated_at ON customers;
DROP TRIGGER IF EXISTS trg_products_updated_at ON products;
DROP FUNCTION IF EXISTS update_customer_debt();
DROP FUNCTION IF EXISTS update_updated_at();
DROP FUNCTION IF EXISTS generate_bill_number();
DROP SEQUENCE IF EXISTS bill_number_seq;

DROP MATERIALIZED VIEW IF EXISTS sales_daily;
DROP TABLE IF EXISTS device_registry;
DROP TABLE IF EXISTS sync_queue;
DROP TABLE IF EXISTS ledger_entries;
DROP TABLE IF EXISTS sale_items;
DROP TABLE IF EXISTS sales;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS staff;
DROP TABLE IF EXISTS unit_conversions;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS product_categories;
DROP TABLE IF EXISTS units;

DROP EXTENSION IF EXISTS pg_trgm;
DROP EXTENSION IF EXISTS timescaledb CASCADE;
DROP EXTENSION IF EXISTS "uuid-ossp";
