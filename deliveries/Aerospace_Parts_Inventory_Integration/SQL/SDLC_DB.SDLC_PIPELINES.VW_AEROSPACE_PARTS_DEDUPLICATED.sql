-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
-- Object Type   : VIEW
-- Jira Story    : SCRUM-159
-- Requirements  : FR-01, FR-02, FR-05, FR-06
-- Reuse Route   : ADAPT_EXISTING
-- Description   : Adapted view: incremental filter via PIPELINE_WATERMARK_PARAM, deduplication by PART_NUMBER/UPDATED_AT, UPPER(MANUFACTURER) for BR-06, IFF weight normalisation for BR-07.
-- Author        : Sucharitha
-- Created Date  : 2026-11-14
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE
--   - SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM
-- Business Rules: BR-01, BR-02, BR-03, BR-06, BR-07
-- Change History:
--   2026-11-14  Sucharitha  SCRUM-159  Initial generation (ADAPT_EXISTING)
-- =============================================================================

-- ADAPTED FROM: SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
CREATE OR REPLACE VIEW SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED (
    PART_NUMBER,
    PART_NAME,
    MANUFACTURER,
    WEIGHT_KG,
    UNIT_PRICE_USD,
    CERTIFICATION_STATUS,
    LEAD_TIME_DAYS,
    LIFECYCLE_STATUS,
    INSTALLATION_DATE,
    QUANTITY_ON_HAND,
    WAREHOUSE_LOCATION,
    SUPPLIER_CODE,
    COUNTRY_OF_ORIGIN,
    UPDATED_AT,
    CATEGORY,
    SUPPLIER_ID,
    PART_STATUS,
    INVENTORY_HEALTH_STATUS,
    STOCK_QUANTITY,
    SUPPLY_RISK_LEVEL,
    SUPPLIER_COUNT,
    RN
) AS
SELECT
    PART_NUMBER,
    PART_NAME,
    MANUFACTURER,
    WEIGHT_KG,
    UNIT_PRICE_USD,
    CERTIFICATION_STATUS,
    LEAD_TIME_DAYS,
    LIFECYCLE_STATUS,
    INSTALLATION_DATE,
    QUANTITY_ON_HAND,
    WAREHOUSE_LOCATION,
    SUPPLIER_CODE,
    COUNTRY_OF_ORIGIN,
    UPDATED_AT,
    CATEGORY,
    SUPPLIER_ID,
    PART_STATUS,
    INVENTORY_HEALTH_STATUS,
    STOCK_QUANTITY,
    SUPPLY_RISK_LEVEL,
    SUPPLIER_COUNT,
    RN
FROM (
    SELECT
        src.PART_NUMBER,
        src.PART_NAME,
        -- BR-06 / FR-05: store MANUFACTURER in uppercase
        UPPER(src.MANUFACTURER)                                   AS MANUFACTURER,
        -- BR-07 / FR-06: replace weight <= 0 with -1
        IFF(src.WEIGHT_KG <= 0, -1, src.WEIGHT_KG)               AS WEIGHT_KG,
        src.UNIT_PRICE_USD,
        src.CERTIFICATION_STATUS,
        src.LEAD_TIME_DAYS,
        src.LIFECYCLE_STATUS,
        src.INSTALLATION_DATE,
        src.QUANTITY_ON_HAND,
        src.WAREHOUSE_LOCATION,
        src.SUPPLIER_CODE,
        src.COUNTRY_OF_ORIGIN,
        src.UPDATED_AT,
        src.CATEGORY,
        src.SUPPLIER_ID,
        src.PART_STATUS,
        src.INVENTORY_HEALTH_STATUS,
        src.STOCK_QUANTITY,
        src.SUPPLY_RISK_LEVEL,
        src.SUPPLIER_COUNT,
        -- BR-03: deduplicate by PART_NUMBER, keep latest UPDATED_AT
        -- NOTE: NO watermark filter here; the view returns ALL source rows
        -- (deduplicated). The pipeline procedure applies the watermark
        -- filter itself when reading this view for the incremental extract.
        -- This allows the soft-delete step to compare against the full
        -- current source keyset (BR-05).
        ROW_NUMBER() OVER (
            PARTITION BY src.PART_NUMBER
            ORDER BY src.UPDATED_AT DESC NULLS LAST
        ) AS RN
    FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE src
    WHERE src.PART_NUMBER IS NOT NULL
)
-- BR-03: retain only the single latest record per PART_NUMBER
WHERE RN = 1;
