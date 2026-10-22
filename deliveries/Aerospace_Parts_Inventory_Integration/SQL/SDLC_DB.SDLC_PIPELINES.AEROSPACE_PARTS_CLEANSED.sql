-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_CLEANSED
-- Object Type   : VIEW
-- Jira Story    : SCRUM-158
-- Requirements  : FR-06
-- Reuse Route   : CREATE_NEW
-- Description   : Cleanses WEIGHT_KG: replaces values <= 0 with -1 (BR-07).
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TRANSFORMED
-- Business Rules: BR-07
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE OR REPLACE VIEW SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_CLEANSED AS
-- FR-06 / BR-07: replace WEIGHT_KG <= 0 with sentinel value -1
SELECT
    PART_NUMBER,
    PART_NAME,
    MANUFACTURER,
    CATEGORY,
    -- BR-07: invalid weight replaced with -1
    CASE WHEN WEIGHT_KG <= 0 THEN -1 ELSE WEIGHT_KG END AS WEIGHT_KG,
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
FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TRANSFORMED;
