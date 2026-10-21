-- =============================================================================
-- Object        : SDLC_DB.ETL.PARTS_TARGET
-- Object Type   : TABLE
-- Jira Story    : SCRUM-156
-- Requirements  : FR-03
-- Reuse Decision: CREATE_NEW
-- Description   : Target table for SCD Type 1 parts data. PART_NUMBER is the natural key; all non-key attributes are overwritten on match per BR-04.
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - none
-- Business Rules: BR-04
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-156  Initial generation (CREATE_NEW)
-- =============================================================================

-- ============================================================
-- TABLE: SDLC_DB.ETL.PARTS_TARGET
-- Purpose : SCD Type 1 target for parts master data (BR-04)
-- FR-03   : MERGE overwrites matched rows; no history retained
-- FR-04   : STATUS column supports soft-delete (BR-05)
-- Clustering on PART_NUMBER justified: primary MERGE join key
-- ============================================================
CREATE TABLE IF NOT EXISTS SDLC_DB.ETL.PARTS_TARGET (
    PART_NUMBER         VARCHAR(100)   NOT NULL,           -- Natural / business key
    PART_NAME           VARCHAR(500),
    MANUFACTURER        VARCHAR(500),                      -- Stored UPPER() per BR-06
    WEIGHT_KG           NUMBER(18,4),                      -- Cleansed per BR-07 (-1 sentinel)
    CERTIFICATION_STATUS VARCHAR(100),
    LEAD_TIME_DAYS      NUMBER(10,0),
    RISK_SCORE          VARCHAR(50),                       -- Derived per BR-08..BR-11
    STATUS              VARCHAR(50)    NOT NULL DEFAULT 'Active', -- BR-05 soft-delete flag
    UPDATED_AT          TIMESTAMP_NTZ,                     -- Source update timestamp
    ETL_LOAD_TIMESTAMP  TIMESTAMP_NTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP(), -- Pipeline load time
    CONSTRAINT PK_PARTS_TARGET PRIMARY KEY (PART_NUMBER)
)
CLUSTER BY (PART_NUMBER); -- Clustering justified: MERGE join key, high-cardinality lookup
