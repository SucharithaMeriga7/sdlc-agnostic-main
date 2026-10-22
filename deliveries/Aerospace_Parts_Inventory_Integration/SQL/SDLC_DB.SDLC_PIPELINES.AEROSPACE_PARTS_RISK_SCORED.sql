-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_RISK_SCORED
-- Object Type   : VIEW
-- Jira Story    : SCRUM-158
-- Requirements  : FR-07
-- Reuse Route   : CREATE_NEW
-- Description   : Adds RISK_SCORE derived column per BR-08 through BR-11.
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_CLEANSED
-- Business Rules: BR-08, BR-09, BR-10, BR-11
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE OR REPLACE VIEW SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_RISK_SCORED AS
-- FR-07: derive RISK_SCORE from CERTIFICATION_STATUS and LEAD_TIME_DAYS
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
    -- BR-08: High Risk when Pending AND lead time > 60
    -- BR-09: Medium Risk when Pending OR lead time > 100 (and not High Risk)
    -- BR-10: Low Risk when cert in (FAA, EASA, Dual) AND lead time <= 60
    -- BR-11: Medium Risk for all remaining cases
    CASE
        WHEN CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60
            THEN 'High Risk'    -- BR-08
        WHEN (CERTIFICATION_STATUS = 'Pending' OR LEAD_TIME_DAYS > 100)
            THEN 'Medium Risk'  -- BR-09 (High Risk already excluded above)
        WHEN CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS <= 60
            THEN 'Low Risk'     -- BR-10
        ELSE 'Medium Risk'      -- BR-11: catch-all
    END AS RISK_SCORE
FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_CLEANSED;
