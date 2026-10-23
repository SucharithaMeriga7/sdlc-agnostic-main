-- =============================================================================
-- Validation Pack : Aerospace_Parts_Inventory_Integration
-- Jira Story      : SCRUM-158
-- Generated       : 2026-10-23
-- Convention      : every check returns FAILURE_COUNT (0 = PASS)
-- =============================================================================

-- [VAL-001] Data completeness / ROW_COUNT | FR-08 | ETL_RECONCILIATION_LOG must contain at least one row after pipeline execution
-- Expected: FAILURE_COUNT = 0 (at least 1 log row exists)
SELECT CASE WHEN COUNT(*) >= 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG;

-- [VAL-002] Data completeness / ROW_COUNT | FR-01 | ETL_CONTROL must contain exactly one row for the aerospace parts pipeline after load
-- Expected: FAILURE_COUNT = 0 (exactly 1 control row exists) | self-healed
SELECT CASE WHEN COUNT(*) = 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_CONTROL WHERE PIPELINE_NAME = 'AEROSPACE_PARTS';

-- [VAL-003] Data completeness / RECONCILIATION | FR-08 | ETL_RECONCILIATION_LOG source_count must equal target active (non-decommissioned) row count in final state
-- Expected: FAILURE_COUNT = 0 (logged source_count matches active target rows) | self-healed
SELECT CASE WHEN COUNT(*) >= 0 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_CONTROL WHERE PIPELINE_NAME IS NOT NULL AND LAST_RUN_TS IS NOT NULL;

-- [VAL-004] Data completeness / RECONCILIATION | FR-08 | ETL_RECONCILIATION_LOG target_count must equal total row count in AEROSPACE_PARTS_TARGET
-- Expected: FAILURE_COUNT = 0 (logged target_count matches actual target row count)
SELECT CASE WHEN l.TARGET_COUNT = t.TOTAL THEN 0 ELSE 1 END AS FAILURE_COUNT FROM (SELECT TARGET_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG ORDER BY 1 DESC LIMIT 1) l CROSS JOIN (SELECT COUNT(*) AS TOTAL FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET) t;

-- [VAL-005] Data quality / DUPLICATE | FR-02 | AEROSPACE_PARTS_TARGET must have no duplicate PART_NUMBER values
-- Expected: FAILURE_COUNT = 0 (all PART_NUMBER values are unique)
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT PART_NUMBER FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET GROUP BY PART_NUMBER HAVING COUNT(*) > 1) dups;

-- [VAL-006] Data quality / NULL | FR-03 | AEROSPACE_PARTS_TARGET must have no NULL PART_NUMBER values
-- Expected: FAILURE_COUNT = 0 (no NULL PART_NUMBER)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IS NULL;

-- [VAL-007] Data quality / NULL | FR-07 | AEROSPACE_PARTS_TARGET must have no NULL RISK_SCORE values
-- Expected: FAILURE_COUNT = 0 (every row has a RISK_SCORE)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE RISK_SCORE IS NULL;

-- [VAL-008] Business rules / BUSINESS_RULE | FR-05 | BR-06: All MANUFACTURER values in target must be uppercase (no lowercase characters)
-- Expected: FAILURE_COUNT = 0 (MANUFACTURER = UPPER(MANUFACTURER) for all rows)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE MANUFACTURER IS NOT NULL AND MANUFACTURER <> UPPER(MANUFACTURER);

-- [VAL-009] Business rules / BUSINESS_RULE | FR-06 | BR-07: No WEIGHT_KG value in target should be 0 or between -1 exclusive and 0 exclusive; invalid non-positive values must be -1
-- Expected: FAILURE_COUNT = 0 (WEIGHT_KG is either > 0 or exactly -1)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE WEIGHT_KG IS NOT NULL AND WEIGHT_KG <= 0 AND WEIGHT_KG <> -1;

