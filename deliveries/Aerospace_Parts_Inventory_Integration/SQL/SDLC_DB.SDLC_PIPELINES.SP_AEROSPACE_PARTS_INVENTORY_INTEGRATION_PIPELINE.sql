-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE
-- Object Type   : PROCEDURE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-01, FR-02, FR-03, FR-04, FR-05, FR-06, FR-07, FR-08, FR-09
-- Reuse Route   : PIPELINE
-- Description   : Pipeline orchestration for Aerospace_Parts_Inventory_Integration
-- Author        : Sucharitha
-- Created Date  : 2026-10-23
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.FN_CAMELCASE_MANUFACTURER
--   - SDLC_DB.SDLC_PIPELINES.FN_NORMALIZE_WEIGHT
--   - SDLC_DB.SDLC_PIPELINES.FN_CALCULATE_RISK_SCORE
--   - SDLC_DB.SDLC_PIPELINES.ETL_CONTROL
--   - SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
--   - SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
-- Business Rules: BR-01, BR-02, BR-03, BR-04, BR-05, BR-06, BR-07, BR-08, BR-09, BR-10, BR-11, BR-12
-- Change History:
--   2026-10-23  Sucharitha  SCRUM-158  Initial generation (PIPELINE)
-- =============================================================================

CREATE OR REPLACE PROCEDURE SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    -- -------------------------------------------------------------------------
    -- Variable declarations - each declared exactly once
    -- -------------------------------------------------------------------------

    -- Pipeline identification constant
    v_pipeline_name     VARCHAR        DEFAULT 'AEROSPACE_PARTS';

    -- Watermark and load type tracking (FR-01, BR-01, BR-02)
    v_last_run_ts       TIMESTAMP_NTZ  DEFAULT NULL;
    v_load_type         VARCHAR        DEFAULT 'FULL';

    -- Row count accumulators for reconciliation (FR-08, BR-12)
    v_source_count      NUMBER(38,0)   DEFAULT 0;
    v_target_count      NUMBER(38,0)   DEFAULT 0;
    v_inserted_count    NUMBER(38,0)   DEFAULT 0;
    v_updated_count     NUMBER(38,0)   DEFAULT 0;
    v_soft_del_count    NUMBER(38,0)   DEFAULT 0;
    v_excluded_count    NUMBER(38,0)   DEFAULT 0;
    v_dedup_count       NUMBER(38,0)   DEFAULT 0;

    -- Temporary variables for RESULT_SCAN reads
    ins                 NUMBER(38,0)   DEFAULT 0;
    upd                 NUMBER(38,0)   DEFAULT 0;

    -- Summary string returned to caller
    v_summary           VARCHAR        DEFAULT '';

