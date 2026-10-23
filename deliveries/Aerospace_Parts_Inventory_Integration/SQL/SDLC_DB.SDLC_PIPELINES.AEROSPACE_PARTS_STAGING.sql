-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING
-- Object Type   : TABLE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-01, FR-02, FR-03
-- Reuse Route   : CREATE_NEW
-- Description   : Transient staging table holding the incremental (or full) deduplicated, transformed, cleansed and risk-scored extract for the current run before MERGE into the target.
-- Author        : Sucharitha
-- Created Date  : 2026-10-23
-- Dependencies  :
--   - none
-- Business Rules: BR-01, BR-02, BR-03
-- Change History:
--   2026-10-23  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE TABLE IF NOT EXISTS SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING (
    PART_NUMBER          VARCHAR(50),
    PART_NAME            VARCHAR(200),
    MANUFACTURER         VARCHAR(100),
    CATEGORY             VARCHAR(100),
    WEIGHT_KG            NUMBER(10,3),
    UNIT_PRICE_USD       NUMBER(14,4),
    QUANTITY_ON_HAND     NUMBER(38,0),
    REORDER_LEVEL        NUMBER(38,0),
    LIFECYCLE_STATUS     VARCHAR(50),
    CERTIFICATION_STATUS VARCHAR(50),
    INSTALLATION_DATE    DATE,
    LEAD_TIME_DAYS       NUMBER(38,0),
    SUPPLIER             VARCHAR(200),
    WAREHOUSE_LOCATION   VARCHAR(100),
    COUNTRY_OF_ORIGIN    VARCHAR(100),
    CREATED_AT           TIMESTAMP_NTZ(9),
    UPDATED_AT           TIMESTAMP_NTZ(9),
    RISK_SCORE           VARCHAR(50)
);
