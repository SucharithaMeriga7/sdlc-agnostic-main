-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE
-- Object Type   : PROCEDURE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-01, FR-02, FR-03, FR-04, FR-05, FR-06, FR-07, FR-08, FR-09
-- Reuse Route   : PIPELINE
-- Description   : Pipeline orchestration for Aerospace_Parts_Inventory_Integration
-- Author        : Sucharitha
-- Created Date  : 2026-10-22
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.PIPELINE_METADATA
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_DEDUPLICATED
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TRANSFORMED
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_CLEANSED
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_RISK_SCORED
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS
--   - SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
-- Business Rules: BR-01, BR-02, BR-03, BR-04, BR-05, BR-06, BR-07, BR-08, BR-09, BR-10, BR-11, BR-12
-- Change History:
--   2026-10-22  Sucharitha  SCRUM-158  Initial generation (PIPELINE)
-- =============================================================================

CREATE OR REPLACE PROCEDURE SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_pipeline_name     VARCHAR  DEFAULT 'AEROSPACE_PARTS_INVENTORY_INTEGRATION';
    v_last_run_ts       TIMESTAMP_NTZ;
    v_run_ts            TIMESTAMP_NTZ;
    v_is_full_load      BOOLEAN  DEFAULT FALSE;
    v_source_count      NUMBER   DEFAULT 0;
    v_target_count      NUMBER   DEFAULT 0;
    v_inserted          NUMBER   DEFAULT 0;
    v_updated           NUMBER   DEFAULT 0;
    v_soft_deleted      NUMBER   DEFAULT 0;
    v_max_source_ts     TIMESTAMP_NTZ;
    v_summary           VARCHAR  DEFAULT '';
    v_err               VARCHAR  DEFAULT '';
