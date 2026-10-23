-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.PARTS_WITH_RISK_SCORE
-- Object Type   : VIEW
-- Jira Story    : SCRUM-158
-- Requirements  : FR-07
-- Reuse Route   : CREATE_NEW
-- Description   : View over PARTS_DEDUPLICATED that derives RISK_SCORE using nested CASE logic per BR-08 through BR-11.
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED
-- Business Rules: BR-08, BR-09, BR-10, BR-11
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

-- Risk scoring view built on top of the deduplicated/transformed view.
-- Evaluation order: BR-08 (High Risk) -> BR-09 (Medium Risk) -> BR-10 (Low Risk) -> BR-11 (default Medium Risk).
CREATE OR REPLACE VIEW SDLC_DB.SDLC_PIPELINES.PARTS_WITH_RISK_SCORE AS
SELECT
    PART_NUMBER,
    PART_NAME,
    MANUFACTURER,
    CATEGORY,
    UNIT_PRICE,
    WEIGHT_KG,
    CERTIFICATION_STATUS,
    LEAD_TIME_DAYS,
    STATUS,
    UPDATED_AT,
    -- BR-08: High Risk when Pending AND lead time > 60 days
    -- BR-09: Medium Risk when Pending OR lead time > 100 days (High Risk not met)
    -- BR-10: Low Risk when certified (FAA/EASA/Dual) AND lead time <= 60 days
    -- BR-11: all remaining cases => Medium Risk
    CASE
        WHEN CERTIFICATION_STATUS = 'Pending'
             AND LEAD_TIME_DAYS > 60
            THEN 'High Risk'
        WHEN (CERTIFICATION_STATUS = 'Pending' OR LEAD_TIME_DAYS > 100)
             AND NOT (CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60)
            THEN 'Medium Risk'
        WHEN CERTIFICATION_STATUS IN ('FAA', 'EASA', 'Dual')
             AND LEAD_TIME_DAYS <= 60
            THEN 'Low Risk'
        ELSE 'Medium Risk'
    END                                                         AS RISK_SCORE
FROM SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED;
