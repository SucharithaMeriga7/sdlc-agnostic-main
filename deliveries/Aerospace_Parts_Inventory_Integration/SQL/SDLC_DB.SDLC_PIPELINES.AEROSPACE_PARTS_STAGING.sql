-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING
-- Object Type   : TABLE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-01, FR-02
-- Reuse Route   : CREATE_NEW
-- Description   : Transient staging table holding the current incremental or full extract before deduplication and transformation.
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - none
-- Business Rules: BR-01, BR-02, BR-03
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE TABLE IF NOT EXISTS SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING (
    PART_NUMBER          TEXT,
    PART_NAME            TEXT,
    MANUFACTURER         TEXT,
    CATEGORY             TEXT,
    WEIGHT_KG            NUMBER(38,10),   -- preserve decimals from source
    UNIT_PRICE_USD       NUMBER(38,10),
    QUANTITY_ON_HAND     NUMBER(38,0),
    REORDER_LEVEL        NUMBER(38,0),
    LIFECYCLE_STATUS     TEXT,
    CERTIFICATION_STATUS TEXT,
    INSTALLATION_DATE    DATE,
    LEAD_TIME_DAYS       NUMBER(38,0),
    SUPPLIER             TEXT,
    WAREHOUSE_LOCATION   TEXT,
    COUNTRY_OF_ORIGIN    TEXT,
    CREATED_AT           TIMESTAMP_NTZ,
    UPDATED_AT           TIMESTAMP_NTZ
);
