-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.TASK_REVIEW_PIPELINE
-- Object Type   : TASK
-- Jira Story    : SCRUM-160
-- Requirements  : all
-- Reuse Route   : PIPELINE
-- Description   : Schedules SDLC_DB.SDLC_PIPELINES.SP_REVIEW_PIPELINE
-- Author        : Sucharitha
-- Created Date  : 2026-11-14
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.SP_REVIEW_PIPELINE
-- Business Rules: n/a
-- Change History:
--   2026-11-14  Sucharitha  SCRUM-160  Initial generation (PIPELINE)
-- =============================================================================

-- Scheduled orchestration of SDLC_DB.SDLC_PIPELINES.SP_REVIEW_PIPELINE (daily 02:00 UTC (default)).
-- Created SUSPENDED; resume after the validation pack passes:
--   ALTER TASK SDLC_DB.SDLC_PIPELINES.TASK_REVIEW_PIPELINE RESUME;
CREATE OR REPLACE TASK SDLC_DB.SDLC_PIPELINES.TASK_REVIEW_PIPELINE
  WAREHOUSE = SNOWFLAKE_LEARNING_WH
  SCHEDULE = 'USING CRON 0 2 * * * UTC'
  USER_TASK_TIMEOUT_MS = 3600000
  COMMENT = 'SCRUM-160 - runs the delivery pipeline'
AS
  CALL SDLC_DB.SDLC_PIPELINES.SP_REVIEW_PIPELINE();
