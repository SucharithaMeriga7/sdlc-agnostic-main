-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE
-- Object Type   : PROCEDURE
-- Jira Story    : SCRUM-159
-- Requirements  : FR-01, FR-02, FR-03, FR-04, FR-05, FR-06, FR-07, FR-08, FR-09
-- Reuse Route   : PIPELINE
-- Description   : Pipeline orchestration for Aerospace_Parts_Inventory_Integration
-- Author        : Sucharitha
-- Created Date  : 2026-10-28
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
--   - SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
--   - SDLC_DB.SDLC_PIPELINES.ETL_CONTROL
--   - SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
-- Business Rules: BR-01, BR-02, BR-03, BR-04, BR-05, BR-06, BR-07, BR-08, BR-09, BR-10, BR-11, BR-12
-- Change History:
--   2026-10-28  Sucharitha  SCRUM-159  Initial generation (PIPELINE)
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
  v_load_type         VARCHAR  DEFAULT 'INCREMENTAL';
  v_watermark         TIMESTAMP_NTZ DEFAULT NULL;
  v_source_count      NUMBER(18,0) DEFAULT 0;
  v_dedup_count       NUMBER(18,0) DEFAULT 0;
  v_inserted          NUMBER(18,0) DEFAULT 0;
  v_updated           NUMBER(18,0) DEFAULT 0;
  v_deleted           NUMBER(18,0) DEFAULT 0;
  v_target_count      NUMBER(18,0) DEFAULT 0;
  v_discrepancy       NUMBER(18,0) DEFAULT 0;
  v_status            VARCHAR  DEFAULT 'SUCCESS';
  v_err_msg           VARCHAR  DEFAULT NULL;
  v_summary           VARCHAR  DEFAULT '';
  v_ins               NUMBER(18,0) DEFAULT 0;
  v_upd               NUMBER(18,0) DEFAULT 0;
