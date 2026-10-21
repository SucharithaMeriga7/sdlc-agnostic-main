-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE
-- Object Type   : PROCEDURE
-- Jira Story    : SCRUM-156
-- Requirements  : FR-01, FR-02, FR-03, FR-04, FR-05, FR-06, FR-07, FR-08, FR-09
-- Reuse Route   : PIPELINE
-- Description   : Pipeline orchestration for Aerospace_Parts_Inventory_Integration
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.PARTS_INCREMENTAL_DT
--   - SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED_VW
--   - SDLC_DB.SDLC_PIPELINES.PARTS_SCD1_MERGE_PROC
--   - SDLC_DB.SDLC_PIPELINES.PARTS_SOFT_DELETE_PROC
--   - SDLC_DB.SDLC_PIPELINES.PARTS_TRANSFORM_VW
--   - SDLC_DB.SDLC_PIPELINES.PARTS_TRANSFORM_VW
--   - SDLC_DB.SDLC_PIPELINES.PARTS_RISK_SCORE_VW
--   - SDLC_DB.SDLC_PIPELINES.RECONCILIATION_CHECK_PROC
--   - SDLC_DB.SDLC_PIPELINES.TASK_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE
-- Business Rules: BR-01, BR-02, BR-03, BR-04, BR-05, BR-06, BR-07, BR-08, BR-09, BR-10, BR-11, BR-12, BR-13
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-156  Initial generation (PIPELINE)
-- =============================================================================

CREATE OR REPLACE PROCEDURE SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE()
  RETURNS VARCHAR
  LANGUAGE SQL
  EXECUTE AS CALLER
AS
$$
DECLARE
  -- Summary counters
  v_step                VARCHAR DEFAULT '';
  v_summary             VARCHAR DEFAULT '';
  v_merge_inserted      NUMBER  DEFAULT 0;
  v_merge_updated       NUMBER  DEFAULT 0;
  v_soft_deleted        NUMBER  DEFAULT 0;
  v_source_count        NUMBER  DEFAULT 0;
  v_target_count        NUMBER  DEFAULT 0;
  v_recon_result        VARCHAR DEFAULT '';
  v_scd1_result         VARCHAR DEFAULT '';
  v_soft_del_result     VARCHAR DEFAULT '';
BEGIN

  -- -------------------------------------------------------------------------
  -- STEP 1: Refresh the incremental dynamic table (FR-01, BR-01, BR-02)
  -- PARTS_INCREMENTAL_DT filters IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE
  -- by UPDATED_AT > last successful execution timestamp; full load on first run.
  -- -------------------------------------------------------------------------
  v_step := 'STEP 1 - Refresh PARTS_INCREMENTAL_DT';
  ALTER DYNAMIC TABLE SDLC_DB.SDLC_PIPELINES.PARTS_INCREMENTAL_DT REFRESH;
  v_summary := v_summary || v_step || ' => OK; ';

  -- -------------------------------------------------------------------------
  -- STEP 2: Capture source record count from the incremental dynamic table
  -- (used later for reconciliation logging per BR-12)
  -- PARTS_DEDUPLICATED_VW (FR-02, BR-03) and PARTS_TRANSFORM_VW (FR-05/FR-06,
  -- BR-06/BR-07) and PARTS_RISK_SCORE_VW (FR-07, BR-08..BR-11) are views that
  -- sit on top of PARTS_INCREMENTAL_DT and are evaluated at merge time.
  -- -------------------------------------------------------------------------
  v_step := 'STEP 2 - Count deduplicated source records';
  SELECT COUNT(*)
    INTO :v_source_count
    FROM SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED_VW;
  v_summary := v_summary || v_step || ' => ' || :v_source_count || ' rows; ';

  -- -------------------------------------------------------------------------
  -- STEP 3: Execute SCD Type 1 MERGE procedure (FR-03, BR-04)
  -- PARTS_SCD1_MERGE_PROC merges PARTS_RISK_SCORE_VW (which chains through
  -- PARTS_TRANSFORM_VW -> PARTS_DEDUPLICATED_VW -> PARTS_INCREMENTAL_DT)
  -- into AEROSPACE_PARTS_TARGET using PART_NUMBER as the business key.
  -- The procedure is expected to return a VARCHAR summary of rows affected.
  -- -------------------------------------------------------------------------
  v_step := 'STEP 3 - SCD1 MERGE via PARTS_SCD1_MERGE_PROC';
  CALL SDLC_DB.SDLC_PIPELINES.PARTS_SCD1_MERGE_PROC()
    INTO :v_scd1_result;
  -- Parse inserted/updated counts from the procedure return string if available
  -- Defaulting to 0 if the procedure does not expose them; reconciliation proc
  -- will compute authoritative counts from ROWCOUNT metadata.
  v_summary := v_summary || v_step || ' => ' || :v_scd1_result || '; ';

  -- -------------------------------------------------------------------------
  -- STEP 4: Execute soft-delete procedure (FR-04, BR-05)
  -- PARTS_SOFT_DELETE_PROC identifies PART_NUMBERs present in
  -- AEROSPACE_PARTS_TARGET but absent from the current source extract and
  -- sets their LIFECYCLE_STATUS to 'Decommissioned'.
  -- -------------------------------------------------------------------------
  v_step := 'STEP 4 - Soft delete via PARTS_SOFT_DELETE_PROC';
  CALL SDLC_DB.SDLC_PIPELINES.PARTS_SOFT_DELETE_PROC()
    INTO :v_soft_del_result;
  v_summary := v_summary || v_step || ' => ' || :v_soft_del_result || '; ';

  -- -------------------------------------------------------------------------
  -- STEP 5: Capture post-merge target record count for reconciliation (BR-12)
  -- -------------------------------------------------------------------------
  v_step := 'STEP 5 - Count target records post-merge';
  SELECT COUNT(*)
    INTO :v_target_count
    FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET;
  v_summary := v_summary || v_step || ' => ' || :v_target_count || ' rows; ';

  -- -------------------------------------------------------------------------
  -- STEP 6: Execute reconciliation check and logging procedure (FR-08, BR-12)
  -- RECONCILIATION_CHECK_PROC logs source_count, target_count, inserted_count,
  -- updated_count, and soft_deleted_count to ETL_RECONCILIATION_LOG.
  -- -------------------------------------------------------------------------
  v_step := 'STEP 6 - Reconciliation logging via RECONCILIATION_CHECK_PROC';
  CALL SDLC_DB.SDLC_PIPELINES.RECONCILIATION_CHECK_PROC()
    INTO :v_recon_result;
  v_summary := v_summary || v_step || ' => ' || :v_recon_result || '; ';

  -- -------------------------------------------------------------------------
  -- All steps completed successfully; return consolidated summary.
  -- -------------------------------------------------------------------------
  RETURN 'SUCCESS: ' || :v_summary;

EXCEPTION
  WHEN OTHER THEN
    -- Capture error details into local variables before use in expressions
    LET err_msg  VARCHAR := SQLERRM;
    LET err_code VARCHAR := SQLCODE;
    LET err_state VARCHAR := SQLSTATE;
    RETURN 'FAILED at ' || :v_step || ' | SQLCODE=' || :err_code
           || ' | SQLSTATE=' || :err_state
           || ' | SQLERRM=' || :err_msg;
END;
$$;

GRANT ALL ON DYNAMIC TABLE SDLC_DB.SDLC_PIPELINES.PARTS_INCREMENTAL_DT TO ROLE SDLC_DEPLOYER;
