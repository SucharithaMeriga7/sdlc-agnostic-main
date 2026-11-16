-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE
-- Object Type   : PROCEDURE
-- Jira Story    : SCRUM-159
-- Requirements  : FR-01, FR-02, FR-03, FR-04, FR-05, FR-06, FR-07, FR-08, FR-09
-- Reuse Route   : PIPELINE
-- Description   : Pipeline orchestration for Aerospace_Parts_Inventory_Integration
-- Author        : Sucharitha
-- Created Date  : 2026-11-16
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
--   - SDLC_DB.SDLC_PIPELINES.PARTS
--   - SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM
--   - SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
-- Business Rules: BR-01, BR-02, BR-03, BR-04, BR-05, BR-06, BR-07, BR-08, BR-09, BR-10
-- Change History:
--   2026-11-16  Sucharitha  SCRUM-159  Initial generation (PIPELINE)
-- =============================================================================

CREATE OR REPLACE PROCEDURE SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    -- ----------------------------------------------------------------
    -- Watermark variables (FR-01, BR-01, BR-02)
    -- ----------------------------------------------------------------
    v_watermark         TIMESTAMP_NTZ(9);   -- last successful run timestamp
    v_load_type         VARCHAR(20);        -- 'FULL' or 'INCREMENTAL'
    v_new_watermark     TIMESTAMP_NTZ(9);   -- watermark captured before merge

    -- ----------------------------------------------------------------
    -- Row count variables
    -- ----------------------------------------------------------------
    v_source_count      NUMBER(18,0) := 0;  -- deduplicated source records in this batch
    v_target_before     NUMBER(18,0) := 0;  -- target row count before merge
    v_target_after      NUMBER(18,0) := 0;  -- target row count after merge
    v_inserted          NUMBER(18,0) := 0;  -- rows inserted by MERGE
    v_updated           NUMBER(18,0) := 0;  -- rows updated by MERGE
    v_soft_deleted      NUMBER(18,0) := 0;  -- rows soft-deleted (BR-05)

    -- ----------------------------------------------------------------
    -- Reconciliation / audit variables (FR-08, BR-09)
    -- ----------------------------------------------------------------
    v_discrepancy       NUMBER(18,0) := 0;
    v_pipeline_status   VARCHAR(20)  := 'SUCCESS';
    v_error_msg         VARCHAR(4000) := NULL;

    -- ----------------------------------------------------------------
    -- Summary string returned to caller
    -- ----------------------------------------------------------------
    v_summary           VARCHAR(4000);

