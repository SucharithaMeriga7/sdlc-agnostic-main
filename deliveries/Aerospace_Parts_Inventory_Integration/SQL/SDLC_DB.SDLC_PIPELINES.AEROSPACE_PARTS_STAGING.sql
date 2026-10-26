-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING
-- Object Type   : TABLE
-- Jira Story    : SCRUM-159
-- Requirements  : FR-01, FR-02, FR-09
-- Reuse Route   : CREATE_NEW
-- Description   : Staging table holding the current incremental/full extract after deduplication, used as the MERGE source for performance (1M records in 5 min target).
-- Author        : Sucharitha
-- Created Date  : 2026-10-26
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE
-- Business Rules: BR-01, BR-02, BR-03
-- Change History:
--   2026-10-26  Sucharitha  SCRUM-159  Initial generation (CREATE_NEW)
-- =============================================================================

-- AEROSPACE_PARTS_STAGING: transient staging for current pipeline run extract (FR-01, FR-02, FR-09)
-- Truncated and reloaded each run; acts as MERGE source for parallelisation (BR-03)
CREATE TABLE IF NOT EXISTS SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING (
    PART_NUMBER            TEXT              NOT NULL COMMENT 'Business key (BR-04)',
    PART_NAME              TEXT              COMMENT 'Part description',
    MANUFACTURER           TEXT              COMMENT 'Manufacturer name; stored UPPER() per BR-06',
    WEIGHT_KG              NUMBER(18,4)      COMMENT 'Weight; -1 when source <= 0 per BR-07',
    UNIT_PRICE_USD         NUMBER(18,2)      COMMENT 'Unit price',
    CERTIFICATION_STATUS   TEXT              COMMENT 'Certification status; drives RISK_SCORE (BR-08 to BR-11)',
    LEAD_TIME_DAYS         NUMBER(10,0)      COMMENT 'Lead time in days; drives RISK_SCORE (BR-08 to BR-11)',
    LIFECYCLE_STATUS       TEXT              COMMENT 'Lifecycle status from source',
    INSTALLATION_DATE      DATE              COMMENT 'Installation date',
    QUANTITY_ON_HAND       NUMBER(10,0)      COMMENT 'Quantity on hand',
    WAREHOUSE_LOCATION     TEXT              COMMENT 'Warehouse location',
    SUPPLIER_CODE          TEXT              COMMENT 'Supplier code',
    COUNTRY_OF_ORIGIN      TEXT              COMMENT 'Country of origin',
    UPDATED_AT             TIMESTAMP_NTZ(9)  COMMENT 'Source last-updated timestamp; used for watermark (BR-01)',
    CATEGORY               TEXT              COMMENT 'Part category',
    SUPPLIER_ID            TEXT              COMMENT 'Supplier identifier',
    PART_STATUS            TEXT              COMMENT 'Part status from source',
    INVENTORY_HEALTH_STATUS TEXT             COMMENT 'Inventory health status',
    STOCK_QUANTITY         NUMBER(10,0)      COMMENT 'Stock quantity',
    SUPPLY_RISK_LEVEL      TEXT              COMMENT 'Supply risk level',
    SUPPLIER_COUNT         NUMBER(38,0)      COMMENT 'Supplier count',
    RISK_SCORE             VARCHAR(20)       COMMENT 'Derived risk score per BR-08 to BR-11',
    CONSTRAINT PK_AEROSPACE_PARTS_STAGING PRIMARY KEY (PART_NUMBER)
);
