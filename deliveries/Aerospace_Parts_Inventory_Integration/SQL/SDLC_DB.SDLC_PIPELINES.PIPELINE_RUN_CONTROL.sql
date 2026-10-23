-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.PIPELINE_RUN_CONTROL
-- Object Type   : TABLE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-01
-- Reuse Route   : CREATE_NEW
-- Description   : Audit/control table that stores the last successful pipeline execution timestamp. Used by the pipeline procedure to determine incremental vs full load boundary.
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - none
-- Business Rules: BR-01, BR-02
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE TABLE IF NOT EXISTS SDLC_DB.SDLC_PIPELINES.PIPELINE_RUN_CONTROL (
    -- Surrogate identifier for each pipeline run control record
    RUN_CONTROL_ID      NUMBER AUTOINCREMENT PRIMARY KEY,
    -- Name of the pipeline this control record belongs to
    PIPELINE_NAME       VARCHAR(200)    NOT NULL,
    -- BR-01/BR-02: Timestamp of the last successful run; NULL triggers full load
    LAST_SUCCESS_TS     TIMESTAMP_NTZ,
    -- Timestamp when this control record was written
    RECORDED_AT         TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
);
