-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.PARTS_INCREMENTAL_DT
-- Object Type   : DYNAMIC TABLE
-- Jira Story    : SCRUM-156
-- Requirements  : FR-01
-- Reuse Route   : CREATE_NEW
-- Description   : Dynamic table that incrementally pulls records from the source parts table. On first run performs a full load (BR-02); on subsequent runs filters by UPDATED_AT > last refresh watermark (BR-01). TARGET_LAG set to 1 day to align with daily schedule (BR-10).
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE
-- Business Rules: BR-01, BR-02
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-156  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE SDLC_DB.SDLC_PIPELINES.PARTS_INCREMENTAL_DT
    -- FR-01: Incremental load dynamic table; TARGET_LAG drives daily refresh cadence
    -- BR-01: Records filtered by UPDATED_AT > last successful execution timestamp (handled by DT incremental refresh)
    -- BR-02: First run performs full load because no prior watermark exists
    TARGET_LAG = '1 day'
    WAREHOUSE = COMPUTE_WH
    REFRESH_MODE = INCREMENTAL
    INITIALIZE = ON_CREATE
    COMMENT = 'Incremental dynamic table for aerospace parts source data. FR-01/BR-01/BR-02.'
AS
SELECT
    PART_NUMBER,
    PART_NAME,
    MANUFACTURER,
    CERTIFICATION,
    LEAD_TIME_DAYS,
    WEIGHT_KG,
    STATUS,
    UPDATED_AT,
    CREATED_AT
FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE
-- BR-01/BR-02: Dynamic table engine manages the incremental watermark automatically;
-- on first initialization all rows are loaded (full load), subsequent refreshes are incremental
;