BEGIN

  -- STEP 1: Resolve watermark from ETL_CONTROL (FR-01 / BR-01 / BR-02)
  SELECT COALESCE(MAX(LAST_RUN_TS), NULL)
    INTO :v_watermark
    FROM SDLC_DB.SDLC_PIPELINES.ETL_CONTROL
   WHERE PIPELINE_NAME = :v_pipeline_name;

  IF (v_watermark IS NULL) THEN
    v_load_type := 'FULL';
  ELSE
    v_load_type := 'INCREMENTAL';
  END IF;

  -- STEP 2: Count raw source records for reconciliation (BR-12)
  IF (v_load_type = 'FULL') THEN
    SELECT COUNT(*)
      INTO :v_source_count
      FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE;
  ELSE
    SELECT COUNT(*)
      INTO :v_source_count
      FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE
     WHERE UPDATED_AT > :v_watermark;
  END IF;

  -- STEP 3: Deduplicate count (FR-02 / BR-03)
  IF (v_load_type = 'FULL') THEN
    SELECT COUNT(DISTINCT PART_NUMBER)
      INTO :v_dedup_count
      FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE;
  ELSE
    SELECT COUNT(DISTINCT PART_NUMBER)
      INTO :v_dedup_count
      FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE
     WHERE UPDATED_AT > :v_watermark;
  END IF;

  -- STEP 4: SCD Type 1 MERGE into AEROSPACE_PARTS_TARGET (FR-03 / BR-04)
  -- BR-08: Pending AND lead_time > 60 => High Risk (no exclusion for lead_time=100)
  MERGE INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET AS t
  USING (
    WITH ranked AS (
      SELECT
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
        ROW_NUMBER() OVER (
          PARTITION BY PART_NUMBER
          ORDER BY UPDATED_AT DESC
        ) AS rn
      FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE
      WHERE (:v_load_type = 'FULL' OR UPDATED_AT > :v_watermark)
    )
    SELECT
      r.PART_NUMBER,
      r.PART_NAME,
      -- BR-06: uppercase manufacturer
      UPPER(r.MANUFACTURER)                          AS MANUFACTURER,
      -- BR-07: replace non-positive weight with -1
      IFF(r.WEIGHT_KG <= 0, -1, r.WEIGHT_KG)        AS WEIGHT_KG,
      r.UNIT_PRICE_USD,
      r.CERTIFICATION_STATUS,
      r.LEAD_TIME_DAYS,
      r.LIFECYCLE_STATUS,
      r.INSTALLATION_DATE,
      r.QUANTITY_ON_HAND,
      r.WAREHOUSE_LOCATION,
      r.SUPPLIER_CODE,
      r.COUNTRY_OF_ORIGIN,
      -- BR-08/BR-09/BR-10/BR-11: derive RISK_SCORE
      CASE
        -- BR-08: Pending AND lead_time > 60 => High Risk
        WHEN r.CERTIFICATION_STATUS = 'Pending'
             AND r.LEAD_TIME_DAYS > 60
          THEN 'High Risk'
        -- BR-09: Pending (lead_time <= 60) OR lead_time > 100 => Medium Risk
        WHEN r.CERTIFICATION_STATUS = 'Pending'
             OR r.LEAD_TIME_DAYS > 100
          THEN 'Medium Risk'
        -- BR-10: FAA/EASA/Dual AND lead_time <= 60 => Low Risk
        WHEN r.CERTIFICATION_STATUS IN ('FAA', 'EASA', 'Dual')
             AND r.LEAD_TIME_DAYS <= 60
          THEN 'Low Risk'
        -- BR-11: all remaining => Medium Risk
        ELSE 'Medium Risk'
      END                                            AS RISK_SCORE,
      r.UPDATED_AT,
      r.CATEGORY,
      r.SUPPLIER_ID,
      r.PART_STATUS,
      r.INVENTORY_HEALTH_STATUS,
      r.STOCK_QUANTITY,
      r.SUPPLY_RISK_LEVEL,
      r.SUPPLIER_COUNT
    FROM ranked r
    WHERE r.rn = 1
  ) AS src
  ON t.PART_NUMBER = src.PART_NUMBER
  WHEN MATCHED THEN
    UPDATE SET
      t.PART_NAME               = src.PART_NAME,
      t.MANUFACTURER            = src.MANUFACTURER,
      t.WEIGHT_KG               = src.WEIGHT_KG,
      t.UNIT_PRICE_USD          = src.UNIT_PRICE_USD,
      t.CERTIFICATION_STATUS    = src.CERTIFICATION_STATUS,
      t.LEAD_TIME_DAYS          = src.LEAD_TIME_DAYS,
      t.LIFECYCLE_STATUS        = src.LIFECYCLE_STATUS,
      t.INSTALLATION_DATE       = src.INSTALLATION_DATE,
      t.QUANTITY_ON_HAND        = src.QUANTITY_ON_HAND,
      t.WAREHOUSE_LOCATION      = src.WAREHOUSE_LOCATION,
      t.SUPPLIER_CODE           = src.SUPPLIER_CODE,
      t.COUNTRY_OF_ORIGIN       = src.COUNTRY_OF_ORIGIN,
      t.RISK_SCORE              = src.RISK_SCORE,
      t.UPDATED_AT              = src.UPDATED_AT,
      t.CATEGORY                = src.CATEGORY,
      t.SUPPLIER_ID             = src.SUPPLIER_ID,
      t.PART_STATUS             = src.PART_STATUS,
      t.INVENTORY_HEALTH_STATUS = src.INVENTORY_HEALTH_STATUS,
      t.STOCK_QUANTITY          = src.STOCK_QUANTITY,
      t.SUPPLY_RISK_LEVEL       = src.SUPPLY_RISK_LEVEL,
      t.SUPPLIER_COUNT          = src.SUPPLIER_COUNT,
      t.DW_UPDATE_TS            = :v_run_ts
  WHEN NOT MATCHED THEN
    INSERT (
      PART_NUMBER, PART_NAME, MANUFACTURER, WEIGHT_KG, UNIT_PRICE_USD,
      CERTIFICATION_STATUS, LEAD_TIME_DAYS, LIFECYCLE_STATUS, INSTALLATION_DATE,
      QUANTITY_ON_HAND, WAREHOUSE_LOCATION, SUPPLIER_CODE, COUNTRY_OF_ORIGIN,
      RISK_SCORE, UPDATED_AT,
      CATEGORY, SUPPLIER_ID, PART_STATUS,
      INVENTORY_HEALTH_STATUS, STOCK_QUANTITY, SUPPLY_RISK_LEVEL, SUPPLIER_COUNT,
      DW_INSERT_TS, DW_UPDATE_TS
    )
    VALUES (
      src.PART_NUMBER, src.PART_NAME, src.MANUFACTURER, src.WEIGHT_KG, src.UNIT_PRICE_USD,
      src.CERTIFICATION_STATUS, src.LEAD_TIME_DAYS, src.LIFECYCLE_STATUS, src.INSTALLATION_DATE,
      src.QUANTITY_ON_HAND, src.WAREHOUSE_LOCATION, src.SUPPLIER_CODE, src.COUNTRY_OF_ORIGIN,
      src.RISK_SCORE, src.UPDATED_AT,
      src.CATEGORY, src.SUPPLIER_ID, src.PART_STATUS,
      src.INVENTORY_HEALTH_STATUS, src.STOCK_QUANTITY, src.SUPPLY_RISK_LEVEL, src.SUPPLIER_COUNT,
      :v_run_ts, :v_run_ts
    );

  -- Capture MERGE row counts
  SELECT
    "number of rows inserted",
    "number of rows updated"
  INTO :v_ins, :v_upd
  FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

  v_inserted := v_ins;
  v_updated  := v_upd;

  -- STEP 5: Soft-delete decommissioned records (FR-04 / BR-05)
  UPDATE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET AS t
     SET t.LIFECYCLE_STATUS  = 'Decommissioned',
         t.DW_UPDATE_TS      = :v_run_ts
   WHERE t.LIFECYCLE_STATUS != 'Decommissioned'
     AND t.PART_NUMBER NOT IN (
           SELECT DISTINCT PART_NUMBER
             FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE
         );

  v_deleted := SQLROWCOUNT;

  -- STEP 6: Count active target records post-load (BR-12)
  SELECT COUNT(*)
    INTO :v_target_count
    FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
   WHERE LIFECYCLE_STATUS != 'Decommissioned';

  -- STEP 7: Update ETL_CONTROL watermark (FR-01)
  MERGE INTO SDLC_DB.SDLC_PIPELINES.ETL_CONTROL AS c
  USING (SELECT :v_pipeline_name AS PIPELINE_NAME, :v_run_ts AS RUN_TS) AS src
    ON c.PIPELINE_NAME = src.PIPELINE_NAME
  WHEN MATCHED THEN
    UPDATE SET c.LAST_RUN_TS = src.RUN_TS
  WHEN NOT MATCHED THEN
    INSERT (PIPELINE_NAME, LAST_RUN_TS)
    VALUES (src.PIPELINE_NAME, src.RUN_TS);

  -- STEP 8: Reconciliation logging (FR-08 / BR-12)
  v_discrepancy := ABS(v_dedup_count - (v_inserted + v_updated));

  INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
    PIPELINE_NAME, RUN_TS, LOAD_TYPE, WATERMARK_USED,
    SOURCE_COUNT, EXCLUDED_COUNT, DEDUPLICATED_COUNT,
    INSERTED_COUNT, UPDATED_COUNT, DELETED_COUNT,
    TARGET_COUNT, PIPELINE_STATUS, ERROR_MESSAGE, DISCREPANCY_COUNT
  )
  VALUES (
    :v_pipeline_name, :v_run_ts, :v_load_type, :v_watermark,
    :v_source_count, 0, :v_dedup_count,
    :v_inserted, :v_updated, :v_deleted,
    :v_target_count, :v_status, :v_err_msg, :v_discrepancy
  );

  -- STEP 9: Return summary
  v_summary := 'SUCCESS | load_type=' || v_load_type
    || ' | source='       || v_source_count
    || ' | dedup='        || v_dedup_count
    || ' | inserted='     || v_inserted
    || ' | updated='      || v_updated
    || ' | soft_deleted=' || v_deleted
    || ' | target_active='|| v_target_count
    || ' | discrepancy='  || v_discrepancy
    || ' | run_ts='       || v_run_ts;

  RETURN :v_summary;

EXCEPTION
  WHEN OTHER THEN
    LET err      VARCHAR := SQLERRM;
    LET err_code VARCHAR := SQLCODE;

    INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
      PIPELINE_NAME, RUN_TS, LOAD_TYPE, WATERMARK_USED,
      SOURCE_COUNT, EXCLUDED_COUNT, DEDUPLICATED_COUNT,
      INSERTED_COUNT, UPDATED_COUNT, DELETED_COUNT,
      TARGET_COUNT, PIPELINE_STATUS, ERROR_MESSAGE, DISCREPANCY_COUNT
    )
    VALUES (
      :v_pipeline_name, :v_run_ts, :v_load_type, :v_watermark,
      :v_source_count, 0, :v_dedup_count,
      :v_inserted, :v_updated, :v_deleted,
      :v_target_count, 'FAILED', :err, 0
    );

    RETURN 'FAILED: [' || :err_code || '] ' || :err;
END;
$$
