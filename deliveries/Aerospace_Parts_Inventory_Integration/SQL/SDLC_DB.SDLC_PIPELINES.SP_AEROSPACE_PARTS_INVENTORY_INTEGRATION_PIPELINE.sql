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
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TRANSFORMED
--   - SDLC_DB.SDLC_PIPELINES.PIPELINE_EXECUTION_LOG
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_DEDUPLICATED
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TRANSFORMED
--   - SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
-- Business Rules: BR-01, BR-02, BR-03, BR-04, BR-05, BR-06, BR-07, BR-08, BR-09, BR-10, BR-11, BR-12, BR-13, BR-14
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
    v_pipeline_name     VARCHAR  DEFAULT 'SP_LOAD_AEROSPACE_PARTS_SCD1';
    v_run_ts            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    v_last_run_ts       TIMESTAMP_NTZ DEFAULT NULL;
    v_source_count      NUMBER   DEFAULT 0;
    v_target_count      NUMBER   DEFAULT 0;
    v_inserted          NUMBER   DEFAULT 0;
    v_updated           NUMBER   DEFAULT 0;
    v_soft_deleted      NUMBER   DEFAULT 0;
    v_summary           VARCHAR  DEFAULT '';
    v_err               VARCHAR  DEFAULT '';
    sd_count            NUMBER   DEFAULT 0;

