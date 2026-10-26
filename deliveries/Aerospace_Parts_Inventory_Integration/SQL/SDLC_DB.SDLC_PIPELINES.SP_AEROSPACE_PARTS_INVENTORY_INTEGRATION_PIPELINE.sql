-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE
-- Object Type   : PROCEDURE
-- Jira Story    : SCRUM-159
-- Requirements  : FR-01, FR-02, FR-03, FR-04, FR-05, FR-06, FR-07, FR-08, FR-09
-- Reuse Route   : PIPELINE
-- Description   : Pipeline orchestration for Aerospace_Parts_Inventory_Integration
-- Author        : Sucharitha
-- Created Date  : 2026-10-26
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
--   - SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
--   - SDLC_DB.SDLC_PIPELINES.ETL_CONTROL
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING
--   - SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
-- Business Rules: BR-01, BR-02, BR-03, BR-04, BR-05, BR-06, BR-07, BR-08, BR-09, BR-10, BR-11, BR-12
-- Change History:
--   2026-10-26  Sucharitha  SCRUM-159  Initial generation (PIPELINE)
-- =============================================================================

CREATE OR REPLACE PROCEDURE SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    -- ----------------------------------------------------------------
    -- Control / watermark variables (FR-01, BR-01, BR-02)
    -- ----------------------------------------------------------------
    v_pipeline_name     VARCHAR  DEFAULT 'AEROSPACE_PARTS_INVENTORY_INTEGRATION';
    v_run_ts            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    v_watermark         TIMESTAMP_NTZ DEFAULT NULL;   -- NULL => full load (BR-02)
    v_load_type         VARCHAR  DEFAULT 'FULL';

    -- ----------------------------------------------------------------
    -- Row-count accumulators
    -- ----------------------------------------------------------------
    v_source_count      NUMBER   DEFAULT 0;
    v_dedup_count       NUMBER   DEFAULT 0;
    v_ins               NUMBER   DEFAULT 0;
    v_upd               NUMBER   DEFAULT 0;
    v_del               NUMBER   DEFAULT 0;
    v_target_count      NUMBER   DEFAULT 0;
    v_discrepancy       NUMBER   DEFAULT 0;

    -- ----------------------------------------------------------------
    -- Error handling
    -- ----------------------------------------------------------------
    v_status            VARCHAR  DEFAULT 'SUCCESS';
    v_err               VARCHAR  DEFAULT NULL;

    -- ----------------------------------------------------------------
    -- Summary string
    -- ----------------------------------------------------------------
    v_summary           VARCHAR  DEFAULT '';

