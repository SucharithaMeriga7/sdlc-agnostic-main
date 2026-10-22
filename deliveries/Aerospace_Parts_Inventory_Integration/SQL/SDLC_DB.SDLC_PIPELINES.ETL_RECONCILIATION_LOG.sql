-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
-- Object Type   : TABLE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-08
-- Reuse Route   : CREATE_NEW
-- Description   : Reconciliation log table capturing per-run metrics: source count, target count, inserted, updated, soft-deleted.
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - none
-- Business Rules: BR-12
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

-- Reconciliation log: one row per pipeline execution (BR-12).
-- Column names and types match exactly what the procedure INSERTs.
CREATE TABLE IF NOT EXISTS SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
    LOG_ID              NUMBER          AUTOINCREMENT PRIMARY KEY,
    PIPELINE_NAME       VARCHAR(200)    NOT NULL,
    RUN_TIMESTAMP       TIMESTAMP_NTZ   NOT NULL,          -- time the reconciliation record is written
    SOURCE_COUNT        NUMBER(18,0)    NOT NULL,          -- records in current extract
    TARGET_COUNT        NUMBER(18,0)    NOT NULL,          -- total active records in target after run
    INSERTED_COUNT      NUMBER(18,0)    NOT NULL,          -- new rows inserted by MERGE
    UPDATED_COUNT       NUMBER(18,0)    NOT NULL,          -- existing rows updated by MERGE
    SOFT_DELETED_COUNT  NUMBER(18,0)    NOT NULL,          -- rows marked Decommissioned (BR-05)
    RUN_STATUS          VARCHAR(50)     NOT NULL           -- SUCCEEDED / FAILED
);
