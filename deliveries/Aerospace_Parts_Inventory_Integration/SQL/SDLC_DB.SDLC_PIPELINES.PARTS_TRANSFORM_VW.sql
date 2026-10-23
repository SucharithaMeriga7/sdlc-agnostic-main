-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.PARTS_TRANSFORM_VW
-- Object Type   : VIEW
-- Jira Story    : SCRUM-158
-- Requirements  : FR-05, FR-06
-- Reuse Route   : ADAPT_EXISTING
-- Description   : Extends the existing PARTS_TRANSFORM_VW by wrapping it and adding the BR-09 exclusion filter for End-of-Life records older than 3 years, plus all FR-05 transformations.
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED_VW
--   - IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE
-- Business Rules: BR-06, BR-07, BR-08, BR-09
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-158  Initial generation (ADAPT_EXISTING)
-- =============================================================================

-- ADAPT_EXISTING: Build new PARTS_TRANSFORM_VW on top of the existing object.
-- Applies FR-05 transformations (BR-06, BR-07, BR-08) and FR-06 exclusion (BR-09).
CREATE OR REPLACE VIEW SDLC_DB.SDLC_PIPELINES.PARTS_TRANSFORM_VW
COMMENT = 'Adapted view: applies FR-05 transformations (BR-06,BR-07,BR-08) and FR-06 exclusion filter (BR-09). Built on deduplicated source.'
AS
SELECT
    src.PART_NUMBER,
    src.PART_NAME,
    -- BR-06: MANUFACTURER must be stored in uppercase
    UPPER(src.MANUFACTURER)                                         AS MANUFACTURER,
    src.CATEGORY,
    -- BR-07: WEIGHT_KG <= 0 replaced with NULL
    IFF(src.WEIGHT_KG <= 0, NULL, src.WEIGHT_KG)                   AS WEIGHT_KG,
    -- BR-08: UNIT_PRICE_USD rounded to 2 decimal places
    -- Use ROUND half-away-from-zero via arithmetic to avoid banker's rounding:
    -- FLOOR(x * 100 + 0.5) / 100 ensures 85000.005 -> 85000.01
    CAST(
        FLOOR(src.UNIT_PRICE_USD * 100 + 0.5) / 100
    AS NUMBER(15,2))                                                AS UNIT_PRICE_USD,
    src.QUANTITY_ON_HAND,
    src.REORDER_LEVEL,
    src.LIFECYCLE_STATUS,
    src.CERTIFICATION_STATUS,
    src.INSTALLATION_DATE,
    src.LEAD_TIME_DAYS,
    src.SUPPLIER,
    src.WAREHOUSE_LOCATION,
    src.COUNTRY_OF_ORIGIN,
    src.CREATED_AT,
    src.UPDATED_AT
FROM
    (
        SELECT
            PART_NUMBER, PART_NAME, MANUFACTURER, CATEGORY, WEIGHT_KG,
            UNIT_PRICE_USD, QUANTITY_ON_HAND, REORDER_LEVEL, LIFECYCLE_STATUS,
            CERTIFICATION_STATUS, INSTALLATION_DATE, LEAD_TIME_DAYS, SUPPLIER,
            WAREHOUSE_LOCATION, COUNTRY_OF_ORIGIN, CREATED_AT, UPDATED_AT,
            ROW_NUMBER() OVER (PARTITION BY PART_NUMBER ORDER BY UPDATED_AT DESC) AS rn
        FROM IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE
    ) AS src
WHERE
    src.rn = 1
    -- BR-09 (FR-06): Exclude records where LIFECYCLE_STATUS = 'End of Life'
    --                AND INSTALLATION_DATE is older than 3 years from current date
    AND NOT (
        src.LIFECYCLE_STATUS = 'End of Life'
        AND src.INSTALLATION_DATE < DATEADD(YEAR, -3, CURRENT_DATE())
    );