BEGIN
    -- ================================================================
    -- STEP 1: Read watermark (FR-01, BR-01, BR-02)
    -- ================================================================
    -- Retrieve the last successful execution timestamp from the
    -- watermark table.  NULL means first run -> full load (BR-02).
    SELECT COALESCE(MAX(WATERMARK_TS), NULL)
    INTO   :v_watermark
    FROM   SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM
    WHERE  PIPELINE_NAME = 'SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE';

    -- Determine load type for logging
    IF (:v_watermark IS NULL) THEN
        v_load_type := 'FULL';          -- BR-02: no prior watermark -> full load
    ELSE
        v_load_type := 'INCREMENTAL';   -- BR-01: filter by UPDATED_AT > watermark
    END IF;

    -- Capture the high-watermark timestamp BEFORE the merge so that
    -- any records written during this run are included next time.
    SELECT CURRENT_TIMESTAMP()
    INTO   :v_new_watermark;

    -- ================================================================
    -- STEP 2: Count deduplicated source records for this batch (FR-08)
    -- ================================================================
    -- VW_AEROSPACE_PARTS_DEDUPLICATED already deduplicates (BR-03) and
    -- applies camelcase (BR-06) and weight normalisation (BR-07).
    -- The watermark filter for incremental load is applied here (BR-01).
    SELECT COUNT(*)
    INTO   :v_source_count
    FROM   SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED src
    WHERE  (:v_watermark IS NULL OR src.UPDATED_AT > :v_watermark);

    -- ================================================================
    -- STEP 3: Capture target row count BEFORE merge (FR-08, BR-09)
    -- ================================================================
    SELECT COUNT(*)
    INTO   :v_target_before
    FROM   SDLC_DB.SDLC_PIPELINES.PARTS;

    -- ================================================================
    -- STEP 4: SCD Type 1 MERGE (FR-03, BR-04) with risk score (FR-07, BR-08)
    -- ================================================================
    -- Source: deduplicated view filtered by watermark (BR-01/BR-02).
    -- Key:    PART_NUMBER.
    -- WHEN MATCHED    -> overwrite all non-key columns (BR-04).
    -- WHEN NOT MATCHED -> insert new record.
    -- RISK_SCORE inline CASE (BR-08, FR-07):
    --   Priority 1: Certification='Pending' AND LEAD_TIME_DAYS>60  -> 'High Risk'
    --   Priority 2: Certification='Pending' OR  LEAD_TIME_DAYS>100 -> 'Medium Risk'
    --   Priority 3: Certification IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS<=60 -> 'Low Risk'
    --   Priority 4: all other cases                                 -> 'Medium Risk'
    MERGE INTO SDLC_DB.SDLC_PIPELINES.PARTS AS tgt
    USING (
        -- Apply incremental watermark filter here (BR-01/BR-02)
        SELECT
            src.PART_NUMBER,
            src.PART_NAME,
            src.MANUFACTURER,          -- already INITCAP from view (BR-06)
            src.WEIGHT_KG,             -- already normalised from view (BR-07)
            src.UNIT_PRICE_USD,
            src.CERTIFICATION_STATUS,
            src.LEAD_TIME_DAYS,
            src.LIFECYCLE_STATUS,
            src.INSTALLATION_DATE,
            src.QUANTITY_ON_HAND,
            src.WAREHOUSE_LOCATION,
            src.SUPPLIER_CODE,
            src.COUNTRY_OF_ORIGIN,
            src.UPDATED_AT,
            src.CATEGORY,
            src.SUPPLIER_ID,
            src.PART_STATUS,
            src.INVENTORY_HEALTH_STATUS,
            src.STOCK_QUANTITY,
            src.SUPPLY_RISK_LEVEL,
            src.SUPPLIER_COUNT,
            -- BR-08 / FR-07: inline risk score derivation (priority order 1->2->3->4)
            CASE
                WHEN src.CERTIFICATION_STATUS = 'Pending'
                     AND src.LEAD_TIME_DAYS > 60
                    THEN 'High Risk'    -- Priority 1
                WHEN src.CERTIFICATION_STATUS = 'Pending'
                     OR  src.LEAD_TIME_DAYS > 100
                    THEN 'Medium Risk'  -- Priority 2
                WHEN src.CERTIFICATION_STATUS IN ('FAA','EASA','Dual')
                     AND src.LEAD_TIME_DAYS <= 60
                    THEN 'Low Risk'     -- Priority 3
                ELSE 'Medium Risk'      -- Priority 4
            END AS RISK_SCORE
        FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED src
        WHERE (:v_watermark IS NULL OR src.UPDATED_AT > :v_watermark)  -- BR-01/BR-02
    ) AS src
    ON tgt.PART_NUMBER = src.PART_NUMBER  -- business key join (FR-03)
    -- BR-04: SCD Type 1 - overwrite all non-key columns on match
    WHEN MATCHED THEN UPDATE SET
        tgt.PART_NAME               = src.PART_NAME,
        tgt.MANUFACTURER            = src.MANUFACTURER,
        tgt.WEIGHT_KG               = src.WEIGHT_KG,
        tgt.UNIT_PRICE_USD          = src.UNIT_PRICE_USD,
        tgt.CERTIFICATION_STATUS    = src.CERTIFICATION_STATUS,
        tgt.LEAD_TIME_DAYS          = src.LEAD_TIME_DAYS,
        tgt.LIFECYCLE_STATUS        = src.LIFECYCLE_STATUS,
        tgt.INSTALLATION_DATE       = src.INSTALLATION_DATE,
        tgt.QUANTITY_ON_HAND        = src.QUANTITY_ON_HAND,
        tgt.WAREHOUSE_LOCATION      = src.WAREHOUSE_LOCATION,
        tgt.SUPPLIER_CODE           = src.SUPPLIER_CODE,
        tgt.COUNTRY_OF_ORIGIN       = src.COUNTRY_OF_ORIGIN,
        tgt.UPDATED_AT              = src.UPDATED_AT,
        tgt.CATEGORY                = src.CATEGORY,
        tgt.SUPPLIER_ID             = src.SUPPLIER_ID,
        tgt.PART_STATUS             = src.PART_STATUS,
        tgt.INVENTORY_HEALTH_STATUS = src.INVENTORY_HEALTH_STATUS,
        tgt.STOCK_QUANTITY          = src.STOCK_QUANTITY,
        tgt.SUPPLY_RISK_LEVEL       = src.SUPPLY_RISK_LEVEL,
        tgt.SUPPLIER_COUNT          = src.SUPPLIER_COUNT,
        tgt.RISK_SCORE              = src.RISK_SCORE,
        tgt.DW_UPDATE_TS            = CURRENT_TIMESTAMP()
    -- New record: insert with all columns including risk score
    WHEN NOT MATCHED THEN INSERT (
        PART_NUMBER, PART_NAME, MANUFACTURER, WEIGHT_KG, UNIT_PRICE_USD,
        CERTIFICATION_STATUS, LEAD_TIME_DAYS, LIFECYCLE_STATUS, INSTALLATION_DATE,
        QUANTITY_ON_HAND, WAREHOUSE_LOCATION, SUPPLIER_CODE, COUNTRY_OF_ORIGIN,
        UPDATED_AT, CATEGORY, SUPPLIER_ID, PART_STATUS, INVENTORY_HEALTH_STATUS,
        STOCK_QUANTITY, SUPPLY_RISK_LEVEL, SUPPLIER_COUNT, RISK_SCORE,
        DW_INSERT_TS, DW_UPDATE_TS
    ) VALUES (
        src.PART_NUMBER, src.PART_NAME, src.MANUFACTURER, src.WEIGHT_KG, src.UNIT_PRICE_USD,
        src.CERTIFICATION_STATUS, src.LEAD_TIME_DAYS, src.LIFECYCLE_STATUS, src.INSTALLATION_DATE,
        src.QUANTITY_ON_HAND, src.WAREHOUSE_LOCATION, src.SUPPLIER_CODE, src.COUNTRY_OF_ORIGIN,
        src.UPDATED_AT, src.CATEGORY, src.SUPPLIER_ID, src.PART_STATUS, src.INVENTORY_HEALTH_STATUS,
        src.STOCK_QUANTITY, src.SUPPLY_RISK_LEVEL, src.SUPPLIER_COUNT, src.RISK_SCORE,
        CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
    );

    -- Read MERGE result counts from RESULT_SCAN (Snowflake scripting pattern)
    SELECT
        "number of rows inserted",
        "number of rows updated"
    INTO :v_inserted, :v_updated
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

    -- ================================================================
    -- STEP 5: Soft-delete (FR-04, BR-05)
    -- ================================================================
    -- Any PART_NUMBER present in PARTS but absent from the FULL
    -- deduplicated source view (all keys, no watermark filter) must
    -- be marked 'Decommissioned'.  We compare against the complete
    -- current keyset so that records that were never updated still
    -- get soft-deleted if they disappear from the source.
    UPDATE SDLC_DB.SDLC_PIPELINES.PARTS AS tgt
    SET
        tgt.LIFECYCLE_STATUS = 'Decommissioned',  -- BR-05
        tgt.DW_UPDATE_TS     = CURRENT_TIMESTAMP()
    WHERE tgt.LIFECYCLE_STATUS <> 'Decommissioned'  -- avoid redundant writes
      AND tgt.PART_NUMBER NOT IN (
            -- Full current keyset from deduplicated view (no watermark filter)
            SELECT src.PART_NUMBER
            FROM   SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED src
      );

    -- Capture soft-delete count via SQLROWCOUNT
    v_soft_deleted := SQLROWCOUNT;

    -- ================================================================
    -- STEP 6: Capture target row count AFTER merge + soft-delete (FR-08)
    -- ================================================================
    SELECT COUNT(*)
    INTO   :v_target_after
    FROM   SDLC_DB.SDLC_PIPELINES.PARTS;

    -- ================================================================
    -- STEP 7: Update watermark to new high-water mark (FR-01)
    -- ================================================================
    -- Upsert the watermark so the next run performs an incremental load.
    MERGE INTO SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM AS w
    USING (
        SELECT
            'SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE' AS PIPELINE_NAME,
            :v_new_watermark AS WATERMARK_TS
    ) AS src
    ON w.PIPELINE_NAME = src.PIPELINE_NAME
    WHEN MATCHED     THEN UPDATE SET w.WATERMARK_TS = src.WATERMARK_TS,
                                     w.UPDATED_AT   = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (PIPELINE_NAME, WATERMARK_TS, UPDATED_AT)
                          VALUES (src.PIPELINE_NAME, src.WATERMARK_TS, CURRENT_TIMESTAMP());

    -- ================================================================
    -- STEP 8: Reconciliation check and logging (FR-08, BR-09)
    -- ================================================================
    -- Discrepancy = source_count - (inserted + updated); ideally 0.
    v_discrepancy := :v_source_count - (:v_inserted + :v_updated);

    -- Insert reconciliation record into ETL_RECONCILIATION_LOG
    -- using only the columns declared in that table.
    INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
        PIPELINE_NAME,
        LOAD_TYPE,
        SOURCE_COUNT,
        TARGET_COUNT,
        INSERTED_COUNT,
        UPDATED_COUNT,
        DELETED_COUNT,
        DISCREPANCY_COUNT,
        PIPELINE_STATUS,
        RUN_TS,
        WATERMARK_USED,
        ERROR_MESSAGE
    )
    VALUES (
        'SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE',
        :v_load_type,
        :v_source_count,
        :v_target_after,
        :v_inserted,
        :v_updated,
        :v_soft_deleted,
        :v_discrepancy,
        :v_pipeline_status,
        :v_new_watermark,
        :v_watermark,
        :v_error_msg
    );

    -- ================================================================
    -- STEP 9: Build and return summary string
    -- ================================================================
    v_summary :=
        'PIPELINE: SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE | ' ||
        'LOAD_TYPE: '       || :v_load_type       || ' | ' ||
        'SOURCE_COUNT: '    || :v_source_count    || ' | ' ||
        'INSERTED: '        || :v_inserted        || ' | ' ||
        'UPDATED: '         || :v_updated         || ' | ' ||
        'SOFT_DELETED: '    || :v_soft_deleted    || ' | ' ||
        'TARGET_BEFORE: '   || :v_target_before   || ' | ' ||
        'TARGET_AFTER: '    || :v_target_after    || ' | ' ||
        'DISCREPANCY: '     || :v_discrepancy     || ' | ' ||
        'STATUS: SUCCESS';

    RETURN :v_summary;

