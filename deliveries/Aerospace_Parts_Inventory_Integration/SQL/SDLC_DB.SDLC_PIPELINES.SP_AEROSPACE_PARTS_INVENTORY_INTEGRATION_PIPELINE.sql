-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE
-- Object Type   : PROCEDURE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-01, FR-02, FR-03, FR-04, FR-05, FR-06, FR-07, FR-08, FR-09
-- Reuse Route   : PIPELINE
-- Description   : Pipeline orchestration for Aerospace_Parts_Inventory_Integration
-- Author        : Sucharitha
-- Created Date  : 2026-10-23
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS
--   - SDLC_DB.SDLC_PIPELINES.PIPELINE_METADATA
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_DEDUPLICATED
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TRANSFORMED
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_CLEANSED
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_RISK_SCORED
--   - SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
-- Business Rules: BR-01, BR-02, BR-03, BR-04, BR-05, BR-06, BR-07, BR-08, BR-09, BR-10, BR-11, BR-12
-- Change History:
--   2026-10-23  Sucharitha  SCRUM-158  Initial generation (PIPELINE)
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
    v_run_ts            TIMESTAMP_NTZ DEFAULT CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ;
    v_last_run_ts       TIMESTAMP_NTZ DEFAULT NULL;
    v_has_prior_run     BOOLEAN  DEFAULT FALSE;

    -- Row count variables
    v_source_count      NUMBER   DEFAULT 0;
    v_target_count      NUMBER   DEFAULT 0;
    v_ins               NUMBER   DEFAULT 0;
    v_upd               NUMBER   DEFAULT 0;
    v_soft_del          NUMBER   DEFAULT 0;

    -- SLA tracking
    v_start_ts          TIMESTAMP_NTZ DEFAULT CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ;
    v_end_ts            TIMESTAMP_NTZ DEFAULT NULL;
    v_elapsed_sec       NUMBER   DEFAULT 0;
    v_sla_note          VARCHAR  DEFAULT '';

    -- Summary
    v_summary           VARCHAR  DEFAULT '';

    -- Error capture
    v_err               VARCHAR  DEFAULT '';

