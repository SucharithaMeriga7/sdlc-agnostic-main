-- =============================================================================
-- Object        : SDLC_DB.ETL.PARTS_INCREMENTAL_LOAD_TASK
-- Object Type   : TASK
-- Jira Story    : SCRUM-156
-- Requirements  : FR-01, FR-02, FR-03, FR-04, FR-05, FR-06, FR-07, FR-08, FR-09
-- Reuse Decision: CREATE_NEW
-- Description   : Orchestrating task scheduled daily at 05:00 UTC. Executes incremental (or full on first run) load via MERGE, calls soft-delete procedure, and logs reconciliation results.
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - SDLC_DB.ETL.EXECUTION_CONTROL
--   - SDLC_DB.ETL.PARTS_TRANSFORM_VIEW
--   - SDLC_DB.ETL.PARTS_DEDUPLICATE_VIEW
--   - SDLC_DB.ETL.PARTS_TARGET
--   - SDLC_DB.ETL.PARTS_SOFT_DELETE_PROCEDURE
--   - SDLC_DB.ETL.ETL_RECONCILIATION_LOG
-- Business Rules: BR-01, BR-02, BR-03, BR-04, BR-05, BR-06, BR-07, BR-08, BR-09, BR-10, BR-11, BR-12
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-156  Initial generation (CREATE_NEW)
-- =============================================================================

-- ============================================================
-- TASK: SDLC_DB.ETL.PARTS_INCREMENTAL_LOAD_TASK
-- Purpose : Daily orchestration of the full parts ETL pipeline
-- FR-09   : Scheduled USING CRON 0 5 * * * UTC
-- FR-01   : Incremental load via UPDATED_AT watermark (BR-01/BR-02)
-- FR-02   : Deduplication via PARTS_DEDUPLICATE_VIEW (BR-03)
-- FR-03   : SCD Type 1 MERGE into PARTS_TARGET (BR-04)
-- FR-04   : Soft-delete via PARTS_SOFT_DELETE_PROCEDURE (BR-05)
-- FR-05/06/07: Transformations via PARTS_TRANSFORM_VIEW (BR-06..BR-11)
-- FR-08   : Reconciliation logged to ETL_RECONCILIATION_LOG (BR-12)
-- ============================================================
CREATE OR REPLACE TASK SDLC_DB.ETL.PARTS_INCREMENTAL_LOAD_TASK
    WAREHOUSE = COMPUTE_WH                    -- Replace with target warehouse
    SCHEDULE  = 'USING CRON 0 5 * * * UTC'   -- FR-09: daily 05:00 UTC
    COMMENT   = 'Daily incremental load for PARTS master data pipeline'
AS
$$
DECLARE
    -- --------------------------------------------------------
    -- State variables
    -- --------------------------------------------------------
    v_execution_id       VARCHAR DEFAULT REPLACE(CURRENT_TIMESTAMP()::VARCHAR,' ','_') || '_PARTS';
    v_watermark          TIMESTAMP_NTZ;        -- Last successful run (NULL = first run)
    v_run_start          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();

    -- Reconciliation counters
    v_source_count       NUMBER DEFAULT 0;
    v_target_before      NUMBER DEFAULT 0;
    v_target_after       NUMBER DEFAULT 0;
    v_inserted_count     NUMBER DEFAULT 0;
    v_updated_count      NUMBER DEFAULT 0;
    v_soft_deleted_count NUMBER DEFAULT 0;
    v_discrepancy        NUMBER DEFAULT 0;
    v_recon_status       VARCHAR DEFAULT 'PASSED';
    v_recon_notes        VARCHAR DEFAULT '';

    v_soft_delete_result VARCHAR DEFAULT '';
