-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.PARTS
-- Object Type   : TABLE
-- Jira Story    : SCRUM-159
-- Requirements  : FR-03, FR-04, FR-05, FR-06, FR-07
-- Reuse Route   : ADAPT_EXISTING
-- Description   : Target SCD Type 1 table adapted from AEROSPACE_PARTS_TARGET; adds RISK_SCORE and soft-delete support. Built on top of existing table via CREATE OR REPLACE referencing same structure.
-- Author        : Sucharitha
-- Created Date  : 2026-11-14
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
-- Business Rules: BR-04, BR-05, BR-06, BR-07, BR-08, BR-09, BR-10, BR-11
-- Change History:
--   2026-11-14  Sucharitha  SCRUM-159  Initial generation (ADAPT_EXISTING)
-- =============================================================================

-- DELTA: Create PARTS as the canonical target table adapted from AEROSPACE_PARTS_TARGET.
-- All columns match AEROSPACE_PARTS_TARGET exactly; RISK_SCORE and DW timestamps already present.
-- DELTA: Using CREATE TABLE IF NOT EXISTS to be idempotent without destroying existing data.
CREATE TABLE IF NOT EXISTS SDLC_DB.SDLC_PIPELINES.PARTS (
    PART_NUMBER          VARCHAR(100)     NOT NULL,        -- Natural key, SCD Type 1 (BR-04)
    PART_NAME            VARCHAR(255),
    MANUFACTURER         VARCHAR(255),                     -- Stored as UPPER() per BR-06
    WEIGHT_KG            NUMBER(10,3),                     -- Normalised: <=0 replaced with -1 per BR-07
    UNIT_PRICE_USD       NUMBER(18,4),
    CERTIFICATION_STATUS VARCHAR(100),
    LEAD_TIME_DAYS       NUMBER(10,0),
    LIFECYCLE_STATUS     VARCHAR(100),                     -- Set to Decommissioned for soft-delete (BR-05)
    INSTALLATION_DATE    DATE,
    QUANTITY_ON_HAND     NUMBER(18,0),
    WAREHOUSE_LOCATION   VARCHAR(255),
    SUPPLIER_CODE        VARCHAR(100),
    COUNTRY_OF_ORIGIN    VARCHAR(100),
    UPDATED_AT           TIMESTAMP_NTZ(9),
    CATEGORY             VARCHAR(100),
    SUPPLIER_ID          VARCHAR(100),
    PART_STATUS          VARCHAR(100),
    INVENTORY_HEALTH_STATUS VARCHAR(100),
    STOCK_QUANTITY       NUMBER(18,0),
    SUPPLY_RISK_LEVEL    VARCHAR(100),
    SUPPLIER_COUNT       NUMBER(10,0),
    RISK_SCORE           VARCHAR(50),                      -- Derived per BR-08/BR-09/BR-10/BR-11
    DW_INSERT_TS         TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    DW_UPDATE_TS         TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_PARTS PRIMARY KEY (PART_NUMBER)
);
