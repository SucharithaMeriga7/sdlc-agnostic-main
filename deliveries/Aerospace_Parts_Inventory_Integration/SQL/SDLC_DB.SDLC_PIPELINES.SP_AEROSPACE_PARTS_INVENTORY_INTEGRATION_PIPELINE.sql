-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE
-- Object Type   : PROCEDURE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-01, FR-02, FR-03, FR-04, FR-05, FR-06, FR-07, FR-08, FR-09
-- Reuse Route   : PIPELINE
-- Description   : Pipeline orchestration for Aerospace_Parts_Inventory_Integration
-- Author        : Sucharitha
-- Created Date  : 2026-10-26
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
--   - SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
--   - SDLC_DB.SDLC_PIPELINES.ETL_CONTROL
--   - SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
-- Business Rules: BR-01, BR-02, BR-03, BR-04, BR-05, BR-06, BR-07, BR-08, BR-09, BR-10, BR-11, BR-12
-- Change History:
--   2026-10-26  Sucharitha  SCRUM-158  Initial generation (PIPELINE)
-- =============================================================================

CREATE OR REPLACE PROCEDURE SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_pipeline_name     VARCHAR  DEFAULT 'AEROSPACE_PARTS_INVENTORY_INTEGRATION';
    v_run_ts            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    v_watermark         TIMESTAMP_NTZ DEFAULT NULL;
    v_load_type         VARCHAR  DEFAULT 'FULL';
    v_source_count      NUMBER   DEFAULT 0;
    v_dedup_count       NUMBER   DEFAULT 0;
    v_ins               NUMBER   DEFAULT 0;
    v_upd               NUMBER   DEFAULT 0;
    v_del               NUMBER   DEFAULT 0;
    v_target_count      NUMBER   DEFAULT 0;
    v_discrepancy       NUMBER   DEFAULT 0;
    v_status            VARCHAR  DEFAULT 'SUCCESS';
    v_err               VARCHAR  DEFAULT NULL;
    v_summary           VARCHAR  DEFAULT '';

BEGIN
    -- ================================================================
    -- STEP 1: Read watermark (FR-01, BR-01, BR-02)
    -- ================================================================
    SELECT LAST_RUN_TS
    INTO   :v_watermark
    FROM   SDLC_DB.SDLC_PIPELINES.ETL_CONTROL
    WHERE  PIPELINE_NAME = :v_pipeline_name
    LIMIT  1;

    IF (v_watermark IS NOT NULL) THEN
        v_load_type := 'INCREMENTAL';
    ELSE
        v_load_type := 'FULL';
    END IF;

    -- ================================================================
    -- STEP 2: Count raw source records (FR-08, BR-12)
    -- ================================================================
    SELECT COUNT(*)
    INTO   :v_source_count
    FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE
    WHERE  (:v_watermark IS NULL OR UPDATED_AT > :v_watermark);

    -- ================================================================
    -- STEP 3: Count deduplicated records (FR-02, BR-03)
    -- ================================================================
    SELECT COUNT(*)
    INTO   :v_dedup_count
    FROM   SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
    WHERE  (:v_watermark IS NULL OR UPDATED_AT > :v_watermark);

    -- ================================================================
    -- STEP 4: MERGE into target (FR-03, BR-04 to BR-11)
    -- ================================================================
    MERGE INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET AS tgt
    USING (
        SELECT
            src.PART_NUMBER,
            src.PART_NAME,
            -- BR-06: uppercase manufacturer
            UPPER(src.MANUFACTURER)                          AS MANUFACTURER,
            -- BR-07: replace weight <= 0 with -1
            IFF(src.WEIGHT_KG <= 0, -1, src.WEIGHT_KG)      AS WEIGHT_KG,
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
            -- BR-08: High Risk  = Pending AND lead_time > 60
            -- BR-10: Low Risk   = (FAA|EASA|Dual) AND lead_time <= 60
            -- BR-09: Medium Risk = Pending (lead_time <= 60) OR lead_time > 100
            -- BR-11: Medium Risk = everything else
            CASE
                WHEN src.CERTIFICATION_STATUS = 'Pending'
                     AND src.LEAD_TIME_DAYS > 60
                    THEN 'High Risk'
                WHEN src.CERTIFICATION_STATUS IN ('FAA', 'EASA', 'Dual')
                     AND src.LEAD_TIME_DAYS <= 60
                    THEN 'Low Risk'
                ELSE 'Medium Risk'
            END                                              AS RISK_SCORE
        FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED AS src
        WHERE (:v_watermark IS NULL OR src.UPDATED_AT > :v_watermark)
    ) AS src
    ON tgt.PART_NUMBER = src.PART_NUMBER
    -- BR-04: SCD Type 1 overwrite
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
        tgt.RISK_SCORE              = src.RISK_SCORE,
        tgt.UPDATED_AT              = src.UPDATED_AT,
        tgt.CATEGORY                = src.CATEGORY,
        tgt.SUPPLIER_ID             = src.SUPPLIER_ID,
        tgt.PART_STATUS             = src.PART_STATUS,
        tgt.INVENTORY_HEALTH_STATUS = src.INVENTORY_HEALTH_STATUS,
        tgt.STOCK_QUANTITY          = src.STOCK_QUANTITY,
        tgt.SUPPLY_RISK_LEVEL       = src.SUPPLY_RISK_LEVEL,
        tgt.SUPPLIER_COUNT          = src.SUPPLIER_COUNT,
        tgt.IS_DELETED              = FALSE,
        tgt.RECORD_STATUS           = 'Active',
        tgt.LAST_MODIFIED_AT        = :v_run_ts,
        tgt.LOAD_TYPE               = :v_load_type,
        tgt.PIPELINE_RUN_TS         = :v_run_ts,
        tgt.LOAD_TIMESTAMP          = :v_run_ts
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
        :v_run_ts,
        :v_run_ts,
        FALSE,
        src.CATEGORY,
        src.SUPPLIER_ID,
        src.PART_STATUS,
        :v_run_ts,
        src.INVENTORY_HEALTH_STATUS,
        src.STOCK_QUANTITY,
        src.SUPPLY_RISK_LEVEL,
        src.SUPPLIER_COUNT,
        'Active',
        :v_run_ts,
        :v_load_type,
        :v_run_ts
    );

    -- Capture MERGE row counts
    SELECT
        "number of rows inserted",
        "number of rows updated"
    INTO :v_ins, :v_upd
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

    -- ================================================================
    -- STEP 5: Soft delete records absent from current source (FR-04, BR-05)
    -- ================================================================
    UPDATE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET AS tgt
    SET
        tgt.LIFECYCLE_STATUS  = 'Decommissioned',
        tgt.IS_DELETED        = TRUE,
        tgt.RECORD_STATUS     = 'Decommissioned',
        tgt.LAST_MODIFIED_AT  = :v_run_ts,
        tgt.PIPELINE_RUN_TS   = :v_run_ts,
        tgt.LOAD_TYPE         = :v_load_type
    WHERE tgt.IS_DELETED = FALSE
      AND tgt.LIFECYCLE_STATUS <> 'Decommissioned'
      AND tgt.PART_NUMBER NOT IN (
          SELECT PART_NUMBER
          FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE
      );

    v_del := SQLROWCOUNT;

    -- ================================================================
    -- STEP 6: Count active target records post-load (FR-08, BR-12)
    -- ================================================================
    SELECT COUNT(*)
    INTO   :v_target_count
    FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
    WHERE  IS_DELETED = FALSE
      AND  LIFECYCLE_STATUS <> 'Decommissioned';

    -- ================================================================
    -- STEP 7: Update ETL_CONTROL watermark (FR-01, BR-01)
    -- ================================================================
    MERGE INTO SDLC_DB.SDLC_PIPELINES.ETL_CONTROL AS ctrl
    USING (SELECT :v_pipeline_name AS PIPELINE_NAME) AS src
    ON ctrl.PIPELINE_NAME = src.PIPELINE_NAME
    WHEN MATCHED THEN UPDATE SET
        ctrl.LAST_RUN_TS  = :v_run_ts,
        ctrl.UPDATED_AT   = :v_run_ts
    WHEN NOT MATCHED THEN INSERT (
        PIPELINE_NAME,
        LAST_RUN_TS,
        UPDATED_AT
    ) VALUES (
        :v_pipeline_name,
        :v_run_ts,
        :v_run_ts
    );

    -- ================================================================
    -- STEP 8: Compute discrepancy and log reconciliation (FR-08, BR-12)
    -- ================================================================
    v_discrepancy := ABS(v_dedup_count - (v_ins + v_upd));

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
        :v_err,
        :v_discrepancy
    );

    -- ================================================================
    -- STEP 9: Return summary
    -- ================================================================
    v_summary := 'PIPELINE: '     || v_pipeline_name
              || ' | LOAD_TYPE: '  || v_load_type
              || ' | SOURCE: '     || v_source_count
              || ' | DEDUP: '      || v_dedup_count
              || ' | INSERTED: '   || v_ins
              || ' | UPDATED: '    || v_upd
              || ' | DELETED: '    || v_del
              || ' | TARGET: '     || v_target_count
              || ' | DISCREPANCY: '|| v_discrepancy
              || ' | STATUS: '     || v_status;

    RETURN v_summary;

EXCEPTION
    WHEN OTHER THEN
        LET err VARCHAR := SQLERRM;
        LET err_status VARCHAR := 'FAILED';

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
            :err_status,
            :err,
            -1
        );

        RETURN 'PIPELINE: ' || v_pipeline_name || ' | STATUS: FAILED | ERROR: ' || err;
END;
$$;
