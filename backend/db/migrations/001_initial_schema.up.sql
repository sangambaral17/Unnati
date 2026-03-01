-- ============================================================================
-- Unnati Retail OS — PostgreSQL Schema (Migration 001)
-- Copyright (c) 2026 Walsong Group. All rights reserved.
-- Founder: Sangam Baral
-- 
-- Run: migrate -database $DATABASE_URL -path db/migrations up
-- Requirements: PostgreSQL 16 + TimescaleDB extension
-- ============================================================================

-- Enable TimescaleDB
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm; -- For fast product name search

-- ============================================================================
-- UNITS (Multi-unit inventory: Roll, Meter, Piece, Box, Kg...)
-- ============================================================================
CREATE TABLE units (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        VARCHAR(50) NOT NULL UNIQUE,  -- "Roll", "Meter", "Piece"
    short_name  VARCHAR(10) NOT NULL,         -- "Rl", "m", "pc"
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed standard Nepal retail units
INSERT INTO units (name, short_name) VALUES
    ('Piece',   'pc'),
    ('Box',     'bx'),
    ('Dozen',   'dz'),
    ('Roll',    'Rl'),
    ('Meter',   'm'),
    ('Kg',      'kg'),
    ('Gram',    'g'),
    ('Liter',   'L'),
    ('Bundle',  'bdl'),
    ('Bag',     'bg'),
    ('Packet',  'pkt'),
    ('Feet',    'ft'),
    ('Inch',    'in');

-- ============================================================================
-- PRODUCT CATEGORIES
-- ============================================================================
CREATE TABLE product_categories (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        VARCHAR(100) NOT NULL,
    parent_id   UUID REFERENCES product_categories(id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO product_categories (name) VALUES
    ('Hardware'),
    ('Electrical'),
    ('Kirana / Grocery'),
    ('Tools'),
    ('Plumbing'),
    ('Paint');

-- ============================================================================
-- PRODUCTS (Core Inventory Entity)
-- ============================================================================
CREATE TABLE products (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sku                 VARCHAR(50) NOT NULL UNIQUE,
    barcode             VARCHAR(50) UNIQUE,
    name                VARCHAR(200) NOT NULL,
    description         TEXT,
    category_id         UUID REFERENCES product_categories(id) ON DELETE SET NULL,
    buying_unit_id      UUID NOT NULL REFERENCES units(id),
    selling_unit_id     UUID NOT NULL REFERENCES units(id),
    stock_qty           NUMERIC(15, 4) NOT NULL DEFAULT 0,

    -- Pricing (SENSITIVE: cost_price hidden from Cashier role)
    cost_price          NUMERIC(15, 2) NOT NULL DEFAULT 0,
    selling_price       NUMERIC(15, 2) NOT NULL DEFAULT 0,
    wholesale_price     NUMERIC(15, 2),
    is_vat_applicable   BOOLEAN NOT NULL DEFAULT FALSE,

    -- Alerts
    reorder_level       NUMERIC(15, 4) NOT NULL DEFAULT 0,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,

    -- CDC fields
    device_id           UUID,                              -- Last modified by device
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Trigram index for fast fuzzy product name search
CREATE INDEX idx_products_name_trgm ON products USING GIN (name gin_trgm_ops);
CREATE INDEX idx_products_barcode ON products (barcode) WHERE barcode IS NOT NULL;

-- ============================================================================
-- UNIT CONVERSIONS (e.g., 1 Roll = 50 Meters for a specific product)
-- ============================================================================
CREATE TABLE unit_conversions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id      UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    from_unit_id    UUID NOT NULL REFERENCES units(id),
    to_unit_id      UUID NOT NULL REFERENCES units(id),
    factor          NUMERIC(15, 6) NOT NULL,    -- from_unit * factor = to_unit
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (product_id, from_unit_id, to_unit_id)
);

-- ============================================================================
-- STAFF & ACCESS CONTROL
-- ============================================================================
CREATE TABLE staff (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(100) NOT NULL,
    phone           VARCHAR(20) NOT NULL UNIQUE,
    pin             VARCHAR(255) NOT NULL,   -- bcrypt hashed 4-digit PIN
    role            VARCHAR(20) NOT NULL CHECK (role IN ('owner', 'manager', 'cashier')),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    last_login_at   TIMESTAMPTZ,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- CUSTOMERS (Udhari Credit System)
-- ============================================================================
CREATE TABLE customers (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(150) NOT NULL,
    phone           VARCHAR(20) UNIQUE,
    pan             VARCHAR(20),                         -- PAN for B2B invoices
    address         TEXT,
    credit_limit    NUMERIC(15, 2) NOT NULL DEFAULT 10000,
    current_debt    NUMERIC(15, 2) NOT NULL DEFAULT 0,   -- Running balance
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    device_id       UUID,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- SUPPLIERS (B2B Purchase System)
-- ============================================================================
CREATE TABLE suppliers (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(150) NOT NULL,
    phone           VARCHAR(20) UNIQUE,
    pan             VARCHAR(20),
    contact_person  VARCHAR(100),
    address         TEXT,
    current_payable NUMERIC(15, 2) NOT NULL DEFAULT 0,   -- Amount we owe them
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    device_id       UUID,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_suppliers_updated_at BEFORE UPDATE ON suppliers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================================
-- PURCHASE ORDERS (Stock In)
-- ============================================================================
CREATE TABLE purchase_orders (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    po_number       VARCHAR(50) NOT NULL UNIQUE,
    supplier_id     UUID NOT NULL REFERENCES suppliers(id),
    staff_id        UUID NOT NULL REFERENCES staff(id),
    status          VARCHAR(20) NOT NULL DEFAULT 'completed' CHECK (status IN ('draft', 'completed', 'cancelled')),
    payment_method  VARCHAR(20) NOT NULL DEFAULT 'cash' CHECK (payment_method IN ('cash', 'credit', 'bank')),
    
    -- Amounts
    total_amount    NUMERIC(15, 2) NOT NULL DEFAULT 0,
    paid_amount     NUMERIC(15, 2) NOT NULL DEFAULT 0,
    
    -- CDC
    device_id       UUID NOT NULL,
    received_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================================
-- SALES (Bills) — TimescaleDB Hypertable on sold_at
-- ============================================================================
CREATE TABLE sales (
    id              UUID NOT NULL,
    bill_number     VARCHAR(30) NOT NULL UNIQUE,
    staff_id        UUID NOT NULL REFERENCES staff(id),
    customer_id     UUID REFERENCES customers(id) ON DELETE SET NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft', 'held', 'completed', 'cancelled', 'refunded')),
    payment_method  VARCHAR(20) NOT NULL DEFAULT 'cash'
                    CHECK (payment_method IN ('cash', 'fonepay', 'credit', 'transfer')),

    -- Amounts
    sub_total       NUMERIC(15, 2) NOT NULL DEFAULT 0,
    discount_amt    NUMERIC(15, 2) NOT NULL DEFAULT 0,
    taxable_amount  NUMERIC(15, 2) NOT NULL DEFAULT 0,
    vat_amount      NUMERIC(15, 2) NOT NULL DEFAULT 0,   -- 13% VAT
    grand_total     NUMERIC(15, 2) NOT NULL DEFAULT 0,
    paid_amount     NUMERIC(15, 2) NOT NULL DEFAULT 0,
    change_amount   NUMERIC(15, 2) NOT NULL DEFAULT 0,

    -- SENSITIVE: net_profit hidden from Cashier role
    net_profit      NUMERIC(15, 2) NOT NULL DEFAULT 0,

    -- Compliance
    customer_pan    VARCHAR(20),
    fiscal_year     VARCHAR(10) NOT NULL,                -- "2081/82"
    notes           TEXT,

    -- Printing
    printed_at      TIMESTAMPTZ,
    print_count     INT NOT NULL DEFAULT 0,

    -- Fonepay QR reconciliation
    fonepay_qr_ref  VARCHAR(100),

    -- CDC
    device_id       UUID NOT NULL,
    sold_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),   -- TimescaleDB partition key
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (id, sold_at)                            -- Composite PK required for TimescaleDB
);

-- Convert sales to TimescaleDB hypertable (partitioned by month)
SELECT create_hypertable('sales', 'sold_at', chunk_time_interval => INTERVAL '1 month');

-- Create continuous aggregate for daily sales analytics
CREATE MATERIALIZED VIEW sales_daily
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 day', sold_at) AS day,
    staff_id,
    COUNT(*) AS total_bills,
    SUM(grand_total) AS total_revenue,
    SUM(vat_amount) AS total_vat,
    SUM(net_profit) AS total_profit
FROM sales
WHERE status = 'completed'
GROUP BY day, staff_id;

-- ============================================================================
-- SALE ITEMS (Line Items / Bill Detail)
-- ============================================================================
CREATE TABLE sale_items (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id             UUID NOT NULL,
    -- NOTE: No FK to sales due to TimescaleDB hypertable partition
    product_id          UUID NOT NULL REFERENCES products(id),
    product_name        VARCHAR(200) NOT NULL,    -- Denormalized for receipt snapshot
    qty                 NUMERIC(15, 4) NOT NULL,
    unit_id             UUID NOT NULL REFERENCES units(id),
    unit_price          NUMERIC(15, 2) NOT NULL,
    discount_pct        NUMERIC(5, 2) NOT NULL DEFAULT 0,
    is_vat_applicable   BOOLEAN NOT NULL DEFAULT FALSE,
    line_total          NUMERIC(15, 2) NOT NULL,

    -- SENSITIVE: cost_price hidden from Cashier role
    cost_price          NUMERIC(15, 2) NOT NULL DEFAULT 0,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sale_items_sale_id ON sale_items (sale_id);
CREATE INDEX idx_sale_items_product_id ON sale_items (product_id);

-- ============================================================================
-- LEDGER ENTRIES (Udhari — Immutable Double-Entry)
-- ============================================================================
CREATE TABLE ledger_entries (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id     UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    sale_id         UUID,                                    -- Optional link to bill
    type            VARCHAR(10) NOT NULL CHECK (type IN ('debit', 'credit')),
    amount          NUMERIC(15, 2) NOT NULL,
    running_balance NUMERIC(15, 2) NOT NULL,                 -- Balance AFTER this entry
    description     VARCHAR(255) NOT NULL,
    staff_id        UUID NOT NULL REFERENCES staff(id),

    -- Payment details (for credit entries)
    payment_method  VARCHAR(20) CHECK (payment_method IN ('cash', 'fonepay', 'credit', 'transfer')),
    fonepay_txn_id  VARCHAR(100),                            -- For QR reconciliation

    -- Credit aging
    due_date        TIMESTAMPTZ,
    is_overdue      BOOLEAN NOT NULL DEFAULT FALSE,

    -- CDC
    device_id       UUID NOT NULL,
    entry_date      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ledger_customer_id ON ledger_entries (customer_id);
CREATE INDEX idx_ledger_entry_date ON ledger_entries (entry_date DESC);

-- ============================================================================
-- CDC SYNC QUEUE (Tracks all changes for offline sync)
-- ============================================================================
CREATE TABLE sync_queue (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id   UUID NOT NULL,
    table_name  VARCHAR(50) NOT NULL,
    record_id   UUID NOT NULL,
    operation   VARCHAR(10) NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    payload     JSONB NOT NULL,
    local_seq   BIGINT NOT NULL,
    status      VARCHAR(20) NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'syncing', 'synced', 'failed', 'conflict')),
    retry_count INT NOT NULL DEFAULT 0,
    error_msg   TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    synced_at   TIMESTAMPTZ
);

CREATE INDEX idx_sync_queue_device_status ON sync_queue (device_id, status);
CREATE INDEX idx_sync_queue_local_seq ON sync_queue (device_id, local_seq);

-- ============================================================================
-- AUDIT TRAIL (Compliance & Security)
-- ============================================================================
CREATE TABLE audit_trail (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id   UUID NOT NULL,
    staff_id    UUID NOT NULL REFERENCES staff(id),
    action      VARCHAR(50) NOT NULL,    -- 'login', 'price_change', 'invoice_cancel', 'manual_sync', 'stock_adjustment'
    entity_name VARCHAR(50),             -- 'products', 'sales'
    entity_id   UUID,
    old_value   JSONB,
    new_value   JSONB,
    reason      TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_trail_created_at ON audit_trail (created_at DESC);
CREATE INDEX idx_audit_trail_staff on audit_trail(staff_id);

-- ============================================================================
-- DEVICE REGISTRY (Tracks all sync clients)
-- ============================================================================
CREATE TABLE device_registry (
    device_id       UUID PRIMARY KEY,
    device_name     VARCHAR(100) NOT NULL,
    staff_id        UUID NOT NULL REFERENCES staff(id),
    platform        VARCHAR(20) NOT NULL CHECK (platform IN ('windows', 'android', 'ios')),
    last_sync_at    TIMESTAMPTZ,
    last_sync_seq   BIGINT NOT NULL DEFAULT 0,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    registered_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- AUTOMATED FUNCTIONS
-- ============================================================================

-- Auto-update updated_at on products, customers, staff
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_customers_updated_at BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_staff_updated_at BEFORE UPDATE ON staff
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Update customer running debt when a ledger entry is inserted
CREATE OR REPLACE FUNCTION update_customer_debt()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.type = 'debit' THEN
        UPDATE customers SET current_debt = current_debt + NEW.amount
        WHERE id = NEW.customer_id;
    ELSIF NEW.type = 'credit' THEN
        UPDATE customers SET current_debt = current_debt - NEW.amount
        WHERE id = NEW.customer_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ledger_update_debt AFTER INSERT ON ledger_entries
    FOR EACH ROW EXECUTE FUNCTION update_customer_debt();

-- Bill number auto-generator (INV-YYMM-NNNNN format)
CREATE SEQUENCE IF NOT EXISTS bill_number_seq;

CREATE OR REPLACE FUNCTION generate_bill_number()
RETURNS TEXT AS $$
DECLARE
    seq_val BIGINT;
    fiscal TEXT;
BEGIN
    seq_val := nextval('bill_number_seq');
    -- Use Nepali fiscal year approximation
    fiscal := TO_CHAR(NOW(), 'YYMM');
    RETURN 'INV-' || fiscal || '-' || LPAD(seq_val::TEXT, 5, '0');
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SYNC LOG (Audit trail: which device sent which update and when)
-- ============================================================================
-- Unlike sync_queue (which is a local device concern), sync_log lives
-- on the PostgreSQL server and records every successfully applied sync batch.
-- This is the answer to: "Which device changed this row, and when?"
CREATE TABLE sync_log (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id       UUID NOT NULL,
    device_name     VARCHAR(100),
    staff_id        UUID REFERENCES staff(id),
    table_name      VARCHAR(50) NOT NULL,
    record_id       UUID NOT NULL,
    operation       VARCHAR(10) NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    payload_hash    VARCHAR(64),                                -- SHA-256 of the payload (dedup)
    local_seq       BIGINT NOT NULL,                            -- Device-side monotonic counter
    server_seq      BIGSERIAL,                                  -- Server-side monotonic counter
    conflict_status VARCHAR(20) DEFAULT 'none'
                    CHECK (conflict_status IN ('none', 'client_wins', 'server_wins')),
    applied_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    client_timestamp TIMESTAMPTZ NOT NULL,                      -- When the change was made on device
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sync_log_device ON sync_log (device_id, applied_at DESC);
CREATE INDEX idx_sync_log_table_record ON sync_log (table_name, record_id);
CREATE INDEX idx_sync_log_server_seq ON sync_log (server_seq);

-- ============================================================================
-- AUTO-DEDUCT STOCK ON sale_items INSERT
-- ============================================================================
-- Safety net: even if the application layer fails to deduct stock,
-- this trigger ensures consistency at the database level.
CREATE OR REPLACE FUNCTION deduct_product_stock()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE products
    SET stock_qty = stock_qty - NEW.qty,
        updated_at = NOW()
    WHERE id = NEW.product_id
      AND stock_qty >= NEW.qty;

    -- Raise an exception if the UPDATE matched zero rows (insufficient stock)
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Insufficient stock for product %', NEW.product_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sale_items_deduct_stock
    AFTER INSERT ON sale_items
    FOR EACH ROW
    EXECUTE FUNCTION deduct_product_stock();

