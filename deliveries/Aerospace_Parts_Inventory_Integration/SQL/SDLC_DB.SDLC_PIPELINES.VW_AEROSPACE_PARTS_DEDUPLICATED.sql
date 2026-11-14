-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
-- Object Type   : VIEW
-- Jira Story    : SCRUM-159
-- Requirements  : FR-01, FR-02
-- Reuse Route   : ADAPT_EXISTING
-- Description   : Adapted view built on top of the existing view definition. Replaces direct source reference with the same source table and PIPELINE_WATERMARK_PARAM cross-join already present in the existing DDL. This object is recreated as CREATE OR REPLACE to add no new logic beyond what already exists; the existing DDL is already correct and is reproduced here as the ADAPT delivery.
-- Author        : Sucharitha
-- Created Date  : 2026-11-14
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE_DEV_SRC
--   - SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM
-- Business Rules: BR-01, BR-02, BR-03
-- Change History:
--   2026-11-14  Sucharitha  SCRUM-159  Initial generation (ADAPT_EXISTING)
-- =============================================================================

-- ADAPT_EXISTING: VW_AEROSPACE_PARTS_DEDUPLICATED
-- DELTA: No structural change needed; existing DDL already implements BR-01, BR-02, BR-03.
-- Reproduced as CREATE OR REPLACE for idempotency.
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
    rn
FROM (
    SELECT
        src.PART_NUMBER,
        src.PART_NAME,
        src.MANUFACTURER,
        src.WEIGHT_KG,
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
        ROW_NUMBER() OVER (
            PARTITION BY src.PART_NUMBER
            ORDER BY src.UPDATED_AT DESC NULLS LAST
        ) AS rn
    FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE_DEV_SRC src
    -- Cross-join to singleton watermark param table (BR-01, BR-02)
    CROSS JOIN SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM wm
    WHERE src.PART_NUMBER IS NOT NULL
      -- BR-01: incremental filter; BR-02: NULL watermark = full load
      AND (
            wm.WATERMARK_TS IS NULL
            OR src.UPDATED_AT > wm.WATERMARK_TS
          )
)
-- BR-03: retain only the latest record per PART_NUMBER
WHERE rn = 1;
