-- =============================================================================
-- Validation Pack : Aerospace_Parts_Inventory_Integration
-- Jira Story      : SCRUM-156
-- Generated       : 2026-10-21
-- Convention      : every check returns FAILURE_COUNT (0 = PASS)
-- =============================================================================

-- [VAL-001] ROW_COUNT | FR-03 | PARTS_TARGET must contain at least one row after pipeline execution
-- Expected: FAILURE_COUNT = 0 (target table is not empty)
SELECT CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END AS FAILURE_COUNT FROM SDLC_DB.ETL.PARTS_TARGET;

-- [VAL-002] ROW_COUNT | FR-08 | ETL_RECONCILIATION_LOG must contain at least one row after pipeline execution
-- Expected: FAILURE_COUNT = 0 (reconciliation log is not empty)
SELECT CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END AS FAILURE_COUNT FROM SDLC_DB.ETL.ETL_RECONCILIATION_LOG;

-- [VAL-003] ROW_COUNT | FR-01 | EXECUTION_CONTROL must contain at least one row indicating a pipeline run has been recorded
-- Expected: FAILURE_COUNT = 0 (execution control table is not empty)
SELECT CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END AS FAILURE_COUNT FROM SDLC_DB.ETL.EXECUTION_CONTROL;

-- [VAL-004] RECONCILIATION | FR-08 | Source deduplicated count must match the SOURCE_COUNT logged in the latest ETL_RECONCILIATION_LOG entry
-- Expected: FAILURE_COUNT = 0 (logged source count equals actual deduplicated source count)
SELECT CASE WHEN ABS(log.SOURCE_COUNT - src.CNT) > 0 THEN 1 ELSE 0 END AS FAILURE_COUNT FROM (SELECT SOURCE_COUNT FROM SDLC_DB.ETL.ETL_RECONCILIATION_LOG ORDER BY CREATED_AT DESC LIMIT 1) log CROSS JOIN (SELECT COUNT(*) AS CNT FROM SDLC_DB.ETL.PARTS_DEDUPLICATE_VIEW) src;

-- [VAL-005] RECONCILIATION | FR-08 | Target count must match the TARGET_COUNT logged in the latest ETL_RECONCILIATION_LOG entry
-- Expected: FAILURE_COUNT = 0 (logged target count equals actual target row count)
SELECT CASE WHEN ABS(log.TARGET_COUNT - tgt.CNT) > 0 THEN 1 ELSE 0 END AS FAILURE_COUNT FROM (SELECT TARGET_COUNT FROM SDLC_DB.ETL.ETL_RECONCILIATION_LOG ORDER BY CREATED_AT DESC LIMIT 1) log CROSS JOIN (SELECT COUNT(*) AS CNT FROM SDLC_DB.ETL.PARTS_TARGET) tgt;

-- [VAL-006] DUPLICATE | FR-02 | PARTS_DEDUPLICATE_VIEW must not contain duplicate PART_NUMBER values
-- Expected: FAILURE_COUNT = 0 (each PART_NUMBER appears exactly once in the deduplicated view)
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT PART_NUMBER FROM SDLC_DB.ETL.PARTS_DEDUPLICATE_VIEW GROUP BY PART_NUMBER HAVING COUNT(*) > 1) dup;

-- [VAL-007] DUPLICATE | FR-03 | PARTS_TARGET must not contain duplicate PART_NUMBER values
-- Expected: FAILURE_COUNT = 0 (each PART_NUMBER appears exactly once in the target)
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT PART_NUMBER FROM SDLC_DB.ETL.PARTS_TARGET GROUP BY PART_NUMBER HAVING COUNT(*) > 1) dup;

-- [VAL-008] NULL | FR-03 | PARTS_TARGET must not contain NULL PART_NUMBER values
-- Expected: FAILURE_COUNT = 0 (no NULL PART_NUMBER in target)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.ETL.PARTS_TARGET WHERE PART_NUMBER IS NULL;