BEGIN
    -- ================================================================
    -- STEP 1: Ensure ETL_CONTROL row exists for this pipeline (FR-01)
    -- BR-02: if no row exists the watermark stays NULL => full load
    -- ================================================================
    INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_CONTROL (PIPELINE_NAME, LAST_RUN_TS, LAST_SUCCESSFUL_RUN_TS, UPDATED_AT)
    SELECT :v_pipeline_name, NULL, NULL, CURRENT_TIMESTAMP()
    WHERE NOT EXISTS (
        SELECT 1 FROM SDLC_DB.SDLC_PIPELINES.ETL_CONTROL
        WHERE PIPELINE_NAME = :v_pipeline_name
    );

    -- ================================================================
    -- STEP 2: Read watermark from ETL_CONTROL (FR-01, BR-01, BR-02)
    -- ================================================================
    SELECT LAST_SUCCESSFUL_RUN_TS
    INTO   :v_watermark
    FROM   SDLC_DB.SDLC_PIPELINES.ETL_CONTROL
    WHERE  PIPELINE_NAME = :v_pipeline_name;

    -- Determine load type
    IF (v_watermark IS NOT NULL) THEN
        v_load_type := 'INCREMENTAL';
    END IF;

    -- ================================================================
    -- STEP 3: Mark run start in ETL_CONTROL
    -- ================================================================
    UPDATE SDLC_DB.SDLC_PIPELINES.ETL_CONTROL
    SET    LAST_RUN_TS  = :v_run_ts,
           UPDATED_AT   = CURRENT_TIMESTAMP()
    WHERE  PIPELINE_NAME = :v_pipeline_name;

    -- ================================================================
    -- STEP 4: Truncate staging table and reload current extract
    -- FR-01 (incremental filter), BR-01, BR-02, FR-09 (performance)
    -- Inline transformations applied here:
    --   BR-06: UPPER(MANUFACTURER)
    --   BR-07: CASE WHEN WEIGHT_KG <= 0 THEN -1 ELSE WEIGHT_KG END
    --   BR-08 to BR-11: RISK_SCORE CASE expression
    -- Deduplication via VW_AEROSPACE_PARTS_DEDUPLICATED (FR-02, BR-03)
    -- ================================================================
    TRUNCATE TABLE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING;

    INSERT INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING (
        PART_NUMBER,
        PART_NAME,
        MANUFACTURER,           -- BR-06: stored as UPPER()
        WEIGHT_KG,              -- BR-07: -1 when source <= 0
        UNIT_PRICE_USD,
        CERTIFICATION_STATUS,
        LEAD_TIME_DAYS,
        LIFECYCLE_STATUS,
        INSTALLATION_DATE,
        QUANTITY_ON_HAND,
        WAREHOUSE_LOCATION,
        SUPPLIER_CODE,
        COUNTRY_OF_ORIGIN,
        UPDATED_AT,
        CATEGORY,
        SUPPLIER_ID,
        PART_STATUS,
        INVENTORY_HEALTH_STATUS,
        STOCK_QUANTITY,
        SUPPLY_RISK_LEVEL,
        SUPPLIER_COUNT,
        RISK_SCORE              -- BR-08 to BR-11: derived inline
    )
    SELECT
        v.PART_NUMBER,
        v.PART_NAME,
        -- BR-06: convert MANUFACTURER to uppercase
        UPPER(v.MANUFACTURER)                                                          AS MANUFACTURER,
        -- BR-07: replace WEIGHT_KG <= 0 with -1
        CASE WHEN v.WEIGHT_KG <= 0 THEN -1 ELSE v.WEIGHT_KG END                       AS WEIGHT_KG,
        v.UNIT_PRICE_USD,
        v.CERTIFICATION_STATUS,
        v.LEAD_TIME_DAYS,
        v.LIFECYCLE_STATUS,
        v.INSTALLATION_DATE,
        v.QUANTITY_ON_HAND,
        v.WAREHOUSE_LOCATION,
        v.SUPPLIER_CODE,
        v.COUNTRY_OF_ORIGIN,
        v.UPDATED_AT,
        v.CATEGORY,
        v.SUPPLIER_ID,
        v.PART_STATUS,
        v.INVENTORY_HEALTH_STATUS,
        v.STOCK_QUANTITY,
        v.SUPPLY_RISK_LEVEL,
        v.SUPPLIER_COUNT,
        -- BR-08: High Risk when Pending AND lead time > 60
        -- BR-09: Medium Risk when Pending OR lead time > 100 (High Risk not met)
        -- BR-10: Low Risk when cert in (FAA, EASA, Dual) AND lead time <= 60
        -- BR-11: Medium Risk for all remaining cases
        CASE
            WHEN v.CERTIFICATION_STATUS = 'Pending' AND v.LEAD_TIME_DAYS > 60
                THEN 'High Risk'
            WHEN (v.CERTIFICATION_STATUS = 'Pending' OR v.LEAD_TIME_DAYS > 100)
                 AND NOT (v.CERTIFICATION_STATUS = 'Pending' AND v.LEAD_TIME_DAYS > 60)
                THEN 'Medium Risk'
            WHEN v.CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND v.LEAD_TIME_DAYS <= 60
                THEN 'Low Risk'
            ELSE 'Medium Risk'
        END                                                                            AS RISK_SCORE
    -- FR-02: use reused deduplication view (BR-03: latest UPDATED_AT per PART_NUMBER)
    FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED v
    -- FR-01, BR-01: incremental filter; BR-02: NULL watermark skips filter (full load)
    WHERE (:v_watermark IS NULL OR v.UPDATED_AT > :v_watermark);

    -- Capture source count before dedup (raw source rows matching watermark)
    SELECT COUNT(*)
    INTO   :v_source_count
    FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE
    WHERE  (:v_watermark IS NULL OR UPDATED_AT > :v_watermark);

    -- Capture deduplicated staging count
    SELECT COUNT(*)
    INTO   :v_dedup_count
    FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING;

    -- ================================================================
    -- STEP 5: SCD Type 1 MERGE into AEROSPACE_PARTS_TARGET (FR-03, BR-04)
    -- Source: AEROSPACE_PARTS_STAGING (already transformed)
    -- Key: PART_NUMBER
    -- WHEN MATCHED: overwrite all non-key attributes (BR-04)
    -- WHEN NOT MATCHED: insert new record
    -- ================================================================
    MERGE INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET AS tgt
    USING SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING    AS src
        ON tgt.PART_NUMBER = src.PART_NUMBER
    -- BR-04: SCD Type 1 overwrite on match
    WHEN MATCHED THEN UPDATE SET
        tgt.PART_NAME              = src.PART_NAME,
        tgt.MANUFACTURER           = src.MANUFACTURER,           -- BR-06 already applied in staging
        tgt.WEIGHT_KG              = src.WEIGHT_KG,              -- BR-07 already applied in staging
        tgt.UNIT_PRICE_USD         = src.UNIT_PRICE_USD,
        tgt.CERTIFICATION_STATUS   = src.CERTIFICATION_STATUS,
        tgt.LEAD_TIME_DAYS         = src.LEAD_TIME_DAYS,
        tgt.LIFECYCLE_STATUS       = src.LIFECYCLE_STATUS,
        tgt.INSTALLATION_DATE      = src.INSTALLATION_DATE,
        tgt.QUANTITY_ON_HAND       = src.QUANTITY_ON_HAND,
        tgt.WAREHOUSE_LOCATION     = src.WAREHOUSE_LOCATION,
        tgt.SUPPLIER_CODE          = src.SUPPLIER_CODE,
        tgt.COUNTRY_OF_ORIGIN      = src.COUNTRY_OF_ORIGIN,
        tgt.RISK_SCORE             = src.RISK_SCORE,             -- BR-08 to BR-11 already applied
        tgt.UPDATED_AT             = src.UPDATED_AT,
        tgt.CATEGORY               = src.CATEGORY,
        tgt.SUPPLIER_ID            = src.SUPPLIER_ID,
        tgt.PART_STATUS            = src.PART_STATUS,
        tgt.INVENTORY_HEALTH_STATUS= src.INVENTORY_HEALTH_STATUS,
        tgt.STOCK_QUANTITY         = src.STOCK_QUANTITY,
        tgt.SUPPLY_RISK_LEVEL      = src.SUPPLY_RISK_LEVEL,
        tgt.SUPPLIER_COUNT         = src.SUPPLIER_COUNT,
        tgt.IS_DELETED             = FALSE,
        tgt.RECORD_STATUS          = 'Active',
        tgt.LAST_MODIFIED_AT       = CURRENT_TIMESTAMP(),
        tgt.LOAD_TYPE              = :v_load_type,
        tgt.PIPELINE_RUN_TS        = :v_run_ts,
        tgt.LOAD_TIMESTAMP         = CURRENT_TIMESTAMP()
    -- New record: insert with all columns
    WHEN NOT MATCHED THEN INSERT (
        PART_NUMBER,
        PART_NAME,
        MANUFACTURER,
        WEIGHT_KG,
        UNIT_PRICE_USD,
        CERTIFICATION_STATUS,
        LEAD_TIME_DAYS,
        LIFECYCLE_STATUS,
        INSTALLATION_DATE,
        QUANTITY_ON_HAND,
        WAREHOUSE_LOCATION,
        SUPPLIER_CODE,
        COUNTRY_OF_ORIGIN,
        RISK_SCORE,
        UPDATED_AT,
        CREATED_AT,
        TARGET_LOADED_AT,
        IS_DELETED,
        CATEGORY,
        SUPPLIER_ID,
        PART_STATUS,
        LOAD_TIMESTAMP,
        INVENTORY_HEALTH_STATUS,
        STOCK_QUANTITY,
        SUPPLY_RISK_LEVEL,
        SUPPLIER_COUNT,
        RECORD_STATUS,
        LAST_MODIFIED_AT,
        LOAD_TYPE,
        PIPELINE_RUN_TS
    ) VALUES (
        src.PART_NUMBER,
        src.PART_NAME,
        src.MANUFACTURER,
        src.WEIGHT_KG,
        src.UNIT_PRICE_USD,
        src.CERTIFICATION_STATUS,
        src.LEAD_TIME_DAYS,
        src.LIFECYCLE_STATUS,
        src.INSTALLATION_DATE,
        src.QUANTITY_ON_HAND,
        src.WAREHOUSE_LOCATION,
        src.SUPPLIER_CODE,
        src.COUNTRY_OF_ORIGIN,
        src.RISK_SCORE,
        src.UPDATED_AT,
        CURRENT_TIMESTAMP(),
        CURRENT_TIMESTAMP(),
        FALSE,
        src.CATEGORY,
        src.SUPPLIER_ID,
        src.PART_STATUS,
        CURRENT_TIMESTAMP(),
        src.INVENTORY_HEALTH_STATUS,
        src.STOCK_QUANTITY,
        src.SUPPLY_RISK_LEVEL,
        src.SUPPLIER_COUNT,
        'Active',
        CURRENT_TIMESTAMP(),
        :v_load_type,
        :v_run_ts
    );

    -- Capture MERGE row counts using RESULT_SCAN (both WHEN clauses present)
    SELECT
        "number of rows inserted",
        "number of rows updated"
    INTO :v_ins, :v_upd
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

    -- ================================================================
    -- STEP 6: Soft-delete logic (FR-04, BR-05)
    -- BR-05: Any PART_NUMBER present in target (not already Decommissioned)
    -- but absent from the FULL current source (all keys, not just incremental
    -- extract) must be soft-deleted with PART_STATUS='Decommissioned'.
    -- We compare against AEROSPACE_PARTS_SOURCE with no watermark filter
    -- to get the complete current set of active source keys.
    -- ================================================================
    UPDATE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET AS tgt
    SET
        tgt.IS_DELETED       = TRUE,
        tgt.PART_STATUS      = 'Decommissioned',
        tgt.RECORD_STATUS    = 'Deleted',
        tgt.LAST_MODIFIED_AT = CURRENT_TIMESTAMP(),
        tgt.LOAD_TYPE        = :v_load_type,
        tgt.PIPELINE_RUN_TS  = :v_run_ts,
        tgt.LOAD_TIMESTAMP   = CURRENT_TIMESTAMP()
    WHERE tgt.PART_STATUS <> 'Decommissioned'
      AND NOT EXISTS (
          SELECT 1
          FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE src
          WHERE  src.PART_NUMBER = tgt.PART_NUMBER
      );

    v_del := SQLROWCOUNT;

    -- ================================================================
    -- STEP 7: Capture final target count (FR-08, BR-12)
    -- TARGET_COUNT = count of non-deleted active rows in target
    -- (COALESCE(IS_DELETED, FALSE) = FALSE)
    -- ================================================================
    SELECT COUNT(*)
    INTO   :v_target_count
    FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
    WHERE  COALESCE(IS_DELETED, FALSE) = FALSE;

    -- ================================================================
    -- STEP 8: Compute discrepancy (BR-12)
    -- discrepancy = |dedup_count - (ins + upd)| for the current run
    -- ================================================================
    v_discrepancy := ABS(v_dedup_count - (v_ins + v_upd));

    -- ================================================================
    -- STEP 9: Update ETL_CONTROL watermark on success (FR-01, BR-01)
    -- ================================================================
    UPDATE SDLC_DB.SDLC_PIPELINES.ETL_CONTROL
    SET    LAST_SUCCESSFUL_RUN_TS = :v_run_ts,
           UPDATED_AT             = CURRENT_TIMESTAMP()
    WHERE  PIPELINE_NAME = :v_pipeline_name;

    -- ================================================================
    -- STEP 10: Write reconciliation log (FR-08)
    -- ================================================================
    INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
        PIPELINE_NAME,
        RUN_TS,
        LOAD_TYPE,
        WATERMARK_USED,
        SOURCE_COUNT,
        EXCLUDED_COUNT,
        DEDUPLICATED_COUNT,
        INSERTED_COUNT,
        UPDATED_COUNT,
        DELETED_COUNT,
        TARGET_COUNT,
        PIPELINE_STATUS,
        ERROR_MESSAGE,
        DISCREPANCY_COUNT
    ) VALUES (
        :v_pipeline_name,
        :v_run_ts,
        :v_load_type,
        :v_watermark,
        :v_source_count,
        :v_source_count - :v_dedup_count,
        :v_dedup_count,
        :v_ins,
        :v_upd,
        :v_del,
        :v_target_count,
        :v_status,
        :v_err,
        :v_discrepancy
    );

    -- Build summary string
    v_summary := 'SUCCESS | load_type=' || v_load_type
        || ' | source='      || v_source_count
        || ' | dedup='       || v_dedup_count
        || ' | ins='         || v_ins
        || ' | upd='         || v_upd
        || ' | del='         || v_del
        || ' | target='      || v_target_count
        || ' | discrepancy=' || v_discrepancy;

    RETURN v_summary;

EXCEPTION
    WHEN OTHER THEN
        LET err VARCHAR := SQLERRM;
        v_status  := 'FAILURE';
        v_summary := 'FAILURE | load_type=' || v_load_type || ' | error=' || :err;

        INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
            PIPELINE_NAME,
            RUN_TS,
            LOAD_TYPE,
            WATERMARK_USED,
            SOURCE_COUNT,
            EXCLUDED_COUNT,
            DEDUPLICATED_COUNT,
            INSERTED_COUNT,
            UPDATED_COUNT,
            DELETED_COUNT,
            TARGET_COUNT,
            PIPELINE_STATUS,
            ERROR_MESSAGE,
            DISCREPANCY_COUNT
        ) VALUES (
            :v_pipeline_name,
            :v_run_ts,
            :v_load_type,
            :v_watermark,
            :v_source_count,
            0,
            :v_dedup_count,
            :v_ins,
            :v_upd,
            :v_del,
            :v_target_count,
            :v_status,
            :err,
            0
        );

        RETURN :v_summary;
END;
$$;
