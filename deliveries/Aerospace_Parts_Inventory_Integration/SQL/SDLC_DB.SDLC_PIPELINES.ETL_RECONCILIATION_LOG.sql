-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
-- Object Type   : TABLE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-08
-- Reuse Route   : CREATE_NEW
-- Description   : Audit log capturing reconciliation metrics after every pipeline run (BR-12).
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - none
-- Business Rules: BR-12
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE TABLE IF NOT EXISTS SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
    LOG_ID              NUMBER AUTOINCREMENT PRIMARY KEY,
    PIPELINE_NAME       VARCHAR(200)    NOT NULL,
    RUN_TIMESTAMP       TIMESTAMP_NTZ   NOT NULL,   -- BR-12: timestamp of this run
    SOURCE_COUNT        NUMBER(38,0),               -- BR-12: rows in source extract
    TARGET_COUNT        NUMBER(38,0),               -- BR-12: rows in target after merge
    INSERTED_COUNT      NUMBER(38,0),               -- BR-12: new rows inserted
    UPDATED_COUNT       NUMBER(38,0),               -- BR-12: existing rows updated
    SOFT_DELETED_COUNT  NUMBER(38,0),               -- BR-12: rows marked Decommissioned
    STATUS              VARCHAR(50),
    NOTES               TEXT
);
