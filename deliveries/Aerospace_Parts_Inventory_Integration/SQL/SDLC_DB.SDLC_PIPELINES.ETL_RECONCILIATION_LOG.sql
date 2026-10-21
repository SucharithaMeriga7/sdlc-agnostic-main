-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
-- Object Type   : TABLE
-- Jira Story    : SCRUM-156
-- Requirements  : FR-08
-- Reuse Route   : CREATE_NEW
-- Description   : Audit/reconciliation log table capturing per-run metrics: source count, target count, inserted, updated, soft-deleted, status, and details (BR-09).
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - none
-- Business Rules: BR-09
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-156  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE TABLE IF NOT EXISTS SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
    -- FR-08/BR-09: Reconciliation log schema
    RUN_ID                  VARCHAR(64)         NOT NULL    COMMENT 'Unique identifier for each pipeline run (UUID or timestamp-based)',
    EXECUTION_TS            TIMESTAMP_NTZ       NOT NULL    COMMENT 'UTC timestamp when the pipeline run executed',
    SOURCE_COUNT            NUMBER(18,0)        NOT NULL    COMMENT 'Total records in source extract for this run',
    TARGET_COUNT            NUMBER(18,0)        NOT NULL    COMMENT 'Total records in target table after merge',
    INSERTED                NUMBER(18,0)        NOT NULL    COMMENT 'Count of net-new records inserted during MERGE',
    UPDATED                 NUMBER(18,0)        NOT NULL    COMMENT 'Count of existing records updated (SCD1 overwrite)',
    SOFT_DELETED            NUMBER(18,0)        NOT NULL    COMMENT 'Count of records soft-deleted (status set to Decommissioned)',
    RECONCILIATION_STATUS   VARCHAR(20)         NOT NULL    COMMENT 'PASS or FAIL based on discrepancy check',
    DETAILS                 VARCHAR(4000)                   COMMENT 'Free-text details, discrepancy descriptions, or error messages'
)
COMMENT = 'ETL reconciliation log for aerospace parts pipeline. FR-08/BR-09.'
;
