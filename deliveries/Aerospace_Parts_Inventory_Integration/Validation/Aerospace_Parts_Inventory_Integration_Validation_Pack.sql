-- =============================================================================
-- Validation Pack : Aerospace_Parts_Inventory_Integration
-- Jira Story      : SCRUM-156
-- Generated       : 2026-10-21
-- Convention      : every check returns FAILURE_COUNT (0 = PASS)
-- =============================================================================

-- [VAL-001] ROW_COUNT | FR-01 | PARTS_INCREMENTAL_DT must contain at least one row, confirming the dynamic table has been populated by either a full or incremental load.
-- Expected: FAILURE_COUNT = 0 (row count > 0)
SELECT CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS_INCREMENTAL_DT;

-- [VAL-002] RECONCILIATION | FR-01 | Row count in PARTS_INCREMENTAL_DT must not exceed the total row count in the source table AEROSPACE_PARTS_SOURCE, ensuring no phantom records were introduced.
-- Expected: FAILURE_COUNT = 0 (incremental DT count <= source count)
SELECT CASE WHEN (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.PARTS_INCREMENTAL_DT) > (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE) THEN 1 ELSE 0 END AS FAILURE_COUNT;

-- [VAL-003] BUSINESS_RULE | FR-01 | BR-01: All records in PARTS_INCREMENTAL_DT must have an UPDATED_AT value that is not NULL, as the incremental filter relies on this column.
-- Expected: FAILURE_COUNT = 0 (no NULL UPDATED_AT in incremental DT)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS_INCREMENTAL_DT WHERE UPDATED_AT IS NULL;

-- [VAL-004] DUPLICATE | FR-02 | BR-03: PARTS_DEDUPLICATED_VW must contain no duplicate PART_NUMBER values; each part number must appear exactly once.
-- Expected: FAILURE_COUNT = 0 (no duplicate PART_NUMBERs)
SELECT COALESCE(SUM(CASE WHEN cnt > 1 THEN 1 ELSE 0 END), 0) AS FAILURE_COUNT FROM (SELECT PART_NUMBER, COUNT(*) AS cnt FROM SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED_VW GROUP BY PART_NUMBER) t;

-- [VAL-005] BUSINESS_RULE | FR-02 | BR-03: For every PART_NUMBER in PARTS_DEDUPLICATED_VW, the retained UPDATED_AT must equal the maximum UPDATED_AT for that PART_NUMBER in PARTS_INCREMENTAL_DT.
-- Expected: FAILURE_COUNT = 0 (only latest record per PART_NUMBER retained)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED_VW dv WHERE dv.UPDATED_AT < (SELECT MAX(src.UPDATED_AT) FROM SDLC_DB.SDLC_PIPELINES.PARTS_INCREMENTAL_DT src WHERE src.PART_NUMBER = dv.PART_NUMBER);

-- [VAL-006] RECONCILIATION | FR-02 | Row count in PARTS_DEDUPLICATED_VW must be less than or equal to the distinct PART_NUMBER count in PARTS_INCREMENTAL_DT, confirming deduplication reduced or maintained the record set.
-- Expected: FAILURE_COUNT = 0 (deduplicated count <= distinct PART_NUMBER count in source)
SELECT CASE WHEN (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED_VW) > (SELECT COUNT(DISTINCT PART_NUMBER) FROM SDLC_DB.SDLC_PIPELINES.PARTS_INCREMENTAL_DT) THEN 1 ELSE 0 END AS FAILURE_COUNT;

-- [VAL-007] BUSINESS_RULE | FR-03 | BR-04: SCD Type 1 — PARTS_TRANSFORM_VW must not contain more than one row per PART_NUMBER, confirming no historical versions are retained.
-- Expected: FAILURE_COUNT = 0 (no PART_NUMBER appears more than once)
SELECT COALESCE(SUM(CASE WHEN cnt > 1 THEN 1 ELSE 0 END), 0) AS FAILURE_COUNT FROM (SELECT PART_NUMBER, COUNT(*) AS cnt FROM SDLC_DB.SDLC_PIPELINES.PARTS_TRANSFORM_VW GROUP BY PART_NUMBER) t;

-- [VAL-008] BUSINESS_RULE | FR-04 | BR-05: Any record in ETL_RECONCILIATION_LOG that records a soft-delete event must correspond to a PART_NUMBER that is absent from the current PARTS_DEDUPLICATED_VW extract.
-- Expected: FAILURE_COUNT = 0 (all logged soft-deleted PART_NUMBERs are absent from current extract)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG rl WHERE rl.SOFT_DELETED_COUNT > 0 AND EXISTS (SELECT 1 FROM SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED_VW dv WHERE dv.PART_NUMBER = rl.PART_NUMBER);