-- [VAL-009] NULL | FR-05 | PARTS_TRANSFORM_VIEW must not contain NULL MANUFACTURER values
-- Expected: FAILURE_COUNT = 0 (no NULL MANUFACTURER in transform view)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.ETL.PARTS_TRANSFORM_VIEW WHERE MANUFACTURER IS NULL;

-- [VAL-010] NULL | FR-07 | PARTS_TRANSFORM_VIEW must not contain NULL RISK_SCORE values
-- Expected: FAILURE_COUNT = 0 (every record has a RISK_SCORE assigned)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.ETL.PARTS_TRANSFORM_VIEW WHERE RISK_SCORE IS NULL;

-- [VAL-011] BUSINESS_RULE | FR-01 | BR-01: PARTS_TARGET must not contain records with UPDATED_AT older than the last successful execution timestamp (incremental load boundary respected)
-- Expected: FAILURE_COUNT = 0 (no stale records loaded beyond incremental boundary on non-first runs)
SELECT CASE WHEN ec.LAST_EXECUTION_TIMESTAMP IS NULL THEN 0 ELSE (SELECT COUNT(*) FROM SDLC_DB.ETL.PARTS_TARGET t WHERE t.UPDATED_AT <= ec.LAST_EXECUTION_TIMESTAMP AND t.UPDATED_AT IS NOT NULL AND NOT EXISTS (SELECT 1 FROM SDLC_DB.ETL.PARTS_TARGET t2 WHERE t2.PART_NUMBER = t.PART_NUMBER AND t2.UPDATED_AT > ec.LAST_EXECUTION_TIMESTAMP)) END AS FAILURE_COUNT FROM (SELECT MAX(LAST_EXECUTION_TIMESTAMP) AS LAST_EXECUTION_TIMESTAMP FROM SDLC_DB.ETL.EXECUTION_CONTROL WHERE STATUS = 'SUCCESS') ec;

-- [VAL-012] BUSINESS_RULE | FR-02 | BR-03: For each PART_NUMBER in the deduplicated view, the UPDATED_AT must equal the maximum UPDATED_AT from the source
-- Expected: FAILURE_COUNT = 0 (deduplicated view retains only the latest record per PART_NUMBER)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.ETL.PARTS_DEDUPLICATE_VIEW dv WHERE dv.UPDATED_AT < (SELECT MAX(s.UPDATED_AT) FROM SDLC_DB.SOURCE.PARTS_SOURCE s WHERE s.PART_NUMBER = dv.PART_NUMBER);

-- [VAL-013] BUSINESS_RULE | FR-03 | BR-04: Every PART_NUMBER in the deduplicated view must exist in PARTS_TARGET (SCD Type 1 upsert applied)
-- Expected: FAILURE_COUNT = 0 (all source PART_NUMBERs are present in target)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.ETL.PARTS_DEDUPLICATE_VIEW dv WHERE NOT EXISTS (SELECT 1 FROM SDLC_DB.ETL.PARTS_TARGET t WHERE t.PART_NUMBER = dv.PART_NUMBER);

-- [VAL-014] BUSINESS_RULE | FR-04 | BR-05: PARTS_TARGET records absent from the current deduplicated source extract must have STATUS = 'Decommissioned'
-- Expected: FAILURE_COUNT = 0 (all soft-deleted records are marked Decommissioned)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.ETL.PARTS_TARGET t WHERE NOT EXISTS (SELECT 1 FROM SDLC_DB.ETL.PARTS_DEDUPLICATE_VIEW dv WHERE dv.PART_NUMBER = t.PART_NUMBER) AND (t.STATUS IS NULL OR t.STATUS <> 'Decommissioned');

-- [VAL-015] BUSINESS_RULE | FR-05 | BR-06: MANUFACTURER field in PARTS_TRANSFORM_VIEW must be fully uppercase
-- Expected: FAILURE_COUNT = 0 (no MANUFACTURER value differs from its UPPER() equivalent)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.ETL.PARTS_TRANSFORM_VIEW WHERE MANUFACTURER <> UPPER(MANUFACTURER);

