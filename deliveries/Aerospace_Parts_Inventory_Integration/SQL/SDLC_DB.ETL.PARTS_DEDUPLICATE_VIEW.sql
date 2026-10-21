-- =============================================================================
-- Object        : SDLC_DB.ETL.PARTS_DEDUPLICATE_VIEW
-- Object Type   : VIEW
-- Jira Story    : SCRUM-156
-- Requirements  : FR-02
-- Reuse Decision: CREATE_NEW
-- Description   : Deduplicates source records by PART_NUMBER retaining only the latest UPDATED_AT record using ROW_NUMBER() per BR-03.
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - SDLC_DB.SOURCE.PARTS_SOURCE
-- Business Rules: BR-03
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-156  Initial generation (CREATE_NEW)
-- =============================================================================

-- ============================================================
-- VIEW: SDLC_DB.ETL.PARTS_DEDUPLICATE_VIEW
-- Purpose : Deduplicate source by PART_NUMBER (BR-03)
-- FR-02   : Retain only max UPDATED_AT per PART_NUMBER
-- QUALIFY : Eliminates subquery; keeps only rank-1 rows
-- ============================================================
CREATE OR REPLACE VIEW SDLC_DB.ETL.PARTS_DEDUPLICATE_VIEW AS
SELECT
    PART_NUMBER,
    PART_NAME,
    MANUFACTURER,
    WEIGHT_KG,
    CERTIFICATION_STATUS,
    LEAD_TIME_DAYS,
    UPDATED_AT
FROM SDLC_DB.SOURCE.PARTS_SOURCE
-- BR-03: partition by PART_NUMBER, order descending by UPDATED_AT
-- QUALIFY filters to only the latest record per PART_NUMBER
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY PART_NUMBER
    ORDER BY UPDATED_AT DESC NULLS LAST
) = 1;
