-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.TASK_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE
-- Object Type   : TASK
-- Jira Story    : SCRUM-158
-- Requirements  : FR-01, FR-02, FR-03, FR-04, FR-05, FR-06, FR-07, FR-08, FR-09
-- Reuse Route   : PIPELINE
-- Description   : Schedules SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE
-- Author        : Sucharitha
-- Created Date  : 2026-10-26
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE
-- Business Rules: BR-01, BR-02, BR-03, BR-04, BR-05, BR-06, BR-07, BR-08, BR-09, BR-10, BR-11, BR-12
-- Change History:
--   2026-10-26  Sucharitha  SCRUM-158  Initial generation (PIPELINE)
-- =============================================================================

-- Scheduled orchestration of SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE (as stated in the MOM (0 5 * * * UTC)).
-- Created SUSPENDED; resume after the validation pack passes:
--   ALTER TASK SDLC_DB.SDLC_PIPELINES.TASK_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE RESUME;
CREATE OR REPLACE TASK SDLC_DB.SDLC_PIPELINES.TASK_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE
  WAREHOUSE = W_CAPG_IDEA_REFACTOR_SOL_XS
  SCHEDULE = 'USING CRON 0 5 * * * UTC'
  USER_TASK_TIMEOUT_MS = 3600000
  COMMENT = 'SCRUM-158 - runs the delivery pipeline'
AS
  CALL SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE();
