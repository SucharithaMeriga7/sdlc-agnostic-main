-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.ETL_CONTROL
-- Object Type   : TABLE
-- Jira Story    : SCRUM-159
-- Requirements  : FR-01
-- Reuse Route   : CREATE_NEW
-- Description   : Watermark control table tracking last successful run timestamp and pipeline metadata for incremental load logic.
-- Author        : Sucharitha
-- Created Date  : 2026-10-26
-- Dependencies  :
--   - none
-- Business Rules: BR-01, BR-02
-- Change History:
--   2026-10-26  Sucharitha  SCRUM-159  Initial generation (CREATE_NEW)
-- =============================================================================

-- ETL_CONTROL: watermark tracking table for incremental load (FR-01, BR-01, BR-02)
CREATE TABLE IF NOT EXISTS SDLC_DB.SDLC_PIPELINES.ETL_CONTROL (
    PIPELINE_NAME          VARCHAR(200)      NOT NULL COMMENT 'Unique pipeline identifier',
    LAST_RUN_TS            TIMESTAMP_NTZ(9)  COMMENT 'Timestamp of the most recent pipeline execution attempt',
    LAST_SUCCESSFUL_RUN_TS TIMESTAMP_NTZ(9)  COMMENT 'Timestamp of the last SUCCESSFUL run; used as incremental watermark (BR-01)',
    UPDATED_AT             TIMESTAMP_NTZ(9)  DEFAULT CURRENT_TIMESTAMP() COMMENT 'Row last-modified timestamp',
    CONSTRAINT PK_ETL_CONTROL PRIMARY KEY (PIPELINE_NAME)
);
