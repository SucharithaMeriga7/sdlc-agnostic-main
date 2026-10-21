-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.RECONCILIATION_CHECK_PROC
-- Object Type   : PROCEDURE
-- Jira Story    : SCRUM-156
-- Requirements  : FR-08
-- Reuse Route   : CREATE_NEW
-- Description   : Stored procedure that compares source vs. target record counts, retrieves merge/soft-delete metrics, evaluates discrepancies, and inserts a row into ETL_RECONCILIATION_LOG (BR-09).
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG
--   - SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED_VW
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
--   - SDLC_DB.SDLC_PIPELINES.MERGE_COUNTS_TMP
--   - SDLC_DB.SDLC_PIPELINES.SOFT_DELETE_COUNTS_TMP
-- Business Rules: BR-09
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-156  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE OR REPLACE PROCEDURE SDLC_DB.SDLC_PIPELINES.RECONCILIATION_CHECK_PROC(
    RUN_ID VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_source_count      NUMBER DEFAULT 0;
    v_target_count      NUMBER DEFAULT 0;
    v_inserted          NUMBER DEFAULT 0;
    v_updated           NUMBER DEFAULT 0;
    v_soft_deleted      NUMBER DEFAULT 0;
    v_discrepancy       NUMBER DEFAULT 0;
    v_status            VARCHAR DEFAULT 'PASS';
    v_details           VARCHAR DEFAULT '';
    v_result            VARCHAR;
BEGIN
    -- FR-08/BR-09: Count records in deduplicated source view
    SELECT COUNT(1)
    INTO v_source_count
    FROM SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED_VW;

    -- BR-09: Count records in target table (all statuses)
    SELECT COUNT(1)
    INTO v_target_count
    FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET;

    -- BR-09: Retrieve inserted and updated counts from MERGE temp table
    SELECT COALESCE(SUM(INSERTED), 0), COALESCE(SUM(UPDATED), 0)
    INTO v_inserted, v_updated
    FROM SDLC_DB.SDLC_PIPELINES.MERGE_COUNTS_TMP
    WHERE RUN_ID = :RUN_ID;

    -- BR-09: Retrieve soft-deleted count from soft-delete temp table
    SELECT COALESCE(SUM(SOFT_DELETED), 0)
    INTO v_soft_deleted
    FROM SDLC_DB.SDLC_PIPELINES.SOFT_DELETE_COUNTS_TMP
    WHERE RUN_ID = :RUN_ID;

    -- BR-09: Discrepancy = source_count minus (inserted + updated) should be 0 for a clean run
    v_discrepancy := v_source_count - (v_inserted + v_updated);

    -- BR-09: Determine reconciliation status
    IF (v_discrepancy <> 0) THEN
        v_status  := 'FAIL';
        v_details := 'Discrepancy detected: SOURCE_COUNT=' || v_source_count
                     || ' INSERTED+UPDATED=' || (v_inserted + v_updated)
                     || ' DELTA=' || v_discrepancy;
    ELSE
        v_status  := 'PASS';
        v_details := 'Reconciliation passed. All source records accounted for.';
    END IF;

    -- BR-09: Insert reconciliation record into ETL_RECONCILIATION_LOG
    INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
        RUN_ID,
        EXECUTION_TS,
        SOURCE_COUNT,
        TARGET_COUNT,
        INSERTED,
        UPDATED,
        SOFT_DELETED,
        RECONCILIATION_STATUS,
        DETAILS
    ) VALUES (
        :RUN_ID,
        CURRENT_TIMESTAMP(),
        :v_source_count,
        :v_target_count,
        :v_inserted,
        :v_updated,
        :v_soft_deleted,
        :v_status,
        :v_details
    );

    v_result := 'RECONCILIATION COMPLETE: STATUS=' || v_status
                || ' SOURCE=' || v_source_count
                || ' TARGET=' || v_target_count
                || ' INSERTED=' || v_inserted
                || ' UPDATED=' || v_updated
                || ' SOFT_DELETED=' || v_soft_deleted;
    RETURN v_result;

EXCEPTION
    WHEN OTHER THEN
        -- Log failure to reconciliation log even on error
        INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
            RUN_ID, EXECUTION_TS, SOURCE_COUNT, TARGET_COUNT,
            INSERTED, UPDATED, SOFT_DELETED, RECONCILIATION_STATUS, DETAILS
        ) VALUES (
            :RUN_ID, CURRENT_TIMESTAMP(), 0, 0, 0, 0, 0,
            'FAIL', 'RECONCILIATION_CHECK_PROC exception: ' || SQLERRM
        );
        RETURN 'FAILED RECONCILIATION_CHECK_PROC: ' || SQLERRM;
END;
$$
;
