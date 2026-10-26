-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_RISK_SCORE
-- Object Type   : VIEW
-- Jira Story    : SCRUM-158
-- Requirements  : FR-07
-- Reuse Route   : CREATE_NEW
-- Description   : Derives RISK_SCORE using nested CASE logic implementing BR-08 through BR-11; layers on weight-transformed view
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_TRANSFORMED_WEIGHT
-- Business Rules: BR-08, BR-09, BR-10, BR-11
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

-- Risk score derivation view per FR-07
-- Layers on weight-transformed view; derives RISK_SCORE per BR-08..BR-11
CREATE OR REPLACE VIEW SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_RISK_SCORE AS
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
    UPDATED_AT,
    -- BR-08: High Risk when CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60
    -- BR-09: Medium Risk when CERTIFICATION_STATUS = 'Pending' OR LEAD_TIME_DAYS > 100 (and not High Risk)
    -- BR-10: Low Risk when CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS <= 60
    -- BR-11: Medium Risk for all remaining cases
    CASE
        WHEN CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60
            THEN 'High Risk'    -- BR-08
        WHEN (CERTIFICATION_STATUS = 'Pending' OR LEAD_TIME_DAYS > 100)
            THEN 'Medium Risk'  -- BR-09 (High Risk already excluded above)
        WHEN CERTIFICATION_STATUS IN ('FAA', 'EASA', 'Dual') AND LEAD_TIME_DAYS <= 60
            THEN 'Low Risk'     -- BR-10
        ELSE 'Medium Risk'      -- BR-11: catch-all
    END                  AS RISK_SCORE
FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_TRANSFORMED_WEIGHT;
