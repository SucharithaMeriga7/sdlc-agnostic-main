-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM
-- Object Type   : TABLE
-- Jira Story    : SCRUM-159
-- Requirements  : FR-01
-- Reuse Route   : CREATE_NEW
-- Description   : Singleton table holding the last successful pipeline run timestamp used as the incremental watermark.
-- Author        : Sucharitha
-- Created Date  : 2026-11-14
-- Dependencies  :
--   - none
-- Business Rules: BR-01, BR-02
-- Change History:
--   2026-11-14  Sucharitha  SCRUM-159  Initial generation (CREATE_NEW)
-- =============================================================================

-- Singleton watermark table; one row per pipeline name.
-- BR-01: stores last successful UPDATED_AT high-water mark.
-- BR-02: WATERMARK_TS IS NULL signals first-run full load.
CREATE TABLE IF NOT EXISTS SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM (
    PIPELINE_NAME   VARCHAR(200)    NOT NULL,
    WATERMARK_TS    TIMESTAMP_NTZ,
    UPDATED_AT      TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
);
