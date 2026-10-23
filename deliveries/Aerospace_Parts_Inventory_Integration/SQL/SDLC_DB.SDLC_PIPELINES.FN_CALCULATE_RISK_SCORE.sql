-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.FN_CALCULATE_RISK_SCORE
-- Object Type   : FUNCTION
-- Jira Story    : SCRUM-158
-- Requirements  : FR-07
-- Reuse Route   : CREATE_NEW
-- Description   : Scalar UDF that derives RISK_SCORE from CERTIFICATION_STATUS and LEAD_TIME_DAYS per BR-08 through BR-11.
-- Author        : Sucharitha
-- Created Date  : 2026-10-23
-- Dependencies  :
--   - none
-- Business Rules: BR-08, BR-09, BR-10, BR-11
-- Change History:
--   2026-10-23  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE OR REPLACE FUNCTION SDLC_DB.SDLC_PIPELINES.FN_CALCULATE_RISK_SCORE(
    CERTIFICATION_STATUS_INPUT VARCHAR,
    LEAD_TIME_DAYS_INPUT NUMBER(38,0)
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    -- BR-08: High Risk when Pending AND lead time > 60
    -- BR-09: Medium Risk when Pending OR lead time > 100 (and not High Risk)
    -- BR-10: Low Risk when cert is FAA/EASA/Dual AND lead time <= 60
    -- BR-11: Medium Risk for all remaining cases
    CASE
        WHEN CERTIFICATION_STATUS_INPUT = 'Pending'
             AND LEAD_TIME_DAYS_INPUT > 60
            THEN 'High Risk'
        WHEN (
                CERTIFICATION_STATUS_INPUT = 'Pending'
                OR LEAD_TIME_DAYS_INPUT > 100
             )
             AND NOT (
                CERTIFICATION_STATUS_INPUT = 'Pending'
                AND LEAD_TIME_DAYS_INPUT > 60
             )
            THEN 'Medium Risk'
        WHEN CERTIFICATION_STATUS_INPUT IN ('FAA', 'EASA', 'Dual')
             AND LEAD_TIME_DAYS_INPUT <= 60
            THEN 'Low Risk'
        ELSE 'Medium Risk'
    END
$$;