BEGIN
    -- =========================================================================
    -- STEP 1: Resolve watermark from ETL_CONTROL (FR-01, BR-01, BR-02)
    -- =========================================================================
    -- Attempt to read the last successful run timestamp for this pipeline.
    -- If no row exists (first run) LAST_RUN_TS will be NULL -> full load.
    SELECT COALESCE(MAX(LAST_RUN_TS), NULL)
    INTO   :v_last_run_ts
    FROM   SDLC_DB.SDLC_PIPELINES.ETL_CONTROL
    WHERE  PIPELINE_NAME = :v_pipeline_name;

    -- BR-02: NULL watermark means first run -> full load
    -- BR-01: Non-NULL watermark means incremental load
    IF (:v_last_run_ts IS NULL) THEN
        v_load_type := 'FULL';
    ELSE
        v_load_type := 'INCREMENTAL';
    END IF;

    -- =========================================================================
    -- STEP 2: Populate staging table with deduplicated, transformed source data
    --         (FR-02, FR-05, FR-06, FR-07, BR-03, BR-06, BR-07, BR-08 to BR-11)
    -- =========================================================================
    -- Truncate staging table before each load to ensure idempotency
    DELETE FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING
    WHERE  1 = 1;

    -- Insert deduplicated and transformed records into staging.
    -- Source: SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED (reused, FR-02)
    -- The view already applies BR-03 deduplication (QUALIFY ROW_NUMBER() = 1 by PART_NUMBER).
    -- Watermark filter implements BR-01 / BR-02 incremental vs full load.
    -- Transformations applied inline:
    --   FN_CAMELCASE_MANUFACTURER -> BR-06 (UPPER)
    --   FN_NORMALIZE_WEIGHT       -> BR-07 (replace <= 0 with -1)
    --   FN_CALCULATE_RISK_SCORE   -> BR-08 to BR-11
    INSERT INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING (
        PART_NUMBER,
        PART_NAME,
        MANUFACTURER,
        WEIGHT_KG,
        CERTIFICATION_STATUS,
        LEAD_TIME_DAYS,
        LIFECYCLE_STATUS,
        RISK_SCORE,
        UPDATED_AT
    )
    SELECT
        v.PART_NUMBER,
        v.PART_NAME,
        -- BR-06: Convert MANUFACTURER to uppercase via UDF
        SDLC_DB.SDLC_PIPELINES.FN_CAMELCASE_MANUFACTURER(v.MANUFACTURER)   AS MANUFACTURER,
        -- BR-07: Replace WEIGHT_KG <= 0 with -1 via UDF
        SDLC_DB.SDLC_PIPELINES.FN_NORMALIZE_WEIGHT(v.WEIGHT_KG)            AS WEIGHT_KG,
        v.CERTIFICATION_STATUS,
        v.LEAD_TIME_DAYS,
        v.LIFECYCLE_STATUS,
        -- BR-08 to BR-11: Derive RISK_SCORE via UDF
        SDLC_DB.SDLC_PIPELINES.FN_CALCULATE_RISK_SCORE(
            v.CERTIFICATION_STATUS,
            v.LEAD_TIME_DAYS
        )                                                                    AS RISK_SCORE,
        v.UPDATED_AT
    FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED v
    WHERE
        -- BR-01: Incremental filter - only records updated after last run
        -- BR-02: Full load when v_last_run_ts IS NULL (no filter applied)
        (:v_last_run_ts IS NULL OR v.UPDATED_AT > :v_last_run_ts);

    -- Capture source count after staging load
    v_source_count := SQLROWCOUNT;

    -- =========================================================================
    -- STEP 3: SCD Type 1 MERGE into target table (FR-03, BR-04)
    -- =========================================================================
    -- MERGE on PART_NUMBER:
    --   WHEN MATCHED    -> overwrite all fields (SCD1, BR-04)
    --   WHEN NOT MATCHED -> insert new record
    MERGE INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET AS tgt
    USING SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING     AS src
        -- Join key: PART_NUMBER is the natural business key
        ON tgt.PART_NUMBER = src.PART_NUMBER
    WHEN MATCHED THEN
        -- BR-04: SCD Type 1 - overwrite all target fields with source values
        UPDATE SET
            tgt.PART_NAME            = src.PART_NAME,
            tgt.MANUFACTURER         = src.MANUFACTURER,
            tgt.WEIGHT_KG            = src.WEIGHT_KG,
            tgt.CERTIFICATION_STATUS = src.CERTIFICATION_STATUS,
            tgt.LEAD_TIME_DAYS       = src.LEAD_TIME_DAYS,
            tgt.LIFECYCLE_STATUS     = src.LIFECYCLE_STATUS,
            tgt.RISK_SCORE           = src.RISK_SCORE,
            tgt.UPDATED_AT           = src.UPDATED_AT
    WHEN NOT MATCHED THEN
        -- Net-new PART_NUMBER: insert full record
        INSERT (
            PART_NUMBER,
            PART_NAME,
            MANUFACTURER,
            WEIGHT_KG,
            CERTIFICATION_STATUS,
            LEAD_TIME_DAYS,
            LIFECYCLE_STATUS,
            RISK_SCORE,
            UPDATED_AT
        )
        VALUES (
            src.PART_NUMBER,
            src.PART_NAME,
            src.MANUFACTURER,
            src.WEIGHT_KG,
            src.CERTIFICATION_STATUS,
            src.LEAD_TIME_DAYS,
            src.LIFECYCLE_STATUS,
            src.RISK_SCORE,
            src.UPDATED_AT
        );

    -- Read MERGE result counts from RESULT_SCAN (both WHEN clauses present)
    SELECT
        "number of rows inserted",
        "number of rows updated"
    INTO :ins, :upd
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

    v_inserted_count := :ins;
    v_updated_count  := :upd;

    -- =========================================================================
    -- STEP 4: Soft-delete records absent from current source extract (FR-04, BR-05)
    -- =========================================================================
    -- Any PART_NUMBER present in the target but NOT in the current staging extract
    -- must be marked as Decommissioned. This implements the soft-delete pattern.
    -- Only apply to records not already Decommissioned to avoid unnecessary updates.
    UPDATE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET AS tgt
    SET    tgt.LIFECYCLE_STATUS = 'Decommissioned'
    WHERE  tgt.LIFECYCLE_STATUS <> 'Decommissioned'
      AND  tgt.PART_NUMBER NOT IN (
               -- Current extract: all PART_NUMBERs present in staging this run
               SELECT PART_NUMBER
               FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING
           );

    -- Capture soft-delete count via SQLROWCOUNT
    v_soft_del_count := SQLROWCOUNT;

    -- =========================================================================
    -- STEP 5: Capture post-load target count for reconciliation (FR-08, BR-12)
    -- =========================================================================
    SELECT COUNT(1)
    INTO   :v_target_count
    FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET;

    -- =========================================================================
    -- STEP 6: Update ETL_CONTROL watermark to current run timestamp (FR-01)
    -- =========================================================================
    -- Upsert the control record so next run uses this run's timestamp as watermark
    MERGE INTO SDLC_DB.SDLC_PIPELINES.ETL_CONTROL AS ctrl
    USING (
        SELECT :v_pipeline_name AS PIPELINE_NAME
    ) AS src
        ON ctrl.PIPELINE_NAME = src.PIPELINE_NAME
    WHEN MATCHED THEN
        UPDATE SET
            ctrl.LAST_RUN_TS  = CURRENT_TIMESTAMP(),
            ctrl.UPDATED_AT   = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN
        INSERT (PIPELINE_NAME, LAST_RUN_TS, UPDATED_AT)
        VALUES (:v_pipeline_name, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());

    -- =========================================================================
    -- STEP 7: Write reconciliation log entry (FR-08, BR-12)
    -- =========================================================================
    -- BR-12: Reconciliation must be logged on every pipeline run without exception.
    -- Column names match exactly what ETL_RECONCILIATION_LOG declares.
    INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
        PIPELINE_NAME,
        LOAD_TYPE,
        WATERMARK_USED,
        SOURCE_COUNT,
        TARGET_COUNT,
        INSERTED_COUNT,
        UPDATED_COUNT,
        DELETED_COUNT,
        EXCLUDED_COUNT,
        DEDUPLICATED_COUNT,
        PIPELINE_STATUS,
        RUN_TS,
        JIRA_ISSUE,
        ERROR_MESSAGE
    )
    VALUES (
        :v_pipeline_name,
        :v_load_type,
        :v_last_run_ts,
        :v_source_count,
        :v_target_count,
        :v_inserted_count,
        :v_updated_count,
        :v_soft_del_count,
        :v_excluded_count,
        :v_dedup_count,
        'SUCCESS',
        CURRENT_TIMESTAMP(),
        NULL,
        NULL
    );

    -- =========================================================================
    -- STEP 8: Build and return summary string
    -- =========================================================================
    v_summary :=
        'PIPELINE: '         || :v_pipeline_name    ||
        ' | LOAD_TYPE: '     || :v_load_type        ||
        ' | SOURCE: '        || :v_source_count     ||
        ' | TARGET: '        || :v_target_count     ||
        ' | INSERTED: '      || :v_inserted_count   ||
        ' | UPDATED: '       || :v_updated_count    ||
        ' | SOFT_DELETED: '  || :v_soft_del_count   ||
        ' | STATUS: SUCCESS';

    RETURN :v_summary;

EXCEPTION
    WHEN OTHER THEN
        -- Capture error details - SQLERRM/SQLCODE only valid in expressions here
        LET err_msg  VARCHAR := SQLERRM;
        LET err_code VARCHAR := SQLCODE;

        -- BR-12: Log failure to reconciliation table even on error
        INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
            PIPELINE_NAME,
            LOAD_TYPE,
            WATERMARK_USED,
            SOURCE_COUNT,
            TARGET_COUNT,
            INSERTED_COUNT,
            UPDATED_COUNT,
            DELETED_COUNT,
            EXCLUDED_COUNT,
            DEDUPLICATED_COUNT,
            PIPELINE_STATUS,
            RUN_TS,
            JIRA_ISSUE,
            ERROR_MESSAGE
        )
        VALUES (
            :v_pipeline_name,
            :v_load_type,
            :v_last_run_ts,
            :v_source_count,
            :v_target_count,
            :v_inserted_count,
            :v_updated_count,
            :v_soft_del_count,
            :v_excluded_count,
            :v_dedup_count,
            'FAILED',
            CURRENT_TIMESTAMP(),
            NULL,
            :err_msg
        );

        RETURN 'FAILED: ' || :err_msg;
END;
$$;
