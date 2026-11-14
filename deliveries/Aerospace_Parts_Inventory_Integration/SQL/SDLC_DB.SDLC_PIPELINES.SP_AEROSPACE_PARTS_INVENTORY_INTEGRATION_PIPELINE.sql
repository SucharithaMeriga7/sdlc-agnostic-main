-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE
-- Object Type   : PROCEDURE
-- Jira Story    : SCRUM-159
-- Requirements  : FR-01, FR-02, FR-03, FR-04, FR-05, FR-06, FR-07, FR-08, FR-09
-- Reuse Route   : PIPELINE
-- Description   : Pipeline orchestration for Aerospace_Parts_Inventory_Integration
-- Author        : Sucharitha
-- Created Date  : 2026-11-14
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
--   - SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
--   - SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
-- Business Rules: BR-01, BR-02, BR-03, BR-04, BR-05, BR-06, BR-07, BR-08, BR-09, BR-10, BR-11, BR-12
-- Change History:
--   2026-11-14  Sucharitha  SCRUM-159  Initial generation (PIPELINE)
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
    v_watermark_ts      TIMESTAMP_NTZ;
    v_load_type         VARCHAR  DEFAULT 'INCREMENTAL';
    v_source_count      NUMBER   DEFAULT 0;
    v_target_count      NUMBER   DEFAULT 0;
    v_ins               NUMBER   DEFAULT 0;
    v_upd               NUMBER   DEFAULT 0;
    v_soft_del          NUMBER   DEFAULT 0;
    v_dedup_count       NUMBER   DEFAULT 0;
    v_new_watermark     TIMESTAMP_NTZ;
    v_summary           VARCHAR  DEFAULT '';
    v_log_id            NUMBER   DEFAULT 0;