EXCEPTION
    WHEN OTHER THEN
        -- Capture error details; SQLERRM/SQLCODE only valid in expressions
        LET err_msg  VARCHAR := SQLERRM;
        LET err_code VARCHAR := SQLCODE;

        -- Log failure to reconciliation table
        INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
            PIPELINE_NAME,
            LOAD_TYPE,
            SOURCE_COUNT,
            TARGET_COUNT,
            INSERTED_COUNT,
            UPDATED_COUNT,
            DELETED_COUNT,
            DISCREPANCY_COUNT,
            PIPELINE_STATUS,
            RUN_TS,
            WATERMARK_USED,
            ERROR_MESSAGE
        )
        VALUES (
            'SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE',
            :v_load_type,
            :v_source_count,
            :v_target_after,
            :v_inserted,
            :v_updated,
            :v_soft_deleted,
            -1,
            'FAILED',
            CURRENT_TIMESTAMP(),
            :v_watermark,
            :err_msg
        );

        RETURN 'FAILED: [' || :err_code || '] ' || :err_msg;
END;
$$;

-- ================================================================
-- TASK: daily schedule at 03:00 UTC (FR-09, BR-10)
-- LARGE warehouse to handle up to 1M records within 3 minutes.
-- NOTE: task is delivered here separately from the procedure;
-- it is never created inside the procedure body.
-- ================================================================
CREATE OR REPLACE TASK SDLC_DB.SDLC_PIPELINES.TSK_AEROSPACE_PARTS_INVENTORY_DAILY
    WAREHOUSE = SNOWFLAKE_LEARNING_WH
    SCHEDULE  = 'USING CRON 0 3 * * * UTC'
    COMMENT   = 'FR-09/BR-10: daily incremental load of aerospace parts inventory'
AS
    CALL SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE();
