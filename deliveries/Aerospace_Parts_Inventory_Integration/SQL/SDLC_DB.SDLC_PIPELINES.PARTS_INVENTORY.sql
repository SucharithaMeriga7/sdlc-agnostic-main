-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.PARTS_INVENTORY
-- Object Type   : TABLE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-03, FR-04
-- Reuse Route   : CREATE_NEW
-- Description   : Target table for aerospace parts inventory. SCD Type 1 merge target with soft-delete support.
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - none
-- Business Rules: BR-04, BR-05
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

-- Target table for SCD Type 1 merge (BR-04) and soft-delete (BR-05).
-- All columns that the procedure writes must be declared here with exact types.
CREATE TABLE IF NOT EXISTS SDLC_DB.SDLC_PIPELINES.PARTS_INVENTORY (
    PART_NUMBER             VARCHAR(100)    NOT NULL,      -- business key (BR-04)
    PART_NAME               VARCHAR(500),
    MANUFACTURER            VARCHAR(500),                  -- stored UPPER() per BR-06
    CATEGORY                VARCHAR(200),
    UNIT_PRICE              NUMBER(18,4),
    WEIGHT_KG               NUMBER(18,4),                  -- -1 when original <= 0 (BR-07)
    CERTIFICATION_STATUS    VARCHAR(100),
    LEAD_TIME_DAYS          NUMBER(10,0),
    STATUS                  VARCHAR(100),                  -- 'Decommissioned' on soft-delete (BR-05)
    RISK_SCORE              VARCHAR(50),                   -- derived per BR-08..BR-11
    UPDATED_AT              TIMESTAMP_NTZ,                 -- source UPDATED_AT
    PIPELINE_LOAD_TS        TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(), -- pipeline write timestamp
    CONSTRAINT PK_PARTS_INVENTORY PRIMARY KEY (PART_NUMBER)
);
