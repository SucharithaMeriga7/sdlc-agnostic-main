-- =============================================================================
-- Object        : SDLC_DB.ETL.ETL_RECONCILIATION_LOG
-- Object Type   : TABLE
-- Jira Story    : SCRUM-156
-- Requirements  : FR-08
-- Reuse Decision: CREATE_NEW
-- Description   : Stores reconciliation results after every pipeline run including counts and discrepancy details per BR-12.
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - none
-- Business Rules: BR-12
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-156  Initial generation (CREATE_NEW)
-- =============================================================================

-- ============================================================
-- TABLE: SDLC_DB.ETL.ETL_RECONCILIATION_LOG
-- Purpose : Persist post-run reconciliation metrics (BR-12)
-- FR-08   : Mandatory after every pipeline execution
-- ============================================================
CREATE TABLE IF NOT EXISTS SDLC_DB.ETL.ETL_RECONCILIATION_LOG (
    LOG_ID              NUMBER AUTOINCREMENT PRIMARY KEY,  -- Surrogate key
    EXECUTION_ID        VARCHAR(100)   NOT NULL,           -- Links to EXECUTION_CONTROL run
    RUN_TIMESTAMP       TIMESTAMP_NTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP(), -- Wall-clock of reconciliation
    CHECK_NAME          VARCHAR(200)   NOT NULL,           -- Descriptive label for the check
    SOURCE_COUNT        NUMBER(18,0)   NOT NULL DEFAULT 0, -- Rows extracted from source
    TARGET_COUNT        NUMBER(18,0)   NOT NULL DEFAULT 0, -- Rows present in target after load
    INSERTED_COUNT      NUMBER(18,0)   NOT NULL DEFAULT 0, -- Net new rows inserted
    UPDATED_COUNT       NUMBER(18,0)   NOT NULL DEFAULT 0, -- Rows overwritten (SCD1)
    SOFT_DELETED_COUNT  NUMBER(18,0)   NOT NULL DEFAULT 0, -- Rows marked Decommissioned (BR-05)
    DISCREPANCY_COUNT   NUMBER(18,0)   NOT NULL DEFAULT 0, -- ABS(SOURCE - TARGET) delta
    STATUS              VARCHAR(50)    NOT NULL,           -- PASSED / FAILED / WARNING
    NOTES               VARCHAR(4000)                      -- Free-text detail for failures
);
