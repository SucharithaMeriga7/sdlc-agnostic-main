-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_TRANSFORMED_WEIGHT
-- Object Type   : VIEW
-- Jira Story    : SCRUM-158
-- Requirements  : FR-06
-- Reuse Route   : CREATE_NEW
-- Description   : Replaces WEIGHT_KG values <= 0 with -1 per BR-07; layers on manufacturer-transformed view
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_TRANSFORMED_MANUFACTURER
-- Business Rules: BR-07
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

-- Weight transformation view per FR-06 / BR-07
-- Layers on manufacturer-transformed view; replaces WEIGHT_KG <= 0 with -1
CREATE OR REPLACE VIEW SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_TRANSFORMED_WEIGHT AS
SELECT
    PART_NUMBER,
    PART_NAME,
    MANUFACTURER,
    CATEGORY,
    -- BR-07: any WEIGHT_KG <= 0 is replaced with -1 (not NULL)
    CASE
        WHEN WEIGHT_KG <= 0 THEN -1
        ELSE WEIGHT_KG
    END                  AS WEIGHT_KG,
    LEAD_TIME_DAYS,
    CERTIFICATION_STATUS,
    LIFECYCLE_STATUS,
    INSTALLATION_DATE,
    UPDATED_AT
FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_TRANSFORMED_MANUFACTURER;
