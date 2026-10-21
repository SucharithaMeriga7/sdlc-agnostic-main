-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE
-- Object Type   : PROCEDURE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-01, FR-02, FR-03, FR-04, FR-05, FR-06, FR-07, FR-08, FR-09
-- Reuse Route   : PIPELINE
-- Description   : Pipeline orchestration for Aerospace_Parts_Inventory_Integration
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_FILTERED
--   - SDLC_DB.SDLC_PIPELINES.PIPELINE_RUN_CONTROL
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_INCREMENTAL_LOAD
--   - SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
--   - SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_TRANSFORMED
--   - SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_RISK_SCORED
--   - SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
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
    -- ----------------------------------------------------------------
    -- Control / bookkeeping variables
    -- ----------------------------------------------------------------
    v_pipeline_name         VARCHAR DEFAULT 'SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE';
    v_run_start_ts          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    v_last_success_ts       TIMESTAMP_NTZ DEFAULT NULL;

    -- ----------------------------------------------------------------
    -- Reconciliation counters
    -- ----------------------------------------------------------------
    v_source_count          INTEGER DEFAULT 0;
    v_inserted_count        INTEGER DEFAULT 0;
    v_updated_count         INTEGER DEFAULT 0;
    v_decommissioned_count  INTEGER DEFAULT 0;
    v_rejected_count        INTEGER DEFAULT 0;

    -- ----------------------------------------------------------------
    -- Merge result variables
    -- ----------------------------------------------------------------
    v_merge_inserted        INTEGER DEFAULT 0;
    v_merge_updated         INTEGER DEFAULT 0;

    -- ----------------------------------------------------------------
    -- Summary / error variables
    -- ----------------------------------------------------------------
    v_summary               VARCHAR DEFAULT '';
    v_err                   VARCHAR DEFAULT '';
    v_step                  VARCHAR DEFAULT 'INIT';

    -- ----------------------------------------------------------------
    -- Temporary counter for rejected calculation
    -- ----------------------------------------------------------------
    v_dedup_count           INTEGER DEFAULT 0;

