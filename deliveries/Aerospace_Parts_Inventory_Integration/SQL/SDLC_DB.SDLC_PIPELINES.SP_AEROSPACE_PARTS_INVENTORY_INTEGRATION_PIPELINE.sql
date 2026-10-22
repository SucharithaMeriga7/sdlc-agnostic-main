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
--   - SDLC_DB.SDLC_PIPELINES.PIPELINE_EXECUTION_STATE
--   - SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
--   - SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_TRANSFORMED_MANUFACTURER
--   - SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_TRANSFORMED_WEIGHT
--   - SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_RISK_SCORE
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
    -- ----------------------------------------------------------------
    -- Pipeline identity constant
    -- ----------------------------------------------------------------
    v_pipeline_name     VARCHAR  DEFAULT 'SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE';

    -- ----------------------------------------------------------------
    -- Incremental load state variables (FR-01 / BR-01 / BR-02)
    -- ----------------------------------------------------------------
    v_last_run_ts       TIMESTAMP_NTZ;
    v_is_first_run      BOOLEAN  DEFAULT FALSE;
    v_run_start_ts      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();

    -- ----------------------------------------------------------------
    -- Row count accumulators (FR-08 / BR-12)
    -- ----------------------------------------------------------------
    v_source_count      NUMBER(38,0) DEFAULT 0;
    v_target_count      NUMBER(38,0) DEFAULT 0;
    v_inserted          NUMBER(38,0) DEFAULT 0;
    v_updated           NUMBER(38,0) DEFAULT 0;
    v_soft_deleted      NUMBER(38,0) DEFAULT 0;

    -- ----------------------------------------------------------------
    -- MERGE result capture variables
    -- ----------------------------------------------------------------
    v_merge_inserted    NUMBER(38,0) DEFAULT 0;
    v_merge_updated     NUMBER(38,0) DEFAULT 0;

    -- ----------------------------------------------------------------
    -- Summary / error variables
    -- ----------------------------------------------------------------
    v_summary           VARCHAR  DEFAULT '';
    v_err               VARCHAR  DEFAULT '';

