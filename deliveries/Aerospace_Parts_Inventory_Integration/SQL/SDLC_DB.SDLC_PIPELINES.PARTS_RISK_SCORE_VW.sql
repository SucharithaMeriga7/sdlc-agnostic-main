-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.PARTS_RISK_SCORE_VW
-- Object Type   : VIEW
-- Jira Story    : SCRUM-156
-- Requirements  : FR-07
-- Reuse Route   : CREATE_NEW
-- Description   : View that derives RISK_SCORE for each part based on CERTIFICATION and LEAD_TIME_DAYS per BR-08 four-tier logic.
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.PARTS_TRANSFORM_VW
-- Business Rules: BR-08
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-156  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE OR REPLACE VIEW SDLC_DB.SDLC_PIPELINES.PARTS_RISK_SCORE_VW
    COMMENT = 'Derives RISK_SCORE per BR-08 certification and lead-time rules. FR-07.'
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
    CREATED_AT,
    -- BR-08: RISK_SCORE derivation rules applied in priority order
    CASE
        -- BR-08 Rule 1: Certification = Pending AND lead_time > 60 => High Risk
        WHEN CERTIFICATION = 'Pending' AND LEAD_TIME_DAYS > 60
            THEN 'High Risk'
        -- BR-08 Rule 2: Certification = Pending OR lead_time > 100 => Medium Risk
        WHEN CERTIFICATION = 'Pending' OR LEAD_TIME_DAYS > 100
            THEN 'Medium Risk'
        -- BR-08 Rule 3: Certification IN (FAA, EASA, Dual) AND lead_time <= 60 => Low Risk
        WHEN CERTIFICATION IN ('FAA', 'EASA', 'Dual') AND LEAD_TIME_DAYS <= 60
            THEN 'Low Risk'
        -- BR-08 Rule 4: All other cases => Medium Risk
        ELSE 'Medium Risk'
    END                                                         AS RISK_SCORE
FROM SDLC_DB.SDLC_PIPELINES.PARTS_TRANSFORM_VW
;