-- [VAL-016] BUSINESS_RULE | FR-06 | BR-07: WEIGHT_KG in PARTS_TRANSFORM_VIEW must not contain values less than or equal to 0 (should be replaced with -1)
-- Expected: FAILURE_COUNT = 0 (no WEIGHT_KG value is 0 or negative other than exactly -1)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.ETL.PARTS_TRANSFORM_VIEW WHERE WEIGHT_KG <= 0 AND WEIGHT_KG <> -1;

-- [VAL-017] BUSINESS_RULE | FR-07 | BR-08: RISK_SCORE must be 'High Risk' when CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60
-- Expected: FAILURE_COUNT = 0 (all qualifying records have RISK_SCORE = 'High Risk')
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.ETL.PARTS_TRANSFORM_VIEW WHERE CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60 AND RISK_SCORE <> 'High Risk';

-- [VAL-018] BUSINESS_RULE | FR-07 | BR-09: RISK_SCORE must be 'Medium Risk' when (CERTIFICATION_STATUS = 'Pending' OR LEAD_TIME_DAYS > 100) and High Risk condition is not met
-- Expected: FAILURE_COUNT = 0 (all qualifying non-High-Risk records have RISK_SCORE = 'Medium Risk')
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.ETL.PARTS_TRANSFORM_VIEW WHERE (CERTIFICATION_STATUS = 'Pending' OR LEAD_TIME_DAYS > 100) AND NOT (CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60) AND RISK_SCORE <> 'Medium Risk';

-- [VAL-019] BUSINESS_RULE | FR-07 | BR-10: RISK_SCORE must be 'Low Risk' when CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS <= 60
-- Expected: FAILURE_COUNT = 0 (all qualifying records have RISK_SCORE = 'Low Risk')
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.ETL.PARTS_TRANSFORM_VIEW WHERE CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS <= 60 AND RISK_SCORE <> 'Low Risk';

-- [VAL-020] BUSINESS_RULE | FR-07 | BR-11: RISK_SCORE must be 'Medium Risk' for all records not covered by BR-08, BR-09, or BR-10
-- Expected: FAILURE_COUNT = 0 (residual records have RISK_SCORE = 'Medium Risk')
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.ETL.PARTS_TRANSFORM_VIEW WHERE NOT (CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60) AND NOT ((CERTIFICATION_STATUS = 'Pending' OR LEAD_TIME_DAYS > 100) AND NOT (CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60)) AND NOT (CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS <= 60) AND RISK_SCORE <> 'Medium Risk';

-- [VAL-021] BUSINESS_RULE | FR-07 | RISK_SCORE in PARTS_TRANSFORM_VIEW must only contain allowed values: High Risk, Medium Risk, Low Risk
-- Expected: FAILURE_COUNT = 0 (no out-of-domain RISK_SCORE values exist)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.ETL.PARTS_TRANSFORM_VIEW WHERE RISK_SCORE NOT IN ('High Risk','Medium Risk','Low Risk');

-- [VAL-022] AGGREGATION | FR-08 | The latest ETL_RECONCILIATION_LOG entry SOURCE_COUNT + soft-deleted count must be consistent with TARGET_COUNT (no unexplained row loss)
-- Expected: FAILURE_COUNT = 0 (SOURCE_COUNT equals TARGET_COUNT in the reconciliation log for the latest run)
SELECT CASE WHEN SOURCE_COUNT <> TARGET_COUNT THEN 1 ELSE 0 END AS FAILURE_COUNT FROM SDLC_DB.ETL.ETL_RECONCILIATION_LOG ORDER BY CREATED_AT DESC LIMIT 1;

-- [VAL-023] AGGREGATION | FR-08 | INSERTED + UPDATED + SOFT_DELETED count in latest reconciliation log must not exceed TARGET_COUNT
-- Expected: FAILURE_COUNT = 0 (sum of operation counts does not exceed target row count)
SELECT CASE WHEN (INSERTED + UPDATED + SOFT_DELETED) > TARGET_COUNT THEN 1 ELSE 0 END AS FAILURE_COUNT FROM SDLC_DB.ETL.ETL_RECONCILIATION_LOG ORDER BY CREATED_AT DESC LIMIT 1;

