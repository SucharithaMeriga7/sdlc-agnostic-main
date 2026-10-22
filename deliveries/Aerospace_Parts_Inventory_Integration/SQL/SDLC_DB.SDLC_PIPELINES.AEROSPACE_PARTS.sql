-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS
-- Object Type   : TABLE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-03
-- Reuse Route   : CREATE_NEW
-- Description   : SCD Type 1 target table for aerospace parts. PART_NUMBER is the business key (BR-04).
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - none
-- Business Rules: BR-04, BR-05
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE TABLE IF NOT EXISTS SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS (
    PART_NUMBER          TEXT            NOT NULL,   -- business key (BR-04)
    PART_NAME            TEXT,
    MANUFACTURER         TEXT,           -- stored uppercase (BR-06)
    CATEGORY             TEXT,
    WEIGHT_KG            NUMBER(38,10),  -- cleansed; -1 for invalid (BR-07)
    UNIT_PRICE_USD       NUMBER(38,10),
    QUANTITY_ON_HAND     NUMBER(38,0),
    REORDER_LEVEL        NUMBER(38,0),
    LIFECYCLE_STATUS     TEXT,           -- 'Decommissioned' for soft-delete (BR-05)
    CERTIFICATION_STATUS TEXT,
    INSTALLATION_DATE    DATE,
    LEAD_TIME_DAYS       NUMBER(38,0),
    SUPPLIER             TEXT,
    WAREHOUSE_LOCATION   TEXT,
    COUNTRY_OF_ORIGIN    TEXT,
    RISK_SCORE           TEXT,           -- derived (BR-08 to BR-11)
    UPDATED_AT           TIMESTAMP_NTZ,
    LOAD_TIMESTAMP       TIMESTAMP_NTZ,  -- pipeline load time
    CONSTRAINT PK_AEROSPACE_PARTS PRIMARY KEY (PART_NUMBER)
);