BEGIN
    -- ========================================================
    -- STEP 1: Read watermark from EXECUTION_CONTROL
    -- BR-01: Use LAST_SUCCESSFUL_RUN as incremental filter
    -- BR-02: NULL watermark => full load
    -- ========================================================
    SELECT LAST_SUCCESSFUL_RUN
    INTO   :v_watermark
    FROM   SDLC_DB.ETL.EXECUTION_CONTROL
    WHERE  PIPELINE_NAME = 'PARTS_INCREMENTAL_LOAD';

    -- Mark run as in-progress
    UPDATE SDLC_DB.ETL.EXECUTION_CONTROL
    SET    LAST_RUN_TIMESTAMP = :v_run_start,
           LAST_RUN_STATUS    = 'RUNNING',
           EXECUTION_ID       = :v_execution_id
    WHERE  PIPELINE_NAME = 'PARTS_INCREMENTAL_LOAD';

    -- ========================================================
    -- STEP 2: Capture pre-load target row count for recon
    -- ========================================================
    SELECT COUNT(1)
    INTO   :v_target_before
    FROM   SDLC_DB.ETL.PARTS_TARGET;

    -- ========================================================
    -- STEP 3: Count source rows for this extraction window
    -- BR-01: Filter by UPDATED_AT > watermark (incremental)
    -- BR-02: No filter when watermark IS NULL (full load)
    -- Source is PARTS_TRANSFORM_VIEW which already applies
    --   deduplication (via PARTS_DEDUPLICATE_VIEW) and all
    --   field transformations (BR-06, BR-07, BR-08..BR-11)
    -- ========================================================
    SELECT COUNT(1)
    INTO   :v_source_count
    FROM   SDLC_DB.ETL.PARTS_TRANSFORM_VIEW
    WHERE  (:v_watermark IS NULL)                  -- BR-02: full load on first run
       OR  (UPDATED_AT > :v_watermark);            -- BR-01: incremental filter

    -- ========================================================
    -- STEP 4: SCD Type 1 MERGE into PARTS_TARGET
    -- BR-04: Match on PART_NUMBER; overwrite all attributes
    -- Transformations already applied in PARTS_TRANSFORM_VIEW:
    --   BR-06 UPPER(MANUFACTURER), BR-07 WEIGHT_KG cleanse,
    --   BR-08..BR-11 RISK_SCORE derivation
    -- ========================================================
    MERGE INTO SDLC_DB.ETL.PARTS_TARGET AS tgt
    USING (
        -- Apply incremental filter at MERGE source level
        -- BR-01 / BR-02: conditional watermark predicate
        SELECT
            PART_NUMBER,
            PART_NAME,
            MANUFACTURER,       -- Already UPPER() via BR-06
            WEIGHT_KG,          -- Already cleansed via BR-07
            CERTIFICATION_STATUS,
            LEAD_TIME_DAYS,
            RISK_SCORE,         -- Derived via BR-08..BR-11
            UPDATED_AT
        FROM SDLC_DB.ETL.PARTS_TRANSFORM_VIEW
        WHERE (:v_watermark IS NULL)               -- BR-02: full load
           OR (UPDATED_AT > :v_watermark)          -- BR-01: incremental
    ) AS src
    ON tgt.PART_NUMBER = src.PART_NUMBER           -- BR-04: natural key match

    -- BR-04: Matched => overwrite all non-key attributes (SCD Type 1)
    WHEN MATCHED THEN UPDATE SET
        tgt.PART_NAME            = src.PART_NAME,
        tgt.MANUFACTURER         = src.MANUFACTURER,
        tgt.WEIGHT_KG            = src.WEIGHT_KG,
        tgt.CERTIFICATION_STATUS = src.CERTIFICATION_STATUS,
        tgt.LEAD_TIME_DAYS       = src.LEAD_TIME_DAYS,
        tgt.RISK_SCORE           = src.RISK_SCORE,
        tgt.STATUS               = 'Active',       -- Reactivate if previously decommissioned
        tgt.UPDATED_AT           = src.UPDATED_AT,
        tgt.ETL_LOAD_TIMESTAMP   = CURRENT_TIMESTAMP()

    -- New PART_NUMBER => insert
    WHEN NOT MATCHED THEN INSERT (
        PART_NUMBER,
        PART_NAME,
        MANUFACTURER,
        WEIGHT_KG,
        CERTIFICATION_STATUS,
        LEAD_TIME_DAYS,
        RISK_SCORE,
        STATUS,
        UPDATED_AT,
        ETL_LOAD_TIMESTAMP
    ) VALUES (
        src.PART_NUMBER,
        src.PART_NAME,
        src.MANUFACTURER,
        src.WEIGHT_KG,
        src.CERTIFICATION_STATUS,
        src.LEAD_TIME_DAYS,
        src.RISK_SCORE,
        'Active',
        src.UPDATED_AT,
        CURRENT_TIMESTAMP()
    );

    -- Capture MERGE row counts via system variables
    -- Snowflake does not expose split INSERT/UPDATE from MERGE directly;
    -- derive from before/after counts
    SELECT COUNT(1) INTO :v_target_after FROM SDLC_DB.ETL.PARTS_TARGET;
    v_inserted_count := v_target_after - v_target_before;
    v_updated_count  := v_source_count - GREATEST(v_inserted_count, 0);

    -- ========================================================
    -- STEP 5: Soft-delete absent parts (BR-05 / FR-04)
    -- Delegate to dedicated procedure for separation of concerns
    -- ========================================================
    CALL SDLC_DB.ETL.PARTS_SOFT_DELETE_PROCEDURE(:v_execution_id)
    INTO :v_soft_delete_result;

    -- Parse soft-deleted count from procedure return string
    v_soft_deleted_count := TRY_TO_NUMBER(
        REGEXP_SUBSTR(v_soft_delete_result, '[0-9]+$')
    );

    -- ========================================================
    -- STEP 6: Reconciliation check and logging (BR-12 / FR-08)
    -- ========================================================
    SELECT COUNT(1) INTO :v_target_after FROM SDLC_DB.ETL.PARTS_TARGET;

    -- Discrepancy: absolute difference between source extract
    -- and net active target rows after this run
    v_discrepancy := ABS(v_source_count - (v_target_after - v_soft_deleted_count));

    IF (v_discrepancy > 0) THEN
        v_recon_status := 'WARNING';
        v_recon_notes  := 'Discrepancy of ' || v_discrepancy::VARCHAR || ' rows detected.';
    END IF;

    -- BR-12: Insert reconciliation record
    INSERT INTO SDLC_DB.ETL.ETL_RECONCILIATION_LOG (
        EXECUTION_ID,
        RUN_TIMESTAMP,
        CHECK_NAME,
        SOURCE_COUNT,
        TARGET_COUNT,
        INSERTED_COUNT,
        UPDATED_COUNT,
        SOFT_DELETED_COUNT,
        DISCREPANCY_COUNT,
        STATUS,
        NOTES
    ) VALUES (
        :v_execution_id,
        :v_run_start,
        'PARTS_INCREMENTAL_LOAD_RECONCILIATION',
        :v_source_count,
        :v_target_after,
        :v_inserted_count,
        :v_updated_count,
        :v_soft_deleted_count,
        :v_discrepancy,
        :v_recon_status,
        :v_recon_notes
    );

    -- ========================================================
    -- STEP 7: Update EXECUTION_CONTROL watermark on success
    -- BR-01: Next run will use this timestamp as lower bound
    -- ========================================================
    UPDATE SDLC_DB.ETL.EXECUTION_CONTROL
    SET    LAST_SUCCESSFUL_RUN  = :v_run_start,
           LAST_RUN_STATUS      = 'SUCCESS',
           LAST_RUN_TIMESTAMP   = CURRENT_TIMESTAMP(),
           EXECUTION_ID         = :v_execution_id
    WHERE  PIPELINE_NAME = 'PARTS_INCREMENTAL_LOAD';

