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
    -- -------------------------------------------------------------------------
    -- Run-level metadata variables
    -- -------------------------------------------------------------------------
    v_run_ts          TIMESTAMP_NTZ(9);   -- wall-clock start of this run
    v_watermark_ts    TIMESTAMP_NTZ(9);   -- watermark read from PIPELINE_WATERMARK_PARAM
    v_load_type       VARCHAR(20);        -- 'FULL' or 'INCREMENTAL'
    v_new_watermark   TIMESTAMP_NTZ(9);   -- max UPDATED_AT from source extract

    -- -------------------------------------------------------------------------
    -- Row-count variables
    -- -------------------------------------------------------------------------
    v_source_count    NUMBER(18,0);       -- raw source rows before dedup
    v_dedup_count     NUMBER(18,0);       -- rows after deduplication (view output)
    v_inserted        NUMBER(18,0);       -- MERGE: rows inserted (new PART_NUMBERs)
    v_updated         NUMBER(18,0);       -- MERGE: rows updated (existing PART_NUMBERs)
    v_deleted         NUMBER(18,0);       -- soft-deleted rows (Decommissioned)
    v_target_count    NUMBER(18,0);       -- active rows in target after load
    v_discrepancy     NUMBER(18,0);       -- |dedup_count - (inserted + updated)|

    -- -------------------------------------------------------------------------
    -- Error-handling variables
    -- -------------------------------------------------------------------------
    v_status          VARCHAR(20);        -- 'SUCCESS' or 'FAILED'
    v_err             VARCHAR(4000);      -- error message captured in handler

    -- -------------------------------------------------------------------------
    -- Summary string returned to caller
    -- -------------------------------------------------------------------------
    v_summary         VARCHAR(4000);

