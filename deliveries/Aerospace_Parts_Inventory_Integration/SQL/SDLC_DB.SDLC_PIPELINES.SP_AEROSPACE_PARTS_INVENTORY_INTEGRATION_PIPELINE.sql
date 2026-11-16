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
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
--   - SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
-- Business Rules: BR-01, BR-02, BR-03, BR-04, BR-05, BR-06, BR-07, BR-08, BR-09
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
  v_watermark        TIMESTAMP_NTZ DEFAULT NULL;
  v_run_ts           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
  v_load_type        VARCHAR(20)   DEFAULT 'INCREMENTAL';
  v_extracted        NUMBER(38,0)  DEFAULT 0;
  v_inserted         NUMBER(38,0)  DEFAULT 0;
  v_updated          NUMBER(38,0)  DEFAULT 0;
  v_soft_deleted     NUMBER(38,0)  DEFAULT 0;
  v_rejected         NUMBER(38,0)  DEFAULT 0;
  v_deduped          NUMBER(38,0)  DEFAULT 0;
  v_source_count     NUMBER(38,0)  DEFAULT 0;
  v_target_count     NUMBER(38,0)  DEFAULT 0;
  v_discrepancy      NUMBER(38,0)  DEFAULT 0;
  v_summary          VARCHAR;
  v_err              VARCHAR;
  v_ins              NUMBER(38,0)  DEFAULT 0;
  v_upd              NUMBER(38,0)  DEFAULT 0;
