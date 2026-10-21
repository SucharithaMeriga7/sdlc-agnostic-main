-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED_VW
-- Object Type   : VIEW
-- Jira Story    : SCRUM-156
-- Requirements  : FR-02
-- Reuse Route   : CREATE_NEW
-- Description   : View over PARTS_INCREMENTAL_DT that deduplicates records by PART_NUMBER, retaining only the row with the maximum UPDATED_AT (BR-03).
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.PARTS_INCREMENTAL_DT
-- Business Rules: BR-03
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-156  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE OR REPLACE VIEW SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED_VW
    COMMENT = 'Deduplicates PARTS_INCREMENTAL_DT by PART_NUMBER keeping latest UPDATED_AT. FR-02/BR-03.'
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
FROM (
    SELECT
        PART_NUMBER,
        PART_NAME,
        MANUFACTURER,
        CERTIFICATION,
        LEAD_TIME_DAYS,
        WEIGHT_KG,
        STATUS,
        UPDATED_AT,
        CREATED_AT,
        -- BR-03: Partition by PART_NUMBER, order by UPDATED_AT DESC to identify latest record
        ROW_NUMBER() OVER (
            PARTITION BY PART_NUMBER
            ORDER BY UPDATED_AT DESC
        ) AS RN
    FROM SDLC_DB.SDLC_PIPELINES.PARTS_INCREMENTAL_DT
)
-- BR-03: Retain only the single latest record per PART_NUMBER
QUALIFY RN = 1
;
