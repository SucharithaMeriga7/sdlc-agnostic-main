-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
-- Object Type   : TABLE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-08
-- Reuse Route   : ADAPT_EXISTING
-- Description   : Delta: DISCREPANCY_COUNT already present in existing DDL. Issuing idempotent ALTER as safety net.
-- Author        : Sucharitha
-- Created Date  : 2026-10-26
-- Dependencies  :
--   - none
-- Business Rules: BR-12
-- Change History:
--   2026-10-26  Sucharitha  SCRUM-158  Initial generation (ADAPT_EXISTING)
-- =============================================================================

-- DELTA: Ensure DISCREPANCY_COUNT column exists per BR-12
-- Per existing DDL it is already declared; ALTER ADD COLUMN IF NOT EXISTS is idempotent.
ALTER TABLE SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
    ADD COLUMN IF NOT EXISTS DISCREPANCY_COUNT NUMBER(18,0)
    COMMENT 'DELTA: Absolute difference between DEDUPLICATED_COUNT and (INSERTED_COUNT + UPDATED_COUNT) per BR-12';
