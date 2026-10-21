-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.PARTS_SCD1_MERGE_PROC
-- Object Type   : PROCEDURE
-- Jira Story    : SCRUM-156
-- Requirements  : FR-03
-- Reuse Route   : CREATE_NEW
-- Description   : Stored procedure executing MERGE from PARTS_RISK_SCORE_VW into the target AEROSPACE_PARTS_TARGET table implementing SCD Type 1 (overwrite on match, insert on new). Returns row counts.
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.PARTS_RISK_SCORE_VW
--   - SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET
-- Business Rules: BR-04
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-156  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE OR REPLACE PROCEDURE SDLC_DB.SDLC_PIPELINES.PARTS_SCD1_MERGE_PROC(
    RUN_ID VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_inserted      NUMBER DEFAULT 0;
    v_updated       NUMBER DEFAULT 0;
    v_result        VARCHAR;
BEGIN
    -- FR-03/BR-04: SCD Type 1 MERGE using PART_NUMBER as business key
    -- MATCHED => overwrite all non-key attributes (no history retained)
    -- NOT MATCHED => insert new record
    MERGE INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET AS TGT
    USING (
        -- Source is the fully transformed and risk-scored view
        SELECT
            PART_NUMBER,
            PART_NAME,
            MANUFACTURER,
            CERTIFICATION,
            LEAD_TIME_DAYS,
            WEIGHT_KG,
            STATUS,
            RISK_SCORE,
            UPDATED_AT,
            CREATED_AT
        FROM SDLC_DB.SDLC_PIPELINES.PARTS_RISK_SCORE_VW
    ) AS SRC
    -- BR-04: Join on PART_NUMBER as the business key
    ON TGT.PART_NUMBER = SRC.PART_NUMBER
    -- BR-04: MATCHED => SCD Type 1 overwrite, no historical record preserved
    WHEN MATCHED THEN UPDATE SET
        TGT.PART_NAME       = SRC.PART_NAME,
        TGT.MANUFACTURER    = SRC.MANUFACTURER,
        TGT.CERTIFICATION   = SRC.CERTIFICATION,
        TGT.LEAD_TIME_DAYS  = SRC.LEAD_TIME_DAYS,
        TGT.WEIGHT_KG       = SRC.WEIGHT_KG,
        TGT.STATUS          = SRC.STATUS,
        TGT.RISK_SCORE      = SRC.RISK_SCORE,
        TGT.UPDATED_AT      = SRC.UPDATED_AT,
        TGT.LAST_MODIFIED_TS = CURRENT_TIMESTAMP()
    -- BR-04: NOT MATCHED => insert brand-new record
    WHEN NOT MATCHED THEN INSERT (
        PART_NUMBER,
        PART_NAME,
        MANUFACTURER,
        CERTIFICATION,
        LEAD_TIME_DAYS,
        WEIGHT_KG,
        STATUS,
        RISK_SCORE,
        UPDATED_AT,
        CREATED_AT,
        LAST_MODIFIED_TS
    ) VALUES (
        SRC.PART_NUMBER,
        SRC.PART_NAME,
        SRC.MANUFACTURER,
        SRC.CERTIFICATION,
        SRC.LEAD_TIME_DAYS,
        SRC.WEIGHT_KG,
        SRC.STATUS,
        SRC.RISK_SCORE,
        SRC.UPDATED_AT,
        SRC.CREATED_AT,
        CURRENT_TIMESTAMP()
    );

    -- Capture DML row counts from MERGE result
    SELECT
        SUM(CASE WHEN "$action" = 'INSERT' THEN 1 ELSE 0 END),
        SUM(CASE WHEN "$action" = 'UPDATE' THEN 1 ELSE 0 END)
    INTO v_inserted, v_updated
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

    -- Store counts in a temporary table for the pipeline procedure to retrieve
    CREATE OR REPLACE TEMPORARY TABLE SDLC_DB.SDLC_PIPELINES.MERGE_COUNTS_TMP (
        RUN_ID      VARCHAR,
        INSERTED    NUMBER,
        UPDATED     NUMBER
    );
    INSERT INTO SDLC_DB.SDLC_PIPELINES.MERGE_COUNTS_TMP (RUN_ID, INSERTED, UPDATED)
    VALUES (:RUN_ID, :v_inserted, :v_updated);

    v_result := 'SCD1_MERGE COMPLETE: INSERTED=' || v_inserted || ' UPDATED=' || v_updated;
    RETURN v_result;

EXCEPTION
    WHEN OTHER THEN
        RETURN 'FAILED PARTS_SCD1_MERGE_PROC: ' || SQLERRM;
END;
$$
;
