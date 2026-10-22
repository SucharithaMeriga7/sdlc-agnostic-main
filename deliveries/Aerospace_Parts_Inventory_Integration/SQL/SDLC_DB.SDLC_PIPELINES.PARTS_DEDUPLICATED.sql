-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED
-- Object Type   : VIEW
-- Jira Story    : SCRUM-158
-- Requirements  : FR-02, FR-05, FR-06
-- Reuse Route   : CREATE_NEW
-- Description   : View over source table that deduplicates by PART_NUMBER (max UPDATED_AT), uppercases MANUFACTURER, and replaces invalid WEIGHT_KG with -1.
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE
-- Business Rules: BR-03, BR-06, BR-07
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

-- Deduplication + transformation view.
-- BR-03: QUALIFY keeps only the latest UPDATED_AT row per PART_NUMBER.
-- BR-06: UPPER(MANUFACTURER) applied here.
-- BR-07: WEIGHT_KG <= 0 replaced with -1.
CREATE OR REPLACE VIEW SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED AS
SELECT
    PART_NUMBER,
    PART_NAME,
    -- BR-06: convert MANUFACTURER to uppercase
    UPPER(MANUFACTURER)                                         AS MANUFACTURER,
    CATEGORY,
    -- source column is UNIT_PRICE_USD; alias to UNIT_PRICE for downstream use
    UNIT_PRICE_USD                                              AS UNIT_PRICE,
    -- BR-07: replace non-positive WEIGHT_KG with sentinel value -1
    CASE WHEN WEIGHT_KG <= 0 THEN CAST(-1 AS NUMBER(18,4))
         ELSE WEIGHT_KG
    END                                                         AS WEIGHT_KG,
    CERTIFICATION_STATUS,
    LEAD_TIME_DAYS,
    -- source column is LIFECYCLE_STATUS; alias to STATUS for downstream use
    LIFECYCLE_STATUS                                            AS STATUS,
    UPDATED_AT
FROM IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE
-- BR-03: deduplicate by PART_NUMBER, keep row with maximum UPDATED_AT
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY PART_NUMBER
    ORDER BY     UPDATED_AT DESC NULLS LAST
) = 1;