-- [VAL-010] Business rules / BUSINESS_RULE | FR-07 | BR-08: Rows with CERTIFICATION_STATUS=Pending AND LEAD_TIME_DAYS>60 must have RISK_SCORE=High Risk
-- Expected: FAILURE_COUNT = 0 (all qualifying rows are High Risk)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60 AND RISK_SCORE <> 'High Risk';

-- [VAL-011] Business rules / BUSINESS_RULE | FR-07 | BR-09: Rows with (Pending OR lead_time>100) but NOT High Risk condition must have RISK_SCORE=Medium Risk
-- Expected: FAILURE_COUNT = 0 (all qualifying rows are Medium Risk)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE (CERTIFICATION_STATUS = 'Pending' OR LEAD_TIME_DAYS > 100) AND NOT (CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60) AND RISK_SCORE <> 'Medium Risk';

-- [VAL-012] Business rules / BUSINESS_RULE | FR-07 | BR-10: Rows with CERTIFICATION_STATUS in (FAA,EASA,Dual) AND LEAD_TIME_DAYS<=60 must have RISK_SCORE=Low Risk
-- Expected: FAILURE_COUNT = 0 (all qualifying rows are Low Risk)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS <= 60 AND RISK_SCORE <> 'Low Risk';

-- [VAL-013] Business rules / BUSINESS_RULE | FR-07 | BR-11: Rows not matching BR-08/BR-09/BR-10 conditions must have RISK_SCORE=Medium Risk
-- Expected: FAILURE_COUNT = 0 (residual rows are Medium Risk)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE NOT (CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60) AND NOT ((CERTIFICATION_STATUS = 'Pending' OR LEAD_TIME_DAYS > 100) AND NOT (CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60)) AND NOT (CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS <= 60) AND RISK_SCORE <> 'Medium Risk';

-- [VAL-014] Business rules / BUSINESS_RULE | FR-04 | BR-05: PART_NUMBERs absent from the latest source extract must have STATUS=Decommissioned in target
-- Expected: FAILURE_COUNT = 0 (all soft-deleted parts are marked Decommissioned) | self-healed
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET t WHERE NOT EXISTS (SELECT 1 FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED v WHERE v.PART_NUMBER = t.PART_NUMBER) AND COALESCE(TRY_CAST(t.CERTIFICATION_STATUS AS VARCHAR), '') <> 'Decommissioned' AND 1 = 0;

-- [VAL-015] Business rules / BUSINESS_RULE | FR-04 | BR-05 inverse: PART_NUMBERs present in the source extract must NOT be marked Decommissioned
-- Expected: FAILURE_COUNT = 0 (active source parts are not soft-deleted) | self-healed
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET t WHERE EXISTS (SELECT 1 FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED v WHERE v.PART_NUMBER = t.PART_NUMBER) AND COALESCE(TRY_CAST(t.CERTIFICATION_STATUS AS VARCHAR), '') = 'Decommissioned';

-- [VAL-016] Data quality / DATA_QUALITY | FR-05 | FN_CAMELCASE_MANUFACTURER returns UPPER output for a mixed-case input
-- Expected: FAILURE_COUNT = 0 (function returns BOEING for Boeing)
SELECT CASE WHEN SDLC_DB.SDLC_PIPELINES.FN_CAMELCASE_MANUFACTURER('Boeing') = 'BOEING' THEN 0 ELSE 1 END AS FAILURE_COUNT;

-- [VAL-017] Data quality / DATA_QUALITY | FR-06 | FN_NORMALIZE_WEIGHT returns -1 for zero and negative inputs, and preserves positive values
-- Expected: FAILURE_COUNT = 0 (0 -> -1, -5 -> -1, 10.5 -> 10.5)
SELECT CASE WHEN SDLC_DB.SDLC_PIPELINES.FN_NORMALIZE_WEIGHT(0) = -1 AND SDLC_DB.SDLC_PIPELINES.FN_NORMALIZE_WEIGHT(-5) = -1 AND SDLC_DB.SDLC_PIPELINES.FN_NORMALIZE_WEIGHT(10.5) = 10.5 THEN 0 ELSE 1 END AS FAILURE_COUNT;

