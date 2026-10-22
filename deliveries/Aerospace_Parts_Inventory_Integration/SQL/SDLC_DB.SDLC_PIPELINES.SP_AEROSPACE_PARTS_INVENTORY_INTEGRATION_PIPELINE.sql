-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE
-- Object Type   : PROCEDURE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-01, FR-02, FR-03, FR-04, FR-05, FR-06, FR-07, FR-08, FR-09
-- Reuse Route   : PIPELINE
-- Description   : Pipeline orchestration for Aerospace_Parts_Inventory_Integration
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.LOAD_CONTROL_STATE
--   - SDLC_DB.SDLC_PIPELINES.PARTS_INVENTORY
--   - SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
--   - SDLC_DB.SDLC_PIPELINES.PARTS_STAGING
--   - SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED
--   - SDLC_DB.SDLC_PIPELINES.PARTS_WITH_RISK_SCORE
-- Business Rules: BR-01, BR-02, BR-03, BR-04, BR-05, BR-06, BR-07, BR-08, BR-09, BR-10, BR-11, BR-12, BR-13
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (PIPELINE)
-- =============================================================================

CREATE OR REPLACE PROCEDURE SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    -- -------------------------------------------------------------------------
    -- Variable declarations
    -- -------------------------------------------------------------------------
    v_pipeline_name     VARCHAR          DEFAULT 'AEROSPACE_PARTS_INVENTORY';
    v_run_ts            TIMESTAMP_NTZ    DEFAULT CURRENT_TIMESTAMP();

    -- Incremental load watermark (BR-01 / BR-02)
    v_last_run_ts       TIMESTAMP_NTZ;
    v_watermark_str     VARCHAR;

    -- Row count accumulators
    v_source_count      NUMBER           DEFAULT 0;
    v_staged_count      NUMBER           DEFAULT 0;
    v_ins               NUMBER           DEFAULT 0;
    v_upd               NUMBER           DEFAULT 0;
    v_soft_del          NUMBER           DEFAULT 0;
    v_target_count      NUMBER           DEFAULT 0;

    -- Step summary builder
    v_summary           VARCHAR          DEFAULT '';

    -- Error capture
    v_err               VARCHAR          DEFAULT '';

