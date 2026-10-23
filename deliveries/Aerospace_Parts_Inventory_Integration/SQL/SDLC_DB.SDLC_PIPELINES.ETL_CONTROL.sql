-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.ETL_CONTROL
-- Object Type   : TABLE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-01
-- Reuse Route   : CREATE_NEW
-- Description   : Watermark control table storing the last successful execution timestamp per pipeline. Used for incremental load logic per BR-01 and BR-02.
-- Author        : Sucharitha
-- Created Date  : 2026-10-23
-- Dependencies  :
--   - none
-- Business Rules: BR-01, BR-02
-- Change History:
--   2026-10-23  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE TABLE IF NOT EXISTS SDLC_DB.SDLC_PIPELINES.ETL_CONTROL (
    -- Unique identifier for the pipeline being tracked
    PIPELINE_NAME       VARCHAR(200)    NOT NULL,
    -- Timestamp of the last successful pipeline execution (NULL on first run -> full load per BR-02)
    LAST_RUN_TS         TIMESTAMP_NTZ,
    -- Timestamp when this control record was last updated
    UPDATED_AT          TIMESTAMP_NTZ   NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_ETL_CONTROL PRIMARY KEY (PIPELINE_NAME)
);

CREATE TABLE IF NOT EXISTS SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING (
    PART_NUMBER          VARCHAR(200)    NOT NULL,
    PART_NAME            VARCHAR(500),
    MANUFACTURER         VARCHAR(500),
    WEIGHT_KG            NUMBER(10,3),
    CERTIFICATION_STATUS VARCHAR(100),
    LEAD_TIME_DAYS       NUMBER(38,0),
    LIFECYCLE_STATUS     VARCHAR(100),
    RISK_SCORE           VARCHAR(100),
    UPDATED_AT           TIMESTAMP_NTZ
);
