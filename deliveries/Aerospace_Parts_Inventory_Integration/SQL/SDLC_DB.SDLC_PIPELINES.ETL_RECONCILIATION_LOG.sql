-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
-- Object Type   : TABLE
-- Jira Story    : SCRUM-159
-- Requirements  : FR-08
-- Reuse Route   : ADAPT_EXISTING
-- Description   : Delta: DISCREPANCY_COUNT already added in existing DDL. All required columns present. No further structural change needed.
-- Author        : Sucharitha
-- Created Date  : 2026-10-26
-- Dependencies  :
--   - none
-- Business Rules: BR-12
-- Change History:
--   2026-10-26  Sucharitha  SCRUM-159  Initial generation (ADAPT_EXISTING)
-- =============================================================================

-- ADAPT_EXISTING: ETL_RECONCILIATION_LOG
-- All required columns already present in existing DDL including DISCREPANCY_COUNT.
-- DELTA: Ensure DISCREPANCY_COUNT comment is accurate - already defined.
-- Idempotent no-op; column presence confirmed by existing DDL.
ALTER TABLE SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
    ALTER COLUMN DISCREPANCY_COUNT COMMENT 'Absolute difference between DEDUPLICATED_COUNT and (INSERTED_COUNT + UPDATED_COUNT) per BR-12'; -- DELTA: refresh comment
