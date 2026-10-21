-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.SP_LOAD_AEROSPACE_PARTS_SCD1
-- Object Type   : PROCEDURE
-- Jira Story    : SCRUM-158
-- Requirements  : FR-09
-- Reuse Route   : CREATE_NEW
-- Description   : Orchestration stored procedure that runs the full aerospace parts pipeline: incremental DT refresh, deduplication (view), transformation+filter (view), risk scoring (view), SCD1 merge, soft delete, and reconciliation logging.
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.PARTS_INCREMENTAL_DT
--   - SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED_VW
--   - SDLC_DB.SDLC_PIPELINES.PARTS_TRANSFORM_VW
--   - SDLC_DB.SDLC_PIPELINES.PARTS_RISK_SCORE_VW
--   - SDLC_DB.SDLC_PIPELINES.PARTS_SCD1_MERGE_PROC
--   - SDLC_DB.SDLC_PIPELINES.PARTS_SOFT_DELETE_PROC
--   - SDLC_DB.SDLC_PIPELINES.RECONCILIATION_CHECK_PROC
-- Business Rules: BR-01, BR-02, BR-03, BR-04, BR-05, BR-06, BR-07, BR-08, BR-09, BR-10, BR-11, BR-12, BR-13, BR-14
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

-- CREATE_NEW: SP_LOAD_AEROSPACE_PARTS_SCD1
-- Orchestrates the full aerospace parts pipeline per FR-09.
CREATE OR REPLACE PROCEDURE SDLC_DB.SDLC_PIPELINES.SP_LOAD_AEROSPACE_PARTS_SCD1()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_step          VARCHAR DEFAULT 'INIT';
    v_summary       VARCHAR DEFAULT '';
    v_src_count     NUMBER  DEFAULT 0;
    v_tgt_count     NUMBER  DEFAULT 0;
