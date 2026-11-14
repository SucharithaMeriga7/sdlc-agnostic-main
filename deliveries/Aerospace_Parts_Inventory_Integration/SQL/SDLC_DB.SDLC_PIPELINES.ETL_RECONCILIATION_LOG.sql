-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
-- Object Type   : TABLE
-- Jira Story    : SCRUM-159
-- Requirements  : FR-08
-- Reuse Route   : ADAPT_EXISTING
-- Description   : Reconciliation log adapted from existing ETL_RECONCILIATION_LOG. All required columns already present; CREATE OR REPLACE preserves structure idempotently.
-- Author        : Sucharitha
-- Created Date  : 2026-11-14
-- Dependencies  :
--   - none
-- Business Rules: BR-12
-- Change History:
--   2026-11-14  Sucharitha  SCRUM-159  Initial generation (ADAPT_EXISTING)
-- =============================================================================

-- DELTA: Ensure ETL_RECONCILIATION_LOG exists with all columns required by BR-12.
-- Using CREATE TABLE IF NOT EXISTS for idempotency; existing data is preserved.
CREATE TABLE IF NOT EXISTS SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
    LOG_ID               NUMBER(38,0)     NOT NULL AUTOINCREMENT START 1 INCREMENT 1 NOORDER
                         COMMENT 'Auto-incremented surrogate primary key uniquely identifying each reconciliation log entry.',
    PIPELINE_NAME        VARCHAR(200)     COMMENT 'Name of the pipeline that produced this log entry',
    RUN_TS               TIMESTAMP_NTZ(9) COMMENT 'Wall-clock timestamp when this pipeline run started',
    LOAD_TYPE            VARCHAR(20)      COMMENT 'FULL or INCREMENTAL - indicates which load mode was used',
    WATERMARK_USED       TIMESTAMP_NTZ(9) COMMENT 'The UPDATED_AT watermark applied for incremental filtering (NULL for full load)',
    SOURCE_COUNT         NUMBER(18,0)     COMMENT 'Total records read from source before exclusions',
    EXCLUDED_COUNT       NUMBER(18,0)     COMMENT 'Records excluded by End-of-Life + age rule',
    DEDUPLICATED_COUNT   NUMBER(18,0)     COMMENT 'Records after deduplication (latest UPDATED_AT per PART_NUMBER)',
    INSERTED_COUNT       NUMBER(18,0)     COMMENT 'Number of new records inserted into PARTS',
    UPDATED_COUNT        NUMBER(18,0)     COMMENT 'Number of existing records updated via SCD Type 1 overwrite',
    DELETED_COUNT        NUMBER(18,0)     COMMENT 'Records soft-deleted (marked Decommissioned) in target',
    TARGET_COUNT         NUMBER(18,0)     COMMENT 'Total active (non-Decommissioned) records in target after load',
    PIPELINE_STATUS      VARCHAR(20)      COMMENT 'Overall run status: SUCCESS or FAILED',
    ERROR_MESSAGE        VARCHAR(4000)    COMMENT 'Error detail if PIPELINE_STATUS = FAILED; NULL on success',
    JIRA_ISSUE           VARCHAR(50)      DEFAULT 'SCRUM-62' COMMENT 'Jira issue key for traceability',
    DISCREPANCY_COUNT    NUMBER(18,0)     COMMENT 'Absolute difference between DEDUPLICATED_COUNT and (INSERTED_COUNT + UPDATED_COUNT) per BR-12',
    CONSTRAINT PK_ETL_RECONCILIATION_LOG PRIMARY KEY (LOG_ID)
);
