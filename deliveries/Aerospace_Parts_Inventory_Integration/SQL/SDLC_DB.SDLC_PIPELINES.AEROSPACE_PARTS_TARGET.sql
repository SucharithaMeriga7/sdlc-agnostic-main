-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
-- Object Type   : TABLE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-04
-- Reuse Route   : MODIFY_EXISTING
-- Description   : Target SCD1 table. No structural column changes needed; soft-delete logic is in the procedure. Recreated idempotently to ensure constraint and defaults are current.
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - none
-- Business Rules: BR-05
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (MODIFY_EXISTING)
-- =============================================================================

-- MODIFY_EXISTING: AEROSPACE_PARTS_TARGET
-- No column additions required for FR-04; soft-delete is handled via LIFECYCLE_STATUS already present.
-- Recreating idempotently to lock in current DDL as baseline.
CREATE TABLE IF NOT EXISTS SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET (
    PART_NUMBER         VARCHAR(16777216)  NOT NULL,          -- Business key (BR-04)
    PART_NAME           VARCHAR(16777216),
    MANUFACTURER        VARCHAR(16777216),                    -- Stored UPPER (BR-06)
    CATEGORY            VARCHAR(16777216),
    WEIGHT_KG           NUMBER(10,3),                         -- NULL when <= 0 (BR-07)
    UNIT_PRICE_USD      NUMBER(14,4),                         -- Rounded to 2dp (BR-08); extra precision retained
    QUANTITY_ON_HAND    NUMBER(38,0),
    REORDER_LEVEL       NUMBER(38,0),
    LIFECYCLE_STATUS    VARCHAR(16777216),                    -- Set 'Decommissioned' on soft-delete (BR-05) -- DELTA: soft-delete value documented
    CERTIFICATION_STATUS VARCHAR(16777216),
    INSTALLATION_DATE   DATE,
    LEAD_TIME_DAYS      NUMBER(38,0),
    SUPPLIER            VARCHAR(16777216),
    WAREHOUSE_LOCATION  VARCHAR(16777216),
    COUNTRY_OF_ORIGIN   VARCHAR(16777216),
    CREATED_AT          TIMESTAMP_NTZ(9),
    UPDATED_AT          TIMESTAMP_NTZ(9),
    RISK_SCORE          VARCHAR(20),                          -- Derived per BR-10..BR-13
    DW_INSERT_TS        TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    DW_UPDATE_TS        TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_AEROSPACE_PARTS_TARGET PRIMARY KEY (PART_NUMBER)
);
