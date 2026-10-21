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
--   - SDLC_DB.SDLC_PIPELINES.PIPELINE_EXECUTION_LOG
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_DEDUPLICATED
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TRANSFORMED
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TRANSFORMED
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TRANSFORMED
--   - SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
-- Business Rules: BR-01, BR-02, BR-03, BR-04, BR-05, BR-06, BR-07, BR-08, BR-09, BR-10, BR-11, BR-12
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
    -- -------------------------------------------------------------------------
    -- Variable declarations
    -- -------------------------------------------------------------------------
    v_pipeline_name     VARCHAR  DEFAULT 'AEROSPACE_PARTS_INVENTORY_INTEGRATION';
    v_run_start         TIMESTAMP_NTZ;
    v_run_end           TIMESTAMP_NTZ;
    v_watermark         TIMESTAMP_NTZ;   -- BR-01/BR-02: last successful run ts
    v_execution_id      NUMBER;

    -- Row count accumulators
    v_source_count      NUMBER   DEFAULT 0;
    v_staging_count     NUMBER   DEFAULT 0;
    v_ins               NUMBER   DEFAULT 0;
    v_upd               NUMBER   DEFAULT 0;
    v_soft_del          NUMBER   DEFAULT 0;
    v_target_count      NUMBER   DEFAULT 0;

    -- Reconciliation helpers
    v_discrepancy       BOOLEAN  DEFAULT FALSE;
    v_disc_detail       VARCHAR  DEFAULT '';

    -- Summary string
    v_summary           VARCHAR  DEFAULT '';

    -- Error capture
    v_err               VARCHAR  DEFAULT '';

