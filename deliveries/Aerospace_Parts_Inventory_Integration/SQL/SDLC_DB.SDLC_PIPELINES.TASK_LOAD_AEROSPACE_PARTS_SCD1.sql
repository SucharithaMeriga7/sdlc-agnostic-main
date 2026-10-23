-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.TASK_LOAD_AEROSPACE_PARTS_SCD1
-- Object Type   : TASK
-- Jira Story    : SCRUM-158
-- Requirements  : FR-10
-- Reuse Route   : CREATE_NEW
-- Description   : Snowflake Task that schedules SP_LOAD_AEROSPACE_PARTS_SCD1 to run daily at 02:00 UTC on warehouse W_CAPG_APAC_IND_DEMO_IDEA_REFACTOR_SOL_XS.
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.SP_LOAD_AEROSPACE_PARTS_SCD1
-- Business Rules: n/a
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

-- CREATE_NEW: TASK_LOAD_AEROSPACE_PARTS_SCD1 (FR-10)
-- Schedules SP_LOAD_AEROSPACE_PARTS_SCD1 daily at 02:00 UTC.
-- Task is created suspended; resume explicitly after validation.
CREATE OR REPLACE TASK SDLC_DB.SDLC_PIPELINES.TASK_LOAD_AEROSPACE_PARTS_SCD1
    WAREHOUSE   = SDLC_WH
    -- FR-10: Execute every day at 02:00 UTC using CRON schedule
    SCHEDULE    = 'USING CRON 0 2 * * * UTC'
    COMMENT     = 'Daily 02:00 UTC trigger for aerospace parts SCD1 pipeline (FR-10)'
AS
    -- Call the orchestration procedure
    CALL SDLC_DB.SDLC_PIPELINES.SP_LOAD_AEROSPACE_PARTS_SCD1();