BEGIN
    -- =========================================================================
    -- STEP 1: Resolve last successful execution timestamp (FR-01, BR-01, BR-02)
    -- If no prior successful run exists, v_last_run_ts remains NULL -> full load.
    -- =========================================================================
    SELECT MAX(EXECUTION_TIMESTAMP)
    INTO   :v_last_run_ts
    FROM   SDLC_DB.SDLC_PIPELINES.PIPELINE_EXECUTION_LOG
    WHERE  STATUS = 'SUCCESS'
      AND  PIPELINE_NAME = :v_pipeline_name;

    -- =========================================================================
    -- STEP 2: Count source records for this extract window (FR-08, BR-14)
    -- Uses AEROSPACE_PARTS_TRANSFORMED (which reads AEROSPACE_PARTS_DEDUPLICATED
    -- which reads IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE).
    -- BR-01: incremental filter on UPDATED_AT when v_last_run_ts is not NULL.
    -- BR-02: full load when v_last_run_ts IS NULL.
    -- BR-09 exclusion is already applied inside AEROSPACE_PARTS_TRANSFORMED.
    -- =========================================================================
    SELECT COUNT(*)
    INTO   :v_source_count
    FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TRANSFORMED
    WHERE  (:v_last_run_ts IS NULL)
        OR (UPDATED_AT > :v_last_run_ts);

    -- =========================================================================
    -- STEP 3: SCD Type 1 MERGE into AEROSPACE_PARTS_TARGET (FR-03, FR-05, FR-07)
    -- Source: AEROSPACE_PARTS_TRANSFORMED (already deduplicated via
    --         AEROSPACE_PARTS_DEDUPLICATED, transformed, and RISK_SCORE derived).
    -- Join key: PART_NUMBER (BR-04).
    -- WHEN MATCHED    -> overwrite all non-key columns (BR-04).
    -- WHEN NOT MATCHED -> insert new row.
    -- Incremental filter: UPDATED_AT > last run ts, or full load on first run.
    -- =========================================================================
    MERGE INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET AS tgt
    USING (
        -- Apply incremental window filter (BR-01 / BR-02)
        SELECT
            PART_NUMBER,
            PART_NAME,
            MANUFACTURER,       -- Already UPPER (BR-06)
            CATEGORY,
            WEIGHT_KG,          -- NULL when <= 0 (BR-07)
            UNIT_PRICE_USD,     -- Rounded to 2dp (BR-08)
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
            RISK_SCORE          -- Derived per BR-10..BR-13
        FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TRANSFORMED
        WHERE (:v_last_run_ts IS NULL)
           OR (UPDATED_AT > :v_last_run_ts)
    ) AS src
    ON tgt.PART_NUMBER = src.PART_NUMBER

    -- BR-04: SCD Type 1 overwrite on match
    WHEN MATCHED THEN UPDATE SET
        tgt.PART_NAME           = src.PART_NAME,
        tgt.MANUFACTURER        = src.MANUFACTURER,
        tgt.CATEGORY            = src.CATEGORY,
        tgt.WEIGHT_KG           = src.WEIGHT_KG,
        tgt.UNIT_PRICE_USD      = src.UNIT_PRICE_USD,
        tgt.QUANTITY_ON_HAND    = src.QUANTITY_ON_HAND,
        tgt.REORDER_LEVEL       = src.REORDER_LEVEL,
        tgt.LIFECYCLE_STATUS    = src.LIFECYCLE_STATUS,
        tgt.CERTIFICATION_STATUS = src.CERTIFICATION_STATUS,
        tgt.INSTALLATION_DATE   = src.INSTALLATION_DATE,
        tgt.LEAD_TIME_DAYS      = src.LEAD_TIME_DAYS,
        tgt.SUPPLIER            = src.SUPPLIER,
        tgt.WAREHOUSE_LOCATION  = src.WAREHOUSE_LOCATION,
        tgt.COUNTRY_OF_ORIGIN   = src.COUNTRY_OF_ORIGIN,
        tgt.CREATED_AT          = src.CREATED_AT,
        tgt.UPDATED_AT          = src.UPDATED_AT,
        tgt.RISK_SCORE          = src.RISK_SCORE,
        tgt.DW_UPDATE_TS        = CURRENT_TIMESTAMP()

    -- New record: insert
    WHEN NOT MATCHED THEN INSERT (
        PART_NUMBER, PART_NAME, MANUFACTURER, CATEGORY,
        WEIGHT_KG, UNIT_PRICE_USD, QUANTITY_ON_HAND, REORDER_LEVEL,
        LIFECYCLE_STATUS, CERTIFICATION_STATUS, INSTALLATION_DATE,
        LEAD_TIME_DAYS, SUPPLIER, WAREHOUSE_LOCATION, COUNTRY_OF_ORIGIN,
        CREATED_AT, UPDATED_AT, RISK_SCORE, DW_INSERT_TS, DW_UPDATE_TS
    ) VALUES (
        src.PART_NUMBER, src.PART_NAME, src.MANUFACTURER, src.CATEGORY,
        src.WEIGHT_KG, src.UNIT_PRICE_USD, src.QUANTITY_ON_HAND, src.REORDER_LEVEL,
        src.LIFECYCLE_STATUS, src.CERTIFICATION_STATUS, src.INSTALLATION_DATE,
        src.LEAD_TIME_DAYS, src.SUPPLIER, src.WAREHOUSE_LOCATION, src.COUNTRY_OF_ORIGIN,
        src.CREATED_AT, src.UPDATED_AT, src.RISK_SCORE, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
    );

    -- Capture MERGE row counts from result scan
    SELECT
        "number of rows inserted",
        "number of rows updated"
    INTO :v_inserted, :v_updated
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

    -- =========================================================================
    -- STEP 4: Soft-delete records missing from current source extract (FR-04, BR-05)
    -- Any PART_NUMBER in target that does NOT appear in the full current
    -- AEROSPACE_PARTS_TRANSFORMED view (no incremental filter - we need the
    -- complete current picture to identify truly missing keys) gets
    -- LIFECYCLE_STATUS set to 'Decommissioned'.
    -- =========================================================================
    UPDATE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET AS tgt
    SET
        tgt.LIFECYCLE_STATUS = 'Decommissioned',  -- BR-05
        tgt.DW_UPDATE_TS     = CURRENT_TIMESTAMP()
    WHERE tgt.LIFECYCLE_STATUS <> 'Decommissioned'  -- Avoid redundant updates
      AND tgt.PART_NUMBER NOT IN (
            -- Full current source extract (all records passing BR-09 filter)
            SELECT PART_NUMBER
            FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TRANSFORMED
      );

    -- Capture soft-delete count
    sd_count := SQLROWCOUNT;
    v_soft_deleted := :sd_count;

    -- =========================================================================
    -- STEP 5: Count target rows after load (FR-08, BR-14)
    -- =========================================================================
    SELECT COUNT(*)
    INTO   :v_target_count
    FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET;

    -- =========================================================================
    -- STEP 6: Log successful execution to PIPELINE_EXECUTION_LOG (FR-01)
    -- Records the run timestamp so the next incremental load can use it.
    -- =========================================================================
    INSERT INTO SDLC_DB.SDLC_PIPELINES.PIPELINE_EXECUTION_LOG (
        PIPELINE_NAME,
        EXECUTION_TIMESTAMP,
        STATUS
    ) VALUES (
        :v_pipeline_name,
        :v_run_ts,
        'SUCCESS'
    );

    -- =========================================================================
    -- STEP 7: Write reconciliation record (FR-08, BR-14)
    -- Logs source count, target count, inserted, updated, soft-deleted.
    -- Column names corrected to match ETL_RECONCILIATION_LOG DDL:
    --   INSERTED_COUNT -> ROWS_INSERTED
    --   UPDATED_COUNT  -> ROWS_UPDATED
    --   SOFT_DELETED_COUNT -> ROWS_SOFT_DELETED
    -- =========================================================================
    INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
        RUN_TIMESTAMP,
        PIPELINE_NAME,
        SOURCE_COUNT,
        TARGET_COUNT,
        ROWS_INSERTED,
        ROWS_UPDATED,
        ROWS_SOFT_DELETED,
        STATUS,
        NOTES
    ) VALUES (
        :v_run_ts,
        :v_pipeline_name,
        :v_source_count,
        :v_target_count,
        :v_inserted,
        :v_updated,
        :v_soft_deleted,
        'SUCCESS',
        'Pipeline completed successfully. Last run ts used: ' || COALESCE(TO_VARCHAR(:v_last_run_ts), 'FULL LOAD')
    );

    -- =========================================================================
    -- STEP 8: Build and return summary string (FR-09)
    -- =========================================================================
    v_summary := 'SP_LOAD_AEROSPACE_PARTS_SCD1 completed. '
              || 'Source rows: '       || :v_source_count    || ', '
              || 'Inserted: '          || :v_inserted        || ', '
              || 'Updated: '           || :v_updated         || ', '
              || 'Soft-deleted: '      || :v_soft_deleted    || ', '
              || 'Target total: '      || :v_target_count    || '. '
              || 'Run ts: '            || TO_VARCHAR(:v_run_ts);

    RETURN :v_summary;

EXCEPTION
    WHEN OTHER THEN
        -- Capture error details before any DML
        LET err VARCHAR := SQLERRM;
        LET err_code VARCHAR := TO_VARCHAR(SQLCODE);

        -- Attempt to log the failure to the reconciliation log
        INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
            RUN_TIMESTAMP,
            PIPELINE_NAME,
            SOURCE_COUNT,
            TARGET_COUNT,
            ROWS_INSERTED,
            ROWS_UPDATED,
            ROWS_SOFT_DELETED,
            STATUS,
            NOTES
        ) VALUES (
            :v_run_ts,
            :v_pipeline_name,
            :v_source_count,
            :v_target_count,
            :v_inserted,
            :v_updated,
            :v_soft_deleted,
            'FAILED',
            'Error code: ' || :err_code || ' | Message: ' || :err
        );

        RETURN 'FAILED: ' || :err;
END;
$$;
