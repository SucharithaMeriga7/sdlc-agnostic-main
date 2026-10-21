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
--   - SDLC_DB.SDLC_PIPELINES.PARTS_TRANSFORM_VW
--   - SDLC_DB.SDLC_PIPELINES.PARTS_RISK_SCORE_VW
--   - SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
--   - SDLC_DB.SDLC_PIPELINES.PARTS_SCD1_MERGE_PROC
--   - SDLC_DB.SDLC_PIPELINES.PARTS_SOFT_DELETE_PROC
--   - SDLC_DB.SDLC_PIPELINES.RECONCILIATION_CHECK_PROC
-- Business Rules: BR-01, BR-02, BR-03, BR-04, BR-05, BR-06, BR-07, BR-08, BR-09, BR-10
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
    -- Pipeline orchestration variables
    v_run_id            VARCHAR;
    v_step_summary      VARCHAR DEFAULT '';
    v_step_result       VARCHAR;
    v_pipeline_status   VARCHAR DEFAULT 'SUCCESS';
BEGIN
    -- -------------------------------------------------------------------------
    -- STEP 0: Generate a unique RUN_ID for this pipeline execution
    -- Used to correlate all reconciliation and audit records for this run
    -- -------------------------------------------------------------------------
    v_run_id := 'RUN_' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDD_HH24MISS_FF3');
    v_step_summary := v_step_summary || 'RUN_ID=' || v_run_id || '; ';

    -- -------------------------------------------------------------------------
    -- STEP 1: Refresh PARTS_INCREMENTAL_DT (Dynamic Table)
    -- FR-01/BR-01/BR-02: Triggers incremental load from source.
    -- First run performs full load; subsequent runs are incremental by UPDATED_AT.
    -- BR-10: Must complete within daily schedule window.
    -- -------------------------------------------------------------------------
    ALTER DYNAMIC TABLE SDLC_DB.SDLC_PIPELINES.PARTS_INCREMENTAL_DT REFRESH;
    v_step_summary := v_step_summary || 'STEP1_INCREMENTAL_DT_REFRESH=OK; ';

    -- -------------------------------------------------------------------------
    -- STEP 2: PARTS_DEDUPLICATED_VW is a view (no refresh needed)
    -- FR-02/BR-03: Deduplication is applied at query time via ROW_NUMBER() QUALIFY.
    -- Downstream steps reference this view directly.
    -- -------------------------------------------------------------------------
    v_step_summary := v_step_summary || 'STEP2_DEDUPLICATED_VW=PASSTHROUGH; ';

    -- -------------------------------------------------------------------------
    -- STEP 3: PARTS_TRANSFORM_VW is a view (no refresh needed)
    -- FR-05/BR-06: MANUFACTURER uppercased.
    -- FR-06/BR-07: WEIGHT_KG <= 0 replaced with -1.
    -- Applied at query time; downstream steps reference this view.
    -- -------------------------------------------------------------------------
    v_step_summary := v_step_summary || 'STEP3_TRANSFORM_VW=PASSTHROUGH; ';

    -- -------------------------------------------------------------------------
    -- STEP 4: PARTS_RISK_SCORE_VW is a view (no refresh needed)
    -- FR-07/BR-08: RISK_SCORE derived from CERTIFICATION and LEAD_TIME_DAYS.
    -- Applied at query time; MERGE in STEP 5 reads from this view.
    -- -------------------------------------------------------------------------
    v_step_summary := v_step_summary || 'STEP4_RISK_SCORE_VW=PASSTHROUGH; ';

    -- -------------------------------------------------------------------------
    -- STEP 5: Execute SCD Type 1 MERGE procedure
    -- FR-03/BR-04: MERGE from PARTS_RISK_SCORE_VW into AEROSPACE_PARTS_TARGET.
    -- MATCHED => overwrite all non-key columns (no history retained).
    -- NOT MATCHED => insert new record.
    -- -------------------------------------------------------------------------
    CALL SDLC_DB.SDLC_PIPELINES.PARTS_SCD1_MERGE_PROC(:v_run_id);
    v_step_result := (SELECT LAST_QUERY_ID());
    v_step_summary := v_step_summary || 'STEP5_SCD1_MERGE=OK; ';

    -- -------------------------------------------------------------------------
    -- STEP 6: Execute soft-delete procedure
    -- FR-04/BR-05: Target records absent from current source extract
    -- have their STATUS set to 'Decommissioned'.
    -- -------------------------------------------------------------------------
    CALL SDLC_DB.SDLC_PIPELINES.PARTS_SOFT_DELETE_PROC(:v_run_id);
    v_step_summary := v_step_summary || 'STEP6_SOFT_DELETE=OK; ';

    -- -------------------------------------------------------------------------
    -- STEP 7: Execute reconciliation check and log results
    -- FR-08/BR-09: Compare source vs. target counts, log inserted/updated/
    -- soft-deleted counts and discrepancy status to ETL_RECONCILIATION_LOG.
    -- -------------------------------------------------------------------------
    CALL SDLC_DB.SDLC_PIPELINES.RECONCILIATION_CHECK_PROC(:v_run_id);
    v_step_summary := v_step_summary || 'STEP7_RECONCILIATION=OK; ';

    -- -------------------------------------------------------------------------
    -- STEP 8: Return pipeline summary
    -- FR-09/BR-10: Pipeline must process up to 1M records within 5 minutes.
    -- Summary string provides observability for task monitoring.
    -- -------------------------------------------------------------------------
    v_step_summary := v_step_summary || 'PIPELINE_STATUS=' || v_pipeline_status;
    RETURN v_step_summary;

EXCEPTION
    WHEN OTHER THEN
        -- Log failure to reconciliation log for auditability (BR-09)
        INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
            RUN_ID, EXECUTION_TS, SOURCE_COUNT, TARGET_COUNT,
            INSERTED, UPDATED, SOFT_DELETED, RECONCILIATION_STATUS, DETAILS
        ) VALUES (
            :v_run_id, CURRENT_TIMESTAMP(), 0, 0, 0, 0, 0,
            'FAIL', 'Pipeline exception at step: ' || :v_step_summary || ' ERROR: ' || SQLERRM
        );
        RETURN 'FAILED: ' || SQLERRM;
END;
$$
;
