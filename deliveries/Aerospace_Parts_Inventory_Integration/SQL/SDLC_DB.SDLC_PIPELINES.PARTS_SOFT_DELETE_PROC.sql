-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.PARTS_SOFT_DELETE_PROC
-- Object Type   : PROCEDURE
-- Jira Story    : SCRUM-156
-- Requirements  : FR-04
-- Reuse Route   : CREATE_NEW
-- Description   : Stored procedure that identifies target records whose PART_NUMBER is absent from the current source extract and sets their STATUS to 'Decommissioned' (BR-05). Returns soft-delete count.
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
--   - SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED_VW
-- Business Rules: BR-05
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-156  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE OR REPLACE PROCEDURE SDLC_DB.SDLC_PIPELINES.PARTS_SOFT_DELETE_PROC(
    RUN_ID VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_soft_deleted  NUMBER DEFAULT 0;
    v_result        VARCHAR;
BEGIN
    -- FR-04/BR-05: Soft-delete target records absent from current source extract
    -- Identify PART_NUMBERs in target that do NOT exist in the deduplicated source view
    UPDATE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET AS TGT
    SET
        TGT.STATUS           = 'Decommissioned',
        TGT.LAST_MODIFIED_TS = CURRENT_TIMESTAMP()
    WHERE
        -- BR-05: PART_NUMBER not present in current source extract
        TGT.PART_NUMBER NOT IN (
            SELECT PART_NUMBER
            FROM SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED_VW
        )
        -- Only update records not already decommissioned to avoid unnecessary writes
        AND TGT.STATUS <> 'Decommissioned';

    -- Capture the number of rows affected by the soft-delete UPDATE
    v_soft_deleted := SQLROWCOUNT;

    -- Persist soft-delete count for reconciliation
    CREATE OR REPLACE TEMPORARY TABLE SDLC_DB.SDLC_PIPELINES.SOFT_DELETE_COUNTS_TMP (
        RUN_ID       VARCHAR,
        SOFT_DELETED NUMBER
    );
    INSERT INTO SDLC_DB.SDLC_PIPELINES.SOFT_DELETE_COUNTS_TMP (RUN_ID, SOFT_DELETED)
    VALUES (:RUN_ID, :v_soft_deleted);

    v_result := 'SOFT_DELETE COMPLETE: SOFT_DELETED=' || v_soft_deleted;
    RETURN v_result;

EXCEPTION
    WHEN OTHER THEN
        RETURN 'FAILED PARTS_SOFT_DELETE_PROC: ' || SQLERRM;
END;
$$
;