BEGIN

  -- ----------------------------------------------------------------
  -- STEP 1: Read watermark from PIPELINE_WATERMARK_PARAM (FR-01, BR-01, BR-02)
  -- Returns NULL when no prior run exists -> triggers full load
  -- ----------------------------------------------------------------
  SELECT WATERMARK_TS
    INTO :v_watermark
    FROM SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM
   WHERE PIPELINE_NAME = 'SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE'
   LIMIT 1;

  -- Determine load type for logging
  IF (:v_watermark IS NULL) THEN
    v_load_type := 'FULL';  -- BR-02: first run, no prior watermark
  ELSE
    v_load_type := 'INCREMENTAL';  -- BR-01: subsequent runs use watermark
  END IF;

  -- ----------------------------------------------------------------
  -- STEP 2: Count raw source records for this extract window (FR-01)
  -- BR-01: filter UPDATED_AT > watermark; BR-02: no filter on full load
  -- ----------------------------------------------------------------
  SELECT COUNT(*)
    INTO :v_source_count
    FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE
   WHERE (:v_watermark IS NULL OR UPDATED_AT > :v_watermark);

  v_extracted := v_source_count;

  -- ----------------------------------------------------------------
  -- STEP 3: Count deduplicated records from the reused view (FR-02, BR-03)
  -- VW_AEROSPACE_PARTS_DEDUPLICATED already applies ROW_NUMBER dedup
  -- We further filter by the watermark window here
  -- ----------------------------------------------------------------
  SELECT COUNT(*)
    INTO :v_deduped
    FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
   WHERE (:v_watermark IS NULL OR UPDATED_AT > :v_watermark);

  -- Rejected = raw extracted minus deduplicated (duplicate rows discarded)
  v_rejected := v_extracted - v_deduped;

  -- ----------------------------------------------------------------
  -- STEP 4: SCD Type 1 MERGE into AEROSPACE_PARTS_TARGET (FR-03, BR-04)
  -- Key: PART_NUMBER
  -- Transformations applied inline:
  --   FR-05 / BR-06: INITCAP(LOWER(MANUFACTURER)) -> CamelCase
  --   FR-06 / BR-07: CASE WHEN WEIGHT_KG <= 0 THEN NULL ELSE WEIGHT_KG END
  --   FR-07 / BR-08: CASE risk score derivation
  -- Source: VW_AEROSPACE_PARTS_DEDUPLICATED filtered by watermark
  -- ----------------------------------------------------------------
  MERGE INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET AS tgt
  USING (
    SELECT
      src.PART_NUMBER,
      src.PART_NAME,
      -- FR-05 / BR-06: CamelCase transformation inlined (no UDF)
      INITCAP(LOWER(src.MANUFACTURER))                                          AS MANUFACTURER,
      -- FR-06 / BR-07: replace WEIGHT_KG <= 0 with NULL
      CASE WHEN src.WEIGHT_KG <= 0 THEN NULL ELSE src.WEIGHT_KG END             AS WEIGHT_KG,
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
      -- FR-07 / BR-08: RISK_SCORE derivation inlined
      CASE
        WHEN UPPER(src.CERTIFICATION_STATUS) = 'PENDING'
             AND src.LEAD_TIME_DAYS > 90
          THEN 'High Risk'       -- BR-08 rule 1: pending AND lead time > 90
        WHEN UPPER(src.CERTIFICATION_STATUS) = 'PENDING'
             OR  src.LEAD_TIME_DAYS > 120
          THEN 'Medium Risk'     -- BR-08 rule 2: pending OR lead time > 120
        WHEN UPPER(src.CERTIFICATION_STATUS) IN ('FAA','EASA','DUAL')
             AND src.LEAD_TIME_DAYS <= 90
          THEN 'Low Risk'        -- BR-08 rule 3: approved cert AND short lead time
        ELSE 'Medium Risk'       -- BR-08 rule 4: all other cases
      END                                                                        AS RISK_SCORE
    FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED AS src
    -- BR-01: incremental filter; BR-02: NULL watermark = full load (no filter)
    WHERE (:v_watermark IS NULL OR src.UPDATED_AT > :v_watermark)
  ) AS src
  ON tgt.PART_NUMBER = src.PART_NUMBER
  -- BR-04: SCD1 - overwrite all non-key columns on match
  WHEN MATCHED THEN UPDATE SET
      tgt.PART_NAME             = src.PART_NAME,
      tgt.MANUFACTURER          = src.MANUFACTURER,
      tgt.WEIGHT_KG             = src.WEIGHT_KG,
      tgt.UNIT_PRICE_USD        = src.UNIT_PRICE_USD,
      tgt.CERTIFICATION_STATUS  = src.CERTIFICATION_STATUS,
      tgt.LEAD_TIME_DAYS        = src.LEAD_TIME_DAYS,
      tgt.LIFECYCLE_STATUS      = src.LIFECYCLE_STATUS,
      tgt.INSTALLATION_DATE     = src.INSTALLATION_DATE,
      tgt.QUANTITY_ON_HAND      = src.QUANTITY_ON_HAND,
      tgt.WAREHOUSE_LOCATION    = src.WAREHOUSE_LOCATION,
      tgt.SUPPLIER_CODE         = src.SUPPLIER_CODE,
      tgt.COUNTRY_OF_ORIGIN     = src.COUNTRY_OF_ORIGIN,
      tgt.UPDATED_AT            = src.UPDATED_AT,
      tgt.CATEGORY              = src.CATEGORY,
      tgt.SUPPLIER_ID           = src.SUPPLIER_ID,
      tgt.PART_STATUS           = src.PART_STATUS,
      tgt.INVENTORY_HEALTH_STATUS = src.INVENTORY_HEALTH_STATUS,
      tgt.STOCK_QUANTITY        = src.STOCK_QUANTITY,
      tgt.SUPPLY_RISK_LEVEL     = src.SUPPLY_RISK_LEVEL,
      tgt.SUPPLIER_COUNT        = src.SUPPLIER_COUNT,
      tgt.RISK_SCORE            = src.RISK_SCORE,
      tgt.DW_UPDATE_TS          = :v_run_ts
  -- BR-04: insert new parts not yet in target
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
      :v_run_ts, :v_run_ts
  );

  -- Capture MERGE row counts from RESULT_SCAN (inserted + updated)
  SELECT
    "number of rows inserted",
    "number of rows updated"
  INTO :v_ins, :v_upd
  FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

  v_inserted := v_ins;
  v_updated  := v_upd;

  -- ----------------------------------------------------------------
  -- STEP 5: Soft delete (FR-04, BR-05)
  -- Parts in target but absent from the FULL current source extract
  -- are marked Decommissioned in LIFECYCLE_STATUS regardless of watermark window
  -- ----------------------------------------------------------------
  UPDATE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET AS tgt
     SET tgt.LIFECYCLE_STATUS = 'Decommissioned',  -- BR-05: soft-delete flag on LIFECYCLE_STATUS
         tgt.PART_STATUS      = 'Decommissioned',  -- keep PART_STATUS consistent
         tgt.DW_UPDATE_TS     = :v_run_ts
   WHERE tgt.LIFECYCLE_STATUS <> 'Decommissioned'
     AND tgt.PART_NUMBER NOT IN (
           -- Use full source (no watermark filter) to detect truly absent parts
           SELECT PART_NUMBER
             FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE
         );

  v_soft_deleted := SQLROWCOUNT;

  -- ----------------------------------------------------------------
  -- STEP 6: Compute target count and discrepancy for reconciliation
  -- Active (non-decommissioned) rows in target after soft-delete
  -- ----------------------------------------------------------------
  SELECT COUNT(*)
    INTO :v_target_count
    FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
   WHERE LIFECYCLE_STATUS <> 'Decommissioned';

  v_discrepancy := ABS(v_deduped - (v_inserted + v_updated));

  -- ----------------------------------------------------------------
  -- STEP 7: Update watermark to current run timestamp (FR-01, BR-01)
  -- Upsert pattern: merge on pipeline name
  -- ----------------------------------------------------------------
  MERGE INTO SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM AS wm
  USING (
    SELECT
      'SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE' AS PIPELINE_NAME,
      :v_run_ts                                            AS NEW_WATERMARK_TS,
      :v_run_ts                                            AS NEW_UPDATED_AT
  ) AS src
  ON wm.PIPELINE_NAME = src.PIPELINE_NAME
  WHEN MATCHED THEN UPDATE SET
      wm.WATERMARK_TS = src.NEW_WATERMARK_TS,
      wm.UPDATED_AT   = src.NEW_UPDATED_AT
  WHEN NOT MATCHED THEN INSERT (
      PIPELINE_NAME,
      WATERMARK_TS,
      UPDATED_AT
  ) VALUES (
      src.PIPELINE_NAME,
      src.NEW_WATERMARK_TS,
      src.NEW_UPDATED_AT
  );

  -- ----------------------------------------------------------------
  -- STEP 8: Log reconciliation metrics (FR-08, BR-09)
  -- Insert one row per pipeline run into ETL_RECONCILIATION_LOG
  -- ----------------------------------------------------------------
  INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
      PIPELINE_NAME,
      LOAD_TYPE,
      RUN_TS,
      SOURCE_COUNT,
      DEDUPLICATED_COUNT,
      INSERTED_COUNT,
      UPDATED_COUNT,
      DELETED_COUNT,
      EXCLUDED_COUNT,
      TARGET_COUNT,
      DISCREPANCY_COUNT,
      PIPELINE_STATUS,
      WATERMARK_USED,
      JIRA_ISSUE,
      ERROR_MESSAGE
  ) VALUES (
      'SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE',  -- PIPELINE_NAME
      :v_load_type,                                          -- LOAD_TYPE
      :v_run_ts,                                             -- RUN_TS
      :v_source_count,                                       -- SOURCE_COUNT  (= RECORDS_EXTRACTED)
      :v_deduped,                                            -- DEDUPLICATED_COUNT
      :v_inserted,                                           -- INSERTED_COUNT (= RECORDS_INSERTED)
      :v_updated,                                            -- UPDATED_COUNT  (= RECORDS_UPDATED)
      :v_soft_deleted,                                       -- DELETED_COUNT  (= RECORDS_SOFT_DELETED)
      :v_rejected,                                           -- EXCLUDED_COUNT (= RECORDS_REJECTED)
      :v_target_count,                                       -- TARGET_COUNT
      :v_discrepancy,                                        -- DISCREPANCY_COUNT
      'SUCCESS',                                             -- PIPELINE_STATUS
      :v_watermark,                                          -- WATERMARK_USED
      NULL,                                                  -- JIRA_ISSUE
      NULL                                                   -- ERROR_MESSAGE
  );

  -- ----------------------------------------------------------------
  -- STEP 9: Build and return summary string
  -- ----------------------------------------------------------------
  v_summary :=
      'PIPELINE: SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE | '
   || 'LOAD_TYPE: '       || :v_load_type      || ' | '
   || 'EXTRACTED: '       || :v_extracted      || ' | '
   || 'DEDUPLICATED: '    || :v_deduped        || ' | '
   || 'INSERTED: '        || :v_inserted       || ' | '
   || 'UPDATED: '         || :v_updated        || ' | '
   || 'SOFT_DELETED: '    || :v_soft_deleted   || ' | '
   || 'REJECTED: '        || :v_rejected       || ' | '
   || 'DISCREPANCY: '     || :v_discrepancy    || ' | '
   || 'STATUS: SUCCESS';

  RETURN :v_summary;

EXCEPTION
  WHEN OTHER THEN
    -- Capture error details before any DML inside the handler
    LET err VARCHAR := SQLERRM;
    -- Log failure row to reconciliation log for observability (FR-08, BR-09)
    INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
        PIPELINE_NAME,
        LOAD_TYPE,
        RUN_TS,
        SOURCE_COUNT,
        DEDUPLICATED_COUNT,
        INSERTED_COUNT,
        UPDATED_COUNT,
        DELETED_COUNT,
        EXCLUDED_COUNT,
        TARGET_COUNT,
        DISCREPANCY_COUNT,
        PIPELINE_STATUS,
        WATERMARK_USED,
        JIRA_ISSUE,
        ERROR_MESSAGE
    ) VALUES (
        'SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE',
        :v_load_type,
        :v_run_ts,
        :v_source_count,
        :v_deduped,
        :v_inserted,
        :v_updated,
        :v_soft_deleted,
        :v_rejected,
        :v_target_count,
        :v_discrepancy,
        'FAILED',
        :v_watermark,
        NULL,
        :err
    );
    RETURN 'FAILED: ' || :err;
END;
$$;
