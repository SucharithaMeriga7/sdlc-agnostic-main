-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TRANSFORMED
-- Object Type   : VIEW
-- Jira Story    : SCRUM-158
-- Requirements  : FR-05
-- Reuse Route   : CREATE_NEW
-- Description   : Applies UPPER() to MANUFACTURER field (BR-06) over deduplicated records.
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_DEDUPLICATED
-- Business Rules: BR-06
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE OR REPLACE VIEW SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TRANSFORMED AS
-- FR-05 / BR-06: convert MANUFACTURER to uppercase
SELECT
    PART_NUMBER,
    PART_NAME,
    UPPER(MANUFACTURER)  AS MANUFACTURER,   -- BR-06: e.g. 'Boeing' -> 'BOEING'
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
FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_DEDUPLICATED;
