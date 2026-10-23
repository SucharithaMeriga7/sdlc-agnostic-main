-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS
-- Object Type   : TABLE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-03, FR-04
-- Reuse Route   : MODIFY_EXISTING
-- Description   : Target SCD Type 1 parts table. DELTA: adds STATUS and CREATED_AT columns to support soft-delete (BR-05) and source audit trail.
-- Author        : Sucharitha
-- Created Date  : 2026-10-23
-- Dependencies  :
--   - none
-- Business Rules: BR-04, BR-05
-- Change History:
--   2026-10-23  Sucharitha  SCRUM-158  Initial generation (MODIFY_EXISTING)
-- =============================================================================

-- ============================================================
-- Aerospace Parts Inventory Integration Pipeline
-- DELTA: add STATUS and CREATED_AT columns if not present
-- ============================================================

-- DELTA: soft-delete status column (BR-05)
ALTER TABLE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS
    ADD COLUMN IF NOT EXISTS STATUS VARCHAR(50);

-- DELTA: source creation timestamp carried from source
ALTER TABLE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS
    ADD COLUMN IF NOT EXISTS CREATED_AT TIMESTAMP_NTZ(9);