BEGIN
    -- ================================================================
    -- STEP 0: Ensure schema and required objects exist
    -- ================================================================
    -- Ensure target schema exists
    CREATE SCHEMA IF NOT EXISTS SDLC_DB.AEROSPACE_PARTS_TARGET;

    -- Ensure execution state table exists (idempotent)
    CREATE TABLE IF NOT EXISTS SDLC_DB.SDLC_PIPELINES.PIPELINE_EXECUTION_STATE (
        PIPELINE_NAME      VARCHAR(200)  NOT NULL,
        LAST_SUCCESSFUL_TS TIMESTAMP_NTZ NOT NULL,
        UPDATED_AT         TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
        CONSTRAINT PK_PIPELINE_EXECUTION_STATE PRIMARY KEY (PIPELINE_NAME)
    );

    -- Ensure target PARTS table exists (idempotent)
    CREATE TABLE IF NOT EXISTS SDLC_DB.AEROSPACE_PARTS_TARGET.PARTS (
        PART_NUMBER          VARCHAR(100)  NOT NULL,
        PART_NAME            VARCHAR(255),
        MANUFACTURER         VARCHAR(255),
        CATEGORY             VARCHAR(100),
        WEIGHT_KG            NUMBER(10,3),
        LEAD_TIME_DAYS       NUMBER(38,0),
        CERTIFICATION_STATUS VARCHAR(100),
        LIFECYCLE_STATUS     VARCHAR(100),
        INSTALLATION_DATE    DATE,
        RISK_SCORE           VARCHAR(50),
        UPDATED_AT           TIMESTAMP_NTZ,
        LOAD_TIMESTAMP       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
        CONSTRAINT PK_PARTS PRIMARY KEY (PART_NUMBER)
    );

    -- Ensure reconciliation log table exists (idempotent)
    CREATE TABLE IF NOT EXISTS SDLC_DB.AEROSPACE_PARTS_TARGET.ETL_RECONCILIATION_LOG (
        LOG_ID             NUMBER AUTOINCREMENT PRIMARY KEY,
        PIPELINE_NAME      VARCHAR(200)  NOT NULL,
        RUN_TIMESTAMP      TIMESTAMP_NTZ NOT NULL,
        SOURCE_COUNT       NUMBER(38,0)  NOT NULL,
        TARGET_COUNT       NUMBER(38,0)  NOT NULL,
        INSERTED_COUNT     NUMBER(38,0)  NOT NULL,
        UPDATED_COUNT      NUMBER(38,0)  NOT NULL,
        SOFT_DELETED_COUNT NUMBER(38,0)  NOT NULL,
        STATUS             VARCHAR(50)   NOT NULL,
        ERROR_MESSAGE      VARCHAR(2000)
    );

    -- ================================================================
    -- STEP 1: Determine incremental vs full load (FR-01 / BR-01 / BR-02)
    -- ================================================================
    -- Attempt to retrieve last successful execution timestamp
    -- from the dedicated execution state table.
    -- If no row exists this is the first run -> full load (BR-02).
    SELECT LAST_SUCCESSFUL_TS
    INTO   :v_last_run_ts
    FROM   SDLC_DB.SDLC_PIPELINES.PIPELINE_EXECUTION_STATE
    WHERE  PIPELINE_NAME = :v_pipeline_name
    LIMIT  1;

    IF (v_last_run_ts IS NULL) THEN
        -- BR-02: first run - set epoch so all records qualify
        v_is_first_run := TRUE;
        v_last_run_ts  := '1970-01-01 00:00:00'::TIMESTAMP_NTZ;
    END IF;

    -- ================================================================
    -- STEP 2: Count source extract rows (FR-08 / BR-12)
    -- ================================================================
    -- Count deduplicated source rows that pass the incremental filter.
    -- VW_AEROSPACE_PARTS_RISK_SCORE is the final transformation view
    -- (chains dedup -> manufacturer -> weight -> risk_score).
    -- BR-01: filter UPDATED_AT > last successful timestamp.
    -- BR-02: on first run v_last_run_ts = epoch so all rows qualify.
    SELECT COUNT(*)
    INTO   :v_source_count
    FROM   SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_RISK_SCORE
    WHERE  UPDATED_AT > :v_last_run_ts;

    -- ================================================================
    -- STEP 3: SCD Type 1 MERGE into target PARTS (FR-03 / BR-04)
    --         with all transformations applied via view chain
    --         (FR-05/BR-06, FR-06/BR-07, FR-07/BR-08..BR-11)
    -- ================================================================
    -- MERGE matches on PART_NUMBER (natural key).
    -- WHEN MATCHED: overwrite all non-key columns (SCD Type 1 - BR-04).
    -- WHEN NOT MATCHED: insert new record.
    -- Source is filtered by incremental timestamp (BR-01 / BR-02).
    MERGE INTO SDLC_DB.AEROSPACE_PARTS_TARGET.PARTS AS tgt
    USING (
        -- Apply incremental filter over the fully-transformed view
        -- (dedup BR-03, UPPER(MANUFACTURER) BR-06, WEIGHT_KG BR-07, RISK_SCORE BR-08..BR-11)
        SELECT
            PART_NUMBER,
            PART_NAME,
            MANUFACTURER,       -- already UPPER() from VW_AEROSPACE_PARTS_TRANSFORMED_MANUFACTURER
            CATEGORY,
            WEIGHT_KG,          -- already -1 for <= 0 from VW_AEROSPACE_PARTS_TRANSFORMED_WEIGHT
            LEAD_TIME_DAYS,
            CERTIFICATION_STATUS,
            LIFECYCLE_STATUS,
            INSTALLATION_DATE,
            RISK_SCORE,         -- derived per BR-08..BR-11
            UPDATED_AT
        FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_RISK_SCORE
        WHERE UPDATED_AT > :v_last_run_ts  -- BR-01 incremental filter
    ) AS src
    ON tgt.PART_NUMBER = src.PART_NUMBER   -- join on natural key
    -- BR-04: SCD Type 1 - overwrite all non-key columns on match
    WHEN MATCHED THEN UPDATE SET
        tgt.PART_NAME            = src.PART_NAME,
        tgt.MANUFACTURER         = src.MANUFACTURER,
        tgt.CATEGORY             = src.CATEGORY,
        tgt.WEIGHT_KG            = src.WEIGHT_KG,
        tgt.LEAD_TIME_DAYS       = src.LEAD_TIME_DAYS,
        tgt.CERTIFICATION_STATUS = src.CERTIFICATION_STATUS,
        tgt.LIFECYCLE_STATUS     = src.LIFECYCLE_STATUS,
        tgt.INSTALLATION_DATE    = src.INSTALLATION_DATE,
        tgt.RISK_SCORE           = src.RISK_SCORE,
        tgt.UPDATED_AT           = src.UPDATED_AT,
        tgt.LOAD_TIMESTAMP       = CURRENT_TIMESTAMP()
    -- New PART_NUMBER not yet in target
    WHEN NOT MATCHED THEN INSERT (
        PART_NUMBER,
        PART_NAME,
        MANUFACTURER,
        CATEGORY,
        WEIGHT_KG,
        LEAD_TIME_DAYS,
        CERTIFICATION_STATUS,
        LIFECYCLE_STATUS,
        INSTALLATION_DATE,
        RISK_SCORE,
        UPDATED_AT,
        LOAD_TIMESTAMP
    ) VALUES (
        src.PART_NUMBER,
        src.PART_NAME,
        src.MANUFACTURER,
        src.CATEGORY,
        src.WEIGHT_KG,
        src.LEAD_TIME_DAYS,
        src.CERTIFICATION_STATUS,
        src.LIFECYCLE_STATUS,
        src.INSTALLATION_DATE,
        src.RISK_SCORE,
        src.UPDATED_AT,
        CURRENT_TIMESTAMP()
    );

    -- Capture MERGE row counts from result scan
    -- Only WHEN NOT MATCHED (insert) and WHEN MATCHED (update) clauses present
    SELECT
        "number of rows inserted",
        "number of rows updated"
    INTO
        :v_merge_inserted,
        :v_merge_updated
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

    v_inserted := v_merge_inserted;
    v_updated  := v_merge_updated;

    -- ================================================================
    -- STEP 4: Soft delete - mark Decommissioned (FR-04 / BR-05)
    -- ================================================================
    -- Identify PART_NUMBERs present in target but absent from the
    -- FULL current source extract (not just the incremental slice).
    -- VW_AEROSPACE_PARTS_DEDUPLICATED covers all source records.
    -- BR-05: set LIFECYCLE_STATUS = 'Decommissioned' for missing parts.
    UPDATE SDLC_DB.AEROSPACE_PARTS_TARGET.PARTS AS tgt
    SET
        tgt.LIFECYCLE_STATUS = 'Decommissioned',
        tgt.LOAD_TIMESTAMP   = CURRENT_TIMESTAMP()
    WHERE tgt.PART_NUMBER NOT IN (
        -- Full source extract (all PART_NUMBERs currently in source)
        SELECT PART_NUMBER
        FROM   SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED
    )
    -- Only update rows not already Decommissioned to avoid unnecessary writes
    AND tgt.LIFECYCLE_STATUS <> 'Decommissioned';

    -- Capture soft-delete count via SQLROWCOUNT
    v_soft_deleted := SQLROWCOUNT;

    -- ================================================================
    -- STEP 5: Count target rows after load (FR-08 / BR-12)
    -- ================================================================
    SELECT COUNT(*)
    INTO   :v_target_count
    FROM   SDLC_DB.AEROSPACE_PARTS_TARGET.PARTS;

    -- ================================================================
    -- STEP 6: Update execution state (FR-01)
    -- ================================================================
    -- Record the run start timestamp as the new last successful TS.
    -- Using run_start_ts (captured before load) ensures no records
    -- written during this run are missed on the next incremental load.
    MERGE INTO SDLC_DB.SDLC_PIPELINES.PIPELINE_EXECUTION_STATE AS st
    USING (SELECT :v_pipeline_name AS PIPELINE_NAME) AS src
    ON st.PIPELINE_NAME = src.PIPELINE_NAME
    WHEN MATCHED THEN UPDATE SET
        st.LAST_SUCCESSFUL_TS = :v_run_start_ts,
        st.UPDATED_AT         = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (
        PIPELINE_NAME,
        LAST_SUCCESSFUL_TS,
        UPDATED_AT
    ) VALUES (
        :v_pipeline_name,
        :v_run_start_ts,
        CURRENT_TIMESTAMP()
    );

    -- ================================================================
    -- STEP 7: Log reconciliation metrics (FR-08 / BR-12)
    -- ================================================================
    -- BR-12: must be logged on every pipeline run without exception.
    INSERT INTO SDLC_DB.AEROSPACE_PARTS_TARGET.ETL_RECONCILIATION_LOG (
        PIPELINE_NAME,
        RUN_TIMESTAMP,
        SOURCE_COUNT,
        TARGET_COUNT,
        INSERTED_COUNT,
        UPDATED_COUNT,
        SOFT_DELETED_COUNT,
        STATUS,
        ERROR_MESSAGE
    ) VALUES (
        :v_pipeline_name,
        :v_run_start_ts,
        :v_source_count,
        :v_target_count,
        :v_inserted,
        :v_updated,
        :v_soft_deleted,
        'SUCCESS',
        NULL
    );

    -- ================================================================
    -- STEP 8: Build and return summary string
    -- ================================================================
    -- FR-09 note: A TASK named TK_AEROSPACE_PARTS_DAILY should be
    -- created externally (outside this procedure) scheduled at
    -- 05:00 UTC daily calling this procedure. Tasks are never
    -- created inside procedures per delivery rules.
    v_summary := 'SUCCESS | pipeline=' || :v_pipeline_name
        || ' | first_run=' || :v_is_first_run::VARCHAR
        || ' | last_run_ts=' || :v_last_run_ts::VARCHAR
        || ' | source_count=' || :v_source_count::VARCHAR
        || ' | inserted=' || :v_inserted::VARCHAR
        || ' | updated=' || :v_updated::VARCHAR
        || ' | soft_deleted=' || :v_soft_deleted::VARCHAR
        || ' | target_count=' || :v_target_count::VARCHAR
        || ' | run_ts=' || :v_run_start_ts::VARCHAR;

    RETURN :v_summary;

EXCEPTION
    WHEN OTHER THEN
    LET sdlc_code VARCHAR := SQLCODE;
        -- Capture error details before any DML (SQLERRM only valid in expression)
        LET err VARCHAR := SQLERRM;
        LET err_code VARCHAR := SQLCODE::VARCHAR;

        -- BR-12: log failure to reconciliation log unconditionally
        INSERT INTO SDLC_DB.AEROSPACE_PARTS_TARGET.ETL_RECONCILIATION_LOG (
            PIPELINE_NAME,
            RUN_TIMESTAMP,
            SOURCE_COUNT,
            TARGET_COUNT,
            INSERTED_COUNT,
            UPDATED_COUNT,
            SOFT_DELETED_COUNT,
            STATUS,
            ERROR_MESSAGE
        ) VALUES (
            :v_pipeline_name,
            :v_run_start_ts,
            :v_source_count,
            :v_target_count,
            :v_inserted,
            :v_updated,
            :v_soft_deleted,
            'FAILED',
            ':sdlc_code=' || :err_code || ' | ' || :err
        );

        RETURN 'FAILED: SQLCODE=' || :err_code || ' | ' || :err;
END;
$$;
