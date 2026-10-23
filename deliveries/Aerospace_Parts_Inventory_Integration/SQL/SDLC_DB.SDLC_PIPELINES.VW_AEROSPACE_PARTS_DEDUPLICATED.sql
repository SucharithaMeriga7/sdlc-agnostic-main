-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
-- Object Type   : VIEW
-- Jira Story    : SCRUM-158
-- Requirements  : FR-02
-- Reuse Route   : CREATE_NEW
-- Description   : Deduplicates source records by PART_NUMBER retaining only the latest UPDATED_AT per BR-03
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE
-- Business Rules: BR-03
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

-- Deduplication view per FR-02 / BR-03
-- Reads directly from source; ROW_NUMBER partitioned by PART_NUMBER, ordered by UPDATED_AT DESC
-- QUALIFY filters to rank = 1 (latest record per PART_NUMBER)
CREATE OR REPLACE VIEW SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED AS
SELECT
    PART_NUMBER,
    PART_NAME,
    MANUFACTURER,
    CATEGORY,
    WEIGHT_KG,
    LEAD_TIME_DAYS,
    CERTIFICATION_STATUS,
    LIFECYCLE_STATUS,
    INSTALLATION_DATE,
    UPDATED_AT
FROM IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE
-- BR-03: retain only the record with the maximum UPDATED_AT per PART_NUMBER
QUALIFY ROW_NUMBER() OVER (PARTITION BY PART_NUMBER ORDER BY UPDATED_AT DESC) = 1;