-- [VAL-009] BUSINESS_RULE | FR-05 | BR-06: All MANUFACTURER values in PARTS_TRANSFORM_VW must be uppercase; any record where MANUFACTURER differs from its UPPER() equivalent is a failure.
-- Expected: FAILURE_COUNT = 0 (all MANUFACTURER values are uppercase)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS_TRANSFORM_VW WHERE MANUFACTURER IS NOT NULL AND MANUFACTURER <> UPPER(MANUFACTURER);

-- [VAL-010] NULL | FR-05 | MANUFACTURER must not be NULL in PARTS_TRANSFORM_VW, as the uppercase conversion implies a non-null source value is expected.
-- Expected: FAILURE_COUNT = 0 (no NULL MANUFACTURER values)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS_TRANSFORM_VW WHERE MANUFACTURER IS NULL;

-- [VAL-011] BUSINESS_RULE | FR-06 | BR-07: No WEIGHT_KG value in PARTS_TRANSFORM_VW should be less than or equal to 0 unless it equals exactly -1 (the sentinel replacement value).
-- Expected: FAILURE_COUNT = 0 (no WEIGHT_KG <= 0 other than -1)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS_TRANSFORM_VW WHERE WEIGHT_KG <= 0 AND WEIGHT_KG <> -1;

-- [VAL-012] DATA_QUALITY | FR-06 | WEIGHT_KG must not be NULL in PARTS_TRANSFORM_VW; invalid weights should be -1, not NULL.
-- Expected: FAILURE_COUNT = 0 (no NULL WEIGHT_KG values)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS_TRANSFORM_VW WHERE WEIGHT_KG IS NULL;

-- [VAL-013] AGGREGATION | FR-06 | The count of records with WEIGHT_KG = -1 in PARTS_TRANSFORM_VW must equal the count of records in PARTS_DEDUPLICATED_VW where WEIGHT_KG was originally <= 0.
-- Expected: FAILURE_COUNT = 0 (sentinel -1 count matches original invalid weight count)
SELECT CASE WHEN (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.PARTS_TRANSFORM_VW WHERE WEIGHT_KG = -1) <> (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.PARTS_DEDUPLICATED_VW WHERE WEIGHT_KG <= 0) THEN 1 ELSE 0 END AS FAILURE_COUNT;

-- [VAL-014] BUSINESS_RULE | FR-07 | BR-08 Rule 1: Records where CERTIFICATION = 'Pending' AND LEAD_TIME > 60 must have RISK_SCORE = 'High Risk' in PARTS_RISK_SCORE_VW.
-- Expected: FAILURE_COUNT = 0 (all Pending + lead_time > 60 records are High Risk)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS_RISK_SCORE_VW WHERE CERTIFICATION = 'Pending' AND LEAD_TIME > 60 AND RISK_SCORE <> 'High Risk';

-- [VAL-015] BUSINESS_RULE | FR-07 | BR-08 Rule 2: Records where CERTIFICATION = 'Pending' OR LEAD_TIME > 100 (but not already High Risk) must have RISK_SCORE = 'Medium Risk'.
-- Expected: FAILURE_COUNT = 0 (Pending OR lead_time > 100 non-High-Risk records are Medium Risk)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS_RISK_SCORE_VW WHERE (CERTIFICATION = 'Pending' OR LEAD_TIME > 100) AND NOT (CERTIFICATION = 'Pending' AND LEAD_TIME > 60) AND RISK_SCORE <> 'Medium Risk';

-- [VAL-016] BUSINESS_RULE | FR-07 | BR-08 Rule 3: Records where CERTIFICATION IN ('FAA','EASA','Dual') AND LEAD_TIME <= 60 must have RISK_SCORE = 'Low Risk'.
-- Expected: FAILURE_COUNT = 0 (certified parts with short lead time are Low Risk)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS_RISK_SCORE_VW WHERE CERTIFICATION IN ('FAA', 'EASA', 'Dual') AND LEAD_TIME <= 60 AND RISK_SCORE <> 'Low Risk';

-- [VAL-017] BUSINESS_RULE | FR-07 | BR-08 Rule 4: All records not matching High Risk or Low Risk conditions must have RISK_SCORE = 'Medium Risk'.
-- Expected: FAILURE_COUNT = 0 (all other cases default to Medium Risk)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS_RISK_SCORE_VW WHERE NOT (CERTIFICATION = 'Pending' AND LEAD_TIME > 60) AND NOT (CERTIFICATION IN ('FAA', 'EASA', 'Dual') AND LEAD_TIME <= 60) AND RISK_SCORE NOT IN ('Medium Risk', 'High Risk');

-- [VAL-018] NULL | FR-07 | RISK_SCORE must not be NULL in PARTS_RISK_SCORE_VW; every record must be assigned a risk classification.
-- Expected: FAILURE_COUNT = 0 (no NULL RISK_SCORE values)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS_RISK_SCORE_VW WHERE RISK_SCORE IS NULL;

