-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.PIPELINE_EXECUTION_STATE
-- Object Type   : TABLE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-01
-- Reuse Route   : CREATE_NEW
-- Description   : Stores last successful execution timestamp for incremental load state management
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - none
-- Business Rules: BR-01, BR-02
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

-- Execution state table: tracks last successful pipeline run timestamp
-- Used by FR-01 / BR-01 / BR-02 to determine incremental vs full load
CREATE TABLE IF NOT EXISTS SDLC_DB.SDLC_PIPELINES.PIPELINE_EXECUTION_STATE (
    PIPELINE_NAME        VARCHAR(200)     NOT NULL,   -- unique pipeline identifier
    LAST_SUCCESSFUL_TS   TIMESTAMP_NTZ    NOT NULL,   -- last successful run timestamp (UTC)
    UPDATED_AT           TIMESTAMP_NTZ    NOT NULL DEFAULT CURRENT_TIMESTAMP(), -- row update time
    CONSTRAINT PK_PIPELINE_EXECUTION_STATE PRIMARY KEY (PIPELINE_NAME)
);
