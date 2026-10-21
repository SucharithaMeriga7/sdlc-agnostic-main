-- =============================================================================
-- Object        : SDLC_DB.ETL.EXECUTION_CONTROL
-- Object Type   : TABLE
-- Jira Story    : SCRUM-156
-- Requirements  : FR-01
-- Reuse Decision: CREATE_NEW
-- Description   : State-tracking table that stores the last successful execution timestamp to drive incremental vs full-load logic per BR-01 and BR-02.
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - none
-- Business Rules: BR-01, BR-02
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-156  Initial generation (CREATE_NEW)
-- =============================================================================

-- ============================================================
-- TABLE: SDLC_DB.ETL.EXECUTION_CONTROL
-- Purpose : Track last successful run timestamp for incremental
--           load watermark (BR-01 / BR-02)
-- FR-01   : NULL LAST_SUCCESSFUL_RUN triggers full load (BR-02)
-- ============================================================
CREATE TABLE IF NOT EXISTS SDLC_DB.ETL.EXECUTION_CONTROL (
    PIPELINE_NAME           VARCHAR(200)  NOT NULL PRIMARY KEY, -- Unique pipeline identifier
    LAST_SUCCESSFUL_RUN     TIMESTAMP_NTZ,                      -- NULL = first run => full load (BR-02)
    LAST_RUN_STATUS         VARCHAR(50),                        -- SUCCESS / FAILED
    LAST_RUN_TIMESTAMP      TIMESTAMP_NTZ,                      -- Wall-clock of last attempt
    EXECUTION_ID            VARCHAR(100)                        -- UUID of last execution
);

-- Seed the control row for this pipeline if it does not already exist
-- BR-02: absence of a row is equivalent to NULL watermark => full load
INSERT INTO SDLC_DB.ETL.EXECUTION_CONTROL (PIPELINE_NAME, LAST_SUCCESSFUL_RUN, LAST_RUN_STATUS)
SELECT 'PARTS_INCREMENTAL_LOAD', NULL, NULL
WHERE NOT EXISTS (
    SELECT 1 FROM SDLC_DB.ETL.EXECUTION_CONTROL
    WHERE PIPELINE_NAME = 'PARTS_INCREMENTAL_LOAD'
);