BEGIN
    -- =========================================================================
    -- STEP 0: Record run start time
    -- =========================================================================
    v_run_start := CURRENT_TIMESTAMP();

    -- =========================================================================
    -- STEP 1: Retrieve incremental watermark from PIPELINE_EXECUTION_LOG
    -- BR-01: use max RUN_END_TIME of successful runs as the watermark
    -- BR-02: if no prior successful run exists, watermark is NULL -> full load
    -- =========================================================================
    SELECT MAX(RUN_END_TIME)
    INTO   :v_watermark
    FROM   SDLC_DB.SDLC_PIPELINES.PIPELINE_EXECUTION_LOG
    WHERE  PIPELINE_NAME = :v_pipeline_name
      AND  STATUS        = 'SUCCESS';

    -- Log execution start row
    INSERT INTO SDLC_DB.SDLC_PIPELINES.PIPELINE_EXECUTION_LOG
        (PIPELINE_NAME, RUN_START_TIME, RUN_END_TIME, STATUS, ROWS_PROCESSED, ERROR_MESSAGE)
    VALUES
        (:v_pipeline_name, :v_run_start, NULL, 'RUNNING', 0, NULL);

    -- Capture the generated EXECUTION_ID for later update
    SELECT MAX(EXECUTION_ID)
    INTO   :v_execution_id
    FROM   SDLC_DB.SDLC_PIPELINES.PIPELINE_EXECUTION_LOG
    WHERE  PIPELINE_NAME = :v_pipeline_name
      AND  STATUS        = 'RUNNING';

    -- =========================================================================
    -- STEP 2: Populate staging table with incremental (or full) extract
    -- BR-01: filter UPDATED_AT > watermark for incremental runs
    -- BR-02: no filter when watermark IS NULL (first run = full load)
    -- =========================================================================
    -- Truncate staging to ensure idempotency within a run
    TRUNCATE TABLE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING;

    -- Insert from source using exact FQN and real column names
    -- Conditional logic: if watermark is NULL load all rows, else load incremental
    IF (:v_watermark IS NULL) THEN
        -- BR-02: full load - no date filter
        INSERT INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING
            (PART_NUMBER, PART_NAME, MANUFACTURER, CATEGORY, WEIGHT_KG,
             UNIT_PRICE_USD, QUANTITY_ON_HAND, REORDER_LEVEL, LIFECYCLE_STATUS,
             CERTIFICATION_STATUS, INSTALLATION_DATE, LEAD_TIME_DAYS, SUPPLIER,
             WAREHOUSE_LOCATION, COUNTRY_OF_ORIGIN, CREATED_AT, UPDATED_AT)
        SELECT
            PART_NUMBER, PART_NAME, MANUFACTURER, CATEGORY, WEIGHT_KG,
            UNIT_PRICE_USD, QUANTITY_ON_HAND, REORDER_LEVEL, LIFECYCLE_STATUS,
            CERTIFICATION_STATUS, INSTALLATION_DATE, LEAD_TIME_DAYS, SUPPLIER,
            WAREHOUSE_LOCATION, COUNTRY_OF_ORIGIN, CREATED_AT, UPDATED_AT
        FROM IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE;
    ELSE
        -- BR-01: incremental load - only records updated after last successful run
        INSERT INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING
            (PART_NUMBER, PART_NAME, MANUFACTURER, CATEGORY, WEIGHT_KG,
             UNIT_PRICE_USD, QUANTITY_ON_HAND, REORDER_LEVEL, LIFECYCLE_STATUS,
             CERTIFICATION_STATUS, INSTALLATION_DATE, LEAD_TIME_DAYS, SUPPLIER,
             WAREHOUSE_LOCATION, COUNTRY_OF_ORIGIN, CREATED_AT, UPDATED_AT)
        SELECT
            PART_NUMBER, PART_NAME, MANUFACTURER, CATEGORY, WEIGHT_KG,
            UNIT_PRICE_USD, QUANTITY_ON_HAND, REORDER_LEVEL, LIFECYCLE_STATUS,
            CERTIFICATION_STATUS, INSTALLATION_DATE, LEAD_TIME_DAYS, SUPPLIER,
            WAREHOUSE_LOCATION, COUNTRY_OF_ORIGIN, CREATED_AT, UPDATED_AT
        FROM IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE
        WHERE UPDATED_AT > :v_watermark;
    END IF;

    -- Capture staging row count (= deduplicated source extract size before dedup)
    v_staging_count := SQLROWCOUNT;

    -- =========================================================================
    -- STEP 3: Count distinct source records after deduplication (BR-03)
    -- AEROSPACE_PARTS_DEDUPLICATED view applies ROW_NUMBER dedup over staging
    -- =========================================================================
    SELECT COUNT(*)
    INTO   :v_source_count
    FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_DEDUPLICATED;

    -- =========================================================================
    -- STEP 4: MERGE into AEROSPACE_PARTS_TARGET using transformed view
    -- FR-03 / BR-04: SCD Type 1 - overwrite on PART_NUMBER match
    -- FR-05 / BR-06: MANUFACTURER uppercased via AEROSPACE_PARTS_TRANSFORMED
    -- FR-06 / BR-07: WEIGHT_KG replacement via AEROSPACE_PARTS_TRANSFORMED
    -- FR-07 / BR-08 to BR-11: RISK_SCORE via AEROSPACE_PARTS_TRANSFORMED
    -- =========================================================================
    MERGE INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET AS tgt
    USING SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TRANSFORMED  AS src
        ON tgt.PART_NUMBER = src.PART_NUMBER
    -- BR-04: matched -> overwrite all columns (SCD Type 1)
    WHEN MATCHED THEN UPDATE SET
        tgt.PART_NAME            = src.PART_NAME,
        tgt.MANUFACTURER         = src.MANUFACTURER,       -- BR-06: already UPPER
        tgt.CATEGORY             = src.CATEGORY,
        tgt.WEIGHT_KG            = src.WEIGHT_KG,          -- BR-07: -1 replacement applied
        tgt.UNIT_PRICE_USD       = src.UNIT_PRICE_USD,
        tgt.QUANTITY_ON_HAND     = src.QUANTITY_ON_HAND,
        tgt.REORDER_LEVEL        = src.REORDER_LEVEL,
        tgt.LIFECYCLE_STATUS     = src.LIFECYCLE_STATUS,
        tgt.CERTIFICATION_STATUS = src.CERTIFICATION_STATUS,
        tgt.INSTALLATION_DATE    = src.INSTALLATION_DATE,
        tgt.LEAD_TIME_DAYS       = src.LEAD_TIME_DAYS,
        tgt.SUPPLIER             = src.SUPPLIER,
        tgt.WAREHOUSE_LOCATION   = src.WAREHOUSE_LOCATION,
        tgt.COUNTRY_OF_ORIGIN    = src.COUNTRY_OF_ORIGIN,
        tgt.CREATED_AT           = src.CREATED_AT,
        tgt.UPDATED_AT           = src.UPDATED_AT,
        tgt.RISK_SCORE           = src.RISK_SCORE,         -- BR-08 to BR-11
        tgt.PIPELINE_LOAD_TS     = CURRENT_TIMESTAMP()
    -- New record in source -> insert into target
    WHEN NOT MATCHED THEN INSERT
        (PART_NUMBER, PART_NAME, MANUFACTURER, CATEGORY, WEIGHT_KG,
         UNIT_PRICE_USD, QUANTITY_ON_HAND, REORDER_LEVEL, LIFECYCLE_STATUS,
         CERTIFICATION_STATUS, INSTALLATION_DATE, LEAD_TIME_DAYS, SUPPLIER,
         WAREHOUSE_LOCATION, COUNTRY_OF_ORIGIN, CREATED_AT, UPDATED_AT,
         RISK_SCORE, PIPELINE_LOAD_TS)
    VALUES
        (src.PART_NUMBER, src.PART_NAME, src.MANUFACTURER, src.CATEGORY, src.WEIGHT_KG,
         src.UNIT_PRICE_USD, src.QUANTITY_ON_HAND, src.REORDER_LEVEL, src.LIFECYCLE_STATUS,
         src.CERTIFICATION_STATUS, src.INSTALLATION_DATE, src.LEAD_TIME_DAYS, src.SUPPLIER,
         src.WAREHOUSE_LOCATION, src.COUNTRY_OF_ORIGIN, src.CREATED_AT, src.UPDATED_AT,
         src.RISK_SCORE, CURRENT_TIMESTAMP());

    -- Read MERGE result counts using RESULT_SCAN
    -- Both WHEN MATCHED and WHEN NOT MATCHED clauses present -> read both columns
    SELECT
        "number of rows inserted",
        "number of rows updated"
    INTO
        :v_ins,
        :v_upd
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

    -- =========================================================================
    -- STEP 5: Soft-delete (FR-04 / BR-05)
    -- Records in target but NOT in the current staging extract -> Decommissioned
    -- Uses AEROSPACE_PARTS_DEDUPLICATED (current extract) as the reference set
    -- =========================================================================
    UPDATE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET AS tgt
    SET
        tgt.LIFECYCLE_STATUS = 'Decommissioned',
        tgt.PIPELINE_LOAD_TS = CURRENT_TIMESTAMP()
    WHERE tgt.LIFECYCLE_STATUS <> 'Decommissioned'   -- avoid redundant updates
      AND tgt.PART_NUMBER NOT IN (
            -- BR-05: current extract part numbers from deduplicated staging
            SELECT PART_NUMBER
            FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_DEDUPLICATED
      );

    v_soft_del := SQLROWCOUNT;

    -- =========================================================================
    -- STEP 6: Reconciliation (FR-08 / BR-12)
    -- Count total target rows, compute discrepancy, insert log row
    -- =========================================================================
    SELECT COUNT(*)
    INTO   :v_target_count
    FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET;

    -- BR-12: discrepancy = source extract count does not equal inserted + updated
    IF (:v_source_count <> (:v_ins + :v_upd)) THEN
        v_discrepancy := TRUE;
        v_disc_detail := 'Source count (' || :v_source_count ||
                         ') != inserted (' || :v_ins ||
                         ') + updated ('  || :v_upd || ')';
    ELSE
        v_discrepancy := FALSE;
        v_disc_detail := 'No discrepancy detected';
    END IF;

    -- Insert reconciliation log row
    INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
        (PIPELINE_NAME, RUN_TIMESTAMP, WATERMARK_USED,
         SOURCE_RECORD_COUNT, TARGET_RECORD_COUNT,
         INSERTED_COUNT, UPDATED_COUNT, SOFT_DELETED_COUNT,
         DISCREPANCY_FLAG, DISCREPANCY_DETAIL, RUN_STATUS)
    VALUES
        (:v_pipeline_name, CURRENT_TIMESTAMP(), :v_watermark,
         :v_source_count, :v_target_count,
         :v_ins, :v_upd, :v_soft_del,
         :v_discrepancy, :v_disc_detail, 'SUCCESS');

    -- =========================================================================
    -- STEP 7: Update PIPELINE_EXECUTION_LOG with success
    -- =========================================================================
    v_run_end := CURRENT_TIMESTAMP();

    UPDATE SDLC_DB.SDLC_PIPELINES.PIPELINE_EXECUTION_LOG
    SET
        RUN_END_TIME    = :v_run_end,
        STATUS          = 'SUCCESS',
        ROWS_PROCESSED  = :v_ins + :v_upd + :v_soft_del,
        ERROR_MESSAGE   = NULL
    WHERE EXECUTION_ID  = :v_execution_id;

    -- =========================================================================
    -- STEP 8: FR-09 note - schedule verification
    -- The Snowflake TASK for this pipeline must use:
    --   SCHEDULE = 'USING CRON 0 5 * * * UTC'
    -- Task DDL is managed outside this procedure (never CREATE/ALTER TASK here).
    -- =========================================================================

    -- Build and return summary string
    v_summary := 'Pipeline: '         || :v_pipeline_name
              || ' | Watermark: '     || COALESCE(TO_VARCHAR(:v_watermark), 'FULL LOAD')
              || ' | Staged: '        || :v_staging_count
              || ' | Deduped: '       || :v_source_count
              || ' | Inserted: '      || :v_ins
              || ' | Updated: '       || :v_upd
              || ' | Soft-Deleted: '  || :v_soft_del
              || ' | Target Total: '  || :v_target_count
              || ' | Discrepancy: '   || :v_disc_detail
              || ' | Status: SUCCESS';

    RETURN :v_summary;

EXCEPTION
    WHEN OTHER THEN
        -- Capture error details before any DML
        LET err VARCHAR := SQLERRM;

        -- Mark execution log row as FAILED
        UPDATE SDLC_DB.SDLC_PIPELINES.PIPELINE_EXECUTION_LOG
        SET
            RUN_END_TIME  = CURRENT_TIMESTAMP(),
            STATUS        = 'FAILED',
            ERROR_MESSAGE = :err
        WHERE EXECUTION_ID = :v_execution_id;

        -- Log failure to reconciliation log
        INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
            (PIPELINE_NAME, RUN_TIMESTAMP, WATERMARK_USED,
             SOURCE_RECORD_COUNT, TARGET_RECORD_COUNT,
             INSERTED_COUNT, UPDATED_COUNT, SOFT_DELETED_COUNT,
             DISCREPANCY_FLAG, DISCREPANCY_DETAIL, RUN_STATUS)
        VALUES
            (:v_pipeline_name, CURRENT_TIMESTAMP(), :v_watermark,
             :v_source_count, :v_target_count,
             :v_ins, :v_upd, :v_soft_del,
             TRUE, :err, 'FAILED');

        RETURN 'FAILED: ' || :err;
END;
$$;
