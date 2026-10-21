-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.PARTS_TRANSFORM_VW
-- Object Type   : VIEW
-- Jira Story    : SCRUM-156
-- Requirements  : FR-05, FR-06
-- Reuse Route   : CREATE_NEW
-- Description   : Transformation view applying UPPER() to MANUFACTURER (BR-06) and replacing WEIGHT_KG <= 0 with -1 (BR-07). Built on PARTS_DEDUPLICATED_VW.
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED_VW
-- Business Rules: BR-06, BR-07
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-156  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE OR REPLACE VIEW SDLC_DB.SDLC_PIPELINES.PARTS_TRANSFORM_VW
    COMMENT = 'Applies MANUFACTURER uppercase (BR-06) and WEIGHT_KG invalid-value replacement (BR-07). FR-05/FR-06.'
AS
SELECT
    PART_NUMBER,
    PART_NAME,
    -- BR-06: Convert MANUFACTURER to uppercase (FR-05)
    UPPER(MANUFACTURER)                                         AS MANUFACTURER,
    CERTIFICATION,
    LEAD_TIME_DAYS,
    -- BR-07: Replace WEIGHT_KG <= 0 with -1 to flag invalid/missing weight (FR-06)
    CASE
        WHEN WEIGHT_KG <= 0 THEN -1
        ELSE WEIGHT_KG
    END                                                         AS WEIGHT_KG,
    STATUS,
    UPDATED_AT,
    CREATED_AT
FROM SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED_VW
;