BEGIN
    -- =========================================================================
    -- STEP 0: Self-seed LOAD_CONTROL_STATE if no row exists yet (BR-02)
    -- Ensures the procedure is idempotent even when the DDL seed was not run.
    -- =========================================================================
    INSERT INTO SDLC_DB.SDLC_PIPELINES.LOAD_CONTROL_STATE
        (PIPELINE_NAME, LAST_SUCCESSFUL_RUN, LAST_RUN_STATUS, UPDATED_AT)
    SELECT :v_pipeline_name, NULL, 'NEVER_RUN', CURRENT_TIMESTAMP()
    WHERE NOT EXISTS (
        SELECT 1
        FROM   SDLC_DB.SDLC_PIPELINES.LOAD_CONTROL_STATE
        WHERE  PIPELINE_NAME = :v_pipeline_name
    );

    -- =========================================================================
    -- STEP 1: Check load state (FR-01 / BR-01 / BR-02)
    -- Read the last successful execution timestamp from LOAD_CONTROL_STATE.
    -- A NULL value means this is the first run => full load.
    -- =========================================================================
    SELECT COALESCE(LAST_SUCCESSFUL_RUN, '1900-01-01 00:00:00'::TIMESTAMP_NTZ)
    INTO   :v_last_run_ts
    FROM   SDLC_DB.SDLC_PIPELINES.LOAD_CONTROL_STATE
    WHERE  PIPELINE_NAME = :v_pipeline_name;

    -- Build a string representation for dynamic SQL watermark injection
    v_watermark_str := TO_VARCHAR(:v_last_run_ts, 'YYYY-MM-DD HH24:MI:SS.FF9');

    v_summary := v_summary || 'STEP1_WATERMARK=' || :v_watermark_str || '; ';

    -- =========================================================================
    -- STEP 2: Extract and deduplicate into staging (FR-01 / FR-02 / BR-01..03)
    -- Truncate staging first so it only holds the current batch.
    -- Then INSERT from PARTS_WITH_RISK_SCORE (which already deduplicates via
    -- PARTS_DEDUPLICATED) filtered by the incremental watermark.
    -- =========================================================================

    -- Clear staging table for this run
    TRUNCATE TABLE SDLC_DB.SDLC_PIPELINES.PARTS_STAGING;

    -- Count raw source records in the current extract window (before dedup)
    -- BR-01: filter by UPDATED_AT > last successful run
    -- BR-02: v_last_run_ts = '1900-01-01' on first run => selects all rows
    SELECT COUNT(*)
    INTO   :v_source_count
    FROM   IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE
    WHERE  UPDATED_AT > :v_last_run_ts;

    -- Insert deduplicated, transformed, risk-scored records into staging
    -- FR-02: deduplication handled by PARTS_DEDUPLICATED view (QUALIFY)
    -- FR-05: UPPER(MANUFACTURER) applied in PARTS_DEDUPLICATED
    -- FR-06: WEIGHT_KG sentinel applied in PARTS_DEDUPLICATED
    -- FR-07: RISK_SCORE derived in PARTS_WITH_RISK_SCORE
    INSERT INTO SDLC_DB.SDLC_PIPELINES.PARTS_STAGING (
        PART_NUMBER,
        PART_NAME,
        MANUFACTURER,
        CATEGORY,
        UNIT_PRICE,
        WEIGHT_KG,
        CERTIFICATION_STATUS,
        LEAD_TIME_DAYS,
        STATUS,
        RISK_SCORE,
        UPDATED_AT
    )
    SELECT
        r.PART_NUMBER,
        r.PART_NAME,
        r.MANUFACTURER,          -- already UPPER() from PARTS_DEDUPLICATED (BR-06)
        r.CATEGORY,
        r.UNIT_PRICE,
        r.WEIGHT_KG,             -- already -1 sentinel from PARTS_DEDUPLICATED (BR-07)
        r.CERTIFICATION_STATUS,
        r.LEAD_TIME_DAYS,
        r.STATUS,
        r.RISK_SCORE,            -- derived in PARTS_WITH_RISK_SCORE (BR-08..BR-11)
        r.UPDATED_AT
    FROM SDLC_DB.SDLC_PIPELINES.PARTS_WITH_RISK_SCORE AS r
    -- BR-01: incremental filter; BR-02: full load when watermark = 1900-01-01
    -- Join back to raw source to apply the UPDATED_AT filter (view has no filter)
    INNER JOIN IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE AS src
        ON  r.PART_NUMBER = src.PART_NUMBER
        AND r.UPDATED_AT  = src.UPDATED_AT   -- match the deduplicated row
    WHERE src.UPDATED_AT > :v_last_run_ts;

    v_staged_count := SQLROWCOUNT;
    v_summary := v_summary || 'STEP2_SOURCE_RAW=' || :v_source_count
                           || '_STAGED=' || :v_staged_count || '; ';

    -- =========================================================================
    -- STEP 3: Apply transformations and risk scoring
    -- Transformations are fully encapsulated in the views; staging already
    -- holds the final transformed data. No additional DML needed here.
    -- =========================================================================
    v_summary := v_summary || 'STEP3_TRANSFORMS_APPLIED_IN_VIEWS; ';

    -- =========================================================================
    -- STEP 4a: SCD Type 1 MERGE into PARTS_INVENTORY (FR-03 / FR-04 / BR-04)
    -- Business key: PART_NUMBER
    -- WHEN MATCHED: overwrite all non-key fields (SCD Type 1 - no history)
    -- WHEN NOT MATCHED: insert new row
    -- =========================================================================
    MERGE INTO SDLC_DB.SDLC_PIPELINES.PARTS_INVENTORY AS tgt
    USING (
        SELECT
            PART_NUMBER,
            PART_NAME,
            MANUFACTURER,
            CATEGORY,
            UNIT_PRICE,
            WEIGHT_KG,
            CERTIFICATION_STATUS,
            LEAD_TIME_DAYS,
            STATUS,
            RISK_SCORE,
            UPDATED_AT
        FROM SDLC_DB.SDLC_PIPELINES.PARTS_STAGING
    ) AS src
    ON tgt.PART_NUMBER = src.PART_NUMBER   -- BR-04: business key join
    -- BR-04: SCD Type 1 - update all non-key fields on match
    WHEN MATCHED THEN UPDATE SET
        tgt.PART_NAME            = src.PART_NAME,
        tgt.MANUFACTURER         = src.MANUFACTURER,
        tgt.CATEGORY             = src.CATEGORY,
        tgt.UNIT_PRICE           = src.UNIT_PRICE,
        tgt.WEIGHT_KG            = src.WEIGHT_KG,
        tgt.CERTIFICATION_STATUS = src.CERTIFICATION_STATUS,
        tgt.LEAD_TIME_DAYS       = src.LEAD_TIME_DAYS,
        tgt.STATUS               = src.STATUS,
        tgt.RISK_SCORE           = src.RISK_SCORE,
        tgt.UPDATED_AT           = src.UPDATED_AT,
        tgt.PIPELINE_LOAD_TS     = CURRENT_TIMESTAMP()
    -- BR-04: insert new rows on no match
    WHEN NOT MATCHED THEN INSERT (
        PART_NUMBER,
        PART_NAME,
        MANUFACTURER,
        CATEGORY,
        UNIT_PRICE,
        WEIGHT_KG,
        CERTIFICATION_STATUS,
        LEAD_TIME_DAYS,
        STATUS,
        RISK_SCORE,
        UPDATED_AT,
        PIPELINE_LOAD_TS
    ) VALUES (
        src.PART_NUMBER,
        src.PART_NAME,
        src.MANUFACTURER,
        src.CATEGORY,
        src.UNIT_PRICE,
        src.WEIGHT_KG,
        src.CERTIFICATION_STATUS,
        src.LEAD_TIME_DAYS,
        src.STATUS,
        src.RISK_SCORE,
        src.UPDATED_AT,
        CURRENT_TIMESTAMP()
    );

    -- Capture MERGE row counts from Snowflake metadata
    SELECT
        "number of rows inserted",
        "number of rows updated"
    INTO :v_ins, :v_upd
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

    v_summary := v_summary || 'STEP4_MERGE_INS=' || :v_ins
                           || '_UPD=' || :v_upd || '; ';

    -- =========================================================================
    -- STEP 4b: Soft-delete (FR-04 / BR-05)
    -- Any PART_NUMBER present in the target but absent from the current
    -- staging extract is marked STATUS = 'Decommissioned'.
    -- Only applies to records not already Decommissioned to avoid noise.
    -- =========================================================================
    UPDATE SDLC_DB.SDLC_PIPELINES.PARTS_INVENTORY AS tgt
    SET
        tgt.STATUS           = 'Decommissioned',
        tgt.PIPELINE_LOAD_TS = CURRENT_TIMESTAMP()
    WHERE tgt.STATUS <> 'Decommissioned'
      AND NOT EXISTS (
          SELECT 1
          FROM   SDLC_DB.SDLC_PIPELINES.PARTS_STAGING AS stg
          WHERE  stg.PART_NUMBER = tgt.PART_NUMBER
      );

    v_soft_del := SQLROWCOUNT;
    v_summary  := v_summary || 'STEP4_SOFT_DEL=' || :v_soft_del || '; ';

    -- =========================================================================
    -- STEP 5: Reconciliation (FR-08 / BR-12)
    -- Count total active (non-decommissioned) records in target after the run.
    -- Log all metrics to ETL_RECONCILIATION_LOG.
    -- =========================================================================
    SELECT COUNT(*)
    INTO   :v_target_count
    FROM   SDLC_DB.SDLC_PIPELINES.PARTS_INVENTORY
    WHERE  STATUS <> 'Decommissioned';

    INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
        PIPELINE_NAME,
        RUN_TIMESTAMP,
        SOURCE_COUNT,
        TARGET_COUNT,
        INSERTED_COUNT,
        UPDATED_COUNT,
        SOFT_DELETED_COUNT,
        RUN_STATUS
    ) VALUES (
        :v_pipeline_name,
        :v_run_ts,
        :v_source_count,
        :v_target_count,
        :v_ins,
        :v_upd,
        :v_soft_del,
        'SUCCEEDED'
    );

    v_summary := v_summary || 'STEP5_RECON_LOGGED; ';

    -- =========================================================================
    -- STEP 6: Update LOAD_CONTROL_STATE (FR-01 / BR-01)
    -- Record the current run timestamp as LAST_SUCCESSFUL_RUN so the next
    -- incremental run uses it as the watermark.
    -- =========================================================================
    UPDATE SDLC_DB.SDLC_PIPELINES.LOAD_CONTROL_STATE
    SET
        LAST_SUCCESSFUL_RUN = :v_run_ts,
        LAST_RUN_STATUS     = 'SUCCESS',
        UPDATED_AT          = CURRENT_TIMESTAMP()
    WHERE PIPELINE_NAME = :v_pipeline_name;

    v_summary := v_summary || 'STEP6_CONTROL_STATE_UPDATED; ';

    RETURN v_summary;

EXCEPTION
    WHEN OTHER THEN
        LET err VARCHAR := SQLERRM;
        -- Log failure to reconciliation log
        INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
            PIPELINE_NAME,
            RUN_TIMESTAMP,
            SOURCE_COUNT,
            TARGET_COUNT,
            INSERTED_COUNT,
            UPDATED_COUNT,
            SOFT_DELETED_COUNT,
            RUN_STATUS
        ) VALUES (
            :v_pipeline_name,
            :v_run_ts,
            :v_source_count,
            :v_target_count,
            :v_ins,
            :v_upd,
            :v_soft_del,
            'FAILED'
        );
        -- Update control state to reflect failure
        UPDATE SDLC_DB.SDLC_PIPELINES.LOAD_CONTROL_STATE
        SET
            LAST_RUN_STATUS = 'FAILED',
            UPDATED_AT      = CURRENT_TIMESTAMP()
        WHERE PIPELINE_NAME = :v_pipeline_name;
        RETURN 'ERROR: ' || :err;
END;
$$;
