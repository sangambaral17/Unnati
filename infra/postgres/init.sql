-- ============================================================================
-- Unnati Retail OS — PostgreSQL Init Script
-- Copyright (c) 2026 Walsong Group. All rights reserved.
-- ============================================================================

-- This script runs once when the Docker container is first created.
-- Run the proper schema via golang-migrate in the API container.

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Set performance-tuned parameters for an 8GB home server
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET work_mem = '16MB';
ALTER SYSTEM SET maintenance_work_mem = '128MB';
ALTER SYSTEM SET checkpoint_completion_target = '0.9';
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = '100';
ALTER SYSTEM SET random_page_cost = '1.1';        -- SSD-tuned
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET log_min_duration_statement = '1000'; -- Log queries > 1s
