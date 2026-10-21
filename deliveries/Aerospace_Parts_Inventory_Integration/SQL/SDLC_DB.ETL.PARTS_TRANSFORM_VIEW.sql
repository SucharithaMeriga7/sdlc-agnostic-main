-- =============================================================================
-- Object        : SDLC_DB.ETL.PARTS_TRANSFORM_VIEW
-- Object Type   : VIEW
-- Jira Story    : SCRUM-156
-- Requirements  : FR-05, FR-06, FR-07
-- Reuse Decision: CREATE_NEW
-- Description   : Applies all field-level transformations: UPPER(MANUFACTURER) per BR-06, WEIGHT_KG cleansing per BR-07, and RISK_SCORE derivation per BR-08 through BR-11. Built on the deduplicated view.
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - SDLC_DB.ETL.PARTS_DEDUPLICATE_VIEW
-- Business Rules: BR-06, BR-07, BR-08, BR-09, BR-10, BR-11
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-156  Initial generation (CREATE_NEW)
-- =============================================================================

-- ============================================================
-- VIEW: SDLC_DB.ETL.PARTS_TRANSFORM_VIEW
-- Purpose : Apply all business transformations before load
-- FR-05   : UPPER(MANUFACTURER)                  (BR-06)
-- FR-06   : WEIGHT_KG <= 0 replaced with -1      (BR-07)
-- FR-07   : RISK_SCORE derived column            (BR-08..BR-11)
-- Source  : SDLC_DB.ETL.PARTS_DEDUPLICATE_VIEW (already deduped)
-- ============================================================
CREATE OR REPLACE VIEW SDLC_DB.ETL.PARTS_TRANSFORM_VIEW AS
SELECT
    PART_NUMBER,
    PART_NAME,

    -- BR-06: Convert MANUFACTURER to uppercase
    UPPER(MANUFACTURER)                                         AS MANUFACTURER,

    -- BR-07: Replace WEIGHT_KG <= 0 with sentinel value -1
    CASE
        WHEN WEIGHT_KG <= 0 THEN -1
        ELSE WEIGHT_KG
    END                                                         AS WEIGHT_KG,

    CERTIFICATION_STATUS,
    LEAD_TIME_DAYS,
    UPDATED_AT,

    -- BR-08: High Risk  => Pending certification AND lead time > 60 days
    -- BR-09: Medium Risk => Pending OR lead time > 100 days (High Risk not met)
    -- BR-10: Low Risk   => Certified (FAA/EASA/Dual) AND lead time <= 60 days
    -- BR-11: Medium Risk => all remaining cases
    CASE
        WHEN CERTIFICATION_STATUS = 'Pending'
             AND LEAD_TIME_DAYS > 60
            THEN 'High Risk'                                    -- BR-08
        WHEN (
                CERTIFICATION_STATUS = 'Pending'
                OR LEAD_TIME_DAYS > 100
             )
             AND NOT (CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60)
            THEN 'Medium Risk'                                  -- BR-09
        WHEN CERTIFICATION_STATUS IN ('FAA', 'EASA', 'Dual')
             AND LEAD_TIME_DAYS <= 60
            THEN 'Low Risk'                                     -- BR-10
        ELSE 'Medium Risk'                                      -- BR-11: catch-all
    END                                                         AS RISK_SCORE

FROM SDLC_DB.ETL.PARTS_DEDUPLICATE_VIEW;