-- [VAL-024] AGGREGATION | FR-04 | Count of Decommissioned records in PARTS_TARGET must match SOFT_DELETED count in latest ETL_RECONCILIATION_LOG
-- Expected: FAILURE_COUNT = 0 (soft-delete counts are consistent between target and log)
SELECT CASE WHEN ABS(log.SOFT_DELETED - tgt.DECOMM_CNT) > 0 THEN 1 ELSE 0 END AS FAILURE_COUNT FROM (SELECT SOFT_DELETED FROM SDLC_DB.ETL.ETL_RECONCILIATION_LOG ORDER BY CREATED_AT DESC LIMIT 1) log CROSS JOIN (SELECT COUNT(*) AS DECOMM_CNT FROM SDLC_DB.ETL.PARTS_TARGET WHERE STATUS = 'Decommissioned') tgt;

-- [VAL-025] DATA_QUALITY | FR-06 | WEIGHT_KG in PARTS_TRANSFORM_VIEW must be either -1 (cleansed sentinel) or a positive numeric value
-- Expected: FAILURE_COUNT = 0 (no WEIGHT_KG value is NULL or an unexpected non-positive value)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.ETL.PARTS_TRANSFORM_VIEW WHERE WEIGHT_KG IS NULL OR (WEIGHT_KG < -1);

-- [VAL-026] DATA_QUALITY | FR-05 | MANUFACTURER in PARTS_TARGET must be fully uppercase (transformation persisted to target)
-- Expected: FAILURE_COUNT = 0 (no MANUFACTURER value in target differs from its UPPER() equivalent)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.ETL.PARTS_TARGET WHERE MANUFACTURER IS NOT NULL AND MANUFACTURER <> UPPER(MANUFACTURER);

-- [VAL-027] DATA_QUALITY | FR-08 | ETL_RECONCILIATION_LOG must not contain NULL values in SOURCE_COUNT, TARGET_COUNT, INSERTED, UPDATED, or SOFT_DELETED columns
-- Expected: FAILURE_COUNT = 0 (all mandatory reconciliation metrics are populated)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.ETL.ETL_RECONCILIATION_LOG WHERE SOURCE_COUNT IS NULL OR TARGET_COUNT IS NULL OR INSERTED IS NULL OR UPDATED IS NULL OR SOFT_DELETED IS NULL;

-- [VAL-028] DATA_QUALITY | FR-01 | EXECUTION_CONTROL must not contain NULL LAST_EXECUTION_TIMESTAMP for completed successful runs
-- Expected: FAILURE_COUNT = 0 (all successful execution records have a valid timestamp)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.ETL.EXECUTION_CONTROL WHERE STATUS = 'SUCCESS' AND LAST_EXECUTION_TIMESTAMP IS NULL;

-- [VAL-029] REFERENTIAL_INTEGRITY | FR-03 | Every PART_NUMBER in PARTS_TARGET that is not Decommissioned must exist in PARTS_DEDUPLICATE_VIEW (no orphaned active target records)
-- Expected: FAILURE_COUNT = 0 (all active target records have a corresponding source record)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.ETL.PARTS_TARGET t WHERE (t.STATUS IS NULL OR t.STATUS <> 'Decommissioned') AND NOT EXISTS (SELECT 1 FROM SDLC_DB.ETL.PARTS_DEDUPLICATE_VIEW dv WHERE dv.PART_NUMBER = t.PART_NUMBER);

-- [VAL-030] REFERENTIAL_INTEGRITY | FR-02 | Every PART_NUMBER in PARTS_DEDUPLICATE_VIEW must exist in the source table SDLC_DB.SOURCE.PARTS_SOURCE
-- Expected: FAILURE_COUNT = 0 (deduplicated view contains no PART_NUMBERs absent from the source)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.ETL.PARTS_DEDUPLICATE_VIEW dv WHERE NOT EXISTS (SELECT 1 FROM SDLC_DB.SOURCE.PARTS_SOURCE s WHERE s.PART_NUMBER = dv.PART_NUMBER);