BEGIN
    -- =========================================================================
    -- STEP 0: Initialise run metadata
    -- =========================================================================
    v_run_ts  := CURRENT_TIMESTAMP()::TIMESTAMP_NTZ(9);
    v_status  := 'SUCCESS';
    v_err     := NULL;

    -- =========================================================================
    -- STEP 1: Read current watermark from PIPELINE_WATERMARK_PARAM
    --         BR-01: incremental filter uses this value.
    --         BR-02: NULL means first run -> full load.
    -- =========================================================================
    SELECT WATERMARK_TS
    INTO   :v_watermark_ts
    FROM   SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM
    LIMIT  1;

    -- Determine load type label for reconciliation log
    IF (v_watermark_ts IS NULL) THEN
        v_load_type := 'FULL';          -- BR-02: no prior run
    ELSE
        v_load_type := 'INCREMENTAL';   -- BR-01: filter by watermark
    END IF;

    -- =========================================================================
    -- STEP 2: Count raw source rows for reconciliation (before dedup)
    --         Mirrors the WHERE clause used in VW_AEROSPACE_PARTS_DEDUPLICATED
    --         so SOURCE_COUNT reflects the same extract window.
    -- =========================================================================
    SELECT COUNT(*)
    INTO   :v_source_count
    FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE_DEV_SRC src
    WHERE  src.PART_NUMBER IS NOT NULL
      AND  (
               :v_watermark_ts IS NULL
               OR src.UPDATED_AT > :v_watermark_ts
           );

    -- =========================================================================
    -- STEP 3: Count deduplicated rows from the adapted view (BR-03)
    --         VW_AEROSPACE_PARTS_DEDUPLICATED already applies ROW_NUMBER()=1
    --         and the watermark filter via PIPELINE_WATERMARK_PARAM cross-join.
    -- =========================================================================
    SELECT COUNT(*)
    INTO   :v_dedup_count
    FROM   SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED;

    -- =========================================================================
    -- STEP 4: Capture new watermark = max UPDATED_AT in current extract
    --         Used to advance the watermark after a successful run.
    -- =========================================================================
    SELECT MAX(UPDATED_AT)
    INTO   :v_new_watermark
    FROM   SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED;

    -- =========================================================================
    -- STEP 5: MERGE into AEROSPACE_PARTS_TARGET
    --
    --   WHEN MATCHED (BR-04: SCD Type 1 overwrite):
    --     - UPPER(MANUFACTURER)                          -> BR-06
    --     - CASE WHEN WEIGHT_KG <= 0 THEN -1 ELSE ...   -> BR-07
    --     - Inline RISK_SCORE CASE expression            -> BR-08 to BR-11
    --
    --   WHEN NOT MATCHED (new PART_NUMBER):
    --     - Same transformations applied on INSERT
    --
    --   BR-05 soft delete handled in a separate UPDATE after MERGE
    -- =========================================================================
    MERGE INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET  tgt
    USING (
        -- Source CTE: pull from deduplicated view, apply all inline transforms
        SELECT
            src.PART_NUMBER,
            src.PART_NAME,
            -- BR-06: MANUFACTURER must be stored as UPPER() (FR-05)
            UPPER(src.MANUFACTURER)                                         AS MANUFACTURER,
            -- BR-07: replace WEIGHT_KG <= 0 with -1 (FR-06)
            CASE
                WHEN src.WEIGHT_KG <= 0 THEN -1
                ELSE src.WEIGHT_KG
            END::NUMBER(10,3)                                               AS WEIGHT_KG,
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
            -- BR-08 to BR-11: inline RISK_SCORE derivation (FR-07)
            CASE
                -- BR-08: High Risk: Pending AND lead time > 60
                WHEN src.CERTIFICATION_STATUS = 'Pending'
                     AND src.LEAD_TIME_DAYS > 60
                    THEN 'High Risk'
                -- BR-09: Medium Risk: Pending OR lead time > 100 (High Risk not met)
                WHEN src.CERTIFICATION_STATUS = 'Pending'
                     OR  src.LEAD_TIME_DAYS > 100
                    THEN 'Medium Risk'
                -- BR-10: Low Risk: FAA/EASA/Dual AND lead time <= 60
                WHEN src.CERTIFICATION_STATUS IN ('FAA', 'EASA', 'Dual')
                     AND src.LEAD_TIME_DAYS <= 60
                    THEN 'Low Risk'
                -- BR-11: all remaining cases -> Medium Risk
                ELSE 'Medium Risk'
            END                                                             AS RISK_SCORE
        FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED src
    ) AS staged
    -- Join key: BR-04 business key is PART_NUMBER
    ON tgt.PART_NUMBER = staged.PART_NUMBER

    -- -------------------------------------------------------------------------
    -- WHEN MATCHED: SCD Type 1 overwrite (BR-04)
    -- -------------------------------------------------------------------------
    WHEN MATCHED THEN UPDATE SET
        tgt.PART_NAME               = staged.PART_NAME,
        tgt.MANUFACTURER            = staged.MANUFACTURER,        -- BR-06
        tgt.WEIGHT_KG               = staged.WEIGHT_KG,           -- BR-07
        tgt.UNIT_PRICE_USD          = staged.UNIT_PRICE_USD,
        tgt.CERTIFICATION_STATUS    = staged.CERTIFICATION_STATUS,
        tgt.LEAD_TIME_DAYS          = staged.LEAD_TIME_DAYS,
        tgt.LIFECYCLE_STATUS        = staged.LIFECYCLE_STATUS,
        tgt.INSTALLATION_DATE       = staged.INSTALLATION_DATE,
        tgt.QUANTITY_ON_HAND        = staged.QUANTITY_ON_HAND,
        tgt.WAREHOUSE_LOCATION      = staged.WAREHOUSE_LOCATION,
        tgt.SUPPLIER_CODE           = staged.SUPPLIER_CODE,
        tgt.COUNTRY_OF_ORIGIN       = staged.COUNTRY_OF_ORIGIN,
        tgt.UPDATED_AT              = staged.UPDATED_AT,
        tgt.CATEGORY                = staged.CATEGORY,
        tgt.SUPPLIER_ID             = staged.SUPPLIER_ID,
        tgt.PART_STATUS             = staged.PART_STATUS,
        tgt.INVENTORY_HEALTH_STATUS = staged.INVENTORY_HEALTH_STATUS,
        tgt.STOCK_QUANTITY          = staged.STOCK_QUANTITY,
        tgt.SUPPLY_RISK_LEVEL       = staged.SUPPLY_RISK_LEVEL,
        tgt.SUPPLIER_COUNT          = staged.SUPPLIER_COUNT,
        tgt.RISK_SCORE              = staged.RISK_SCORE,           -- BR-08 to BR-11
        tgt.DW_UPDATE_TS            = CURRENT_TIMESTAMP()::TIMESTAMP_NTZ(9)

    -- -------------------------------------------------------------------------
    -- WHEN NOT MATCHED: new PART_NUMBER -> INSERT
    -- -------------------------------------------------------------------------
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
        UPDATED_AT,
        CATEGORY,
        SUPPLIER_ID,
        PART_STATUS,
        INVENTORY_HEALTH_STATUS,
        STOCK_QUANTITY,
        SUPPLY_RISK_LEVEL,
        SUPPLIER_COUNT,
        RISK_SCORE,
        DW_INSERT_TS,
        DW_UPDATE_TS
    ) VALUES (
        staged.PART_NUMBER,
        staged.PART_NAME,
        staged.MANUFACTURER,        -- BR-06: already UPPER()
        staged.WEIGHT_KG,           -- BR-07: already normalised
        staged.UNIT_PRICE_USD,
        staged.CERTIFICATION_STATUS,
        staged.LEAD_TIME_DAYS,
        staged.LIFECYCLE_STATUS,
        staged.INSTALLATION_DATE,
        staged.QUANTITY_ON_HAND,
        staged.WAREHOUSE_LOCATION,
        staged.SUPPLIER_CODE,
        staged.COUNTRY_OF_ORIGIN,
        staged.UPDATED_AT,
        staged.CATEGORY,
        staged.SUPPLIER_ID,
        staged.PART_STATUS,
        staged.INVENTORY_HEALTH_STATUS,
        staged.STOCK_QUANTITY,
        staged.SUPPLY_RISK_LEVEL,
        staged.SUPPLIER_COUNT,
        staged.RISK_SCORE,          -- BR-08 to BR-11
        CURRENT_TIMESTAMP()::TIMESTAMP_NTZ(9),
        CURRENT_TIMESTAMP()::TIMESTAMP_NTZ(9)
    );

    -- =========================================================================
    -- STEP 6: Read MERGE result counts
    --         Snowflake MERGE result columns:
    --           "number of rows inserted"  -> v_inserted
    --           "number of rows updated"   -> v_updated
    -- =========================================================================
    SELECT
        "number of rows inserted",
        "number of rows updated"
    INTO
        :v_inserted,
        :v_updated
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

    -- =========================================================================
    -- STEP 7: Soft delete orphaned target rows (BR-05)
    --         Only apply to rows not already Decommissioned to avoid
    --         unnecessary updates. Rows absent from the deduplicated view
    --         are identified by LEFT JOIN / NOT EXISTS against the source.
    -- =========================================================================
    UPDATE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET tgt
    SET    tgt.LIFECYCLE_STATUS = 'Decommissioned',
           tgt.DW_UPDATE_TS     = CURRENT_TIMESTAMP()::TIMESTAMP_NTZ(9)
    WHERE  tgt.LIFECYCLE_STATUS <> 'Decommissioned'
      AND  NOT EXISTS (
               SELECT 1
               FROM   SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED src
               WHERE  src.PART_NUMBER = tgt.PART_NUMBER
           );

    v_deleted := SQLROWCOUNT;

    -- =========================================================================
    -- STEP 8: Count active (non-Decommissioned) target rows after load
    -- =========================================================================
    SELECT COUNT(*)
    INTO   :v_target_count
    FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
    WHERE  LIFECYCLE_STATUS <> 'Decommissioned';

    -- =========================================================================
    -- STEP 9: Advance watermark in PIPELINE_WATERMARK_PARAM
    --         Only update if new_watermark is not NULL (i.e. source had rows).
    -- =========================================================================
    IF (v_new_watermark IS NOT NULL) THEN
        UPDATE SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM
        SET    WATERMARK_TS = :v_new_watermark;
    END IF;

    -- =========================================================================
    -- STEP 10: Compute reconciliation discrepancy
    --          |dedup_count - (inserted + updated)| should be 0.
    -- =========================================================================
    v_discrepancy := ABS(v_dedup_count - (v_inserted + v_updated));

    -- =========================================================================
    -- STEP 11: Log run to PIPELINE_RUN_LOG
    -- =========================================================================
    INSERT INTO SDLC_DB.SDLC_PIPELINES.PIPELINE_RUN_LOG (
        RUN_TS,
        LOAD_TYPE,
        SOURCE_COUNT,
        DEDUP_COUNT,
        INSERTED,
        UPDATED,
        DELETED,
        TARGET_COUNT,
        DISCREPANCY,
        STATUS,
        ERROR_MESSAGE
    ) VALUES (
        :v_run_ts,
        :v_load_type,
        :v_source_count,
        :v_dedup_count,
        :v_inserted,
        :v_updated,
        :v_deleted,
        :v_target_count,
        :v_discrepancy,
        :v_status,
        :v_err
    );

    -- =========================================================================
    -- STEP 12: Build and return summary string
    -- =========================================================================
    v_summary := 'Status='        || v_status
              || ' LoadType='     || v_load_type
              || ' Source='       || v_source_count::VARCHAR
              || ' Dedup='        || v_dedup_count::VARCHAR
              || ' Inserted='     || v_inserted::VARCHAR
              || ' Updated='      || v_updated::VARCHAR
              || ' Deleted='      || v_deleted::VARCHAR
              || ' Target='       || v_target_count::VARCHAR
              || ' Discrepancy='  || v_discrepancy::VARCHAR;

    RETURN v_summary;

EXCEPTION
    WHEN OTHER THEN
        LET err VARCHAR := SQLERRM;
        v_status := 'FAILED';
        INSERT INTO SDLC_DB.SDLC_PIPELINES.PIPELINE_RUN_LOG (
            RUN_TS,
            LOAD_TYPE,
            SOURCE_COUNT,
            DEDUP_COUNT,
            INSERTED,
            UPDATED,
            DELETED,
            TARGET_COUNT,
            DISCREPANCY,
            STATUS,
            ERROR_MESSAGE
        ) VALUES (
            :v_run_ts,
            :v_load_type,
            :v_source_count,
            :v_dedup_count,
            :v_inserted,
            :v_updated,
            :v_deleted,
            :v_target_count,
            :v_discrepancy,
            :v_status,
            :err
        );
        RETURN 'FAILED: ' || :err;
END;
$$;