BEGIN
    -- ================================================================
    -- STEP 1: Resolve watermark (BR-01 / BR-02)
    -- Read the last successful run timestamp from the singleton table.
    -- If no row exists or WATERMARK_TS IS NULL => full load (BR-02).
    -- ================================================================
    SELECT COALESCE(MAX(WATERMARK_TS), NULL)
    INTO   :v_watermark_ts
    FROM   SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM
    WHERE  PIPELINE_NAME = :v_pipeline_name;

    -- Ensure exactly one row exists in the watermark singleton for this pipeline
    MERGE INTO SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM tgt
    USING (
        SELECT :v_pipeline_name AS PIPELINE_NAME,
               :v_watermark_ts  AS WATERMARK_TS
    ) src
    ON tgt.PIPELINE_NAME = src.PIPELINE_NAME
    WHEN NOT MATCHED THEN
        INSERT (PIPELINE_NAME, WATERMARK_TS, UPDATED_AT)
        VALUES (src.PIPELINE_NAME, src.WATERMARK_TS, CURRENT_TIMESTAMP());

    -- Determine load type label for logging
    IF (:v_watermark_ts IS NULL) THEN
        v_load_type := 'FULL';
    END IF;

    -- ================================================================
    -- STEP 2: Count deduplicated source records for this run (FR-02 / BR-03)
    -- Apply watermark filter inline here; the view no longer embeds it.
    -- BR-02: NULL watermark => full load, count all deduplicated rows.
    -- BR-01: incremental => count only rows with UPDATED_AT > watermark.
    -- ================================================================
    SELECT COUNT(*)
    INTO   :v_source_count
    FROM   SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
    WHERE  (
               :v_watermark_ts IS NULL
               OR UPDATED_AT > :v_watermark_ts
           );

    v_dedup_count := v_source_count;

    -- ================================================================
    -- STEP 3: SCD Type 1 MERGE into AEROSPACE_PARTS_TARGET (FR-03)
    -- Business key: PART_NUMBER (BR-04)
    -- Watermark filter applied inline so only changed/new rows are merged.
    -- Transformations applied in view:
    --   UPPER(MANUFACTURER)                          => BR-06 / FR-05
    --   IFF(WEIGHT_KG <= 0, -1, WEIGHT_KG)           => BR-07 / FR-06
    -- RISK_SCORE derived inline per BR-08 through BR-11 / FR-07.
    -- ================================================================
    MERGE INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET tgt
    USING (
        -- Source projection: watermark-filtered deduplicated rows
        -- with inline RISK_SCORE derivation per BR-08 through BR-11 (FR-07)
        SELECT
            src.PART_NUMBER,
            src.PART_NAME,
            src.MANUFACTURER,          -- already UPPER() from view (BR-06)
            src.WEIGHT_KG,             -- already IFF normalised from view (BR-07)
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
            -- FR-07 / BR-08-BR-11: inline RISK_SCORE derivation
            CASE
                -- BR-08: High Risk when Pending AND lead time > 60
                WHEN src.CERTIFICATION_STATUS = 'Pending'
                     AND src.LEAD_TIME_DAYS > 60
                    THEN 'High Risk'
                -- BR-09: Medium Risk when Pending (lead time <= 60, so not High Risk)
                WHEN src.CERTIFICATION_STATUS = 'Pending'
                    THEN 'Medium Risk'
                -- BR-10: Low Risk when FAA/EASA/Dual AND lead time <= 60
                WHEN src.CERTIFICATION_STATUS IN ('FAA', 'EASA', 'Dual')
                     AND src.LEAD_TIME_DAYS <= 60
                    THEN 'Low Risk'
                -- BR-11: FAA/EASA/Dual with lead time > 60 but <= 100 => Medium Risk
                -- BR-09 extension: lead time > 100 => Medium Risk
                ELSE 'Medium Risk'
            END AS RISK_SCORE
        FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED src
        -- BR-01 / BR-02: apply watermark filter inline
        WHERE (
                  :v_watermark_ts IS NULL
                  OR src.UPDATED_AT > :v_watermark_ts
              )
    ) src
    ON tgt.PART_NUMBER = src.PART_NUMBER
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
        tgt.RISK_SCORE              = src.RISK_SCORE
    -- New record: insert with all columns
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

    -- Capture MERGE row counts from result scan
    SELECT
        "number of rows inserted",
        "number of rows updated"
    INTO :v_ins, :v_upd
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

    -- ================================================================
    -- STEP 4: Soft-delete decommissioned parts (FR-04 / BR-05)
    -- Any PART_NUMBER in the target that is NOT in the FULL current
    -- deduplicated source (view without watermark filter) gets
    -- LIFECYCLE_STATUS = 'Decommissioned'.
    -- The view now returns all deduplicated source rows (no watermark
    -- filter embedded), so this correctly identifies removed keys.
    -- ================================================================
    UPDATE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
    SET    LIFECYCLE_STATUS = 'Decommissioned'
    WHERE  PART_NUMBER NOT IN (
               -- BR-05: full current source keyset from deduplicated view
               SELECT PART_NUMBER
               FROM   SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
           )
      AND  LIFECYCLE_STATUS <> 'Decommissioned';  -- avoid redundant updates

    -- Capture soft-delete count via SQLROWCOUNT
    v_soft_del := SQLROWCOUNT;

    -- ================================================================
    -- STEP 5: Count total target rows after load (FR-08 / BR-12)
    -- ================================================================
    SELECT COUNT(*)
    INTO   :v_target_count
    FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET;

    -- ================================================================
    -- STEP 6: Determine new watermark = MAX(UPDATED_AT) from source
    -- Used to update the watermark for the next incremental run (BR-01)
    -- ================================================================
    SELECT MAX(UPDATED_AT)
    INTO   :v_new_watermark
    FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE;

    -- ================================================================
    -- STEP 7: Update watermark singleton for next run (BR-01)
    -- ================================================================
    UPDATE SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM
    SET    WATERMARK_TS = :v_new_watermark,
           UPDATED_AT   = CURRENT_TIMESTAMP()
    WHERE  PIPELINE_NAME = :v_pipeline_name;

    -- ================================================================
    -- STEP 8: Write reconciliation log (FR-08 / BR-12)
    -- ================================================================
    SELECT COALESCE(MAX(LOG_ID), 0) + 1
    INTO   :v_log_id
    FROM   SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG;

    INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
        LOG_ID,
        PIPELINE_NAME,
        PIPELINE_STATUS,
        LOAD_TYPE,
        SOURCE_COUNT,
        TARGET_COUNT,
        INSERTED_COUNT,
        UPDATED_COUNT,
        DEDUPLICATED_COUNT,
        DELETED_COUNT,
        EXCLUDED_COUNT,
        DISCREPANCY_COUNT,
        ERROR_MESSAGE,
        JIRA_ISSUE,
        WATERMARK_USED,
        RUN_TS
    ) VALUES (
        :v_log_id,
        :v_pipeline_name,
        'SUCCESS',
        :v_load_type,
        :v_source_count,
        :v_target_count,
        :v_ins,
        :v_upd,
        :v_dedup_count,
        :v_soft_del,
        0,
        ABS(:v_source_count - (:v_ins + :v_upd)),
        NULL,
        NULL,
        :v_watermark_ts,
        CURRENT_TIMESTAMP()
    );

    -- ================================================================
    -- STEP 9: Build and return summary string
    -- ================================================================
    v_summary := 'PIPELINE: '    || :v_pipeline_name
              || ' | LOAD_TYPE: '|| :v_load_type
              || ' | SOURCE: '   || :v_source_count
              || ' | TARGET: '   || :v_target_count
              || ' | INSERTED: ' || :v_ins
              || ' | UPDATED: '  || :v_upd
              || ' | SOFT_DEL: ' || :v_soft_del
              || ' | WATERMARK: '|| COALESCE(TO_VARCHAR(:v_new_watermark), 'NULL')
              || ' | STATUS: SUCCESS';

    RETURN :v_summary;

EXCEPTION
    WHEN OTHER THEN
        LET err VARCHAR := SQLERRM;
        LET err_code VARCHAR := SQLSTATE;
        LET log_id_ex NUMBER := 0;

        SELECT COALESCE(MAX(LOG_ID), 0) + 1
        INTO   :log_id_ex
        FROM   SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG;

        INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
            LOG_ID,
            PIPELINE_NAME,
            PIPELINE_STATUS,
            LOAD_TYPE,
            SOURCE_COUNT,
            TARGET_COUNT,
            INSERTED_COUNT,
            UPDATED_COUNT,
            DEDUPLICATED_COUNT,
            DELETED_COUNT,
            EXCLUDED_COUNT,
            DISCREPANCY_COUNT,
            ERROR_MESSAGE,
            JIRA_ISSUE,
            WATERMARK_USED,
            RUN_TS
        ) VALUES (
            :log_id_ex,
            :v_pipeline_name,
            'FAILURE',
            :v_load_type,
            :v_source_count,
            :v_target_count,
            :v_ins,
            :v_upd,
            :v_dedup_count,
            :v_soft_del,
            0,
            -1,
            :err,
            NULL,
            :v_watermark_ts,
            CURRENT_TIMESTAMP()
        );

        RETURN 'PIPELINE: ' || :v_pipeline_name
            || ' | STATUS: FAILURE'
            || ' | ERROR_CODE: ' || :err_code
            || ' | ERROR: ' || :err;
END;
$$;
