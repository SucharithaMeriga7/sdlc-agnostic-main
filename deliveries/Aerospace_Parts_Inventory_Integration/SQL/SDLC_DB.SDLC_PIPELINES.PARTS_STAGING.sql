-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.PARTS_STAGING
-- Object Type   : TABLE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-01, FR-02
-- Reuse Route   : CREATE_NEW
-- Description   : Transient staging table holding the current incremental/full extract after deduplication, used as MERGE source.
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - none
-- Business Rules: BR-01, BR-02, BR-03
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

-- Staging table: populated each run with the deduplicated, transformed, risk-scored extract.
-- Truncated at the start of each run so it always reflects only the current batch.
CREATE TABLE IF NOT EXISTS SDLC_DB.SDLC_PIPELINES.PARTS_STAGING (
    PART_NUMBER             VARCHAR(100)    NOT NULL,
    PART_NAME               VARCHAR(500),
    MANUFACTURER            VARCHAR(500),
    CATEGORY                VARCHAR(200),
    UNIT_PRICE              NUMBER(18,4),
    WEIGHT_KG               NUMBER(18,4),
    CERTIFICATION_STATUS    VARCHAR(100),
    LEAD_TIME_DAYS          NUMBER(10,0),
    STATUS                  VARCHAR(100),
    RISK_SCORE              VARCHAR(50),
    UPDATED_AT              TIMESTAMP_NTZ
);
