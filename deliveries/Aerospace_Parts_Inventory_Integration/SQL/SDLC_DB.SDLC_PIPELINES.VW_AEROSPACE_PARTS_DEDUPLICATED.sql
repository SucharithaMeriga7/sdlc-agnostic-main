-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
-- Object Type   : VIEW
-- Jira Story    : SCRUM-159
-- Requirements  : FR-02, FR-05, FR-06
-- Reuse Route   : MODIFY_EXISTING
-- Description   : Deduplicated view of aerospace parts source. Applies camelcase to MANUFACTURER (BR-06/FR-05) and weight normalisation (BR-07/FR-06) inline. Deduplicates by PART_NUMBER keeping latest UPDATED_AT (BR-03/FR-02). No watermark filter here; procedure applies it separately so soft-delete can compare full keyset.
-- Author        : Sucharitha
-- Created Date  : 2026-11-16
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE_DEV_SRC
-- Business Rules: BR-03, BR-06, BR-07
-- Change History:
--   2026-11-16  Sucharitha  SCRUM-159  Initial generation (MODIFY_EXISTING)
-- =============================================================================

-- ADAPTED FROM: SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
-- MODIFY_EXISTING: replace view body to inline camelcase and weight normalisation
-- and remove references to external UDFs (FR-05, FR-06, BR-06, BR-07)
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
        -- DELTA: BR-06 / FR-05: inline camelcase via INITCAP instead of UDF FN_CAMELCASE_MANUFACTURER
        INITCAP(src.MANUFACTURER)                                  AS MANUFACTURER,  -- DELTA: camelcase inline (FR-05, BR-06)
        -- DELTA: BR-07 / FR-06: inline weight normalisation instead of UDF FN_NORMALIZE_WEIGHT
        IFF(src.WEIGHT_KG <= 0, -1, src.WEIGHT_KG)                AS WEIGHT_KG,     -- DELTA: weight normalisation inline (FR-06, BR-07)
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
        -- BR-03 / FR-02: deduplicate by PART_NUMBER, keep latest UPDATED_AT
        -- No watermark filter applied here; procedure filters for incremental
        -- extract and uses full keyset for soft-delete (BR-05)
        ROW_NUMBER() OVER (
            PARTITION BY src.PART_NUMBER
            ORDER BY src.UPDATED_AT DESC NULLS LAST
        ) AS RN
    FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE_DEV_SRC src
    WHERE src.PART_NUMBER IS NOT NULL  -- exclude records with no business key
)
-- BR-03: retain only the single latest record per PART_NUMBER
WHERE RN = 1;
