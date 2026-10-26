-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
-- Object Type   : TABLE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-03, FR-04
-- Reuse Route   : ADAPT_EXISTING
-- Description   : Delta: ensure audit columns LAST_MODIFIED_AT, LOAD_TYPE, PIPELINE_RUN_TS exist (already present in existing DDL). No structural change needed; object shown for completeness of ADAPT decision.
-- Author        : Sucharitha
-- Created Date  : 2026-10-26
-- Dependencies  :
--   - none
-- Business Rules: BR-04, BR-05
-- Change History:
--   2026-10-26  Sucharitha  SCRUM-158  Initial generation (ADAPT_EXISTING)
-- =============================================================================

-- DELTA: Verify and add any missing audit columns to AEROSPACE_PARTS_TARGET
-- Per existing DDL, LAST_MODIFIED_AT, LOAD_TYPE, PIPELINE_RUN_TS already exist.
-- DELTA: Add RISK_SCORE column if somehow absent (idempotent guard via TRY)
-- All columns confirmed present in existing DDL; issuing idempotent ALTERs as safety net.

-- DELTA: Ensure LAST_MODIFIED_AT exists (already present, ALTER is a no-op if column exists)
ALTER TABLE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
    ADD COLUMN IF NOT EXISTS LAST_MODIFIED_AT TIMESTAMP_NTZ(9); -- DELTA: audit column

-- DELTA: Ensure LOAD_TYPE exists
ALTER TABLE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
    ADD COLUMN IF NOT EXISTS LOAD_TYPE VARCHAR(20); -- DELTA: full vs incremental indicator

-- DELTA: Ensure PIPELINE_RUN_TS exists
ALTER TABLE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
    ADD COLUMN IF NOT EXISTS PIPELINE_RUN_TS TIMESTAMP_NTZ(9); -- DELTA: pipeline execution timestamp

-- DELTA: Ensure RISK_SCORE exists with correct type
ALTER TABLE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
    ADD COLUMN IF NOT EXISTS RISK_SCORE VARCHAR(20); -- DELTA: derived risk score per BR-08 to BR-11
