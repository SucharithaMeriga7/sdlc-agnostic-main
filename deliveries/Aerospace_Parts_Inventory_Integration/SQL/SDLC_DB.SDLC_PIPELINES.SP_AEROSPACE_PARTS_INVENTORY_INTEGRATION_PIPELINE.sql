-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE
-- Object Type   : PROCEDURE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-01, FR-02, FR-03, FR-04, FR-05, FR-06, FR-07, FR-08, FR-09, FR-10
-- Reuse Route   : PIPELINE
-- Description   : Pipeline orchestration for Aerospace_Parts_Inventory_Integration
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.PARTS_TRANSFORM_VW
--   - SDLC_DB.SDLC_PIPELINES.SP_LOAD_AEROSPACE_PARTS_SCD1
--   - SDLC_DB.SDLC_PIPELINES.TASK_LOAD_AEROSPACE_PARTS_SCD1
--   - SDLC_DB.SDLC_PIPELINES.PARTS_INCREMENTAL_DT
--   - SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED_VW
--   - SDLC_DB.SDLC_PIPELINES.PARTS_SCD1_MERGE_PROC
--   - SDLC_DB.SDLC_PIPELINES.PARTS_SOFT_DELETE_PROC
--   - SDLC_DB.SDLC_PIPELINES.PARTS_TRANSFORM_VW
--   - SDLC_DB.SDLC_PIPELINES.PARTS_RISK_SCORE_VW
--   - SDLC_DB.SDLC_PIPELINES.RECONCILIATION_CHECK_PROC
-- Business Rules: BR-01, BR-02, BR-03, BR-04, BR-05, BR-06, BR-07, BR-08, BR-09, BR-10, BR-11, BR-12, BR-13, BR-14
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-158  Initial generation (PIPELINE)
-- =============================================================================

CREATE OR REPLACE PROCEDURE SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_step    VARCHAR DEFAULT 'INIT';
    v_result  VARCHAR DEFAULT '';
    v_summary VARCHAR DEFAULT '';
BEGIN
    -- ================================================================
    -- AEROSPACE PARTS INVENTORY INTEGRATION PIPELINE
    -- Single entry point: delegates to SP_LOAD_AEROSPACE_PARTS_SCD1
    -- which performs all pipeline steps (FR-01..FR-09).
    -- ================================================================

    -- ----------------------------------------------------------------
    -- STEP 1: Execute full pipeline via SP_LOAD_AEROSPACE_PARTS_SCD1
    -- (FR-09). Covers incremental load, dedup, transform, risk score,
    -- SCD1 merge, soft delete, and reconciliation logging.
    -- Capture the return value to propagate errors upward.
    -- ----------------------------------------------------------------
    v_step := 'STEP1_SP_LOAD_AEROSPACE_PARTS_SCD1';
    CALL SDLC_DB.SDLC_PIPELINES.SP_LOAD_AEROSPACE_PARTS_SCD1()
        INTO :v_result;
    v_summary := :v_summary
        || 'STEP1:SP_LOAD_AEROSPACE_PARTS_SCD1 returned=' || :v_result || '; ';

    -- ----------------------------------------------------------------
    -- All steps completed successfully; return summary
    -- ----------------------------------------------------------------
    RETURN 'SUCCESS | ' || :v_summary;

EXCEPTION
    WHEN OTHER THEN
        LET err_msg   VARCHAR := SQLERRM;
        LET err_code  VARCHAR := SQLCODE;
        LET err_state VARCHAR := SQLSTATE;
        RETURN 'FAILED at ' || :v_step
            || ' | SQLCODE='  || :err_code
            || ' | SQLSTATE=' || :err_state
            || ' | SQLERRM='  || :err_msg;
END;
$$;
