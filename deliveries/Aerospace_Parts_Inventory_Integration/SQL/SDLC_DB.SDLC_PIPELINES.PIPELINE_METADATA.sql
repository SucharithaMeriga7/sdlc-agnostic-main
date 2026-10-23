-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.PIPELINE_METADATA
-- Object Type   : TABLE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-01
-- Reuse Route   : CREATE_NEW
-- Description   : Stores last successful execution timestamp for incremental load logic (BR-01, BR-02).
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - none
-- Business Rules: BR-01, BR-02
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE TABLE IF NOT EXISTS SDLC_DB.SDLC_PIPELINES.PIPELINE_METADATA (
    PIPELINE_NAME       VARCHAR(200)    NOT NULL,
    LAST_RUN_TIMESTAMP  TIMESTAMP_NTZ,          -- NULL on first run triggers full load (BR-02)
    LAST_RUN_STATUS     VARCHAR(50),
    UPDATED_AT          TIMESTAMP_NTZ,
    CONSTRAINT PK_PIPELINE_METADATA PRIMARY KEY (PIPELINE_NAME)
);