BEGIN
    -- ================================================================
    -- STEP 0: Capture run timestamp
    -- ================================================================
    v_run_ts := CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ;

    -- ================================================================
    -- STEP 1 (FR-01 / BR-01 / BR-02): Retrieve last successful run
    --        timestamp from PIPELINE_METADATA.
    --        NULL => first run => full load.
    -- ================================================================
    SELECT LAST_RUN_TIMESTAMP
    INTO   :v_last_run_ts
    FROM   SDLC_DB.SDLC_PIPELINES.PIPELINE_METADATA
    WHERE  PIPELINE_NAME = :v_pipeline_name;

    IF (v_last_run_ts IS NULL) THEN
        v_is_full_load := TRUE;
    END IF;

    -- ================================================================
    -- STEP 2 (FR-01 / BR-01 / BR-02): Populate staging table.
    --        Full load on first run; incremental on subsequent runs.
    -- ================================================================
    TRUNCATE TABLE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING;

    IF (v_is_full_load) THEN
        -- BR-02: No prior timestamp -> load all source records
        INSERT INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING (
            PART_NUMBER, PART_NAME, MANUFACTURER, CATEGORY,
            WEIGHT_KG, UNIT_PRICE_USD, QUANTITY_ON_HAND, REORDER_LEVEL,
            LIFECYCLE_STATUS, CERTIFICATION_STATUS, INSTALLATION_DATE,
            LEAD_TIME_DAYS, SUPPLIER, WAREHOUSE_LOCATION, COUNTRY_OF_ORIGIN,
            CREATED_AT, UPDATED_AT
        )
        SELECT
            PART_NUMBER, PART_NAME, MANUFACTURER, CATEGORY,
            WEIGHT_KG, UNIT_PRICE_USD, QUANTITY_ON_HAND, REORDER_LEVEL,
            LIFECYCLE_STATUS, CERTIFICATION_STATUS, INSTALLATION_DATE,
            LEAD_TIME_DAYS, SUPPLIER, WAREHOUSE_LOCATION, COUNTRY_OF_ORIGIN,
            CREATED_AT, UPDATED_AT
        FROM IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE;
    ELSE
        -- BR-01: Incremental load - only records updated after last source watermark
        INSERT INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING (
            PART_NUMBER, PART_NAME, MANUFACTURER, CATEGORY,
            WEIGHT_KG, UNIT_PRICE_USD, QUANTITY_ON_HAND, REORDER_LEVEL,
            LIFECYCLE_STATUS, CERTIFICATION_STATUS, INSTALLATION_DATE,
            LEAD_TIME_DAYS, SUPPLIER, WAREHOUSE_LOCATION, COUNTRY_OF_ORIGIN,
            CREATED_AT, UPDATED_AT
        )
        SELECT
            PART_NUMBER, PART_NAME, MANUFACTURER, CATEGORY,
            WEIGHT_KG, UNIT_PRICE_USD, QUANTITY_ON_HAND, REORDER_LEVEL,
            LIFECYCLE_STATUS, CERTIFICATION_STATUS, INSTALLATION_DATE,
            LEAD_TIME_DAYS, SUPPLIER, WAREHOUSE_LOCATION, COUNTRY_OF_ORIGIN,
            CREATED_AT, UPDATED_AT
        FROM IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE
        WHERE UPDATED_AT > :v_last_run_ts; -- BR-01: incremental filter
    END IF;

    -- Capture source extract row count for reconciliation (BR-12)
    v_source_count := SQLROWCOUNT;

    -- ================================================================
    -- STEP 3-6: Deduplication, transformation, cleansing, risk scoring
    --           handled by chained views reading from staging.
    -- ================================================================

    -- ================================================================
    -- STEP 7 (FR-03 / BR-04): SCD Type 1 MERGE into target table.
    -- ================================================================
    MERGE INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS AS TGT
    USING (
        SELECT
            PART_NUMBER,
            PART_NAME,
            MANUFACTURER,
            CATEGORY,
            WEIGHT_KG,
            UNIT_PRICE_USD,
            QUANTITY_ON_HAND,
            REORDER_LEVEL,
            LIFECYCLE_STATUS,
            CERTIFICATION_STATUS,
            INSTALLATION_DATE,
            LEAD_TIME_DAYS,
            SUPPLIER,
            WAREHOUSE_LOCATION,
            COUNTRY_OF_ORIGIN,
            RISK_SCORE,
            UPDATED_AT
        FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_RISK_SCORED
    ) AS SRC
    ON TGT.PART_NUMBER = SRC.PART_NUMBER
    WHEN MATCHED THEN UPDATE SET
        TGT.PART_NAME            = SRC.PART_NAME,
        TGT.MANUFACTURER         = SRC.MANUFACTURER,
        TGT.CATEGORY             = SRC.CATEGORY,
        TGT.WEIGHT_KG            = SRC.WEIGHT_KG,
        TGT.UNIT_PRICE_USD       = SRC.UNIT_PRICE_USD,
        TGT.QUANTITY_ON_HAND     = SRC.QUANTITY_ON_HAND,
        TGT.REORDER_LEVEL        = SRC.REORDER_LEVEL,
        TGT.LIFECYCLE_STATUS     = SRC.LIFECYCLE_STATUS,
        TGT.CERTIFICATION_STATUS = SRC.CERTIFICATION_STATUS,
        TGT.INSTALLATION_DATE    = SRC.INSTALLATION_DATE,
        TGT.LEAD_TIME_DAYS       = SRC.LEAD_TIME_DAYS,
        TGT.SUPPLIER             = SRC.SUPPLIER,
        TGT.WAREHOUSE_LOCATION   = SRC.WAREHOUSE_LOCATION,
        TGT.COUNTRY_OF_ORIGIN    = SRC.COUNTRY_OF_ORIGIN,
        TGT.RISK_SCORE           = SRC.RISK_SCORE,
        TGT.UPDATED_AT           = SRC.UPDATED_AT,
        TGT.LOAD_TIMESTAMP       = :v_run_ts
    WHEN NOT MATCHED THEN INSERT (
        PART_NUMBER, PART_NAME, MANUFACTURER, CATEGORY,
        WEIGHT_KG, UNIT_PRICE_USD, QUANTITY_ON_HAND, REORDER_LEVEL,
        LIFECYCLE_STATUS, CERTIFICATION_STATUS, INSTALLATION_DATE,
        LEAD_TIME_DAYS, SUPPLIER, WAREHOUSE_LOCATION, COUNTRY_OF_ORIGIN,
        RISK_SCORE, UPDATED_AT, LOAD_TIMESTAMP
    ) VALUES (
        SRC.PART_NUMBER, SRC.PART_NAME, SRC.MANUFACTURER, SRC.CATEGORY,
        SRC.WEIGHT_KG, SRC.UNIT_PRICE_USD, SRC.QUANTITY_ON_HAND, SRC.REORDER_LEVEL,
        SRC.LIFECYCLE_STATUS, SRC.CERTIFICATION_STATUS, SRC.INSTALLATION_DATE,
        SRC.LEAD_TIME_DAYS, SRC.SUPPLIER, SRC.WAREHOUSE_LOCATION, SRC.COUNTRY_OF_ORIGIN,
        SRC.RISK_SCORE, SRC.UPDATED_AT, :v_run_ts
    );

    -- Read MERGE result counts (both WHEN clauses present)
    SELECT
        "number of rows inserted",
        "number of rows updated"
    INTO :v_inserted, :v_updated
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

    -- ================================================================
    -- STEP 8 (FR-04 / BR-05): Soft-delete rows present in target but
    --        absent from the FULL current source.
    --        Must use the complete source table (not just staging delta)
    --        so that unchanged rows are not incorrectly decommissioned.
    -- ================================================================
    UPDATE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS AS TGT
    SET
        TGT.LIFECYCLE_STATUS = 'Decommissioned',
        TGT.LOAD_TIMESTAMP   = :v_run_ts
    WHERE TGT.LIFECYCLE_STATUS <> 'Decommissioned'
      AND NOT EXISTS (
          -- Anti-join against the FULL source to find truly absent keys
          SELECT 1
          FROM IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE SRC
          WHERE SRC.PART_NUMBER = TGT.PART_NUMBER
      );

    v_soft_deleted := SQLROWCOUNT;

    -- ================================================================
    -- STEP 9: Capture target total row count after all operations
    -- ================================================================
    SELECT COUNT(*)
    INTO   :v_target_count
    FROM   SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS;

    -- ================================================================
    -- STEP 10: Compute max UPDATED_AT from source as the new watermark.
    --          Storing source-domain max timestamp prevents wall-clock
    --          drift from breaking future incremental filters (BR-01).
    -- ================================================================
    SELECT MAX(UPDATED_AT)
    INTO   :v_max_source_ts
    FROM   IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE;

    -- ================================================================
    -- STEP 11 (FR-08 / BR-12): Write reconciliation log entry.
    -- ================================================================
    INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
        PIPELINE_NAME, RUN_TIMESTAMP, SOURCE_COUNT, TARGET_COUNT,
        INSERTED_COUNT, UPDATED_COUNT, SOFT_DELETED_COUNT, STATUS, NOTES
    ) VALUES (
        :v_pipeline_name,
        :v_run_ts,
        :v_source_count,
        :v_target_count,
        :v_inserted,
        :v_updated,
        :v_soft_deleted,
        'SUCCESS',
        'Load completed successfully'
    );

    -- ================================================================
    -- STEP 12: Update PIPELINE_METADATA with the source-domain
    --          watermark so the next incremental load filters correctly.
    -- ================================================================
    MERGE INTO SDLC_DB.SDLC_PIPELINES.PIPELINE_METADATA AS M
    USING (
        SELECT
            :v_pipeline_name  AS PIPELINE_NAME,
            :v_max_source_ts  AS LAST_RUN_TIMESTAMP,
            'SUCCESS'         AS LAST_RUN_STATUS,
            :v_run_ts         AS UPDATED_AT
    ) AS S
    ON M.PIPELINE_NAME = S.PIPELINE_NAME
    WHEN MATCHED THEN UPDATE SET
        M.LAST_RUN_TIMESTAMP = S.LAST_RUN_TIMESTAMP,
        M.LAST_RUN_STATUS    = S.LAST_RUN_STATUS,
        M.UPDATED_AT         = S.UPDATED_AT
    WHEN NOT MATCHED THEN INSERT (
        PIPELINE_NAME, LAST_RUN_TIMESTAMP, LAST_RUN_STATUS, UPDATED_AT
    ) VALUES (
        S.PIPELINE_NAME, S.LAST_RUN_TIMESTAMP, S.LAST_RUN_STATUS, S.UPDATED_AT
    );

    v_summary := 'Pipeline ' || :v_pipeline_name
        || ' completed. Inserted=' || :v_inserted
        || ' Updated='            || :v_updated
        || ' SoftDeleted='        || :v_soft_deleted
        || ' SourceCount='        || :v_source_count
        || ' TargetTotal='        || :v_target_count
        || ' LoadType='           || IFF(:v_is_full_load, 'FULL', 'INCREMENTAL');

    RETURN :v_summary;

EXCEPTION
    WHEN OTHER THEN
        LET err VARCHAR := SQLERRM;
        INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
            PIPELINE_NAME, RUN_TIMESTAMP, SOURCE_COUNT, TARGET_COUNT,
            INSERTED_COUNT, UPDATED_COUNT, SOFT_DELETED_COUNT, STATUS, NOTES
        ) VALUES (
            :v_pipeline_name,
            :v_run_ts,
            :v_source_count,
            :v_target_count,
            :v_inserted,
            :v_updated,
            :v_soft_deleted,
            'FAILED',
            :err
        );
        RETURN 'ERROR: ' || :err;
END;
$$;