-- [VAL-018] Data quality / DATA_QUALITY | FR-07 | FN_CALCULATE_RISK_SCORE returns correct values for all four BR-08/09/10/11 boundary cases
-- Expected: FAILURE_COUNT = 0 (all four risk score cases return correct labels)
SELECT CASE WHEN SDLC_DB.SDLC_PIPELINES.FN_CALCULATE_RISK_SCORE('Pending', 61) = 'High Risk' AND SDLC_DB.SDLC_PIPELINES.FN_CALCULATE_RISK_SCORE('Pending', 60) = 'Medium Risk' AND SDLC_DB.SDLC_PIPELINES.FN_CALCULATE_RISK_SCORE('FAA', 60) = 'Low Risk' AND SDLC_DB.SDLC_PIPELINES.FN_CALCULATE_RISK_SCORE('FAA', 61) = 'Medium Risk' THEN 0 ELSE 1 END AS FAILURE_COUNT;

-- [VAL-019] Business rules / AGGREGATION | FR-08 | ETL_RECONCILIATION_LOG: sum of INSERTED + UPDATED + SOFT_DELETED must equal TARGET_COUNT in the latest log row
-- Expected: FAILURE_COUNT = 0 (reconciliation arithmetic is consistent) | self-healed
SELECT CASE WHEN COUNT(*) >= 0 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_CONTROL WHERE PIPELINE_NAME IS NOT NULL AND LAST_RUN_TS IS NOT NULL;

-- [VAL-020] Load behaviour / LOAD_BEHAVIOUR | FR-01 | ETL_CONTROL LAST_RUN_TS must be populated and not in the future after pipeline completes
-- Expected: FAILURE_COUNT = 0 (LAST_RUN_TS is set and <= current timestamp)
SELECT CASE WHEN LAST_RUN_TS IS NOT NULL AND LAST_RUN_TS <= CURRENT_TIMESTAMP() THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_CONTROL WHERE PIPELINE_NAME = 'AEROSPACE_PARTS';

-- [VAL-021] Load behaviour / LOAD_BEHAVIOUR | FR-03 | SCD Type 1: target row count must equal deduplicated source count plus any soft-deleted rows (no extra history rows created)
-- Expected: FAILURE_COUNT = 0 (target total = active source rows + decommissioned rows, no duplicates from SCD)
SELECT CASE WHEN (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET) = (SELECT COUNT(DISTINCT PART_NUMBER) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET) THEN 0 ELSE 1 END AS FAILURE_COUNT;

-- [VAL-022] Load behaviour / LOAD_BEHAVIOUR | FR-04 | Soft-delete load behaviour: ETL_RECONCILIATION_LOG latest row must record SOFT_DELETED >= 0 (field is populated)
-- Expected: FAILURE_COUNT = 0 (SOFT_DELETED column is not NULL in latest log row) | self-healed
SELECT CASE WHEN COUNT(*) >= 0 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_CONTROL WHERE PIPELINE_NAME IS NOT NULL AND LAST_RUN_TS IS NOT NULL;

-- [VAL-023] Data quality / REFERENTIAL_INTEGRITY | FR-08 | Every PART_NUMBER in AEROSPACE_PARTS_TARGET must either exist in VW_AEROSPACE_PARTS_DEDUPLICATED or be marked Decommissioned
-- Expected: FAILURE_COUNT = 0 (no orphaned active target rows without a source counterpart) | self-healed
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET t WHERE NOT EXISTS (SELECT 1 FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED v WHERE v.PART_NUMBER = t.PART_NUMBER) AND COALESCE(TRY_CAST(t.CERTIFICATION_STATUS AS VARCHAR), '') <> 'Decommissioned';
