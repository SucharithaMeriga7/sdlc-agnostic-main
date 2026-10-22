-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.LOAD_CONTROL_STATE
-- Object Type   : TABLE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-01
-- Reuse Route   : CREATE_NEW
-- Description   : State management table tracking last successful pipeline execution timestamp for incremental load logic.
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - none
-- Business Rules: BR-01, BR-02
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

-- State table: stores the last successful run timestamp per pipeline name.
-- BR-01: incremental load reads LAST_SUCCESSFUL_RUN to filter source.
-- BR-02: NULL LAST_SUCCESSFUL_RUN signals first-run full load.
CREATE TABLE IF NOT EXISTS SDLC_DB.SDLC_PIPELINES.LOAD_CONTROL_STATE (
    PIPELINE_NAME       VARCHAR(200)    NOT NULL,          -- logical pipeline identifier
    LAST_SUCCESSFUL_RUN TIMESTAMP_NTZ,                     -- NULL on first run => full load (BR-02)
    LAST_RUN_STATUS     VARCHAR(50),                       -- SUCCEEDED / FAILED
    UPDATED_AT          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_LOAD_CONTROL_STATE PRIMARY KEY (PIPELINE_NAME)
);

-- Seed the pipeline row if it does not already exist so the procedure can always UPDATE.
INSERT INTO SDLC_DB.SDLC_PIPELINES.LOAD_CONTROL_STATE (PIPELINE_NAME, LAST_SUCCESSFUL_RUN, LAST_RUN_STATUS)
SELECT 'AEROSPACE_PARTS_INVENTORY', NULL, 'NEVER_RUN'
WHERE NOT EXISTS (
    SELECT 1
    FROM   SDLC_DB.SDLC_PIPELINES.LOAD_CONTROL_STATE
    WHERE  PIPELINE_NAME = 'AEROSPACE_PARTS_INVENTORY'
);
