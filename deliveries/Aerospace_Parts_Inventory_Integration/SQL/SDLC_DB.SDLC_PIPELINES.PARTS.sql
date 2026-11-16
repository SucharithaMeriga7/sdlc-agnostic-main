-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.PARTS
-- Object Type   : TABLE
-- Jira Story    : SCRUM-159
-- Requirements  : FR-03, FR-04, FR-07
-- Reuse Route   : MODIFY_EXISTING
-- Description   : Target SCD Type 1 parts table. Ensures RISK_SCORE and LIFECYCLE_STATUS columns exist for merge, risk score population, and soft-delete. All existing columns preserved.
-- Author        : Sucharitha
-- Created Date  : 2026-11-16
-- Dependencies  :
--   - none
-- Business Rules: BR-04, BR-05, BR-08
-- Change History:
--   2026-11-16  Sucharitha  SCRUM-159  Initial generation (MODIFY_EXISTING)
-- =============================================================================

-- ADAPTED FROM: SDLC_DB.SDLC_PIPELINES.PARTS
-- MODIFY_EXISTING: ensure RISK_SCORE and LIFECYCLE_STATUS exist with correct types
CREATE TABLE IF NOT EXISTS SDLC_DB.SDLC_PIPELINES.PARTS (
    PART_NUMBER             VARCHAR(100)     NOT NULL,
    PART_NAME               VARCHAR(255),
    MANUFACTURER            VARCHAR(255),
    WEIGHT_KG               NUMBER(10,3),
    UNIT_PRICE_USD          NUMBER(18,4),
    CERTIFICATION_STATUS    VARCHAR(100),
    LEAD_TIME_DAYS          NUMBER(10,0),
    LIFECYCLE_STATUS        VARCHAR(100),
    INSTALLATION_DATE       DATE,
    QUANTITY_ON_HAND        NUMBER(18,0),
    WAREHOUSE_LOCATION      VARCHAR(255),
    SUPPLIER_CODE           VARCHAR(100),
    COUNTRY_OF_ORIGIN       VARCHAR(100),
    UPDATED_AT              TIMESTAMP_NTZ(9),
    CATEGORY                VARCHAR(100),
    SUPPLIER_ID             VARCHAR(100),
    PART_STATUS             VARCHAR(100),
    INVENTORY_HEALTH_STATUS VARCHAR(100),
    STOCK_QUANTITY          NUMBER(18,0),
    SUPPLY_RISK_LEVEL       VARCHAR(100),
    SUPPLIER_COUNT          NUMBER(10,0),
    RISK_SCORE              VARCHAR(50),
    DW_INSERT_TS            TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    DW_UPDATE_TS            TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_PARTS PRIMARY KEY (PART_NUMBER)
);
-- DELTA: new columns (guard with IF NOT EXISTS in case table already existed without them)
ALTER TABLE SDLC_DB.SDLC_PIPELINES.PARTS ADD COLUMN IF NOT EXISTS RISK_SCORE       VARCHAR(50);          -- DELTA: required for BR-08 / FR-07 risk score storage
ALTER TABLE SDLC_DB.SDLC_PIPELINES.PARTS ADD COLUMN IF NOT EXISTS LIFECYCLE_STATUS VARCHAR(100);         -- DELTA: required for BR-05 / FR-04 soft-delete status
