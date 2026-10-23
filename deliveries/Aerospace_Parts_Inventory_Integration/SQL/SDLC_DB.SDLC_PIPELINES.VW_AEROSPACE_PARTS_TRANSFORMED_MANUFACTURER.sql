-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_TRANSFORMED_MANUFACTURER
-- Object Type   : VIEW
-- Jira Story    : SCRUM-158
-- Requirements  : FR-05
-- Reuse Route   : CREATE_NEW
-- Description   : Applies UPPER() to MANUFACTURER column over the deduplicated view per BR-06
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
-- Business Rules: BR-06
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

-- Manufacturer transformation view per FR-05 / BR-06
-- Layers on top of deduplicated view; applies UPPER() to MANUFACTURER
CREATE OR REPLACE VIEW SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_TRANSFORMED_MANUFACTURER AS
SELECT
    PART_NUMBER,
    PART_NAME,
    -- BR-06: convert MANUFACTURER to uppercase before target load
    UPPER(MANUFACTURER)  AS MANUFACTURER,
    CATEGORY,
    WEIGHT_KG,
    LEAD_TIME_DAYS,
    CERTIFICATION_STATUS,
    LIFECYCLE_STATUS,
    INSTALLATION_DATE,
    UPDATED_AT
FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED;