-- [VAL-019] DATA_QUALITY | FR-07 | RISK_SCORE values in PARTS_RISK_SCORE_VW must only contain the allowed values: 'High Risk', 'Medium Risk', or 'Low Risk'.
-- Expected: FAILURE_COUNT = 0 (no out-of-domain RISK_SCORE values)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS_RISK_SCORE_VW WHERE RISK_SCORE NOT IN ('High Risk', 'Medium Risk', 'Low Risk');

-- [VAL-020] AGGREGATION | FR-07 | The total count of records in PARTS_RISK_SCORE_VW must equal the total count in PARTS_TRANSFORM_VW, confirming no records were lost or duplicated during RISK_SCORE derivation.
-- Expected: FAILURE_COUNT = 0 (row counts match between transform and risk score views)
SELECT CASE WHEN (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.PARTS_RISK_SCORE_VW) <> (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.PARTS_TRANSFORM_VW) THEN 1 ELSE 0 END AS FAILURE_COUNT;

-- [VAL-021] BUSINESS_RULE | FR-08 | BR-09: ETL_RECONCILIATION_LOG must contain at least one entry per pipeline run date, confirming reconciliation logging occurs after every execution.
-- Expected: FAILURE_COUNT = 0 (at least one log entry exists for today's run date)
SELECT CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG WHERE CAST(RUN_TIMESTAMP AS DATE) = CURRENT_DATE();

-- [VAL-022] NULL | FR-08 | BR-09: Critical reconciliation columns (SOURCE_COUNT, TARGET_COUNT, INSERTED_COUNT, UPDATED_COUNT, SOFT_DELETED_COUNT) must not be NULL in ETL_RECONCILIATION_LOG.
-- Expected: FAILURE_COUNT = 0 (no NULL values in mandatory reconciliation metric columns)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG WHERE SOURCE_COUNT IS NULL OR TARGET_COUNT IS NULL OR INSERTED_COUNT IS NULL OR UPDATED_COUNT IS NULL OR SOFT_DELETED_COUNT IS NULL;

-- [VAL-023] RECONCILIATION | FR-08 | BR-09: For the latest pipeline run log entry, SOURCE_COUNT must equal TARGET_COUNT + SOFT_DELETED_COUNT or a logged discrepancy must exist, validating reconciliation arithmetic.
-- Expected: FAILURE_COUNT = 0 (source count reconciles with target + soft-deleted, or discrepancy is logged)
SELECT CASE WHEN SOURCE_COUNT <> (TARGET_COUNT + SOFT_DELETED_COUNT) AND (DISCREPANCY_COUNT IS NULL OR DISCREPANCY_COUNT = 0) THEN 1 ELSE 0 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG ORDER BY RUN_TIMESTAMP DESC LIMIT 1;

-- [VAL-024] DATA_QUALITY | FR-08 | All numeric count columns in ETL_RECONCILIATION_LOG must be >= 0; negative counts indicate data corruption.
-- Expected: FAILURE_COUNT = 0 (no negative values in count columns)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG WHERE SOURCE_COUNT < 0 OR TARGET_COUNT < 0 OR INSERTED_COUNT < 0 OR UPDATED_COUNT < 0 OR SOFT_DELETED_COUNT < 0;

-- [VAL-025] REFERENTIAL_INTEGRITY | FR-08 | Every PART_NUMBER referenced in ETL_RECONCILIATION_LOG (where applicable) must exist in PARTS_RISK_SCORE_VW or have a corresponding soft-delete record, ensuring log entries reference valid pipeline objects.
-- Expected: FAILURE_COUNT = 0 (no orphaned PART_NUMBER references in reconciliation log)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG rl WHERE rl.PART_NUMBER IS NOT NULL AND NOT EXISTS (SELECT 1 FROM SDLC_DB.SDLC_PIPELINES.PARTS_RISK_SCORE_VW rsv WHERE rsv.PART_NUMBER = rl.PART_NUMBER);

-- [VAL-026] BUSINESS_RULE | FR-09 | BR-10: The most recent ETL_RECONCILIATION_LOG entry must have a RUN_TIMESTAMP between 05:00 UTC and 05:05 UTC on the current date, confirming the pipeline executed within its scheduled window.
-- Expected: FAILURE_COUNT = 0 (latest run timestamp falls within the 05:00–05:05 UTC window)
SELECT CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG WHERE CAST(RUN_TIMESTAMP AS DATE) = CURRENT_DATE() AND HOUR(CONVERT_TIMEZONE('UTC', RUN_TIMESTAMP)) = 5 AND MINUTE(CONVERT_TIMEZONE('UTC', RUN_TIMESTAMP)) BETWEEN 0 AND 5;

-- [VAL-027] AGGREGATION | FR-09 | BR-10: The SOURCE_COUNT in the latest ETL_RECONCILIATION_LOG entry must not exceed 1,000,000, validating the pipeline processed within the defined record volume limit.
-- Expected: FAILURE_COUNT = 0 (source count <= 1,000,000)
SELECT CASE WHEN SOURCE_COUNT > 1000000 THEN 1 ELSE 0 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG ORDER BY RUN_TIMESTAMP DESC LIMIT 1;
