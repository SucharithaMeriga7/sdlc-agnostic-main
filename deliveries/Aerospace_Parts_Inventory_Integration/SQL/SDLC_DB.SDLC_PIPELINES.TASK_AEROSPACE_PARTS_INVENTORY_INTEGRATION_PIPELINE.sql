-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.TASK_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE
-- Object Type   : TASK
-- Jira Story    : SCRUM-156
-- Requirements  : FR-01, FR-02, FR-03, FR-04, FR-05, FR-06, FR-07, FR-08, FR-09
-- Reuse Route   : PIPELINE
-- Description   : Schedules SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE
-- Business Rules: BR-01, BR-02, BR-03, BR-04, BR-05, BR-06, BR-07, BR-08, BR-09, BR-10
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-156  Initial generation (PIPELINE)
-- =============================================================================

-- Scheduled orchestration of SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE (daily 02:00 UTC).
-- Tasks are created SUSPENDED; resume only after the validation pack passes.
CREATE OR REPLACE TASK SDLC_DB.SDLC_PIPELINES.TASK_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE
  WAREHOUSE = SDLC_WH
  SCHEDULE = 'USING CRON 0 2 * * * UTC'
  USER_TASK_TIMEOUT_MS = 3600000
  COMMENT = 'SCRUM-156 - runs the delivery pipeline'
AS
  CALL SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE();

-- After validation:
-- ALTER TASK SDLC_DB.SDLC_PIPELINES.TASK_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE RESUME;
