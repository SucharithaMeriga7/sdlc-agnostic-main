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
--   - SDLC_DB.SDLC_PIPELINES.PARTS
--   - SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
--   - SDLC_DB.SDLC_PIPELINES.ETL_CONTROL
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
    v_pipeline_name     VARCHAR  DEFAULT 'AEROSPACE_PARTS_INVENTORY_INTEGRATION';
    v_run_ts            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    v_load_type         VARCHAR  DEFAULT 'INCREMENTAL';
    v_watermark         TIMESTAMP_NTZ DEFAULT NULL;
    v_new_watermark     TIMESTAMP_NTZ DEFAULT NULL;
    v_source_count      NUMBER(18,0) DEFAULT 0;
    v_excluded_count    NUMBER(18,0) DEFAULT 0;
    v_dedup_count       NUMBER(18,0) DEFAULT 0;
    v_ins               NUMBER(18,0) DEFAULT 0;
    v_upd               NUMBER(18,0) DEFAULT 0;
    v_del               NUMBER(18,0) DEFAULT 0;
    v_target_count      NUMBER(18,0) DEFAULT 0;
    v_discrepancy       NUMBER(18,0) DEFAULT 0;
    v_summary           VARCHAR  DEFAULT '';
    v_err               VARCHAR  DEFAULT NULL;