EXCEPTION
    WHEN OTHER THEN
        -- Log failure to EXECUTION_CONTROL
        UPDATE SDLC_DB.ETL.EXECUTION_CONTROL
        SET    LAST_RUN_STATUS    = 'FAILED',
               LAST_RUN_TIMESTAMP = CURRENT_TIMESTAMP(),
               EXECUTION_ID       = :v_execution_id
        WHERE  PIPELINE_NAME = 'PARTS_INCREMENTAL_LOAD';

        -- Log failure reconciliation record (BR-12)
        INSERT INTO SDLC_DB.ETL.ETL_RECONCILIATION_LOG (
            EXECUTION_ID, RUN_TIMESTAMP, CHECK_NAME,
            SOURCE_COUNT, TARGET_COUNT, INSERTED_COUNT,
            UPDATED_COUNT, SOFT_DELETED_COUNT, DISCREPANCY_COUNT,
            STATUS, NOTES
        ) VALUES (
            :v_execution_id, :v_run_start, 'PARTS_INCREMENTAL_LOAD_RECONCILIATION',
            :v_source_count, :v_target_before, :v_inserted_count,
            :v_updated_count, :v_soft_deleted_count, -1,
            'FAILED', 'Pipeline error: SQLCODE=' || SQLCODE::VARCHAR || ' SQLERRM=' || SQLERRM
        );

        RAISE; -- Re-raise so Snowflake marks the task run as failed
END;
$$;

-- ============================================================
-- Resume the task after creation (tasks are suspended by default)
-- FR-09: Activate daily 05:00 UTC schedule
-- ============================================================
ALTER TASK SDLC_DB.ETL.PARTS_INCREMENTAL_LOAD_TASK RESUME;
