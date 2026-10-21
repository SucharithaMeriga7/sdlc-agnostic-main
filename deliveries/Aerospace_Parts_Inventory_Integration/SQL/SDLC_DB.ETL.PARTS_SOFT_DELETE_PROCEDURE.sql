-- =============================================================================
-- Object        : SDLC_DB.ETL.PARTS_SOFT_DELETE_PROCEDURE
-- Object Type   : PROCEDURE
-- Jira Story    : SCRUM-156
-- Requirements  : FR-04
-- Reuse Decision: CREATE_NEW
-- Description   : Identifies PART_NUMBERs present in PARTS_TARGET but absent from the current source extract and sets their STATUS to 'Decommissioned' per BR-05.
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - SDLC_DB.ETL.PARTS_TARGET
--   - SDLC_DB.ETL.PARTS_DEDUPLICATE_VIEW
-- Business Rules: BR-05
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-156  Initial generation (CREATE_NEW)
-- =============================================================================

-- ============================================================
-- PROCEDURE: SDLC_DB.ETL.PARTS_SOFT_DELETE_PROCEDURE
-- Purpose  : Soft-delete parts absent from current source (BR-05)
-- FR-04    : Sets STATUS = 'Decommissioned' for missing parts
-- Returns  : Number of rows soft-deleted as VARCHAR
-- ============================================================
CREATE OR REPLACE PROCEDURE SDLC_DB.ETL.PARTS_SOFT_DELETE_PROCEDURE(
    EXECUTION_ID VARCHAR  -- Passed from orchestrating task for traceability
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_soft_deleted_count NUMBER DEFAULT 0;
    v_error_message      VARCHAR DEFAULT '';
BEGIN
    -- --------------------------------------------------------
    -- BR-05: Update STATUS to 'Decommissioned' for any
    -- PART_NUMBER in the target that does NOT appear in the
    -- current deduplicated source extract.
    -- Only rows currently Active are eligible to avoid
    -- redundant updates on already-decommissioned parts.
    -- --------------------------------------------------------
    UPDATE SDLC_DB.ETL.PARTS_TARGET AS tgt
    SET
        STATUS             = 'Decommissioned',
        ETL_LOAD_TIMESTAMP = CURRENT_TIMESTAMP()
    WHERE tgt.STATUS != 'Decommissioned'  -- Skip already soft-deleted rows
      AND NOT EXISTS (
          -- Anti-join: part absent from current source extract
          SELECT 1
          FROM SDLC_DB.ETL.PARTS_DEDUPLICATE_VIEW AS src
          WHERE src.PART_NUMBER = tgt.PART_NUMBER
      );

    -- Capture row count for reconciliation logging
    v_soft_deleted_count := SQLROWCOUNT;

    RETURN 'Soft-deleted rows: ' || v_soft_deleted_count::VARCHAR;

EXCEPTION
    WHEN OTHER THEN
        v_error_message := 'PARTS_SOFT_DELETE_PROCEDURE failed. SQLCODE=' ||
                           SQLCODE::VARCHAR || ' SQLERRM=' || SQLERRM;
        -- Surface error to calling task for visibility
        RAISE;
END;
$$;
