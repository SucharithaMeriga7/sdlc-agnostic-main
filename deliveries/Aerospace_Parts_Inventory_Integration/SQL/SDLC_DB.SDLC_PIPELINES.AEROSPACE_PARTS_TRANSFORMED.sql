-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TRANSFORMED
-- Object Type   : VIEW
-- Jira Story    : SCRUM-158
-- Requirements  : FR-05, FR-06, FR-07
-- Reuse Route   : MODIFY_EXISTING
-- Description   : Transformation view over AEROSPACE_PARTS_DEDUPLICATED. Corrects MANUFACTURER to UPPER (BR-06), WEIGHT_KG<=0 to NULL (BR-07), rounds UNIT_PRICE_USD (BR-08), excludes End-of-Life >3yr (BR-09), derives RISK_SCORE (BR-10..BR-13).
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_DEDUPLICATED
-- Business Rules: BR-06, BR-07, BR-08, BR-09, BR-10, BR-11, BR-12, BR-13
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (MODIFY_EXISTING)
-- =============================================================================

-- MODIFY_EXISTING: AEROSPACE_PARTS_TRANSFORMED
-- DELTA: MANUFACTURER changed from INITCAP to UPPER (BR-06)
-- DELTA: WEIGHT_KG sentinel -1 replaced with NULL for values <= 0 (BR-07)
-- DELTA: UNIT_PRICE_USD now rounded to 2 decimal places (BR-08)
-- DELTA: WHERE clause added to exclude End of Life records older than 3 years (BR-09)
-- DELTA: RISK_SCORE CASE rewritten to implement BR-10, BR-11, BR-12, BR-13 correctly
CREATE OR REPLACE VIEW SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TRANSFORMED (
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
    RISK_SCORE
) AS
SELECT
    PART_NUMBER,
    PART_NAME,

    -- BR-06 DELTA: UPPER replaces INITCAP to store manufacturer in full uppercase
    UPPER(MANUFACTURER)                                                     AS MANUFACTURER,  -- DELTA:

    CATEGORY,

    -- BR-07 DELTA: NULL replaces sentinel -1 for WEIGHT_KG <= 0
    CASE
        WHEN WEIGHT_KG <= 0 THEN NULL                                                         -- DELTA:
        ELSE WEIGHT_KG
    END                                                                     AS WEIGHT_KG,

    -- BR-08 DELTA: Round UNIT_PRICE_USD to 2 decimal places
    ROUND(UNIT_PRICE_USD, 2)                                                AS UNIT_PRICE_USD, -- DELTA:

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

    -- BR-10..BR-13 DELTA: Rewritten RISK_SCORE derivation
    -- Evaluation order: High Risk (BR-10) -> Low Risk (BR-12) -> Medium Risk (BR-11/BR-13)
    CASE
        -- BR-10: High Risk when Pending certification AND lead time > 90 days
        WHEN UPPER(CERTIFICATION_STATUS) = 'PENDING'
             AND LEAD_TIME_DAYS > 90
            THEN 'High Risk'                                                                   -- DELTA:

        -- BR-12: Low Risk when FAA/EASA/Dual certified AND lead time <= 60 days
        WHEN UPPER(CERTIFICATION_STATUS) IN ('FAA', 'EASA', 'DUAL')
             AND LEAD_TIME_DAYS <= 60
            THEN 'Low Risk'                                                                    -- DELTA:

        -- BR-11: Medium Risk when Pending (not already High Risk) OR lead time > 120 days
        WHEN UPPER(CERTIFICATION_STATUS) = 'PENDING'
             OR LEAD_TIME_DAYS > 120
            THEN 'Medium Risk'                                                                 -- DELTA:

        -- BR-13: Default Medium Risk for all remaining cases
        ELSE 'Medium Risk'
    END                                                                     AS RISK_SCORE      -- DELTA:

FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_DEDUPLICATED

-- BR-09 DELTA: Exclude records where LIFECYCLE_STATUS = 'End of Life' AND INSTALLATION_DATE older than 3 years
WHERE NOT (
    UPPER(LIFECYCLE_STATUS) = 'END OF LIFE'
    AND INSTALLATION_DATE < DATEADD(YEAR, -3, CURRENT_DATE())
);                                                                                             -- DELTA:
