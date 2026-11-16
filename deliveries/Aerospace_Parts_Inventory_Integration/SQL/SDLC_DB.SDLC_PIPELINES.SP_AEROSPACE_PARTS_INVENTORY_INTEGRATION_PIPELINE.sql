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
--   - SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM
--   - SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
--   - SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
--   - SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
-- Business Rules: BR-01, BR-02, BR-03, BR-04, BR-05, BR-06, BR-07, BR-08, BR-09, BR-10, BR-11, BR-12
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
    -- Variable declarations
    -- ----------------------------------------------------------------
    v_pipeline_name     VARCHAR  DEFAULT 'AEROSPACE_PARTS_INVENTORY_INTEGRATION';
    v_watermark         TIMESTAMP_NTZ DEFAULT NULL;
    v_load_type         VARCHAR  DEFAULT 'INCREMENTAL';
    v_source_count      NUMBER(38,0) DEFAULT 0;
    v_target_count      NUMBER(38,0) DEFAULT 0;
    v_inserted          NUMBER(38,0) DEFAULT 0;
    v_updated           NUMBER(38,0) DEFAULT 0;
    v_soft_deleted      NUMBER(38,0) DEFAULT 0;
    v_log_id            NUMBER(38,0) DEFAULT 0;
    v_run_ts            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    v_summary           VARCHAR  DEFAULT '';
    v_err               VARCHAR  DEFAULT '';
BEGIN
    -- ----------------------------------------------------------------
    -- STEP 1: Read watermark (FR-01, BR-01, BR-02)
    -- If no prior run exists, watermark is NULL => full load
    -- ----------------------------------------------------------------
    SELECT COALESCE(MAX(WATERMARK_TS), NULL)
      INTO :v_watermark
      FROM SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM
     WHERE PIPELINE_NAME = :v_pipeline_name;

    -- Determine load type for logging
    IF (:v_watermark IS NULL) THEN
        v_load_type := 'FULL';  -- BR-02: first run, no prior timestamp
    ELSE
        v_load_type := 'INCREMENTAL';  -- BR-01: filter by UPDATED_AT > watermark
    END IF;

    -- ----------------------------------------------------------------
    -- STEP 2: Count source records for reconciliation (FR-08, BR-12)
    -- Uses deduplicated view which applies UPPER(MANUFACTURER) (FR-05, BR-06)
    -- and deduplicates by MAX(UPDATED_AT) per PART_NUMBER (FR-02, BR-03)
    -- Applies incremental filter if watermark exists (FR-01, BR-01)
    -- ----------------------------------------------------------------
    SELECT COUNT(*)
      INTO :v_source_count
      FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
     WHERE (:v_watermark IS NULL OR UPDATED_AT > :v_watermark);

    -- ----------------------------------------------------------------
    -- STEP 3: SCD Type 1 MERGE into target (FR-03, BR-04)
    -- Source: VW_AEROSPACE_PARTS_DEDUPLICATED filtered by watermark
    -- Transformations applied inline:
    --   UPPER(MANUFACTURER)                          (FR-05, BR-06)
    --   CASE WEIGHT_KG <= 0 THEN -1                  (FR-06, BR-07)
    --   Inline RISK_SCORE CASE expression            (FR-07, BR-08..BR-11)
    -- ----------------------------------------------------------------
    MERGE INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET AS tgt
    USING (
        SELECT
            src.PART_NUMBER,
            src.PART_NAME,
            -- BR-06: MANUFACTURER must be uppercase
            UPPER(src.MANUFACTURER)                                          AS MANUFACTURER,
            -- BR-07: replace WEIGHT_KG <= 0 with -1
            CASE WHEN src.WEIGHT_KG <= 0 THEN -1 ELSE src.WEIGHT_KG END      AS WEIGHT_KG,
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
            -- BR-08: High Risk when Pending AND lead time > 60
            -- BR-09: Medium Risk when Pending OR lead time > 100 (not High Risk)
            -- BR-10: Low Risk when FAA/EASA/Dual AND lead time <= 60
            -- BR-11: Medium Risk for all other cases
            CASE
                WHEN src.CERTIFICATION_STATUS = 'Pending'
                     AND src.LEAD_TIME_DAYS > 60
                    THEN 'High Risk'
                WHEN (src.CERTIFICATION_STATUS = 'Pending'
                      OR src.LEAD_TIME_DAYS > 100)
                     AND NOT (src.CERTIFICATION_STATUS = 'Pending'
                              AND src.LEAD_TIME_DAYS > 60)
                    THEN 'Medium Risk'
                WHEN src.CERTIFICATION_STATUS IN ('FAA', 'EASA', 'Dual')
                     AND src.LEAD_TIME_DAYS <= 60
                    THEN 'Low Risk'
                ELSE 'Medium Risk'
            END                                                              AS RISK_SCORE
        FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED AS src
        -- BR-01: incremental filter; BR-02: skip filter on full load
        WHERE (:v_watermark IS NULL OR src.UPDATED_AT > :v_watermark)
    ) AS src
    ON tgt.PART_NUMBER = src.PART_NUMBER
    -- BR-04: SCD Type 1 - overwrite all non-key columns on match
    WHEN MATCHED THEN UPDATE SET
        tgt.PART_NAME              = src.PART_NAME,
        tgt.MANUFACTURER           = src.MANUFACTURER,
        tgt.WEIGHT_KG              = src.WEIGHT_KG,
        tgt.UNIT_PRICE_USD         = src.UNIT_PRICE_USD,
        tgt.CERTIFICATION_STATUS   = src.CERTIFICATION_STATUS,
        tgt.LEAD_TIME_DAYS         = src.LEAD_TIME_DAYS,
        tgt.LIFECYCLE_STATUS       = src.LIFECYCLE_STATUS,
        tgt.INSTALLATION_DATE      = src.INSTALLATION_DATE,
        tgt.QUANTITY_ON_HAND       = src.QUANTITY_ON_HAND,
        tgt.WAREHOUSE_LOCATION     = src.WAREHOUSE_LOCATION,
        tgt.SUPPLIER_CODE          = src.SUPPLIER_CODE,
        tgt.COUNTRY_OF_ORIGIN      = src.COUNTRY_OF_ORIGIN,
        tgt.UPDATED_AT             = src.UPDATED_AT,
        tgt.CATEGORY               = src.CATEGORY,
        tgt.SUPPLIER_ID            = src.SUPPLIER_ID,
        tgt.PART_STATUS            = src.PART_STATUS,
        tgt.INVENTORY_HEALTH_STATUS = src.INVENTORY_HEALTH_STATUS,
        tgt.STOCK_QUANTITY         = src.STOCK_QUANTITY,
        tgt.SUPPLY_RISK_LEVEL      = src.SUPPLY_RISK_LEVEL,
        tgt.SUPPLIER_COUNT         = src.SUPPLIER_COUNT,
        tgt.RISK_SCORE             = src.RISK_SCORE
    -- BR-04: insert new records
    WHEN NOT MATCHED THEN INSERT (
        PART_NUMBER, PART_NAME, MANUFACTURER, WEIGHT_KG, UNIT_PRICE_USD,
        CERTIFICATION_STATUS, LEAD_TIME_DAYS, LIFECYCLE_STATUS, INSTALLATION_DATE,
        QUANTITY_ON_HAND, WAREHOUSE_LOCATION, SUPPLIER_CODE, COUNTRY_OF_ORIGIN,
        UPDATED_AT, CATEGORY, SUPPLIER_ID, PART_STATUS, INVENTORY_HEALTH_STATUS,
        STOCK_QUANTITY, SUPPLY_RISK_LEVEL, SUPPLIER_COUNT, RISK_SCORE
    ) VALUES (
        src.PART_NUMBER, src.PART_NAME, src.MANUFACTURER, src.WEIGHT_KG, src.UNIT_PRICE_USD,
        src.CERTIFICATION_STATUS, src.LEAD_TIME_DAYS, src.LIFECYCLE_STATUS, src.INSTALLATION_DATE,
        src.QUANTITY_ON_HAND, src.WAREHOUSE_LOCATION, src.SUPPLIER_CODE, src.COUNTRY_OF_ORIGIN,
        src.UPDATED_AT, src.CATEGORY, src.SUPPLIER_ID, src.PART_STATUS, src.INVENTORY_HEALTH_STATUS,
        src.STOCK_QUANTITY, src.SUPPLY_RISK_LEVEL, src.SUPPLIER_COUNT, src.RISK_SCORE
    );

    -- Read MERGE result counts (both WHEN MATCHED and WHEN NOT MATCHED clauses present)
    SELECT
        "number of rows inserted",
        "number of rows updated"
      INTO :v_inserted, :v_updated
      FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

    -- ----------------------------------------------------------------
    -- STEP 4: Soft-delete decommissioned parts (FR-04, BR-05)
    -- Any PART_NUMBER in target but absent from the FULL current source
    -- extract (not just the incremental slice) is set to Decommissioned
    -- ----------------------------------------------------------------
    UPDATE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET AS tgt
       SET tgt.LIFECYCLE_STATUS = 'Decommissioned'
     WHERE tgt.LIFECYCLE_STATUS <> 'Decommissioned'
       AND tgt.PART_NUMBER NOT IN (
           -- Compare against the complete source, not the incremental slice
           SELECT DISTINCT PART_NUMBER
             FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE
       );

    -- Capture soft-delete row count immediately after UPDATE
    v_soft_deleted := SQLROWCOUNT;

    -- ----------------------------------------------------------------
    -- STEP 5: Count target records for reconciliation (FR-08, BR-12)
    -- ----------------------------------------------------------------
    SELECT COUNT(*)
      INTO :v_target_count
      FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET;

    -- ----------------------------------------------------------------
    -- STEP 6: Update watermark to latest UPDATED_AT processed (FR-01)
    -- Upsert pattern: merge on PIPELINE_NAME
    -- PIPELINE_WATERMARK_PARAM has columns: PIPELINE_NAME, WATERMARK_TS, UPDATED_AT
    -- ----------------------------------------------------------------
    MERGE INTO SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM AS wm
    USING (
        SELECT
            :v_pipeline_name                                        AS PIPELINE_NAME,
            CURRENT_TIMESTAMP()                                     AS UPDATED_AT,
            (
                SELECT COALESCE(MAX(UPDATED_AT), CURRENT_TIMESTAMP())
                  FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE
            )                                                       AS WATERMARK_TS
    ) AS src
    ON wm.PIPELINE_NAME = src.PIPELINE_NAME
    WHEN MATCHED THEN UPDATE SET
        wm.WATERMARK_TS            = src.WATERMARK_TS,
        wm.UPDATED_AT              = src.UPDATED_AT
    WHEN NOT MATCHED THEN INSERT (
        PIPELINE_NAME, WATERMARK_TS, UPDATED_AT
    ) VALUES (
        src.PIPELINE_NAME, src.WATERMARK_TS, src.UPDATED_AT
    );

    -- ----------------------------------------------------------------
    -- STEP 7: Log reconciliation record (FR-08, BR-12)
    -- ----------------------------------------------------------------
    SELECT COALESCE(MAX(LOG_ID), 0) + 1
      INTO :v_log_id
      FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG;

    INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
        LOG_ID,
        PIPELINE_NAME,
        PIPELINE_STATUS,
        LOAD_TYPE,
        SOURCE_COUNT,
        TARGET_COUNT,
        INSERTED_COUNT,
        UPDATED_COUNT,
        DELETED_COUNT,
        DEDUPLICATED_COUNT,
        EXCLUDED_COUNT,
        DISCREPANCY_COUNT,
        WATERMARK_USED,
        ERROR_MESSAGE,
        JIRA_ISSUE,
        RUN_TS
    ) VALUES (
        :v_log_id,
        :v_pipeline_name,
        'SUCCESS',
        :v_load_type,
        :v_source_count,
        :v_target_count,
        :v_inserted,
        :v_updated,
        :v_soft_deleted,
        :v_source_count,   -- deduplicated count equals post-dedup source count
        0,                 -- excluded count not applicable in this pipeline
        (:v_source_count - :v_inserted - :v_updated),  -- discrepancy
        :v_watermark,
        NULL,
        NULL,
        :v_run_ts
    );

    -- ----------------------------------------------------------------
    -- STEP 8: Build and return summary string
    -- ----------------------------------------------------------------
    v_summary := 'SUCCESS | load_type=' || :v_load_type
                 || ' | source=' || :v_source_count
                 || ' | inserted=' || :v_inserted
                 || ' | updated=' || :v_updated
                 || ' | soft_deleted=' || :v_soft_deleted
                 || ' | target_total=' || :v_target_count
                 || ' | run_ts=' || TO_VARCHAR(:v_run_ts);
    RETURN :v_summary;

EXCEPTION
    WHEN OTHER THEN
        -- Capture error details before any further statements
        LET err VARCHAR := SQLERRM;
        -- Log failure to reconciliation table for observability (FR-08)
        LET err_log_id NUMBER(38,0) DEFAULT 0;
        SELECT COALESCE(MAX(LOG_ID), 0) + 1
          INTO :err_log_id
          FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG;
        INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
            LOG_ID,
            PIPELINE_NAME,
            PIPELINE_STATUS,
            LOAD_TYPE,
            SOURCE_COUNT,
            TARGET_COUNT,
            INSERTED_COUNT,
            UPDATED_COUNT,
            DELETED_COUNT,
            DEDUPLICATED_COUNT,
            EXCLUDED_COUNT,
            DISCREPANCY_COUNT,
            WATERMARK_USED,
            ERROR_MESSAGE,
            JIRA_ISSUE,
            RUN_TS
        ) VALUES (
            :err_log_id,
            :v_pipeline_name,
            'FAILED',
            :v_load_type,
            :v_source_count,
            :v_target_count,
            :v_inserted,
            :v_updated,
            :v_soft_deleted,
            0,
            0,
            0,
            :v_watermark,
            :err,
            NULL,
            :v_run_ts
        );
        RETURN 'FAILED: ' || :err;
END;
$$;
