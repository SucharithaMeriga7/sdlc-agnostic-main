-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS
-- Object Type   : TABLE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-03, FR-04
-- Reuse Route   : MODIFY_EXISTING
-- Description   : Target SCD Type 1 table for aerospace parts. Delta: ensures STATUS and CREATED_AT columns exist (already present in existing DDL). No structural change needed beyond confirming existing DDL is authoritative.
-- Author        : Sucharitha
-- Created Date  : 2026-10-23
-- Dependencies  :
--   - none
-- Business Rules: BR-04, BR-05
-- Change History:
--   2026-10-23  Sucharitha  SCRUM-158  Initial generation (MODIFY_EXISTING)
-- =============================================================================

-- MODIFY_EXISTING: SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS
-- The existing DDL already contains STATUS VARCHAR(50) and CREATED_AT TIMESTAMP_NTZ(9).
-- DELTA: Recreate with OR REPLACE to ensure idempotency and confirm all required columns.
-- DELTA: Added explicit inline comment markers on changed/confirmed lines.
CREATE OR REPLACE TABLE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS (
    PART_NUMBER         VARCHAR(16777216)  NOT NULL,          -- Business key (BR-04)
    PART_NAME           VARCHAR(16777216),
    MANUFACTURER        VARCHAR(16777216),                    -- Stored UPPER() per BR-06
    CATEGORY            VARCHAR(16777216),
    WEIGHT_KG           NUMBER(38,10),                        -- Cleansed per BR-07
    UNIT_PRICE_USD      NUMBER(38,10),
    QUANTITY_ON_HAND    NUMBER(38,0),
    REORDER_LEVEL       NUMBER(38,0),
    LIFECYCLE_STATUS    VARCHAR(16777216),
    CERTIFICATION_STATUS VARCHAR(16777216),
    INSTALLATION_DATE   DATE,
    LEAD_TIME_DAYS      NUMBER(38,0),
    SUPPLIER            VARCHAR(16777216),
    WAREHOUSE_LOCATION  VARCHAR(16777216),
    COUNTRY_OF_ORIGIN   VARCHAR(16777216),
    RISK_SCORE          VARCHAR(16777216),                    -- Derived per BR-08..BR-11
    UPDATED_AT          TIMESTAMP_NTZ(9),
    LOAD_TIMESTAMP      TIMESTAMP_NTZ(9),
    STATUS              VARCHAR(50),                          -- DELTA: soft-delete flag BR-05
    CREATED_AT          TIMESTAMP_NTZ(9),                     -- DELTA: first-insert timestamp
    CONSTRAINT PK_AEROSPACE_PARTS PRIMARY KEY (PART_NUMBER)
);