BEGIN
    -- ================================================================
    -- STEP 1: Retrieve last successful run timestamp (FR-01, BR-01, BR-02)
    -- ================================================================
    -- Read the most recent SUCCESS timestamp from PIPELINE_METADATA.
    -- If no row exists this is the first run -> full load (BR-02).
    SELECT
        LAST_RUN_TIMESTAMP,
        TRUE
    INTO
        :v_last_run_ts,
        :v_has_prior_run
    FROM SDLC_DB.SDLC_PIPELINES.PIPELINE_METADATA
    WHERE PIPELINE_NAME = :v_pipeline_name
      AND LAST_RUN_STATUS = 'SUCCESS'
    ORDER BY LAST_RUN_TIMESTAMP DESC NULLS LAST
    LIMIT 1;

    -- ================================================================
    -- STEP 2: Populate AEROSPACE_PARTS_DEDUPLICATED from raw source
    -- (FR-02, BR-03) - deduplicate keeping latest record per PART_NUMBER
    -- ================================================================
    -- Full replace of deduplicated staging table each run so that
    -- soft-delete detection in STEP 5 always reflects the complete
    -- current source universe.
    TRUNCATE TABLE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_DEDUPLICATED;

    INSERT INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_DEDUPLICATED (
        PART_NUMBER, PART_NAME, MANUFACTURER, CATEGORY,
        WEIGHT_KG, UNIT_PRICE_USD, QUANTITY_ON_HAND, REORDER_LEVEL,
        LIFECYCLE_STATUS, CERTIFICATION_STATUS, INSTALLATION_DATE,
        LEAD_TIME_DAYS, SUPPLIER, WAREHOUSE_LOCATION, COUNTRY_OF_ORIGIN,
        CREATED_AT, UPDATED_AT
    )
    SELECT
        PART_NUMBER,
        PART_NAME,
        UPPER(MANUFACTURER)  AS MANUFACTURER,   -- BR-06: normalise to upper case
        CATEGORY,
        CASE WHEN WEIGHT_KG < 0 THEN NULL ELSE WEIGHT_KG END AS WEIGHT_KG,  -- BR-07: cleanse negative weights
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
        CREATED_AT,
        UPDATED_AT
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY PART_NUMBER ORDER BY UPDATED_AT DESC NULLS LAST) AS rn
        FROM IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE
    ) deduped
    WHERE rn = 1;

    -- ================================================================
    -- STEP 3: Populate AEROSPACE_PARTS_RISK_SCORED from deduplicated
    -- (FR-02, BR-08..BR-11) - derive RISK_SCORE
    -- ================================================================
    TRUNCATE TABLE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_RISK_SCORED;

    INSERT INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_RISK_SCORED (
        PART_NUMBER, PART_NAME, MANUFACTURER, CATEGORY,
        WEIGHT_KG, UNIT_PRICE_USD, QUANTITY_ON_HAND, REORDER_LEVEL,
        LIFECYCLE_STATUS, CERTIFICATION_STATUS, INSTALLATION_DATE,
        LEAD_TIME_DAYS, SUPPLIER, WAREHOUSE_LOCATION, COUNTRY_OF_ORIGIN,
        CREATED_AT, UPDATED_AT, RISK_SCORE
    )
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
        CREATED_AT,
        UPDATED_AT,
        -- BR-08..BR-11: derive risk score from lifecycle, certification, quantity and lead time
        CASE
            WHEN LIFECYCLE_STATUS     = 'Obsolete'       THEN 'HIGH'
            WHEN CERTIFICATION_STATUS = 'Non-Certified'  THEN 'HIGH'
            WHEN QUANTITY_ON_HAND <= REORDER_LEVEL       THEN 'MEDIUM'
            WHEN LEAD_TIME_DAYS   > 90                   THEN 'MEDIUM'
            ELSE 'LOW'
        END AS RISK_SCORE
    FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_DEDUPLICATED;

    -- ================================================================
    -- STEP 4: Count incremental source rows (FR-01, BR-01, BR-02)
    -- ================================================================
    -- When v_has_prior_run is FALSE (first run) load all records (BR-02).
    -- Otherwise filter by UPDATED_AT > last successful timestamp (BR-01).
    IF (:v_has_prior_run = FALSE) THEN
        -- BR-02: full load - no timestamp filter
        SELECT COUNT(*)
        INTO :v_source_count
        FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_RISK_SCORED;
    ELSE
        -- BR-01: incremental filter on UPDATED_AT
        SELECT COUNT(*)
        INTO :v_source_count
        FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_RISK_SCORED
        WHERE UPDATED_AT > :v_last_run_ts;
    END IF;

    -- ================================================================
    -- STEP 5: SCD Type 1 MERGE into AEROSPACE_PARTS (FR-03, FR-04, BR-04, BR-05)
    -- ================================================================
    -- The source CTE applies the incremental filter (BR-01/BR-02).
    -- WHEN MATCHED -> overwrite all non-key columns (BR-04, SCD1).
    -- WHEN NOT MATCHED BY TARGET -> insert new row.
    -- Soft-delete (BR-05) is handled separately in STEP 6 to allow
    -- accurate row-count capture from RESULT_SCAN.
    IF (:v_has_prior_run = FALSE) THEN
        -- Full load merge (BR-02)
        MERGE INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS AS TGT
        USING (
            -- Source: full risk-scored, cleansed, transformed, deduplicated view chain
            SELECT
                PART_NUMBER,
                PART_NAME,
                MANUFACTURER,          -- Already UPPER() per BR-06
                CATEGORY,
                WEIGHT_KG,             -- Already cleansed per BR-07
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
                RISK_SCORE,            -- Derived per BR-08..BR-11
                CREATED_AT,
                UPDATED_AT
            FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_RISK_SCORED
        ) AS SRC
        ON TGT.PART_NUMBER = SRC.PART_NUMBER  -- Business key join (BR-04)
        -- BR-04: SCD Type 1 - overwrite all non-key attributes
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
            TGT.LOAD_TIMESTAMP       = :v_run_ts,
            TGT.STATUS               = 'Active'
        -- New part numbers not yet in target
        WHEN NOT MATCHED THEN INSERT (
            PART_NUMBER, PART_NAME, MANUFACTURER, CATEGORY,
            WEIGHT_KG, UNIT_PRICE_USD, QUANTITY_ON_HAND, REORDER_LEVEL,
            LIFECYCLE_STATUS, CERTIFICATION_STATUS, INSTALLATION_DATE,
            LEAD_TIME_DAYS, SUPPLIER, WAREHOUSE_LOCATION, COUNTRY_OF_ORIGIN,
            RISK_SCORE, UPDATED_AT, LOAD_TIMESTAMP, STATUS, CREATED_AT
        ) VALUES (
            SRC.PART_NUMBER, SRC.PART_NAME, SRC.MANUFACTURER, SRC.CATEGORY,
            SRC.WEIGHT_KG, SRC.UNIT_PRICE_USD, SRC.QUANTITY_ON_HAND, SRC.REORDER_LEVEL,
            SRC.LIFECYCLE_STATUS, SRC.CERTIFICATION_STATUS, SRC.INSTALLATION_DATE,
            SRC.LEAD_TIME_DAYS, SRC.SUPPLIER, SRC.WAREHOUSE_LOCATION, SRC.COUNTRY_OF_ORIGIN,
            SRC.RISK_SCORE, SRC.UPDATED_AT, :v_run_ts, 'Active', SRC.CREATED_AT
        );
    ELSE
        -- Incremental merge (BR-01)
        MERGE INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS AS TGT
        USING (
            -- Source: incremental slice filtered by last successful run timestamp
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
                CREATED_AT,
                UPDATED_AT
            FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_RISK_SCORED
            WHERE UPDATED_AT > :v_last_run_ts  -- BR-01: incremental filter
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
            TGT.LOAD_TIMESTAMP       = :v_run_ts,
            TGT.STATUS               = 'Active'
        WHEN NOT MATCHED THEN INSERT (
            PART_NUMBER, PART_NAME, MANUFACTURER, CATEGORY,
            WEIGHT_KG, UNIT_PRICE_USD, QUANTITY_ON_HAND, REORDER_LEVEL,
            LIFECYCLE_STATUS, CERTIFICATION_STATUS, INSTALLATION_DATE,
            LEAD_TIME_DAYS, SUPPLIER, WAREHOUSE_LOCATION, COUNTRY_OF_ORIGIN,
            RISK_SCORE, UPDATED_AT, LOAD_TIMESTAMP, STATUS, CREATED_AT
        ) VALUES (
            SRC.PART_NUMBER, SRC.PART_NAME, SRC.MANUFACTURER, SRC.CATEGORY,
            SRC.WEIGHT_KG, SRC.UNIT_PRICE_USD, SRC.QUANTITY_ON_HAND, SRC.REORDER_LEVEL,
            SRC.LIFECYCLE_STATUS, SRC.CERTIFICATION_STATUS, SRC.INSTALLATION_DATE,
            SRC.LEAD_TIME_DAYS, SRC.SUPPLIER, SRC.WAREHOUSE_LOCATION, SRC.COUNTRY_OF_ORIGIN,
            SRC.RISK_SCORE, SRC.UPDATED_AT, :v_run_ts, 'Active', SRC.CREATED_AT
        );
    END IF;

    -- Capture MERGE row counts from RESULT_SCAN (inserted and updated clauses both present)
    SELECT
        "number of rows inserted",
        "number of rows updated"
    INTO :v_ins, :v_upd
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

    -- ================================================================
    -- STEP 6: Soft-delete records absent from full source (FR-04, BR-05)
    -- ================================================================
    -- Any PART_NUMBER in the target that does NOT appear in the
    -- deduplicated source view at all is marked Decommissioned.
    -- This uses the full (non-incremental) deduplicated table so that
    -- parts that were never in this run's incremental slice are also
    -- evaluated for decommission.
    UPDATE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS AS TGT
    SET
        TGT.STATUS         = 'Decommissioned',   -- BR-05: soft delete
        TGT.LOAD_TIMESTAMP = :v_run_ts
    WHERE TGT.STATUS <> 'Decommissioned'         -- Avoid redundant updates
      AND TGT.PART_NUMBER NOT IN (
          -- Full source deduplicated - all currently known PART_NUMBERs
          SELECT PART_NUMBER
          FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_DEDUPLICATED
      );

    -- Capture soft-delete count via SQLROWCOUNT
    v_soft_del := SQLROWCOUNT;

    -- ================================================================
    -- STEP 7: Count target rows post-merge (FR-08, BR-12)
    -- ================================================================
    SELECT COUNT(*)
    INTO :v_target_count
    FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS;

    -- ================================================================
    -- STEP 8: Write reconciliation log (FR-08, BR-12)
    -- ================================================================
    -- Captures source_count, target_count, inserted, updated, soft-deleted, run_timestamp.
    v_end_ts      := CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ;
    v_elapsed_sec := DATEDIFF('second', :v_start_ts, :v_end_ts);

    -- FR-09: SLA check - flag if elapsed time exceeds 300 seconds (5 minutes)
    IF (:v_elapsed_sec > 300) THEN
        v_sla_note := 'SLA BREACH: elapsed ' || :v_elapsed_sec || 's exceeds 300s threshold for 1M records.';
    ELSE
        v_sla_note := 'SLA OK: elapsed ' || :v_elapsed_sec || 's.';
    END IF;

    INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
        PIPELINE_NAME,
        RUN_TIMESTAMP,
        SOURCE_COUNT,
        TARGET_COUNT,
        INSERTED_COUNT,
        UPDATED_COUNT,
        SOFT_DELETED_COUNT,
        STATUS,
        NOTES
    ) VALUES (
        :v_pipeline_name,
        :v_run_ts,
        :v_source_count,
        :v_target_count,
        :v_ins,
        :v_upd,
        :v_soft_del,
        'SUCCESS',
        :v_sla_note
    );

    -- ================================================================
    -- STEP 9: Update PIPELINE_METADATA with SUCCESS status (FR-01)
    -- ================================================================
    -- Upsert so that both first-run (INSERT) and subsequent runs (UPDATE) are handled.
    MERGE INTO SDLC_DB.SDLC_PIPELINES.PIPELINE_METADATA AS M
    USING (SELECT :v_pipeline_name AS PIPELINE_NAME) AS SRC
    ON M.PIPELINE_NAME = SRC.PIPELINE_NAME
    WHEN MATCHED THEN UPDATE SET
        M.LAST_RUN_TIMESTAMP = :v_run_ts,
        M.LAST_RUN_STATUS    = 'SUCCESS',
        M.UPDATED_AT         = :v_run_ts
    WHEN NOT MATCHED THEN INSERT (
        PIPELINE_NAME,
        LAST_RUN_TIMESTAMP,
        LAST_RUN_STATUS,
        UPDATED_AT
    ) VALUES (
        :v_pipeline_name,
        :v_run_ts,
        'SUCCESS',
        :v_run_ts
    );

    -- ================================================================
    -- STEP 10: Build and return summary string
    -- ================================================================
    v_summary :=
        'PIPELINE: '         || :v_pipeline_name
        || ' | RUN_TS: '     || TO_VARCHAR(:v_run_ts)
        || ' | SOURCE: '     || :v_source_count
        || ' | INSERTED: '   || :v_ins
        || ' | UPDATED: '    || :v_upd
        || ' | SOFT_DEL: '   || :v_soft_del
        || ' | TARGET: '     || :v_target_count
        || ' | ' || :v_sla_note;

    RETURN :v_summary;

EXCEPTION
    WHEN OTHER THEN
        -- Capture error details before any further statements
        LET err VARCHAR := SQLERRM;

        -- Attempt to log the failure into PIPELINE_METADATA
        MERGE INTO SDLC_DB.SDLC_PIPELINES.PIPELINE_METADATA AS M
        USING (SELECT :v_pipeline_name AS PIPELINE_NAME) AS SRC
        ON M.PIPELINE_NAME = SRC.PIPELINE_NAME
        WHEN MATCHED THEN UPDATE SET
            M.LAST_RUN_TIMESTAMP = :v_run_ts,
            M.LAST_RUN_STATUS    = 'FAILED',
            M.UPDATED_AT         = :v_run_ts
        WHEN NOT MATCHED THEN INSERT (
            PIPELINE_NAME,
            LAST_RUN_TIMESTAMP,
            LAST_RUN_STATUS,
            UPDATED_AT
        ) VALUES (
            :v_pipeline_name,
            :v_run_ts,
            'FAILED',
            :v_run_ts
        );

        RETURN 'FAILED: ' || :err;
END;
$$;
