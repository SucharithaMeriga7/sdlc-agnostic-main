-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_DEDUPLICATED
-- Object Type   : VIEW
-- Jira Story    : SCRUM-158
-- Requirements  : FR-02
-- Reuse Route   : CREATE_NEW
-- Description   : Deduplicates staging records by PART_NUMBER, retaining the row with the latest UPDATED_AT (BR-03).
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING
-- Business Rules: BR-03
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE OR REPLACE VIEW SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_DEDUPLICATED AS
-- BR-03: retain only the record with the maximum UPDATED_AT per PART_NUMBER
SELECT
    PART_NUMBER,
    PART_NAME,
    MANUFACTURER,
    CATEGORY,
    WEIGHT_KG,
    UNIT_PRICE_USD,
    QUANTITY_ON_HAND,
    REORDER_LEVEL,
    LIFECYCLE_STATUS,
    CERTIFICATION_STATUS,
    INSTALLATION_DATE,
    LEAD_TIME_DAYS,
    SUPPLIER,
    WAREHOUSE_LOCATION,
    COUNTRY_OF_ORIGIN,
    CREATED_AT,
    UPDATED_AT
FROM (
    SELECT
        PART_NUMBER,
        PART_NAME,
        MANUFACTURER,
        CATEGORY,
        WEIGHT_KG,
        UNIT_PRICE_USD,
        QUANTITY_ON_HAND,
        REORDER_LEVEL,
        LIFECYCLE_STATUS,
        CERTIFICATION_STATUS,
        INSTALLATION_DATE,
        LEAD_TIME_DAYS,
        SUPPLIER,
        WAREHOUSE_LOCATION,
        COUNTRY_OF_ORIGIN,
        CREATED_AT,
        UPDATED_AT,
        -- Assign row number: partition by PART_NUMBER, latest UPDATED_AT first
        ROW_NUMBER() OVER (
            PARTITION BY PART_NUMBER
            ORDER BY UPDATED_AT DESC NULLS LAST
        ) AS RN
    FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING
)
QUALIFY RN = 1; -- keep only the latest record per PART_NUMBER