BEGIN

    -- ================================================================
    -- STEP 1: Retrieve last successful execution timestamp
    --         BR-01: incremental load uses this as the lower bound
    --         BR-02: NULL means first run -> full load
    -- ================================================================
    v_step := 'STEP_1_GET_LAST_SUCCESS_TS';

    SELECT MAX(LAST_SUCCESS_TS)
    INTO   :v_last_success_ts
    FROM   SDLC_DB.SDLC_PIPELINES.PIPELINE_RUN_CONTROL
    WHERE  PIPELINE_NAME = :v_pipeline_name;

    -- ================================================================
    -- STEP 2: Refresh the incremental dynamic table
    --         FR-01: AEROSPACE_PARTS_INCREMENTAL_LOAD is a DYNAMIC TABLE
    --         that already encodes the UPDATED_AT > last_ts predicate.
    --         We trigger a manual refresh to ensure it reflects the
    --         latest source data before we read from the view chain.
    -- ================================================================
    v_step := 'STEP_2_REFRESH_DYNAMIC_TABLE';

    ALTER DYNAMIC TABLE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_INCREMENTAL_LOAD REFRESH;

    -- ================================================================
    -- STEP 3: Count source records after filtering (FR-02, FR-04, FR-05, FR-06)
    --         VW_AEROSPACE_PARTS_FILTERED is the terminal view that
    --         chains: INCREMENTAL_LOAD -> DEDUPLICATED -> TRANSFORMED
    --         -> RISK_SCORED -> FILTERED
    --         BR-08: End-of-Life + old installation records already excluded
    -- ================================================================
    v_step := 'STEP_3_COUNT_SOURCE';

    SELECT COUNT(*)
    INTO   :v_source_count
    FROM   SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_FILTERED;

    -- ================================================================
    -- STEP 4: SCD Type 1 MERGE into AEROSPACE_PARTS_TARGET
    --         FR-03 / BR-04: PART_NUMBER is the business key.
    --         On match  -> overwrite all attributes (no history).
    --         On no match -> insert new record.
    --         FR-04 / BR-05,06,07: transformations already applied
    --         by VW_AEROSPACE_PARTS_TRANSFORMED (upstream of FILTERED).
    --         FR-06 / BR-09..12: RISK_SCORE already derived upstream.
    -- ================================================================
    v_step := 'STEP_4_SCD1_MERGE';

    MERGE INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET AS TGT
    USING (
        -- Source: fully filtered, deduplicated, transformed, risk-scored view
        SELECT
            PART_NUMBER,
            PART_NAME,
            MANUFACTURER,       -- BR-05: already UPPER() in transformed view
            CATEGORY,
            WEIGHT_KG,          -- BR-06: already NULL when <= 0
            UNIT_PRICE_USD,     -- BR-07: already ROUND(...,2)
            QUANTITY_ON_HAND,
            REORDER_LEVEL,
            LIFECYCLE_STATUS,
            CERTIFICATION_STATUS,
            INSTALLATION_DATE,
            LEAD_TIME_DAYS,
            SUPPLIER,
            WAREHOUSE_LOCATION,
            COUNTRY_OF_ORIGIN,
            CREATED_AT,
            UPDATED_AT,
            RISK_SCORE          -- FR-06 / BR-09..12
        FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_FILTERED
    ) AS SRC
    -- Join on business key (BR-04)
    ON TGT.PART_NUMBER = SRC.PART_NUMBER

    -- BR-04: SCD1 overwrite on match
    WHEN MATCHED THEN UPDATE SET
        TGT.PART_NAME            = SRC.PART_NAME,
        TGT.MANUFACTURER         = SRC.MANUFACTURER,
        TGT.CATEGORY             = SRC.CATEGORY,
        TGT.WEIGHT_KG            = SRC.WEIGHT_KG,
        TGT.UNIT_PRICE_USD       = SRC.UNIT_PRICE_USD,
        TGT.QUANTITY_ON_HAND     = SRC.QUANTITY_ON_HAND,
        TGT.REORDER_LEVEL        = SRC.REORDER_LEVEL,
        TGT.LIFECYCLE_STATUS     = SRC.LIFECYCLE_STATUS,
        TGT.CERTIFICATION_STATUS = SRC.CERTIFICATION_STATUS,
        TGT.INSTALLATION_DATE    = SRC.INSTALLATION_DATE,
        TGT.LEAD_TIME_DAYS       = SRC.LEAD_TIME_DAYS,
        TGT.SUPPLIER             = SRC.SUPPLIER,
        TGT.WAREHOUSE_LOCATION   = SRC.WAREHOUSE_LOCATION,
        TGT.COUNTRY_OF_ORIGIN    = SRC.COUNTRY_OF_ORIGIN,
        TGT.CREATED_AT           = SRC.CREATED_AT,
        TGT.UPDATED_AT           = SRC.UPDATED_AT,
        TGT.RISK_SCORE           = SRC.RISK_SCORE

    -- New record: insert
    WHEN NOT MATCHED THEN INSERT (
        PART_NUMBER,
        PART_NAME,
        MANUFACTURER,
        CATEGORY,
        WEIGHT_KG,
        UNIT_PRICE_USD,
        QUANTITY_ON_HAND,
        REORDER_LEVEL,
        LIFECYCLE_STATUS,
        CERTIFICATION_STATUS,
        INSTALLATION_DATE,
        LEAD_TIME_DAYS,
        SUPPLIER,
        WAREHOUSE_LOCATION,
        COUNTRY_OF_ORIGIN,
        CREATED_AT,
        UPDATED_AT,
        RISK_SCORE
    ) VALUES (
        SRC.PART_NUMBER,
        SRC.PART_NAME,
        SRC.MANUFACTURER,
        SRC.CATEGORY,
        SRC.WEIGHT_KG,
        SRC.UNIT_PRICE_USD,
        SRC.QUANTITY_ON_HAND,
        SRC.REORDER_LEVEL,
        SRC.LIFECYCLE_STATUS,
        SRC.CERTIFICATION_STATUS,
        SRC.INSTALLATION_DATE,
        SRC.LEAD_TIME_DAYS,
        SRC.SUPPLIER,
        SRC.WAREHOUSE_LOCATION,
        SRC.COUNTRY_OF_ORIGIN,
        SRC.CREATED_AT,
        SRC.UPDATED_AT,
        SRC.RISK_SCORE
    );

    -- Capture merge row counts from result set metadata
    -- Snowflake returns number_of_rows_inserted and number_of_rows_updated
    -- via the implicit result; we approximate via direct counts post-merge.
    SELECT COUNT(*)
    INTO   :v_merge_inserted
    FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
    WHERE  CREATED_AT >= :v_run_start_ts;

    SELECT COUNT(*)
    INTO   :v_merge_updated
    FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
    WHERE  UPDATED_AT >= :v_run_start_ts
      AND  CREATED_AT <  :v_run_start_ts;

    v_inserted_count := v_merge_inserted;
    v_updated_count  := v_merge_updated;

    -- ================================================================
    -- STEP 5: Soft Delete (FR-07 / BR-13)
    --         Records present in AEROSPACE_PARTS_TARGET but absent
    --         from the FULL current source extract (not just incremental)
    --         are marked 'Decommissioned'.
    --         We compare against the raw source to catch all active parts.
    -- ================================================================
    v_step := 'STEP_5_SOFT_DELETE';

    UPDATE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET AS TGT
    SET    TGT.LIFECYCLE_STATUS = 'Decommissioned'
    WHERE  TGT.LIFECYCLE_STATUS <> 'Decommissioned'
      AND  TGT.PART_NUMBER NOT IN (
               -- BR-13: full source extract (all PART_NUMBERs currently in source)
               SELECT DISTINCT PART_NUMBER
               FROM   IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE
           );

    -- Count how many records were soft-deleted this run
    SELECT COUNT(*)
    INTO   :v_decommissioned_count
    FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
    WHERE  LIFECYCLE_STATUS = 'Decommissioned'
      AND  UPDATED_AT >= :v_run_start_ts;

    -- ================================================================
    -- STEP 6: Count rejected records
    --         BR-08: records excluded by VW_AEROSPACE_PARTS_FILTERED
    --         = total deduplicated source minus filtered source count
    -- ================================================================
    v_step := 'STEP_6_COUNT_REJECTED';

    SELECT COUNT(*)
    INTO   :v_dedup_count
    FROM   SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED;

    v_rejected_count := v_dedup_count - v_source_count;

    -- ================================================================
    -- STEP 7: Reconciliation logging (FR-08 / BR-14)
    --         Insert one row per run with all counters.
    -- ================================================================
    v_step := 'STEP_7_RECONCILIATION_LOG';

    INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
        PIPELINE_NAME,
        RUN_START_TS,
        RUN_END_TS,
        SOURCE_COUNT,
        INSERTED_COUNT,
        UPDATED_COUNT,
        DECOMMISSIONED_COUNT,
        REJECTED_COUNT,
        STATUS
    ) VALUES (
        :v_pipeline_name,
        :v_run_start_ts,
        CURRENT_TIMESTAMP(),
        :v_source_count,
        :v_inserted_count,
        :v_updated_count,
        :v_decommissioned_count,
        :v_rejected_count,
        'SUCCESS'
    );

    -- ================================================================
    -- STEP 8: Update run control with last successful timestamp
    --         BR-01: next incremental run will use this value.
    -- ================================================================
    v_step := 'STEP_8_UPDATE_RUN_CONTROL';

    MERGE INTO SDLC_DB.SDLC_PIPELINES.PIPELINE_RUN_CONTROL AS RC
    USING (
        SELECT :v_pipeline_name AS PIPELINE_NAME,
               :v_run_start_ts  AS RUN_START_TS
    ) AS SRC
    ON RC.PIPELINE_NAME = SRC.PIPELINE_NAME
    WHEN MATCHED THEN UPDATE SET
        RC.LAST_SUCCESS_TS = SRC.RUN_START_TS,
        RC.RECORDED_AT     = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (
        PIPELINE_NAME,
        LAST_SUCCESS_TS,
        RECORDED_AT
    ) VALUES (
        SRC.PIPELINE_NAME,
        SRC.RUN_START_TS,
        CURRENT_TIMESTAMP()
    );

    -- ================================================================
    -- STEP 9: Build and return summary string
    -- ================================================================
    v_summary :=
        'SUCCESS | pipeline=' || :v_pipeline_name ||
        ' | run_start='        || TO_VARCHAR(:v_run_start_ts) ||
        ' | last_success_ts='  || COALESCE(TO_VARCHAR(:v_last_success_ts), 'FULL_LOAD') ||
        ' | source='           || :v_source_count ||
        ' | inserted='         || :v_inserted_count ||
        ' | updated='          || :v_updated_count ||
        ' | decommissioned='   || :v_decommissioned_count ||
        ' | rejected='         || :v_rejected_count;

    RETURN :v_summary;

EXCEPTION
    WHEN OTHER THEN
        -- Capture error details into local variable before use in SQL
        LET err VARCHAR := SQLERRM;

        -- Log the failure to the reconciliation table for observability (BR-14)
        INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
            PIPELINE_NAME,
            RUN_START_TS,
            RUN_END_TS,
            SOURCE_COUNT,
            INSERTED_COUNT,
            UPDATED_COUNT,
            DECOMMISSIONED_COUNT,
            REJECTED_COUNT,
            STATUS
        ) VALUES (
            :v_pipeline_name,
            :v_run_start_ts,
            CURRENT_TIMESTAMP(),
            :v_source_count,
            :v_inserted_count,
            :v_updated_count,
            :v_decommissioned_count,
            :v_rejected_count,
            'FAILED: ' || :err
        );

        RETURN 'FAILED at ' || :v_step || ': ' || :err;
END;
$$;