BEGIN
    -- ----------------------------------------------------------------
    -- STEP 1: Refresh the incremental dynamic table (FR-01, BR-01, BR-02)
    -- ----------------------------------------------------------------
    v_step := 'STEP1_REFRESH_INCREMENTAL_DT';
    ALTER DYNAMIC TABLE SDLC_DB.SDLC_PIPELINES.PARTS_INCREMENTAL_DT REFRESH;
    v_summary := :v_summary || 'STEP1:PARTS_INCREMENTAL_DT refreshed; ';

    -- ----------------------------------------------------------------
    -- STEP 2: Deduplication view is query-time (FR-02, BR-03).
    -- ----------------------------------------------------------------
    v_step := 'STEP2_DEDUP_VIEW_READY';
    v_summary := :v_summary || 'STEP2:PARTS_DEDUPLICATED_VW ready (query-time); ';

    -- ----------------------------------------------------------------
    -- STEP 3: Transformation + BR-09 filter view is query-time (FR-05, FR-06).
    -- ----------------------------------------------------------------
    v_step := 'STEP3_TRANSFORM_VIEW_READY';
    v_summary := :v_summary || 'STEP3:PARTS_TRANSFORM_VW ready (query-time); ';

    -- ----------------------------------------------------------------
    -- STEP 4: Risk score view is query-time (FR-07, BR-10..BR-13).
    -- ----------------------------------------------------------------
    v_step := 'STEP4_RISK_SCORE_VIEW_READY';
    v_summary := :v_summary || 'STEP4:PARTS_RISK_SCORE_VW ready (query-time); ';

    -- ----------------------------------------------------------------
    -- STEP 5: SCD Type 1 MERGE upsert into AEROSPACE_PARTS_TARGET
    -- (FR-03, BR-04). Source is deduplicated + transformed + filtered.
    -- BR-08: Use FLOOR(x*100+0.5)/100 for half-away-from-zero rounding
    --        to ensure 85000.005->85000.01 and 2100.1234->2100.12.
    -- ----------------------------------------------------------------
    v_step := 'STEP5_SCD1_MERGE';
    MERGE INTO SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET AS tgt
    USING (
        SELECT
            src.PART_NUMBER,
            src.PART_NAME,
            -- BR-06: uppercase manufacturer
            UPPER(src.MANUFACTURER)                                          AS MANUFACTURER,
            src.CATEGORY,
            -- BR-07: zero/negative weight -> NULL
            IFF(src.WEIGHT_KG <= 0, NULL, src.WEIGHT_KG)                    AS WEIGHT_KG,
            -- BR-08: half-away-from-zero rounding to 2 dp
            CAST(FLOOR(src.UNIT_PRICE_USD * 100 + 0.5) / 100 AS NUMBER(15,2)) AS UNIT_PRICE_USD,
            src.QUANTITY_ON_HAND,
            src.REORDER_LEVEL,
            src.LIFECYCLE_STATUS,
            src.CERTIFICATION_STATUS,
            src.INSTALLATION_DATE,
            src.LEAD_TIME_DAYS,
            src.SUPPLIER,
            src.WAREHOUSE_LOCATION,
            src.COUNTRY_OF_ORIGIN,
            src.CREATED_AT,
            src.UPDATED_AT,
            -- BR-10: Pending AND lead_time > 90 => High Risk
            -- BR-11: Pending OR lead_time > 120  => Medium Risk (after BR-10)
            -- BR-12: FAA/EASA/Dual AND <= 60     => Low Risk
            -- BR-13: all others                  => Medium Risk
            CASE
                WHEN src.CERTIFICATION_STATUS = 'Pending'
                     AND src.LEAD_TIME_DAYS > 90                  THEN 'High Risk'
                WHEN src.CERTIFICATION_STATUS = 'Pending'
                     OR  src.LEAD_TIME_DAYS > 120                 THEN 'Medium Risk'
                WHEN src.CERTIFICATION_STATUS IN ('FAA','EASA','Dual')
                     AND src.LEAD_TIME_DAYS <= 60                 THEN 'Low Risk'
                ELSE 'Medium Risk'
            END                                                              AS RISK_SCORE
        FROM (
            -- Deduplicate: keep latest UPDATED_AT per PART_NUMBER
            SELECT
                PART_NUMBER, PART_NAME, MANUFACTURER, CATEGORY, WEIGHT_KG,
                UNIT_PRICE_USD, QUANTITY_ON_HAND, REORDER_LEVEL, LIFECYCLE_STATUS,
                CERTIFICATION_STATUS, INSTALLATION_DATE, LEAD_TIME_DAYS, SUPPLIER,
                WAREHOUSE_LOCATION, COUNTRY_OF_ORIGIN, CREATED_AT, UPDATED_AT
            FROM IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE
            QUALIFY ROW_NUMBER() OVER (
                PARTITION BY PART_NUMBER ORDER BY UPDATED_AT DESC
            ) = 1
        ) AS src
        WHERE
            -- BR-09 (FR-06): Exclude End-of-Life records older than 3 years
            NOT (
                src.LIFECYCLE_STATUS = 'End of Life'
                AND src.INSTALLATION_DATE < DATEADD(YEAR, -3, CURRENT_DATE())
            )
    ) AS src
    ON tgt.PART_NUMBER = src.PART_NUMBER
    WHEN MATCHED THEN UPDATE SET
        tgt.PART_NAME            = src.PART_NAME,
        tgt.MANUFACTURER         = src.MANUFACTURER,
        tgt.CATEGORY             = src.CATEGORY,
        tgt.WEIGHT_KG            = src.WEIGHT_KG,
        tgt.UNIT_PRICE_USD       = src.UNIT_PRICE_USD,
        tgt.QUANTITY_ON_HAND     = src.QUANTITY_ON_HAND,
        tgt.REORDER_LEVEL        = src.REORDER_LEVEL,
        tgt.LIFECYCLE_STATUS     = src.LIFECYCLE_STATUS,
        tgt.CERTIFICATION_STATUS = src.CERTIFICATION_STATUS,
        tgt.INSTALLATION_DATE    = src.INSTALLATION_DATE,
        tgt.LEAD_TIME_DAYS       = src.LEAD_TIME_DAYS,
        tgt.SUPPLIER             = src.SUPPLIER,
        tgt.WAREHOUSE_LOCATION   = src.WAREHOUSE_LOCATION,
        tgt.COUNTRY_OF_ORIGIN    = src.COUNTRY_OF_ORIGIN,
        tgt.CREATED_AT           = src.CREATED_AT,
        tgt.UPDATED_AT           = src.UPDATED_AT,
        tgt.RISK_SCORE           = src.RISK_SCORE
    WHEN NOT MATCHED THEN INSERT (
        PART_NUMBER, PART_NAME, MANUFACTURER, CATEGORY, WEIGHT_KG,
        UNIT_PRICE_USD, QUANTITY_ON_HAND, REORDER_LEVEL, LIFECYCLE_STATUS,
        CERTIFICATION_STATUS, INSTALLATION_DATE, LEAD_TIME_DAYS, SUPPLIER,
        WAREHOUSE_LOCATION, COUNTRY_OF_ORIGIN, CREATED_AT, UPDATED_AT, RISK_SCORE
    ) VALUES (
        src.PART_NUMBER, src.PART_NAME, src.MANUFACTURER, src.CATEGORY, src.WEIGHT_KG,
        src.UNIT_PRICE_USD, src.QUANTITY_ON_HAND, src.REORDER_LEVEL, src.LIFECYCLE_STATUS,
        src.CERTIFICATION_STATUS, src.INSTALLATION_DATE, src.LEAD_TIME_DAYS, src.SUPPLIER,
        src.WAREHOUSE_LOCATION, src.COUNTRY_OF_ORIGIN, src.CREATED_AT, src.UPDATED_AT, src.RISK_SCORE
    );
    v_summary := :v_summary || 'STEP5:SCD1 MERGE executed; ';

    -- ----------------------------------------------------------------
    -- STEP 6: Soft delete (FR-04, BR-05).
    -- Set LIFECYCLE_STATUS = 'Decommissioned' for any PART_NUMBER in
    -- AEROSPACE_PARTS_TARGET that is absent from the current source
    -- extract (after dedup). Parts excluded by BR-09 are also absent
    -- from the MERGE source and must be decommissioned.
    -- ----------------------------------------------------------------
    v_step := 'STEP6_SOFT_DELETE';
    UPDATE SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET AS tgt
    SET tgt.LIFECYCLE_STATUS = 'Decommissioned'
    WHERE tgt.LIFECYCLE_STATUS <> 'Decommissioned'
      AND NOT EXISTS (
          SELECT 1
          FROM (
              SELECT PART_NUMBER
              FROM IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE
              QUALIFY ROW_NUMBER() OVER (
                  PARTITION BY PART_NUMBER ORDER BY UPDATED_AT DESC
              ) = 1
          ) AS current_src
          WHERE current_src.PART_NUMBER = tgt.PART_NUMBER
      );
    v_summary := :v_summary || 'STEP6:Soft delete executed; ';

    -- ----------------------------------------------------------------
    -- STEP 7: Reconciliation logging (FR-08, BR-14).
    -- Insert one row per pipeline run into ETL_RECONCILIATION_LOG.
    -- ----------------------------------------------------------------
    v_step := 'STEP7_RECONCILIATION';
    v_src_count := (SELECT COUNT(*) FROM IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE);
    v_tgt_count := (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET);
    INSERT INTO SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG (
        RUN_TIMESTAMP,
        SOURCE_COUNT,
        TARGET_COUNT,
        PIPELINE_NAME
    ) VALUES (
        CURRENT_TIMESTAMP(),
        :v_src_count,
        :v_tgt_count,
        'SP_LOAD_AEROSPACE_PARTS_SCD1'
    );
    v_summary := :v_summary || 'STEP7:Reconciliation log inserted; ';

    -- ----------------------------------------------------------------
    -- All steps completed successfully
    -- ----------------------------------------------------------------
    RETURN 'SUCCESS: ' || :v_summary;

EXCEPTION
    WHEN OTHER THEN
        LET err_msg   VARCHAR := SQLERRM;
        LET err_code  VARCHAR := SQLCODE;
        LET err_state VARCHAR := SQLSTATE;
        RETURN 'FAILED at ' || :v_step
            || ' | SQLCODE='  || :err_code
            || ' | SQLSTATE=' || :err_state
            || ' | SQLERRM='  || :err_msg;
END;
$$;