BEGIN
    -- =========================================================================
    -- STEP 1: Read last successful watermark from ETL_CONTROL (FR-01, BR-01, BR-02)
    -- =========================================================================
    SELECT COALESCE(MAX(LAST_SUCCESSFUL_RUN_TS), NULL)
    INTO   :v_watermark
    FROM   SDLC_DB.SDLC_PIPELINES.ETL_CONTROL
    WHERE  PIPELINE_NAME = :v_pipeline_name;

    IF (:v_watermark IS NULL) THEN
        v_load_type := 'FULL';
    ELSE
        v_load_type := 'INCREMENTAL';
    END IF;

    -- =========================================================================
    -- STEP 2: Count raw source records for reconciliation (BR-12)
    -- =========================================================================
    SELECT COUNT(*)
    INTO   :v_source_count
    FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE
    WHERE  (:v_load_type = 'FULL' OR UPDATED_AT > :v_watermark);

    v_excluded_count := 0;

    -- =========================================================================
    -- STEP 3: Count deduplicated records (FR-02, BR-03)
    -- Inline ROW_NUMBER() dedup directly on AEROSPACE_PARTS_SOURCE;
    -- replaces the view reference which returned 0 rows.
    -- =========================================================================
    SELECT COUNT(*)
    INTO   :v_dedup_count
    FROM (
        SELECT PART_NUMBER,
               ROW_NUMBER() OVER (PARTITION BY PART_NUMBER ORDER BY UPDATED_AT DESC) AS RN
        FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE
        WHERE  (:v_load_type = 'FULL' OR UPDATED_AT > :v_watermark)
    )
    WHERE RN = 1;

    -- =========================================================================
    -- STEP 4: Capture new watermark before MERGE
    -- =========================================================================
    SELECT MAX(UPDATED_AT)
    INTO   :v_new_watermark
    FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE
    WHERE  (:v_load_type = 'FULL' OR UPDATED_AT > :v_watermark);

    -- =========================================================================
    -- STEP 5: MERGE into PARTS - SCD Type 1 (FR-03, BR-04)
    --   FR-05/BR-06: UPPER(MANUFACTURER)
    --   FR-06/BR-07: IFF(WEIGHT_KG<=0,-1,WEIGHT_KG)
    --   FR-07/BR-08/09/10/11: CASE RISK_SCORE
    -- Inline ROW_NUMBER() dedup replaces view to guarantee rows are visible.
    -- =========================================================================
    MERGE INTO SDLC_DB.SDLC_PIPELINES.PARTS AS TGT
    USING (
        SELECT
            PART_NUMBER,
            PART_NAME,
            UPPER(MANUFACTURER)                                              AS MANUFACTURER,
            IFF(WEIGHT_KG <= 0, -1, WEIGHT_KG)                              AS WEIGHT_KG,
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
            CASE
                WHEN CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60
                    THEN 'High Risk'
                WHEN (CERTIFICATION_STATUS = 'Pending' OR LEAD_TIME_DAYS > 100)
                    THEN 'Medium Risk'
                WHEN CERTIFICATION_STATUS IN ('FAA', 'EASA', 'Dual') AND LEAD_TIME_DAYS <= 60
                    THEN 'Low Risk'
                ELSE 'Medium Risk'
            END AS RISK_SCORE
        FROM (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY PART_NUMBER ORDER BY UPDATED_AT DESC) AS _RN
            FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE
            WHERE  (:v_load_type = 'FULL' OR UPDATED_AT > :v_watermark)
        )
        WHERE _RN = 1
    ) AS SRC
    ON TGT.PART_NUMBER = SRC.PART_NUMBER
    WHEN MATCHED THEN UPDATE SET
        TGT.PART_NAME               = SRC.PART_NAME,
        TGT.MANUFACTURER            = SRC.MANUFACTURER,
        TGT.WEIGHT_KG               = SRC.WEIGHT_KG,
        TGT.UNIT_PRICE_USD          = SRC.UNIT_PRICE_USD,
        TGT.CERTIFICATION_STATUS    = SRC.CERTIFICATION_STATUS,
        TGT.LEAD_TIME_DAYS          = SRC.LEAD_TIME_DAYS,
        TGT.LIFECYCLE_STATUS        = SRC.LIFECYCLE_STATUS,
        TGT.INSTALLATION_DATE       = SRC.INSTALLATION_DATE,
        TGT.QUANTITY_ON_HAND        = SRC.QUANTITY_ON_HAND,
        TGT.WAREHOUSE_LOCATION      = SRC.WAREHOUSE_LOCATION,
        TGT.SUPPLIER_CODE           = SRC.SUPPLIER_CODE,
        TGT.COUNTRY_OF_ORIGIN       = SRC.COUNTRY_OF_ORIGIN,
        TGT.UPDATED_AT              = SRC.UPDATED_AT,
        TGT.CATEGORY                = SRC.CATEGORY,
        TGT.SUPPLIER_ID             = SRC.SUPPLIER_ID,
        TGT.PART_STATUS             = SRC.PART_STATUS,
        TGT.INVENTORY_HEALTH_STATUS = SRC.INVENTORY_HEALTH_STATUS,
        TGT.STOCK_QUANTITY          = SRC.STOCK_QUANTITY,
        TGT.SUPPLY_RISK_LEVEL       = SRC.SUPPLY_RISK_LEVEL,
        TGT.SUPPLIER_COUNT          = SRC.SUPPLIER_COUNT,
        TGT.RISK_SCORE              = SRC.RISK_SCORE,
        TGT.DW_UPDATE_TS            = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (
        PART_NUMBER, PART_NAME, MANUFACTURER, WEIGHT_KG, UNIT_PRICE_USD,
        CERTIFICATION_STATUS, LEAD_TIME_DAYS, LIFECYCLE_STATUS, INSTALLATION_DATE,
        QUANTITY_ON_HAND, WAREHOUSE_LOCATION, SUPPLIER_CODE, COUNTRY_OF_ORIGIN,
        UPDATED_AT, CATEGORY, SUPPLIER_ID, PART_STATUS, INVENTORY_HEALTH_STATUS,
        STOCK_QUANTITY, SUPPLY_RISK_LEVEL, SUPPLIER_COUNT, RISK_SCORE,
        DW_INSERT_TS, DW_UPDATE_TS
    ) VALUES (
        SRC.PART_NUMBER, SRC.PART_NAME, SRC.MANUFACTURER, SRC.WEIGHT_KG, SRC.UNIT_PRICE_USD,
        SRC.CERTIFICATION_STATUS, SRC.LEAD_TIME_DAYS, SRC.LIFECYCLE_STATUS, SRC.INSTALLATION_DATE,
        SRC.QUANTITY_ON_HAND, SRC.WAREHOUSE_LOCATION, SRC.SUPPLIER_CODE, SRC.COUNTRY_OF_ORIGIN,
        SRC.UPDATED_AT, SRC.CATEGORY, SRC.SUPPLIER_ID, SRC.PART_STATUS, SRC.INVENTORY_HEALTH_STATUS,
        SRC.STOCK_QUANTITY, SRC.SUPPLY_RISK_LEVEL, SRC.SUPPLIER_COUNT, SRC.RISK_SCORE,
        CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
    );

    -- Read MERGE result counts (only INSERT and UPDATE clauses present)
    SELECT "number of rows inserted", "number of rows updated"
    INTO   :v_ins, :v_upd
    FROM   TABLE(RESULT_SCAN(LAST_QUERY_ID()));

    -- =========================================================================
    -- STEP 6: Soft-delete - mark Decommissioned for records absent from
    --         current source extract (FR-04, BR-05)
    -- =========================================================================
    UPDATE SDLC_DB.SDLC_PIPELINES.PARTS AS TGT
    SET
        TGT.LIFECYCLE_STATUS = 'Decommissioned',
        TGT.DW_UPDATE_TS     = CURRENT_TIMESTAMP()
    WHERE TGT.LIFECYCLE_STATUS <> 'Decommissioned'
      AND TGT.PART_NUMBER NOT IN (
            SELECT PART_NUMBER
            FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE
      );

    v_del := SQLROWCOUNT;

    -- =========================================================================
    -- STEP 7: Count active target records after load (BR-12)
    -- =========================================================================
    SELECT COUNT(*)
    INTO   :v_target_count
    FROM   SDLC_DB.SDLC_PIPELINES.PARTS
    WHERE  LIFECYCLE_STATUS <> 'Decommissioned';

    -- =========================================================================
    -- STEP 8: Calculate discrepancy (BR-12)
    -- =========================================================================
    v_discrepancy := ABS(:v_dedup_count - (:v_ins + :v_upd));

    -- =========================================================================
    -- STEP 9: Update ETL_CONTROL watermark (FR-01)
    -- =========================================================================
    MERGE INTO SDLC_DB.SDLC_PIPELINES.ETL_CONTROL AS CTL
    USING (
        SELECT :v_pipeline_name AS PIPELINE_NAME,
               :v_new_watermark AS LAST_SUCCESSFUL_RUN_TS
    ) AS SRC
    ON CTL.PIPELINE_NAME = SRC.PIPELINE_NAME
    WHEN MATCHED THEN UPDATE SET
        CTL.LAST_SUCCESSFUL_RUN_TS = SRC.LAST_SUCCESSFUL_RUN_TS
    WHEN NOT MATCHED THEN INSERT (
        PIPELINE_NAME,
        LAST_SUCCESSFUL_RUN_TS
    ) VALUES (
        SRC.PIPELINE_NAME,
        SRC.LAST_SUCCESSFUL_RUN_TS
    );

    -- =========================================================================
    -- STEP 10: Log reconciliation results (FR-08, BR-12)
    -- =========================================================================
    INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
        PIPELINE_NAME, RUN_TS, LOAD_TYPE, WATERMARK_USED,
        SOURCE_COUNT, EXCLUDED_COUNT, DEDUPLICATED_COUNT,
        INSERTED_COUNT, UPDATED_COUNT, DELETED_COUNT, TARGET_COUNT,
        PIPELINE_STATUS, ERROR_MESSAGE, JIRA_ISSUE, DISCREPANCY_COUNT
    ) VALUES (
        :v_pipeline_name, :v_run_ts, :v_load_type, :v_watermark,
        :v_source_count, :v_excluded_count, :v_dedup_count,
        :v_ins, :v_upd, :v_del, :v_target_count,
        'SUCCESS', NULL, 'SCRUM-62', :v_discrepancy
    );

    -- =========================================================================
    -- STEP 11: Build and return summary string
    -- =========================================================================
    v_summary :=
        'PIPELINE=' || :v_pipeline_name ||
        ' | LOAD_TYPE='        || :v_load_type ||
        ' | SOURCE='           || :v_source_count ||
        ' | DEDUP='            || :v_dedup_count ||
        ' | INSERTED='         || :v_ins ||
        ' | UPDATED='          || :v_upd ||
        ' | SOFT_DELETED='     || :v_del ||
        ' | TARGET_ACTIVE='    || :v_target_count ||
        ' | DISCREPANCY='      || :v_discrepancy ||
        ' | STATUS=SUCCESS';

    RETURN :v_summary;

EXCEPTION
    WHEN OTHER THEN
        LET err VARCHAR := SQLERRM;
        LET err_code VARCHAR := SQLCODE;

        INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
            PIPELINE_NAME, RUN_TS, LOAD_TYPE, WATERMARK_USED,
            SOURCE_COUNT, EXCLUDED_COUNT, DEDUPLICATED_COUNT,
            INSERTED_COUNT, UPDATED_COUNT, DELETED_COUNT, TARGET_COUNT,
            PIPELINE_STATUS, ERROR_MESSAGE, JIRA_ISSUE, DISCREPANCY_COUNT
        ) VALUES (
            :v_pipeline_name, :v_run_ts, :v_load_type, :v_watermark,
            :v_source_count, :v_excluded_count, :v_dedup_count,
            :v_ins, :v_upd, :v_del, :v_target_count,
            'FAILED', :err, 'SCRUM-62', :v_discrepancy
        );

        RETURN 'FAILED: [' || :err_code || '] ' || :err;
END;
$$;
